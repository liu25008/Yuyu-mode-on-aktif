-- =====================================================================
-- VD UTILITY - FINAL GITHUB GUI (SLIDER 0.1-3, MINIMIZE, CLOSE, & LG ICON)
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
	line = Color3.fromRGB(33, 44, 37),
	accent = Color3.fromRGB(30, 112, 64),
	accentSoft = Color3.fromRGB(78, 164, 108),
	text = Color3.fromRGB(224, 232, 226),
	muted = Color3.fromRGB(125, 141, 130),
	off = Color3.fromRGB(42, 52, 46),
	knob = Color3.fromRGB(190, 200, 193),
}

-- ===== HALAMAN & MENU LENGKAP =====
local PAGES = {
	{
		name = "Survivor", title = "Survivor Utility", icon = "person",
		rows = {
			{kind = "toggle", id = "auto_parry", label = "Auto Parry (Dagger)"},
			{kind = "toggle", id = "fast_vault", label = "Fast Vault"},
			{kind = "toggle", id = "speed_boost", label = "Speed Boost"},
			{kind = "slider", id = "speed_value", label = "Kecepatan tambahan", min = 0.1, max = 3.0, default = 1.0},
			{kind = "toggle", id = "auto_skill", label = "Auto Skill"},
		},
	},
	{
		name = "ESP", title = "ESP", icon = "eye",
		rows = {
			{kind = "toggle", id = "esp_killer", label = "Killer"},
			{kind = "toggle", id = "esp_survivor", label = "Survivor"},
			{kind = "toggle", id = "esp_window", label = "Window / Vault"},
			{kind = "toggle", id = "esp_generator", label = "Generator"},
		},
	},
}

local GUI = {State = {}, Defaults = {}, Closed = false}
local setters, listeners = {}, {}

local function fire(id, v)
	for _, fn in ipairs(listeners[id] or {}) do pcall(fn, v, id) end
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

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function round(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function stroke(o, color, th) return new("UIStroke", {Color = color, Thickness = th or 1}, o) end
local function tween(o, t, props) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play() end

local function drawIcon(kind, parent, color)
	local box = new("Frame", {Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1}, parent)
	local function part(size, pos, radius)
		local f = new("Frame", {Size = size, Position = pos, BackgroundColor3 = color, BorderSizePixel = 0}, box)
		if radius then round(f, radius) end
		return f
	end
	if kind == "person" then
		part(UDim2.fromOffset(7, 7), UDim2.fromOffset(5, 1), 4)
		part(UDim2.fromOffset(14, 8), UDim2.fromOffset(2, 10), 4)
	else
		local ring = new("Frame", {Size = UDim2.fromOffset(18, 10), Position = UDim2.fromOffset(0, 4), BackgroundTransparency = 1}, box)
		round(ring, 5); stroke(ring, color, 2)
		part(UDim2.fromOffset(6, 6), UDim2.fromOffset(6, 6), 3)
	end
	return box
end

-- Setup Window GUI
local W, H = 420, 340
local parentGui = (gethui and gethui()) or CoreGui
local oldGui = parentGui:FindFirstChild("VDHub")
if oldGui then oldGui:Destroy() end

local gui = new("ScreenGui", {Name = "VDHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100}, parentGui)
local root = new("Frame", {Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, -W/2, 0.5, -H/2), BackgroundTransparency = 1}, gui)
local main = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.bg, ClipsDescendants = true}, root)
round(main, 12); stroke(main, T.line, 1)

local header = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, main)
new("TextLabel", {Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = "VD Utility - Final"}, header)
new("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.line, BorderSizePixel = 0}, header)

-- Tombol Minimize (-) dan Close (X) di Header
local btnClose = new("TextButton", {Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -35, 0.5, -15), BackgroundColor3 = Color3.fromRGB(110, 38, 38), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.text, Text = "X"}, header)
round(btnClose, 6)

local btnMin = new("TextButton", {Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -70, 0.5, -15), BackgroundColor3 = T.surface, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = T.text, Text = "-"}, header)
round(btnMin, 6); stroke(btnMin, T.line, 1)

-- Floating Logo LG untuk membuka kembali GUI saat diminimize
local floatBtn = new("TextButton", {Size = UDim2.fromOffset(45, 45), Position = UDim2.new(0, 30, 0.5, -22), BackgroundColor3 = T.accent, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = T.text, Text = "LG", Visible = false, ZIndex = 999}, gui)
round(floatBtn, 22); stroke(floatBtn, T.accentSoft, 2)

btnMin.MouseButton1Click:Connect(function()
	root.Visible = false
	floatBtn.Visible = true
end)

floatBtn.MouseButton1Click:Connect(function()
	root.Visible = true
	floatBtn.Visible = false
end)

btnClose.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

local side = new("Frame", {Size = UDim2.new(0, 110, 1, -40), Position = UDim2.fromOffset(0, 40), BackgroundColor3 = T.side}, main)
new("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.line}, side)
local indicator = new("Frame", {Size = UDim2.fromOffset(3, 22), Position = UDim2.fromOffset(0, 19), BackgroundColor3 = T.accentSoft}, side)
round(indicator, 2)

local content = new("Frame", {Size = UDim2.new(1, -110, 1, -40), Position = UDim2.new(0, 110, 0, 40), BackgroundTransparency = 1}, main)

-- Build Toggles
local function buildToggle(parent, spec, order)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = T.surface, LayoutOrder = order}, parent)
	round(row, 9); stroke(row, T.line, 1)
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
	hit.MouseButton1Click:Connect(function() GUI:Set(spec.id, not GUI.State[spec.id]) end)
end

-- Build Sliders (Kecepatan 0.1 - 3.0)
local function buildSlider(parent, spec, order)
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.surface, LayoutOrder = order}, parent)
	round(row, 9); stroke(row, T.line, 1)

	new("TextLabel", {Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 6), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = spec.label}, row)
	
	local valLbl = new("TextLabel", {Size = UDim2.new(0, 50, 0, 20), Position = UDim2.new(1, -62, 0, 6), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.accentSoft, TextXAlignment = Enum.TextXAlignment.Right, Text = tostring(spec.default)}, row)

	local sliderBar = new("Frame", {Size = UDim2.new(1, -24, 0, 6), Position = UDim2.new(0, 12, 1, -16), BackgroundColor3 = T.off}, row)
	round(sliderBar, 3)

	local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.accent}, sliderBar)
	round(fill, 3)

	local btn = new("TextButton", {Size = UDim2.new(1, 10, 1, 10), Position = UDim2.new(0, -5, 0, -5), BackgroundTransparency = 1, Text = ""}, sliderBar)

	local dragging = false
	local function update(input)
		local pos = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
		local val = spec.min + (spec.max - spec.min) * pos
		val = math.floor(val * 10 + 0.5) / 10
		GUI:Set(spec.id, val)
	end

	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i) end
	end)

	register(spec.id, spec.default, function(v)
		local pct = math.clamp((v - spec.min) / (spec.max - spec.min), 0, 1)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		valLbl.Text = string.format("%.1f", v)
	end)
end

local pageObjs = {}
for idx, page in ipairs(PAGES) do
	local pg = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false}, content)
	local scroll = new("ScrollingFrame", {Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y}, pg)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, scroll)

	for order, spec in ipairs(page.rows) do
		if spec.kind == "toggle" then buildToggle(scroll, spec, order)
		elseif spec.kind == "slider" then buildSlider(scroll, spec, order) end
	end

	local tab = new("TextButton", {Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 10 + (idx-1)*46), BackgroundTransparency = 1, Text = ""}, side)
	drawIcon(page.icon, tab, T.muted)
	local lbl = new("TextLabel", {Size = UDim2.new(1, -38, 1, 0), Position = UDim2.fromOffset(34, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = page.name}, tab)
	pageObjs[idx] = {frame = pg, tab = tab, label = lbl, y = 10 + (idx-1)*46}
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

-- Draggable Window
local draggingWindow, startInput, startWindowPos
header.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		draggingWindow = true; startInput = i.Position; startWindowPos = root.Position
	end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then draggingWindow = false end
end)
UIS.InputChanged:Connect(function(i)
	if draggingWindow and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local delta = i.Position - startInput
		root.Position = UDim2.new(startWindowPos.X.Scale, startWindowPos.X.Offset + delta.X, startWindowPos.Y.Scale, startWindowPos.Y.Offset + delta.Y)
	end
end)

-- =====================================================================
-- INJEKSI FITUR: SURVIVOR UTILITY & ESP
-- =====================================================================
task.spawn(function()
	local playerGui = lp:WaitForChild("PlayerGui", 5)
	if not playerGui then return end

	-- Auto Skill
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

	-- Fast Vault
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
							args[2].asset = "rbxassetid://79965656177" --[span_0](start_span)[span_0](end_span)
						end
					end
					return old(self, table.unpack(args, 1, args.n))
				end
			end
			return old(self, ...)
		end))
	end

	-- Speed Boost Slider Handler (0.1 - 3.0)
	local lastSet, gameWS = nil, nil
	local function sameSpeed(a, b) return b ~= nil and math.abs(a - b) < 0.02 end

	RunService.Heartbeat:Connect(function()
		local c = lp.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not (hum and c) then return end

		if not GUI:Get("speed_boost") or c:GetAttribute("Knocked") == true then
			if lastSet and sameSpeed(hum.WalkSpeed, lastSet) and gameWS then hum.WalkSpeed = gameWS end
			lastSet = nil
			return
		end

		if lastSet == nil or not sameSpeed(hum.WalkSpeed, lastSet) then
			gameWS = hum.WalkSpeed
		end

		local multiplier = GUI:Get("speed_value") or 1.0
		local target = gameWS * multiplier
		local allowed = c:GetAttribute("AC_AllowedSpeed")
		if type(allowed) == "number" then target = math.min(target, allowed - 0.5) end
		if target < gameWS then target = gameWS end

		lastSet = target
		hum.WalkSpeed = target
	end)
end)

-- ESP Handler
task.spawn(function()
	local function applyHighlight(targetModel, color, toggleKey)
		local enabled = GUI:Get(toggleKey)
		local existing = targetModel:FindFirstChild("VD_HL")
		if not enabled then
			if existing then existing:Destroy() end
			return
		end
		if targetModel and not existing then
			local hl = Instance.new("Highlight")
			hl.Name = "VD_HL"
			hl.Adornee = targetModel
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.FillColor = color
			hl.FillTransparency = 0.5
			hl.OutlineColor = color
			hl.OutlineTransparency = 0
			hl.Parent = targetModel
		end
	end

	RunService.Heartbeat:Connect(function()
		pcall(function()
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

print("[VD Utility] GitHub GUI Updated Successfully!")
return GUI
