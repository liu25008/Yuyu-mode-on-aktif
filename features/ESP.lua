-- features/ESP.lua
-- Halaman ESP: Generator memunculkan Nama + Progres (Tanpa Jarak), Pallet & Window highlight bersih tanpa kotak.
-- By: @texx-breaker & Asisten

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local GUI = env.VD_GUI
if not GUI then
	warn("[VD] gui.lua belum dijalankan, jalankan gui.lua dulu")
	return
end
if env.VD_ESP_CLEANUP then pcall(env.VD_ESP_CLEANUP) end

local CFG = {
	UPDATE = 0.1,
	OBJ_MAX_DIST = 300,
	OBJ_FILL = 0.4,
	PROG_WORDS = {"progress", "percent", "repair", "charge", "completion"},
}

local alive = true
local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local parentGui = (gethui and gethui()) or CoreGui
local oldFolder = parentGui:FindFirstChild("VDESP")
if oldFolder then oldFolder:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "VDESP"
folder.Parent = parentGui

local function labelColor(c)
	return c:Lerp(Color3.new(1, 1, 1), 0.4)
end

local function makeLabel(adornee, yOff)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 20)
	bb.StudsOffset = Vector3.new(0, yOff, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = math.huge
	bb.LightInfluence = 0
	bb.Adornee = adornee
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamMedium
	tl.TextSize = 13
	tl.TextStrokeTransparency = 0.35
	tl.TextStrokeColor3 = Color3.new(0, 0, 0)
	tl.Text = ""
	tl.Parent = bb
	bb.Parent = folder
	return bb, tl
end

local function myRoot()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function inMatch()
	local t = lp.Team
	return t ~= nil and (t.Name == "Survivors" or t.Name == "Killer")
end

-- ===== ESP PEMAIN =====
local players = {}

local function dropPlayer(p)
	local e = players[p]
	if not e then return end
	pcall(function() e.hl:Destroy() end)
	pcall(function() e.bb:Destroy() end)
	players[p] = nil
end

local function updatePlayer(p, myR)
	local kind
	local team = p.Team
	if p ~= lp and team then
		if team.Name == "Killer" then
			kind = "killer"
		elseif team.Name == "Survivors" then
			kind = "survivor"
		end
	end
	local c = p.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (kind and GUI:Get("esp_" .. kind) and root and c.Parent and hum and hum.Health > 0) then
		dropPlayer(p)
		return
	end
	local e = players[p]
	if e and (e.char ~= c or e.kind ~= kind) then
		dropPlayer(p)
		e = nil
	end
	local color = GUI:Get("esp_" .. kind .. "_color")
	if not e then
		local hl = Instance.new("Highlight")
		hl.Adornee = c
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = 0.6
		hl.OutlineTransparency = 0
		hl.Parent = c
		local bb, tl = makeLabel(c:FindFirstChild("Head") or root, 2.6)
		e = {char = c, kind = kind, hl = hl, bb = bb, label = tl, color = nil}
		players[p] = e
	end
	if e.color ~= color then
		e.color = color
		e.hl.FillColor = color
		e.hl.OutlineColor = color
		e.label.TextColor3 = labelColor(color)
	end
	local prefix = (kind == "killer") and "Killer  " or ""
	if myR then
		local d = (root.Position - myR.Position).Magnitude
		e.label.Text = string.format("%s%s  %dm", prefix, p.Name, math.floor(d + 0.5))
	else
		e.label.Text = prefix .. p.Name
	end
end

-- ===== ESP OBJEK =====
local KINDS = {
	gen = {toggle = "esp_generator", name = "Generator", y = 3, label = true},
	pallet = {toggle = "esp_pallet"},
	window = {toggle = "esp_window"},
	trap = {toggle = "esp_jtrap"},
	zombie = {toggle = "esp_zombie"},
}
local entities = {}

local function hideObject(e)
	if e.hl then pcall(function() e.hl:Destroy() end) e.hl = nil end
	if e.bb then pcall(function() e.bb:Destroy() end) e.bb = nil end
	e.color = nil
end

local function dropObject(model)
	local e = entities[model]
	if not e then return end
	hideObject(e)
	if e.conn then pcall(function() e.conn:Disconnect() end) end
	entities[model] = nil
end

local function addObject(kind, model)
	if entities[model] or not model.Parent then return end
	local e = {kind = kind, model = model, nextProg = 0}
	entities[model] = e
	e.conn = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then dropObject(model) end
	end)
end

local function mainPart(model)
	if model:IsA("BasePart") then return model end
	if model:IsA("Model") then
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function resolveAdornee(model)
	if model:IsA("BasePart") then return model end
	local part = model:FindFirstChild("MeshPart") or model:FindFirstChild("Part") or model:FindFirstChildWhichIsA("BasePart", true)
	return part or model
end

local function looksLikeProgress(n)
	n = n:lower()
	for _, w in ipairs(CFG.PROG_WORDS) do
		if n:find(w, 1, true) then return true end
	end
	return false
end

local function toPercent(v)
	if type(v) ~= "number" then return nil end
	if v >= 0 and v <= 1.0001 then return v * 100 end
	if v > 1 and v <= 100 then return v end
	return nil
end

local function findProgressSource(model)
	for k, v in pairs(model:GetAttributes()) do
		if looksLikeProgress(k) and toPercent(v) then return {t = "attr", inst = model, key = k} end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("NumberValue") or d:IsA("IntValue")) and looksLikeProgress(d.Name) then
			return {t = "val", inst = d}
		end
		for k, v in pairs(d:GetAttributes()) do
			if looksLikeProgress(k) and toPercent(v) then return {t = "attr", inst = d, key = k} end
		end
		if d:IsA("TextLabel") and d.Text:match("%d+%.?%d*%%") then
			return {t = "text", inst = d}
		end
	end
	return nil
end

local function readProgress(src)
	if not src or not src.inst or not src.inst.Parent then return nil end
	if src.t == "attr" then return toPercent(src.inst:GetAttribute(src.key)) end
	if src.t == "val" then return toPercent(src.inst.Value) end
	local n = tonumber(src.inst.Text:match("(%d+%.?%d*)%%"))
	if n and n <= 100 then return n end
	return nil
end

local function updateObject(model, e, myR, match)
	local cfg = KINDS[e.kind]
	if not (match and GUI:Get(cfg.toggle)) or not model:IsDescendantOf(workspace) then
		hideObject(e)
		return
	end
	local part = e.part
	if not part or not part.Parent then
		part = mainPart(model)
		e.part = part
	end
	if not part then return end
	local d = myR and (part.Position - myR.Position).Magnitude or 0
	if d > CFG.OBJ_MAX_DIST then
		hideObject(e)
		return
	end
	local color = GUI:Get(cfg.toggle .. "_color")
	if not e.hl then
		local hl = Instance.new("Highlight")
		hl.Adornee = resolveAdornee(model)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = CFG.OBJ_FILL
		hl.OutlineTransparency = 0
		hl.Parent = folder
		e.hl = hl
		if cfg.label then
			local bb, tl = makeLabel(part, cfg.y)
			e.bb, e.label = bb, tl
		end
		e.color = nil
	end
	if e.color ~= color then
		e.color = color
		e.hl.FillColor = color
		e.hl.OutlineColor = color
		if e.label then e.label.TextColor3 = labelColor(color) end
	end
	if e.label then
		local text = cfg.name
		if e.kind == "gen" then
			if not e.src and os.clock() >= e.nextProg then
				e.nextProg = os.clock() + 3
				e.src = findProgressSource(model)
			end
			local pct = readProgress(e.src)
			if pct then text = string.format("%s %d%%", cfg.name, math.floor(pct + 0.5)) end
		end
		e.label.Text = text
	end
end

local function onInstance(inst)
	if inst:IsA("BasePart") then
		local n = inst.Name
		local lowN = n:lower()
		if n:sub(1, 14) == "GeneratorPoint" then
			local m = inst.Parent
			if m and m:IsA("Model") then addObject("gen", m) end
		elseif n == "PalletPoint" or lowN:find("pallet") or lowN:find("newpallet") then
			local m = inst:FindFirstAncestor("Newpallet") or inst:FindFirstAncestorOfClass("Model") or inst.Parent
			if m and m:IsA("Model") then addObject("pallet", m) else addObject("pallet", inst) end
		elseif n == "VaultTrigger" or n == "Window" or lowN:find("vault") or lowN:find("window") then
			local m = inst.Parent
			if m and m:IsA("Model") then addObject("window", m) else addObject("window", inst) end
		end
	elseif inst:IsA("Model") then
		local ln = inst.Name:lower()
		if ln:find("jtrap", 1, true) or (ln:find("trap", 1, true) and inst:GetFullName():lower():find("jason", 1, true)) then
			addObject("trap", inst)
		elseif ln:find("window") or ln:find("vault") then
			addObject("window", inst)
		elseif ln:find("pallet") or ln:find("newpallet") then
			addObject("pallet", inst)
		end
	elseif inst:IsA("Humanoid") then
		local m = inst.Parent
		if m and m:IsA("Model") and m.Name:lower():find("zombie", 1, true) and not Players:GetPlayerFromCharacter(m) then
			addObject("zombie", m)
		end
	end
end

task.spawn(function()
	local n = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if not alive then return end
		onInstance(d)
		n = n + 1
		if n % 3000 == 0 then task.wait() end
	end
end)
connect(workspace.DescendantAdded, onInstance)
connect(Players.PlayerRemoving, dropPlayer)

local acc = 0
connect(RunService.Heartbeat, function(dt)
	if GUI.Closed then return end
	acc = acc + dt
	if acc < CFG.UPDATE then return end
	acc = 0
	local myR = myRoot()
	local match = inMatch()
	for _, p in ipairs(Players:GetPlayers()) do updatePlayer(p, myR) end
	for model, e in pairs(entities) do updateObject(model, e, myR, match) end
end)

local function cleanup()
	alive = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	for p in pairs(players) do dropPlayer(p) end
	for model in pairs(entities) do dropObject(model) end
	pcall(function() folder:Destroy() end)
end
env.VD_ESP_CLEANUP = cleanup
GUI:OnClose(cleanup)

print("[VD] ESP siap (Generator ber-nama/persen, Objek tanpa jarak)")
