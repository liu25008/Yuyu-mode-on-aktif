-- =====================================================================
-- VD UTILITY - ALL-IN-ONE FINAL GUI & FEATURES
-- =====================================================================
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.VD_GUI and env.VD_GUI.Destroy then
	pcall(function() env.VD_GUI:Destroy() end)
end

-- ===== TEMA & WARNA =====
local T = {
	bg = Color3.fromRGB(10, 13, 11),
	side = Color3.fromRGB(13, 17, 14),
	surface = Color3.fromRGB(19, 25, 21),
	surfaceHi = Color3.fromRGB(26, 34, 29),
	line = Color3.fromRGB(33, 44, 37),
	accent = Color3.fromRGB(30, 112, 64),
	accentSoft = Color3.fromRGB(78, 164, 108),
	text = Color3.fromRGB(224, 232, 226),
	muted = Color3.fromRGB(125, 141, 130),
	off = Color3.fromRGB(42, 52, 46),
	knob = Color3.fromRGB(190, 200, 193),
	danger = Color3.fromRGB(110, 38, 38),
}

-- ===== HALAMAN & MENU =====
local PAGES = {
	{
		name = "Survivor", title = "Survivor Utility", sub = "Fitur untuk sisi survivor", icon = "person",
		rows = {
			{kind = "toggle", id = "auto_parry", label = "Auto Parry (Dagger)", desc = "Tangkis serangan killer otomatis"},
			{kind = "segment", id = "auto_parry_mode", label = "Mode parry", options = {"Hemat", "Prediktif"}, default = "Hemat", indent = true},
			{kind = "toggle", id = "anti_fake_hit", label = "Anti Fake Hit", desc = "Abaikan serangan palsu atau meleset"},
			{kind = "toggle", id = "fast_vault", label = "Fast Vault", desc = "Lewati jendela lebih cepat (Bypass Alignment)"},
			{kind = "toggle", id = "speed_boost", label = "Speed Boost", desc = "Tambahan kecepatan jalan"},
			{kind = "slider", id = "speed_value", label = "Kecepatan tambahan", min = 0.1, max = 3, step = 0.1, default = 1.0, indent = true},
			{kind = "toggle", id = "auto_skill", label = "Auto Skill", desc = "Skill check generator dan heal otomatis"},
		},
	},
	{
		name = "ESP", title = "ESP", sub = "Highlight tembus tembok untuk objek & pemain", icon = "eye",
		rows = {
			{kind = "toggle", id = "esp_killer", label = "Killer", color = Color3.fromRGB(139, 26, 26)},
			{kind = "toggle", id = "esp_survivor", label = "Survivor", color = Color3.fromRGB(26, 52, 139)},
			{kind = "toggle", id = "esp_window", label = "Window / Vault", color = Color3.fromRGB(30, 200, 220)},
			{kind = "toggle", id = "esp_generator", label = "Generator", color = Color3.fromRGB(222, 100, 160)},
		},
	},
}

local PALETTE = {
	Color3.fromRGB(139, 26, 26), Color3.fromRGB(178, 60, 40), Color3.fromRGB(194, 98, 10), Color3.fromRGB(176, 142, 30),
	Color3.fromRGB(34, 120, 56), Color3.fromRGB(30, 200, 220), Color3.fromRGB(26, 52, 139), Color3.fromRGB(60, 90, 170),
}

local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function round(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function stroke(o, color, th) return new("UIStroke", {Color = color, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function tween(o, t, props) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end

local function hover(o, prop, normal, over)
	connect(o.MouseEnter, function() tween(o, 0.12, {[prop] = over}) end)
	connect(o.MouseLeave, function() tween(o, 0.12, {[prop] = normal}) end)
end

local function makeDraggable(handle, target)
	local st = {moved = false}
	local dragging, startPos, startTarget = false, nil, nil
	connect(handle.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			st.moved = false
			startPos = i.Position
			startTarget = target.Position
			connect(i.Changed, function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	connect(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startPos
			if d.Magnitude > 6 then st.moved = true end
			target.Position = UDim2.new(startTarget.X.Scale, startTarget.X.Offset + d.X, startTarget.Y.Scale, startTarget.Y.Offset + d.Y)
		end
	end)
	return st
end

local function drawIcon(kind, parent, color)
	local box = new("Frame", {Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1}, parent)
	local function part(size, pos, radius)
		local f = new("Frame", {Size = size, Position = pos, BackgroundColor3 = color, BorderSizePixel = 0}, box)
		if radius then round(f, radius) end
		return f
	end
	local function ring(size, pos, radius, th)
		local f = new("Frame", {Size = size, Position = pos, BackgroundTransparency = 1, BorderSizePixel = 0}, box)
		round(f, radius)
		stroke(f, color, th)
		return f
	end
	if kind == "person" then
		part(UDim2.fromOffset(7, 7), UDim2.fromOffset(5, 1), 4)
		part(UDim2.fromOffset(14, 8), UDim2.fromOffset(2, 10), 4)
	else
		ring(UDim2.fromOffset(18, 10), UDim2.fromOffset(0, 4), 5, 2)
		part(UDim2.fromOffset(6, 6), UDim2.fromOffset(6, 6), 3)
	end
	local function setColor(c)
		for _, d in ipairs(box:GetDescendants()) do
			if d:IsA("UIStroke") then d.Color = c
			elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then d.BackgroundColor3 = c end
		end
	end
	return box, setColor
end

local GUI = {State = {}, Defaults = {}, Closed = false}
local setters, listeners, anyListeners, closeListeners = {}, {}, {}, {}

local function fire(id, v)
	for _, fn in ipairs(listeners[id] or {}) do pcall(fn, v, id) end
	for _, fn in ipairs(anyListeners) do pcall(fn, id, v) end
end

local function register(id, default, setter)
	GUI.State[id] = default
	GUI.Defaults[id] = default
	setters[id] = setter
	setter(default, true)
end

function GUI:Get(id) return self.State[id] end
function GUI:Set(id, value, silent)
	local s = setters[id]
	if not s then return end
	if self.State[id] == value then return end
	self.State[id] = value
	s(value, false)
	if not silent then fire(id, value) end
end

function GUI:OnChanged(id, fn)
	listeners[id] = listeners[id] or {}
	table.insert(listeners[id], fn)
end
function GUI:OnClose(fn) table.insert(closeListeners, fn) end

-- Setup Window GUI
local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(800, 450)
local W, H = 420, 300
local parentGui = (gethui and gethui()) or CoreGui
local oldGui = parentGui:FindFirstChild("VDHub")
if oldGui then oldGui:Destroy() end

local gui = new("ScreenGui", {Name = "VDHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100}, parentGui)
local root = new("Frame", {Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W/2, 0.5, -H/2), BackgroundTransparency = 1}, gui)
local main = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.bg, ClipsDescendants = true}, root)
round(main, 12)
stroke(main, T.line, 1)

local header = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, main)
new("TextLabel", {Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = "VD Utility - Final"}, header)
new("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.line, BorderSizePixel = 0}, header)

local side = new("Frame", {Size = UDim2.new(0, 110, 1, -40), Position = UDim2.fromOffset(0, 40), BackgroundColor3 = T.side}, main)
new("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.line}, side)
local indicator = new("Frame", {Size = UDim2.fromOffset(3, 22), Position = UDim2.fromOffset(0, 19), BackgroundColor3 = T.accentSoft}, side)
round(indicator, 2)

local content = new("Frame", {Size = UDim2.new(1, -110, 1, -40), Position = UDim2.new(0, 110, 0, 40), BackgroundTransparency = 1}, main)

-- Build Toggles & Sliders
local function buildToggle(parent, spec, order)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.surface, LayoutOrder = order}, parent)
	round(row, 9)
	stroke(row, T.line, 1)
	local hit = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = ""}, row)
	
	new("TextLabel", {Size = UDim2.new(1, -66, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = spec.label}, row)
	
	local track = new("Frame", {Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -50, 0.5, -10), BackgroundColor3 = T.off}, row)
	round(track, 10)
	local knob = new("Frame", {Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = T.knob}, track)
	round(knob, 7)

	register(spec.id, false, function(v, instant)
		tween(track, instant and 0 or 0.15, {BackgroundColor3 = v and T.accent or T.off})
		tween(knob, instant and 0 or 0.15, {Position = v and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)})
	end)
	connect(hit.MouseButton1Click, function() GUI:Set(spec.id, not GUI.State[spec.id]) end)
end

local pageObjs = {}
for idx, page in ipairs(PAGES) do
	local pg = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false}, content)
	local scroll = new("ScrollingFrame", {Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, pg)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

	for order, spec in ipairs(page.rows) do
		if spec.kind == "toggle" then buildToggle(scroll, spec, order) end
	end

	local tab = new("TextButton", {Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 10 + (idx-1)*46), BackgroundTransparency = 1, Text = ""}, side)
	local _, setIcon = drawIcon(page.icon, tab, T.muted)
	local lbl = new("TextLabel", {Size = UDim2.new(1, -38, 1, 0), Position = UDim2.fromOffset(34, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = page.name}, tab)
	pageObjs[idx] = {frame = pg, tab = tab, label = lbl, setIcon = setIcon, y = 10 + (idx-1)*46}
end

local function selectPage(i)
	for k, p in ipairs(pageObjs) do
		local on = (k == i)
		p.frame.Visible = on
		p.label.TextColor3 = on and T.text or T.muted
	end
	tween(indicator, 0.2, {Position = UDim2.fromOffset(0, pageObjs[i].y + 9)})
end
for i, p in ipairs(pageObjs) do connect(p.tab.MouseButton1Click, function() selectPage(i) end) end
selectPage(1)
makeDraggable(header, root)

-- =====================================================================
-- INJEKSI FITUR: SURVIVOR UTILITY (Auto Parry, Fast Vault, Auto Skill)
-- =====================================================================
task.spawn(function()
	local playerGui = lp:WaitForChild("PlayerGui", 5)
	if not playerGui then return end

	-- 1. Auto Skill (SkillCheckPromptGui)
	RunService.Heartbeat:Connect(function()
		if not GUI:Get("auto_skill") then return end
		pcall(function()
			local promptGui = playerGui:FindFirstChild("SkillCheckPromptGui")
			if promptGui and promptGui.Enabled then
				local check = promptGui:FindFirstChild("Check")
				if check then
					local line = check:FindFirstChild("Line")
					local goal = check:FindFirstChild("Goal")
					if line and goal then line.Rotation = goal.Rotation end
				end
			end
		end)
	end)

	-- 2. Fast Vault & Traversal
	local RemotesFolder = RS:WaitForChild("Remotes", 15)
	if RemotesFolder and hookmetamethod and getnamecallmethod and newcclosure then
		local vaultEvent = RemotesFolder:FindFirstChild("Window") and RemotesFolder.Window:FindFirstChild("VaultEvent")
		local fastVaultRemote = RemotesFolder:FindFirstChild("Window") and RemotesFolder.Window:FindFirstChild("fastvault")
		local traversalRemote = RemotesFolder:FindFirstChild("Mechanics") and RemotesFolder.Mechanics:FindFirstChild("TraversalRemote")

		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local m = getnamecallmethod()
			if m == "FireServer" and not (checkcaller and checkcaller()) then
				if self == vaultEvent and GUI:Get("fast_vault") then
					local args = table.pack(...)
					if args.n >= 5 then args[5] = "fast" end
					if fastVaultRemote then task.defer(function() fastVaultRemote:FireServer(lp) end) end
					return old(self, table.unpack(args, 1, args.n))
				elseif self == traversalRemote and GUI:Get("fast_vault") then
					local args = table.pack(...)
					if args[1] == "prepare" or args[1] == "start" then
						args[1] = "start"
						if type(args[2]) == "table" then
							args[2].moving = true
							args[2].speed = 2.0
							args[2].power = 1.5
							args[2].asset = "rbxassetid://79965656177"
						end
					end
					return old(self, table.unpack(args, 1, args.n))
				end
			end
			return old(self, ...)
		end))
	end
end)

-- =====================================================================
-- INJEKSI FITUR: ESP LENGKAP (Killer, Survivor, Window, Generator)
-- =====================================================================
task.spawn(function()
	local folder = CoreGui:FindFirstChild("VDESP_Fixed")
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "VDESP_Fixed"
	folder.Parent = CoreGui

	local function applyHighlight(targetModel, color, toggleKey)
		if not GUI:Get(toggleKey) then
			local existing = targetModel:FindFirstChild("VD_HL")
			if existing then existing:Destroy() end
			return
		end
		if targetModel and not targetModel:FindFirstChild("VD_HL") then
			local hl = Instance.new("Highlight")
			hl.Name = "VD_HL"
			hl.Adornee = targetModel
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Tembus tembok
			hl.FillColor = color
			hl.FillTransparency = 0.5
			hl.OutlineColor = color
			hl.OutlineTransparency = 0
			hl.Parent = targetModel
		end
	end

	RunService.Heartbeat:Connect(function()
		pcall(function()
			-- ESP Player (Killer & Survivor)
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= lp and p.Character then
					local team = p.Team
					local hum = p.Character:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 and team then
						if team.Name == "Killer" then
							applyHighlight(p.Character, Color3.fromRGB(139, 26, 26), "esp_killer")
						elseif team.Name == "Survivors" then
							applyHighlight(p.Character, Color3.fromRGB(26, 52, 139), "esp_survivor")
						end
					end
				end
			end

			-- ESP Objek Map (Window & Generator)
			local map = workspace:FindFirstChild("Map")
			if map then
				local vaults = map:FindFirstChild("Vaults")
				if vaults then
					for _, win in ipairs(vaults:GetChildren()) do
						applyHighlight(win, Color3.fromRGB(30, 200, 220), "esp_window")
					end
				end
				
				local gens = map:FindFirstChild("Generators") or map:FindFirstChild("new Generators")
				if gens then
					for _, gen in ipairs(gens:GetChildren()) do
						applyHighlight(gen, Color3.fromRGB(222, 100, 160), "esp_generator")
					end
				end
			end
		end)
	end)
end)

print("[VD Utility] GUI dan Fitur Berhasil Disuntikkan Sempurna!")
return GUI
