-- =====================================================================
-- MODUL 1: SURVIVOR UTILITY (Fixed Fast Vault & Skill Check Prompt)
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer

local function initSurvivorUtility()
	local playerGui = lp:WaitForChild("PlayerGui", 5)
	if not playerGui then return end

	-- Fix Auto Skill / Generator berdasarkan VD_SkillGui.txt
	RunService.Heartbeat:Connect(function()
		pcall(function()
			local promptGui = playerGui:FindFirstChild("SkillCheckPromptGui")
			if promptGui and promptGui.Enabled then
				local check = promptGui:FindFirstChild("Check")
				if check then
					local line = check:FindFirstChild("Line")
					local goal = check:FindFirstChild("Goal")
					if line and goal then
						line.Rotation = goal.Rotation -- Auto nyamain posisi jarum ke target
					end
				end
			end
		end)
	end)

	-- Fix Fast Vault & TraversalRemote berdasarkan VD_VaultLog.txt
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
end

task.spawn(initSurvivorUtility)
print("[VD] Modul Survivor Utility Loaded!")
