-- =====================================================================
-- MODUL: SURVIVOR UTILITY (Auto Skill, Fast Vault, & Speed Slider 0.1 - 3.0)
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local function initSurvivorUtility()
	local playerGui = lp:WaitForChild("PlayerGui", 5)
	if not playerGui then return end

	-- 1. Auto Skill / Generator Check
	RunService.Heartbeat:Connect(function()
		pcall(function()
			local promptGui = playerGui:FindFirstChild("SkillCheckPromptGui")
			if promptGui and promptGui.Enabled then
				local check = promptGui:FindFirstChild("Check")
				if check then
					local line = check:FindFirstChild("Line")
					local goal = check:FindFirstChild("Goal")
					if line and goal then
						line.Rotation = goal.Rotation -- Auto sukses instan
					end
				end
			end
		end)
	end)

	-- 2. Fast Vault & Traversal Remote (Berdasarkan Log Asli)
	local RemotesFolder = RS:WaitForChild("Remotes", 15)
	if RemotesFolder and hookmetamethod and getnamecallmethod and newcclosure then
		local vaultEvent = RemotesFolder:FindFirstChild("Window") and RemotesFolder.Window:FindFirstChild("VaultEvent")
		local fastVaultRemote = RemotesFolder:FindFirstChild("Window") and RemotesFolder.Window:FindFirstChild("fastvault")
		local traversalRemote = RemotesFolder:FindFirstChild("Mechanics") and RemotesFolder.Mechanics:FindFirstChild("TraversalRemote")

		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local m = getnamecallmethod()
			if m == "FireServer" and not (checkcaller and checkcaller()) then
				if self == vaultEvent then
					local args = table.pack(...)
					if args.n >= 5 then args[5] = "fast" end
					if fastVaultRemote then
						task.defer(function() fastVaultRemote:FireServer(lp) end)
					end
					return old(self, table.unpack(args, 1, args.n))
				elseif self == traversalRemote then
					local args = table.pack(...)
					if args[1] == "prepare" or args[1] == "start" then
						args[1] = "start"
						if type(args[2]) == "table" then
							args[2].moving = true
							args[2].speed = 2.0
							args[2].power = 1.5
							args[2].asset = "rbxassetid://79965656177" -- Asset ID Fast Vault asli dari log
						end
					end
					return old(self, table.unpack(args, 1, args.n))
				end
			end
			return old(self, ...)
		end))
	end

	-- 3. Speed Boost Aman dengan Slider (0.1 - 3.0)
	local lastSet, gameWS = nil, nil
	local function sameSpeed(a, b) return b ~= nil and math.abs(a - b) < 0.02 end

	RunService.Heartbeat:Connect(function()
		local c = lp.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not (hum and c) then return end

		-- Cek apakah fitur speed_boost aktif dan karakter tidak sedang knocked
		local speedToggle = _G.VD_GUI and _G.VD_GUI:Get("speed_boost") or false
		if not speedToggle or c:GetAttribute("Knocked") == true then
			if lastSet and sameSpeed(hum.WalkSpeed, lastSet) and gameWS then 
				hum.WalkSpeed = gameWS 
			end
			lastSet = nil
			return
		end

		if lastSet == nil or not sameSpeed(hum.WalkSpeed, lastSet) then
			gameWS = hum.WalkSpeed
		end

		-- Ambil multiplier dari slider (0.1 sampai 3.0)
		local multiplier = _G.VD_GUI and _G.VD_GUI:Get("speed_value") or 1.0
		local target = gameWS * multiplier

		-- Proteksi anti-cheat game (AC_AllowedSpeed) agar tidak kena banned
		local allowed = c:GetAttribute("AC_AllowedSpeed")
		if type(allowed) == "number" then 
			target = math.min(target, allowed - 0.5) 
		end
		if target < gameWS then target = gameWS end

		lastSet = target
		hum.WalkSpeed = target
	end)
end

task.spawn(initSurvivorUtility)
print("[VD] Modul Survivor Utility Terbaru Loaded!")
