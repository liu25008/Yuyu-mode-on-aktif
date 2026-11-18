-- =====================================================================
-- MODUL ESP LENGKAP: Killer, Survivor, Window, & Generator (Tembus Tembok)
-- =====================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer

local function initESP()
	local folder = CoreGui:FindFirstChild("VDESP_Fixed")
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "VDESP_Fixed"
	folder.Parent = CoreGui

	local function applyHighlight(targetModel, color)
		if targetModel and not targetModel:FindFirstChildOfClass("Highlight") then
			local hl = Instance.new("Highlight")
			hl.Adornee = targetModel
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Wajib supaya tembus tembok
			hl.FillColor = color
			hl.FillTransparency = 0.5
			hl.OutlineColor = color
			hl.OutlineTransparency = 0
			hl.Parent = folder
		end
	end

	-- Tabel untuk melacak ESP Player agar tidak numpuk
	local playerHighlights = {}

	RunService.Heartbeat:Connect(function()
		pcall(function()
			-- 1. ESP Player (Killer & Survivor)
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= lp then
					local char = p.Character
					local team = p.Team
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					
					if char and hum and hum.Health > 0 and team then
						local color = nil
						if team.Name == "Killer" then
							color = Color3.fromRGB(139, 26, 26) -- Merah untuk Killer
						elseif team.Name == "Survivors" then
							color = Color3.fromRGB(26, 52, 139) -- Biru untuk Survivor
						end
						
						if color then
							applyHighlight(char, color)
						end
					end
				end
			end

			-- 2. ESP Objek Map (Window/Vault & Generator berdasarkan log asli)
			local map = workspace:FindFirstChild("Map")
			if map then
				local vaults = map:FindFirstChild("Vaults")
				if vaults then
					for _, win in ipairs(vaults:GetChildren()) do
						applyHighlight(win, Color3.fromRGB(30, 200, 220)) -- Cyan untuk Window
					end
				end
				
				local gens = map:FindFirstChild("Generators") or map:FindFirstChild("new Generators")
				if gens then
					for _, gen in ipairs(gens:GetChildren()) do
						applyHighlight(gen, Color3.fromRGB(222, 100, 160)) -- Pink untuk Generator
					end
				end
			end
		end)
	end)
end

task.spawn(initESP)
print("[VD] Modul ESP Lengkap (Player & Objek) Loaded!")
