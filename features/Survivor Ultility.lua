-- =====================================================================
-- FITUR: Survivor Utility (Fixed Fast Vault & Parry Cooldown Sesuai Mekanisme Asli)
-- =====================================================================
local function featureSurvivor()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer

if env.VD_SURV_CLEANUP then pcall(env.VD_SURV_CLEANUP) end

local CFG = {
	MAX_DIST = 14,
	FAKE_MAX_DIST = 10.5,
	FAKE_MIN_FACING = 0.3,
	FAKE_OPENING = 1.5,
	PRED_RANGE = 6.5,
	PRED_FACING = 0.6,
	PRED_CLOSING = 0.6,
	PRED_COOLDOWN = 3,
	PARRY_COOLDOWN = 1.0,
	PLAY_PARRY_ANIM = true,
	PARRY_ANIM = "rbxassetid://109133187196613",
	FAST_ASSET = "rbxassetid://79965656177566",
	FAST_VAULT_MAX_ANIM = 10,
	SKILL_GEN = {0.75, 0.95},
	SKILL_HEAL = {0.80, 1.05},
	SKILL_INSTAN = {0.02, 0.05},
	PISTOL_KEYWORDS = {"pistol", "gun", "revolver", "handgun"},
	AIM_PART = "Head",
	AIM_FOV = 60,
	AIM_RANGE = 120,
	AIM_SMOOTH = 0.35,
	BULLET_SPEED = 250,
	AIM_LEAD = true,
	KILLER_KEYWORDS = {"abyss", "abby"},
	CROUCH_RANGE = 40,
	STAND_RANGE = 52,
}

local WINDUP = {
	127417297154354, 129626174716003, 84926129581106, 125430111937587, 135002183282873,
	117042998468241, 105374834496520, 113255068724446, 93902163029544,
}
local SWING = {
	83333467665074, 113691709436161, 81963230963908, 101636125032002, 121216847022485,
	133963973694098, 111920872708571, 74968262036854, 75618342544502,
}

local conns = {}
local function connectSig(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local RemotesFolder = RS:WaitForChild("Remotes", 15)
if not RemotesFolder then return end
local function remote(...)
	local o = RemotesFolder
	for _, n in ipairs({...}) do
		if not o then return nil end
		o = o:FindFirstChild(n)
	end
	return o
end
local R = {
	GenEvent = remote("Generator", "SkillCheckEvent"),
	GenResult = remote("Generator", "SkillCheckResultEvent"),
	HealEvent = remote("Healing", "SkillCheckEvent"),
	HealResult = remote("Healing", "SkillCheckResultEvent"),
	Parry = remote("Items", "Parrying Dagger", "parry"),
	Vault = remote("Window", "VaultEvent"),
	FastVault = remote("Window", "fastvault"),
	VaultPart1 = remote("Window", "VaultCompleteEventpart1"),
	Traversal = remote("Mechanics", "TraversalRemote"),
	ChangeAttr = remote("Mechanics", "ChangeAttribute"),
}

local function myChar() return lp.Character end
local function myRoot()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function myHum()
	local c = lp.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function aliveHum(c)
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then return h end
	return nil
end

local function isKiller(plr)
	if plr == lp then return false end
	local team = plr.Team
	if team and team.Name == "Killer" then return true end
	local c = plr.Character
	return c ~= nil and c:GetAttribute("Killer") == true
end

local function rand(range)
	return range[1] + math.random() * (range[2] - range[1])
end

local function idOf(track)
	local anim = track.Animation
	if not anim then return nil end
	return tonumber(tostring(anim.AnimationId):match("(%d+)$"))
end

local hist = {}
local function sample()
	local mr = myRoot()
	if not mr then return end
	local now = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		if isKiller(p) then
			local kr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if kr then
				local h = hist[p]
				if not h then
					h = {}
					hist[p] = h
				end
				h[#h + 1] = {t = now, d = (kr.Position - mr.Position).Magnitude}
				while #h > 0 and now - h[1].t > 1.2 do table.remove(h, 1) end
			end
		end
	end
end

local function distBefore(p, dt)
	local h = hist[p]
	if not h or #h == 0 then return nil end
	local target = os.clock() - dt
	local best, bestGap
	for _, s in ipairs(h) do
		local gap = math.abs(s.t - target)
		if not bestGap or gap < bestGap then
			best, bestGap = s, gap
		end
	end
	if best and bestGap < 0.2 then return best.d end
	return nil
end

-- ===== AUTO PARRY (Fixed Cooldown Sesuai Mekanisme Asli) =====
local lastParry, lastPred = 0, 0
local lastWindup = {}
local attackUntil = {}
local lastHealth = nil

local function playAnimOnMe(assetId)
	local hum = myHum()
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = assetId
		local tr = animator:LoadAnimation(a)
		tr.Priority = Enum.AnimationPriority.Action
		tr:Play()
	end)
end

local function findDaggerButton()
	local pg = lp:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("GuiButton") then
			local n = d.Name:lower()
			if n:find("dagger", 1, true) or n:find("parry", 1, true) or n:find("tangkis", 1, true) then
				return d
			end
		end
	end
	return nil
end

local function pressButton(btn)
	local fired = false
	for _, sig in ipairs({btn.MouseButton1Down, btn.MouseButton1Click, btn.Activated}) do
		if getconnections then
			local ok, list = pcall(getconnections, sig)
			if ok and list then
				for _, c in ipairs(list) do
					if pcall(c.Fire, c) then fired = true end
				end
			end
		elseif firesignal then
			if pcall(firesignal, sig) then fired = true end
		end
	end
	return fired
end

local function checkParryReset()
	local c = myChar()
	local hum = myHum()
	if not (c and hum) then return end
	if lastHealth == nil then lastHealth = hum.Health end
	
	if hum.Health < lastHealth or c:GetAttribute("Hurt") == true or c:GetAttribute("Stunned") == true or c:GetAttribute("ParrySpent") == nil then
		c:SetAttribute("ParrySpent", false)
		c:SetAttribute("VD_ParryUsed", false)
		c:SetAttribute("Parry", false)
	end
	lastHealth = hum.Health
end

local function parryReady()
	checkParryReset()
	local c = myChar()
	if not c then return false end
	
	if c:GetAttribute("ParrySpent") == true or c:GetAttribute("VD_ParryUsed") == true then 
		return false 
	end
	if c:GetAttribute("Knocked") == true or c:GetAttribute("IsHooked") == true or c:GetAttribute("IsCarried") == true then 
		return false 
	end
	
	local tool = c:FindFirstChild("Parrying Dagger")
	if not tool then return false end
	return true
end

local function doParry(why)
	if os.clock() - lastParry < CFG.PARRY_COOLDOWN then return end
	if not parryReady() then return end
	lastParry = os.clock()
	local c = lp.Character
	if c then
		c:SetAttribute("VD_ParryUsed", true)
	end
	local btn = findDaggerButton()
	if btn and pressButton(btn) then
		if CFG.PLAY_PARRY_ANIM then playAnimOnMe(CFG.PARRY_ANIM) end
		return
	end
	if R.Parry then R.Parry:FireServer(c) end
	if CFG.PLAY_PARRY_ANIM then playAnimOnMe(CFG.PARRY_ANIM) end
end

local function passesFilter(plr, kr, mr, d)
	local strict = GUI:Get("anti_fake_hit")
	if d > (strict and CFG.FAKE_MAX_DIST or CFG.MAX_DIST) then return false end
	if strict then
		local toMe = mr.Position - kr.Position
		if toMe.Magnitude > 0.1 and kr.CFrame.LookVector:Dot(toMe.Unit) < CFG.FAKE_MIN_FACING then return false end
		local prev = distBefore(plr, 0.25)
		if prev and d - prev > CFG.FAKE_OPENING then return false end
	end
	return true
end

local function onAttackAnim(plr, char, isWindup)
	if not GUI:Get("auto_parry") then return end
	local now = os.clock()
	if isWindup then
		lastWindup[plr] = now
	elseif lastWindup[plr] and now - lastWindup[plr] < 1 then
		return
	end
	attackUntil[plr] = now + 0.9
	local mr, kr = myRoot(), char:FindFirstChild("HumanoidRootPart")
	if not (mr and kr) then return end
	local d = (kr.Position - mr.Position).Magnitude
	if passesFilter(plr, kr, mr, d) then
		doParry(isWindup and "aba-aba" or "pukulan")
	end
end

local function hookAnimator(plr, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local function attach(animator)
		connectSig(animator.AnimationPlayed, function(track)
			if not isKiller(plr) then return end
			local id = idOf(track)
			if not id then return end
			for _, wId in ipairs(WINDUP) do if wId == id then onAttackAnim(plr, char, true) return end end
			for _, sId in ipairs(SWING) do if sId == id then onAttackAnim(plr, char, false) return end end
		end)
	end
	local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
	if animator then attach(animator) end
	connectSig(hum.ChildAdded, function(c)
		if c:IsA("Animator") then attach(c) end
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	if p ~= lp then
		if p.Character then task.spawn(hookAnimator, p, p.Character) end
		connectSig(p.CharacterAdded, function(c) task.spawn(hookAnimator, p, c) end)
	end
end
connectSig(Players.PlayerAdded, function(p)
	connectSig(p.CharacterAdded, function(c) task.spawn(hookAnimator, p, c) end)
end)

local function predictive()
	if not GUI:Get("auto_parry") or GUI:Get("auto_parry_mode") ~= "Prediktif" then return end
	local c, mr = myChar(), myRoot()
	if not (c and mr) or c:GetAttribute("IsChased") ~= true then return end
	if os.clock() - lastPred < CFG.PRED_COOLDOWN then return end
	for _, p in ipairs(Players:GetPlayers()) do
		if isKiller(p) and p.Character then
			local kr = p.Character:FindFirstChild("HumanoidRootPart")
			if kr and not (attackUntil[p] and os.clock() < attackUntil[p]) then
				local toMe = mr.Position - kr.Position
				local d = toMe.Magnitude
				if d <= CFG.PRED_RANGE and d > 0.1 then
					local facing = kr.CFrame.LookVector:Dot(toMe.Unit)
					local prev = distBefore(p, 0.2)
					if facing >= CFG.PRED_FACING and prev and prev - d >= CFG.PRED_CLOSING then
						lastPred = os.clock()
						doParry("prediktif")
						return
					end
				end
			end
		end
	end
end

-- ===== AUTO SKILL & FAST VAULT HOOK =====
local handled = {}
local function markHandled(guid)
	local now = os.clock()
	handled[guid] = now
	for k, t in pairs(handled) do
		if now - t > 30 then handled[k] = nil end
	end
end

local function skillDelay(kind)
	if GUI:Get("auto_skill_mode") == "Instan" then return rand(CFG.SKILL_INSTAN) end
	return rand(kind == "gen" and CFG.SKILL_GEN or CFG.SKILL_HEAL)
end

local function playerLeaving()
	local hum = myHum()
	if not hum then return true end
	if hum.MoveDirection.Magnitude > 0.15 then return true end
	for _, k in ipairs({Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
		Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right}) do
		if UIS:IsKeyDown(k) then return true end
	end
	return false
end

local function answerLater(kind, guid, send)
	task.spawn(function()
		local untilT = os.clock() + skillDelay(kind)
		while os.clock() < untilT do
			if GUI.Closed or not GUI:Get("auto_skill") or playerLeaving() then return end
			task.wait(0.01)
		end
		if GUI.Closed or not GUI:Get("auto_skill") or playerLeaving() then return end
		markHandled(guid)
		send()
	end)
end

if R.GenEvent and R.GenResult then
	connectSig(R.GenEvent.OnClientEvent, function(...)
		if not GUI:Get("auto_skill") then return end
		local a = table.pack(...)
		local gen, point, guid = a[1], a[2], a[3]
		if typeof(gen) ~= "Instance" or type(guid) ~= "string" then return end
		answerLater("gen", guid, function()
			R.GenResult:FireServer("success", 1, gen, point, guid, lp.Character)
		end)
	end)
end
if R.HealEvent and R.HealResult then
	connectSig(R.HealEvent.OnClientEvent, function(...)
		if not GUI:Get("auto_skill") then return end
		local a = table.pack(...)
		local target, guid = a[1], a[2]
		if typeof(target) ~= "Instance" or type(guid) ~= "string" then return end
		answerLater("heal", guid, function()
			R.HealResult:FireServer("success", 1, target, guid, lp.Character)
		end)
	end)
end

local vaultWindow = 0
local handler = function(remote, args)
	if (remote == R.Vault or remote == R.VaultPart1) and GUI:Get("fast_vault") then
		vaultWindow = os.clock() + 1.5
		task.defer(function()
			if R.FastVault then R.FastVault:FireServer(lp) end
		end)
		if args.n >= 2 then
			args[2] = true
			if args.n >= 5 then args[5] = "fast" end
		end
	elseif remote == R.Traversal and GUI:Get("fast_vault") then
		if args[1] == "prepare" or args[1] == "start" then
			args[1] = "start"
			if type(args[2]) == "table" then
				args[2].moving = true
				args[2].speed = 1.2
				args[2].power = 1.5
				args[2].asset = CFG.FAST_ASSET
			end
		end
	elseif remote == R.GenResult or remote == R.HealResult then
		local guid = (remote == R.GenResult) and args[5] or args[4]
		if type(guid) == "string" and handled[guid] then return "drop" end
	end
	return nil
end
env.VD_SURV_HANDLER = handler

if not env.VD_SURV_HOOKED then
	if hookmetamethod and getnamecallmethod and newcclosure then
		env.VD_SURV_HOOKED = true
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local m = getnamecallmethod()
			if (m == "FireServer" or m == "InvokeServer") and not (checkcaller and checkcaller()) then
				local h = env.VD_SURV_HANDLER
				if h and typeof(self) == "Instance" then
					local args = table.pack(...)
					local ok, res = pcall(h, self, args)
					if ok and res == "drop" then return end
					return old(self, table.unpack(args, 1, args.n))
				end
			end
			return old(self, ...)
		end))
	end
end

local function hookMyAnimator(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
	if not animator then return end
	connectSig(animator.AnimationPlayed, function(track)
		if not GUI:Get("fast_vault") then return end
		if track.Looped or track.Length < 0.6 then return end
		local prio = track.Priority
		if prio == Enum.AnimationPriority.Core or prio == Enum.AnimationPriority.Idle then return end
		if char:GetAttribute("isvaulting") == true or os.clock() < vaultWindow then
			track:AdjustSpeed(CFG.FAST_VAULT_MAX_ANIM)
		end
	end)
end
if lp.Character then task.spawn(hookMyAnimator, lp.Character) end
connectSig(lp.CharacterAdded, function(c) task.spawn(hookMyAnimator, c) end)

local lastSet, gameWS = nil, nil
local function sameSpeed(a, b)
	return b ~= nil and math.abs(a - b) < 0.02
end

local function speedStep()
	local hum, c = myHum(), myChar()
	if not (hum and c) then return end
	if not GUI:Get("speed_boost") or c:GetAttribute("Knocked") == true then
		if lastSet and sameSpeed(hum.WalkSpeed, lastSet) and gameWS then hum.WalkSpeed = gameWS end
		lastSet = nil
		return
	end
	if lastSet == nil or not sameSpeed(hum.WalkSpeed, lastSet) then
		gameWS = hum.WalkSpeed
	end
	local target = gameWS * (GUI:Get("speed_value") or 1.0)
	local allowed = c:GetAttribute("AC_AllowedSpeed")
	if type(allowed) == "number" then target = math.min(target, allowed - 0.5) end
	if target < gameWS then target = gameWS end
	lastSet = target
	hum.WalkSpeed = target
end

local acc = 0
connect(RunService.Heartbeat, function(dt)
	if GUI.Closed then return end
	speedStep()
	acc = acc + dt
	if acc >= 0.05 then
		acc = 0
		sample()
		predictive()
		checkParryReset()
	end
end)
end
