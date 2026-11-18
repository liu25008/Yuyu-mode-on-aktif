-- features/ESP.lua
-- Isi file ini sama dengan blok featureESP di gui.lua. Boleh dijalankan sebagai file sendiri
-- setelah gui.lua, atau ditempel di dalam: local function featureESP() ... end
-- By: @texx-breaker
--
-- Perubahan: window sekarang digambar sebagai kotak cyan di part VaultTrigger (model window di map
-- semuanya transparan, jadi Highlight tidak menampilkan apa-apa). Kalau GUI punya tombol "esp_window",
-- window punya toggle dan warna sendiri. Kalau belum ada, window ikut toggle "esp_objects" dengan warna WINDOW_COLOR.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local GUI = env.VD_GUI
if not GUI then return end
if env.VD_ESP_CLEANUP then pcall(env.VD_ESP_CLEANUP) end

-- ===== pengaturan =====
local CFG = {
	UPDATE = 0.1,            -- detik antar pembaruan label dan jarak
	OBJ_MAX_DIST = 300,      -- jarak maksimum untuk objek (pallet, window, generator, dll)
	OBJ_FILL = 0.35,         -- transparansi warna di badan objek (0 = pekat, 1 = bening)
	GEN_TEXT_SIZE = 16,      -- ukuran tulisan nama dan progres generator
	MAX_HIGHLIGHTS = 30,     -- Roblox hanya menggambar sekitar 31 highlight sekaligus, objek terdekat didahulukan
	WINDOW_COLOR = Color3.fromRGB(0, 200, 230), -- warna window kalau GUI belum punya tombol esp_window
	WINDOW_FILL = 0.45,      -- transparansi kotak window
	PROG_WORDS = {"progress", "percent", "repair", "charge", "completion"}, -- nama sumber progres generator
}

local alive = true
local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

-- ===== folder tempat semua visual (lokal, tidak terlihat server) =====
local parentGui = (gethui and gethui()) or CoreGui
local oldFolder = parentGui:FindFirstChild("VDESP")
if oldFolder then oldFolder:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "VDESP"
folder.Parent = parentGui

local function labelColor(c)
	return c:Lerp(Color3.new(1, 1, 1), 0.4)
end

local function makeLabel(adornee, yOff, textSize)
	local ts = textSize or 13
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, ts + 10)
	bb.StudsOffset = Vector3.new(0, yOff, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = math.huge
	bb.LightInfluence = 0
	bb.Adornee = adornee
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamMedium
	tl.TextSize = ts
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

-- ===== ESP pemain (killer dan survivor, lengkap dengan jarak) =====
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

-- ===== ESP objek (generator, pallet, window, jtrap, zombie) =====
-- Pallet, generator, jtrap, zombie: Highlight di badan objek. Window: kotak di part VaultTrigger.
-- Tulisan hanya untuk generator, window, jtrap, zombie, tanpa jarak.
local KINDS = {
	gen = {toggle = "esp_generator", name = "Generator", y = 3, label = true, size = CFG.GEN_TEXT_SIZE},
	pallet = {toggle = "esp_objects", name = "Pallet"},
	window = {toggle = "esp_window", fallback = "esp_objects", name = "Window", y = 2, label = true, size = 13},
	trap = {toggle = "esp_jtrap", name = "JTrap", y = 2, label = true, size = 13},
	zombie = {toggle = "esp_zombie", name = "Zombie", y = 3.2, label = true, size = 13},
}

-- window memakai tombol esp_window kalau ada di GUI, kalau tidak pakai esp_objects
local function toggleOf(cfg)
	if cfg.fallback and GUI.State[cfg.toggle] == nil then return cfg.fallback end
	return cfg.toggle
end

local function colorOf(kind, cfg)
	local t = toggleOf(cfg)
	if kind == "window" and t ~= cfg.toggle then return CFG.WINDOW_COLOR end
	return GUI:Get(t .. "_color")
end

local entities = {}
local windowSeen = {}
local diagWritten = false

local function hideObject(e)
	if e.hl then pcall(function() e.hl:Destroy() end) e.hl = nil end
	if e.bb then pcall(function() e.bb:Destroy() end) e.bb = nil end
	if e.fx then
		for _, o in ipairs(e.fx) do pcall(function() o:Destroy() end) end
		e.fx = nil
	end
	e.label = nil
	e.color = nil
end

local function dropObject(model)
	local e = entities[model]
	if not e then return end
	hideObject(e)
	if e.conn then pcall(function() e.conn:Disconnect() end) end
	entities[model] = nil
end

local function addObject(kind, model, trigger, labelled)
	if entities[model] or not model.Parent then return end
	local e = {kind = kind, model = model, nextProg = 0, trigger = trigger, part = trigger, labelled = labelled}
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

-- progres generator: nilai bisa berupa atribut, NumberValue, atau teks berisi persen
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

-- kalau sumber progres tidak ketemu, simpan isi generator pertama biar bisa dicocokkan
local function writeDiag(model)
	if diagWritten or not writefile then return end
	diagWritten = true
	local lines = {"Generator: " .. model:GetFullName()}
	for k, v in pairs(model:GetAttributes()) do lines[#lines + 1] = "attr " .. k .. "=" .. tostring(v) end
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		n = n + 1
		if n > 80 then break end
		local extra = ""
		if d:IsA("ValueBase") then extra = " = " .. tostring(d.Value) end
		if d:IsA("TextLabel") then extra = " text=" .. d.Text end
		lines[#lines + 1] = d.ClassName .. " " .. d.Name .. extra
		for k, v in pairs(d:GetAttributes()) do lines[#lines + 1] = "  attr " .. k .. "=" .. tostring(v) end
	end
	pcall(writefile, "VD_GenInfo.txt", table.concat(lines, "\n"))
end

-- hitung jarak objek, sembunyikan kalau tidak perlu tampil; hasilnya jarak atau nil
local function objectDistance(model, e, myR, match)
	local cfg = KINDS[e.kind]
	if not (match and GUI:Get(toggleOf(cfg))) or not model:IsDescendantOf(workspace) then
		hideObject(e)
		return nil
	end
	local part = e.part
	if not part or not part.Parent then
		part = mainPart(model)
		e.part = part
	end
	if not part then
		hideObject(e)
		return nil
	end
	local d = myR and (part.Position - myR.Position).Magnitude or 0
	if d > CFG.OBJ_MAX_DIST then
		hideObject(e)
		return nil
	end
	return d
end

-- Highlight hanya menggambar bagian yang kelihatan. Kalau model cuma berisi pemicu transparan,
-- naik ke induk yang punya bentuk kelihatan.
local function hasVisible(m)
	if m:IsA("BasePart") and m.Transparency < 0.9 then return true end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 then return true end
	end
	return false
end

local noVisLogged = false
local function resolveAdornee(model)
	if hasVisible(model) then return model end
	local p = model.Parent
	for _ = 1, 3 do
		if not p or p == workspace or not p:IsA("Model") then break end
		if p:GetExtentsSize().Magnitude <= 40 and hasVisible(p) then return p end
		p = p.Parent
	end
	if not noVisLogged and appendfile then
		noVisLogged = true
		local lines = {"tanpa bagian kelihatan: " .. model:GetFullName()}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				lines[#lines + 1] = d.ClassName .. " " .. d.Name .. " transparansi=" .. tostring(d.Transparency)
			end
		end
		pcall(appendfile, "VD_NoVisible.txt", table.concat(lines, "\n") .. "\n")
	end
	return model
end

-- window: kotak di part VaultTrigger (part itu transparan, jadi Highlight tidak kelihatan)
local function showWindow(e, cfg, color)
	local trig = e.trigger
	if not (trig and trig.Parent) then return end
	if not e.fx then
		local box = Instance.new("BoxHandleAdornment")
		box.Adornee = trig
		box.Size = trig.Size + Vector3.new(0.2, 0.2, 0.2)
		box.AlwaysOnTop = true
		box.ZIndex = 5
		box.Transparency = CFG.WINDOW_FILL
		box.Parent = folder
		local sel = Instance.new("SelectionBox")
		sel.Adornee = trig
		sel.LineThickness = 0.05
		sel.Parent = folder
		e.fx = {box, sel}
		e.color = nil
		if e.labelled then
			local bb, tl = makeLabel(trig, cfg.y, cfg.size)
			tl.Text = cfg.name
			e.bb, e.label = bb, tl
		end
	end
	if e.color ~= color then
		e.color = color
		e.fx[1].Color3 = color
		e.fx[2].Color3 = color
		if e.label then e.label.TextColor3 = labelColor(color) end
	end
end

local function showObject(model, e)
	local cfg = KINDS[e.kind]
	local color = colorOf(e.kind, cfg)
	if e.kind == "window" then
		showWindow(e, cfg, color)
		return
	end
	if not e.hl then
		local hl = Instance.new("Highlight")
		hl.Adornee = resolveAdornee(model)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = CFG.OBJ_FILL
		hl.OutlineTransparency = 0
		hl.Parent = folder
		e.hl = hl
		if cfg.label then
			local bb, tl = makeLabel(e.part, cfg.y, cfg.size)
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
	if not e.label then return end
	local text = cfg.name
	if e.kind == "gen" then
		if not e.src and os.clock() >= e.nextProg then
			e.nextProg = os.clock() + 3
			e.src = findProgressSource(model)
			if not e.src then writeDiag(model) end
		end
		local pct = readProgress(e.src)
		if pct then text = string.format("%s %d%%", cfg.name, math.floor(pct + 0.5)) end
	end
	e.label.Text = text
end

-- jatah highlight dibagi bergantian antar jenis, tiap jenis dari yang terdekat.
-- window tidak memakai highlight, jadi tidak memakan jatah.
local function updateObjects(myR, match, budget)
	local byKind = {}
	for model, e in pairs(entities) do
		local d = objectDistance(model, e, myR, match)
		if d then
			local l = byKind[e.kind]
			if not l then
				l = {}
				byKind[e.kind] = l
			end
			l[#l + 1] = {model = model, e = e, d = d}
		end
	end
	local lists = {}
	for _, l in pairs(byKind) do
		table.sort(l, function(a, b) return a.d < b.d end)
		lists[#lists + 1] = {items = l, i = 1}
	end
	local shown = 0
	local progress = true
	while progress do
		progress = false
		for _, L in ipairs(lists) do
			local it = L.items[L.i]
			if it then
				L.i = L.i + 1
				progress = true
				if it.e.kind == "window" then
					showObject(it.model, it.e)
				elseif shown < budget then
					shown = shown + 1
					showObject(it.model, it.e)
				else
					hideObject(it.e)
				end
			end
		end
	end
end

-- ===== deteksi objek di map =====
local seenNames = {}
local nameLog = 0
local function logName(inst)
	local full = inst:GetFullName()
	if seenNames[full] or nameLog >= 30 or not appendfile then return end
	seenNames[full] = true
	nameLog = nameLog + 1
	pcall(appendfile, "VD_ESP_Names.txt", inst.ClassName .. " " .. full .. "\n")
end

local function onInstance(inst)
	if inst:IsA("BasePart") then
		local n = inst.Name
		if n:sub(1, 14) == "GeneratorPoint" then
			local m = inst.Parent
			if m and m:IsA("Model") then addObject("gen", m) end
		elseif n == "PalletPoint" then
			local m = inst:FindFirstAncestor("Newpallet") or (inst.Parent and inst.Parent.Parent)
			-- jaga-jaga: kalau yang ketemu model raksasa (bukan pallet), pakai induk langsung
			if m and m:IsA("Model") and m:GetExtentsSize().Magnitude > 40 and inst.Parent and inst.Parent:IsA("Model") then m = inst.Parent end
			if m and m:IsA("Model") then addObject("pallet", m) end
		elseif n == "VaultTrigger" then
			-- tiap part VaultTrigger jadi satu entri (satu window punya dua trigger); label hanya di yang pertama
			local par = inst.Parent
			if par and not entities[inst] then
				windowSeen[par] = (windowSeen[par] or 0) + 1
				addObject("window", inst, inst, windowSeen[par] == 1)
			end
		end
	elseif inst:IsA("Model") then
		local ln = inst.Name:lower()
		if ln:find("jtrap", 1, true) or (ln:find("trap", 1, true) and inst:GetFullName():lower():find("jason", 1, true)) then
			addObject("trap", inst)
		end
		if ln:find("trap", 1, true) or ln:find("zombie", 1, true) or ln:find("jason", 1, true) then logName(inst) end
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

-- ===== loop pembaruan =====
local acc = 0
connect(RunService.Heartbeat, function(dt)
	if GUI.Closed then return end
	acc = acc + dt
	if acc < CFG.UPDATE then return end
	acc = 0
	local myR = myRoot()
	local match = inMatch()
	for _, p in ipairs(Players:GetPlayers()) do updatePlayer(p, myR) end
	local used = 0
	for _ in pairs(players) do used = used + 1 end
	updateObjects(myR, match, math.max(0, CFG.MAX_HIGHLIGHTS - used))
end)

-- ===== bersihkan =====
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

print("[VD] ESP siap")
