-- =====================================================================
-- VD UTILITY - CLEAN & FIXED GUI (GITHUB VERSION)
-- =====================================================================
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local parentGui = (gethui and gethui()) or CoreGui
local oldGui = parentGui:FindFirstChild("VDHub")
if oldGui then oldGui:Destroy() end

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

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function round(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function stroke(o, color, th) return new("UIStroke", {Color = color, Thickness = th or 1}, o) end

local gui = new("ScreenGui", {Name = "VDHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100}, parentGui)
local root = new("Frame", {Size = UDim2.fromOffset(420, 320), Position = UDim2.new(0.5, -210, 0.5, -160), BackgroundTransparency = 1}, gui)
local main = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.bg, ClipsDescendants = true}, root)
round(main, 12); stroke(main, T.line, 1)

local header = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, main)
new("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = "VD Utility - Final Fixed"}, header)
new("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.line, BorderSizePixel = 0}, header)

local side = new("Frame", {Size = UDim2.new(0, 110, 1, -40), Position = UDim2.fromOffset(0, 40), BackgroundColor3 = T.side}, main)
new("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.line}, side)

local content = new("Frame", {Size = UDim2.new(1, -110, 1, -40), Position = UDim2.new(0, 110, 0, 40), BackgroundTransparency = 1}, main)

-- Halaman Survivor
local pgSurvivor = new("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,250), AutomaticCanvasSize = Enum.AutomaticSize.Y}, content)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, pgSurvivor)

local State = {auto_skill = false, fast_vault = false, speed_boost = false, speed_value = 1.0, esp_killer = false, esp_survivor = false, esp_window = false, esp_generator = false}

local function makeToggle(parent, labelText, stateKey)
	local row = new("Frame", {Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 0), BackgroundColor3 = T.surface}, parent)
	round(row, 8); stroke(row, T.line, 1)
	new("TextLabel", {Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = labelText}, row)
	
	local track = new("Frame", {Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -50, 0.5, -10), BackgroundColor3 = T.off}, row)
	round(track, 10)
	local knob = new("Frame", {Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = T.knob}, track)
	round(knob, 7)

	local btn = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = ""}, row)
	btn.MouseButton1Click:Connect(function()
		State[stateKey] = not State[stateKey]
		track.BackgroundColor3 = State[stateKey] and T.accent or T.off
		knob.Position = State[stateKey] and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
	end)
end

makeToggle(pgSurvivor, "Auto Skill", "auto_skill")
makeToggle(pgSurvivor, "Fast Vault", "fast_vault")
makeToggle(pgSurvivor, "Speed Boost", "speed_boost")

-- Halaman ESP
local pgEsp = new("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, CanvasSize = UDim2.new(0,0,0,250), AutomaticCanvasSize = Enum.AutomaticSize.Y}, content)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, pgEsp)

makeToggle(pgEsp, "Killer ESP", "esp_killer")
makeToggle(pgEsp, "Survivor ESP", "esp_survivor")
makeToggle(pgEsp, "Window ESP", "esp_window")
makeToggle(pgEsp, "Generator ESP", "esp_generator")

-- Tab Samping
local tabSurv = new("TextButton", {Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 10), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = "  Survivor"}, side)
local tabEsp = new("TextButton", {Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 56), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = "  ESP"}, side)

tabSurv.MouseButton1Click:Connect(function()
	pgSurvivor.Visible = true; pgEsp.Visible = false
	tabSurv.TextColor3 = T.text; tabEsp.TextColor3 = T.muted
end)
tabEsp.MouseButton1Click:Connect(function()
	pgSurvivor.Visible = false; pgEsp.Visible = true
	tabSurv.TextColor3 = T.muted; tabEsp.TextColor3 = T.text
end)

-- Draggable
local dragging, dragInput, startPos
header.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging = true; dragInput = i.Position; startPos = root.Position
	end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
UIS.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragInput
		root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

-- Injeksi Fitur (Auto Skill, Fast Vault, Speed, ESP)
task.spawn(function()
	local playerGui = lp:WaitForChild("PlayerGui", 5)
	if not playerGui then return end

	RunService.Heartbeat:Connect(function()
		if State.auto_skill then
			pcall(function()
				local promptGui = playerGui:FindFirstChild("SkillCheckPromptGui")
				if promptGui and promptGui.Enabled then
					local check = promptGui:FindFirstChild("Check")
					if check and check:FindFirstChild("Line") and check:FindFirstChild("Goal") then
						check.Line.Rotation = check.Goal.Rotation
					end
				end
			end)
		end

		local c = lp.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if hum and c then
			if State.speed_boost and c:GetAttribute("Knocked") ~= true then
				local allowed = c:GetAttribute("AC_AllowedSpeed")
				local target = (hum.WalkSpeed) * 1.5
				if type(allowed) == "number" then target = math.min(target, allowed - 0.5) end
				hum.WalkSpeed = math.max(target, hum.WalkSpeed)
			end
		end
	end)

	local function applyHighlight(targetModel, color, enabled)
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
							applyHighlight(p.Character, Color3.fromRGB(139, 26, 26), State.esp_killer)
						elseif team.Name == "Survivors" then
							applyHighlight(p.Character, Color3.fromRGB(26, 52, 139), State.esp_survivor)
						end
					end
				end
			end

			local map = workspace:FindFirstChild("Map")
			if map then
				local vaults = map:FindFirstChild("Vaults")
				if vaults then
					for _, win in ipairs(vaults:GetChildren()) do
						applyHighlight(win, Color3.fromRGB(30, 200, 220), State.esp_window)
					end
				end
				local gens = map:FindFirstChild("Generators") or map:FindFirstChild("new Generators")
				if gens then
					for _, gen in ipairs(gens:GetChildren()) do
						applyHighlight(gen, Color3.fromRGB(222, 100, 160), State.esp_generator)
					end
				end
			end
		end)
	end)
end)

print("[VD Utility] GitHub Clean GUI Loaded!")
