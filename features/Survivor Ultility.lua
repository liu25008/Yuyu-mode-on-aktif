-- features/Survivor Utility.lua
-- Fitur halaman Survivor Utility. Jalankan SETELAH gui.lua.
-- By: @texx-breaker (Updated with SmugLib-style logic integration)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local GUI = env.VD_GUI
if not GUI then
	warn("[VD] gui.lua belum dijalankan, jalankan gui.lua dulu")
	return
end
if env.VD_SURV_CLEANUP then pcall(env.VD_SURV_CLEANUP) end

-- ===== pengaturan =====
local CFG = {
	-- parry
	MAX_DIST = 14,             -- jarak maksimum killer (tanpa Anti Fake Hit)
	FAKE_MAX_DIST = 10.5,      -- jarak maksimum (dengan Anti Fake Hit), dari data: sukses sampai 10.4
	FAKE_MIN_FACING = 0.3,     -- killer harus menghadap ke arah lo (1 = lurus, 0 = menyamping)
	FAKE_OPENING = 1.5,        -- abaikan kalau killer menjauh lebih dari ini dalam 0.25 detik
	PRED_RANGE = 6.5,          -- mode Prediktif: jarak killer
	PRED_FACING = 0.6,
	PRED_CLOSING = 0.6,        -- mode Prediktif: killer harus mendekat minimal sekian stud per 0.2 detik
	PRED_COOLDOWN = 3,
	PARRY_COOLDOWN = 0.8,      -- jeda minimum antar kiriman parry (disesuaikan standar SmugLib)
	PLAY_PARRY_ANIM = true,
	PARRY_ANIM = "rbxassetid://109133187196613",
	-- fast vault
	FAST_ASSET = "rbxassetid://83873880822918",
	FAST_VAULT_TIME = 0.65,    -- target durasi animasi vault (detik)
	FAST_VAULT_MAX_ANIM = 2.2, -- batas percepatan animasi
	-- speed boost (diubah mengadopsi standar multiplikasi)
	SPEED_FACTOR = 1.15,
	-- auto skill (detik)
	SKILL_GEN = {0.98, 1.48},
	SKILL_HEAL = {1.45, 1.65},
	SKILL_INSTAN = {0.03, 0.08},
	-- aimbot pistol
	PISTOL_KEYWORDS = {"pistol", "gun", "revolver", "handgun"},
	AIM_PART = "Head",
	AIM_FOV = 60,
	AIM_RANGE = 120,
	AIM_SMOOTH = 0.35,
	BULLET_SPEED = 250,
	AIM_LEAD = true,
	-- auto jongkok
	KILLER_KEYWORDS = {"abyss", "abby"},
	CROUCH_RANGE = 40,
	STAND_RANGE = 52,
	CROUCH_SPEED_CAP = 4,
	CROUCH_ANIM = "rbxassetid://107190870183828",
}

-- ID animasi serangan killer (TETAP AMAN TIDAK DIHILANGKAN)
local WINDUP = {}
for _, id in ipairs({
	127417297154354, 129626174716003, 84926129581106, 125430111937587, 135002183282873,
	117042998468241, 105374834496520, 113255068724446, 93902163029544,
}) do WINDUP[id] = true end
local SWING = {}
for _, id in ipairs({
	83333467665074, 113691709436161, 81963230963908, 101636125032002, 121216847022485,
	133963973694098, 111920872708571, 74968262036854, 75618342544502,
}) do SWING[id] = true end
local OTHER = {}
for _, id in ipairs({
	78196404793645, 126497551689502, 79935565590141, 73681849513551, 81499468767530,
	132493859298130, 85030641905220, 98163597193511, 133881825716964,
}) do OTHER[id] = true end

-- ===== dasar =====
local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local function note(msg)
	print("[VD] " .. msg)
	pcall(function()
		StarterGui:SetCore("SendNotification", {Title = "VD Utility", Text = msg, Duration = 4})
	end)
end

local RemotesFolder = RS:WaitForChild("Remotes", 15)
if not RemotesFolder then
	warn("[VD] folder Remotes tidak ketemu")
	return
end
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

-- ===== riwayat jarak killer =====
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

-- ===== AUTO PARRY (Diperbarui dengan integrasi logika SmugLib: Prioritas & TimePosition) =====
local lastParry, lastPred = 0, 0
local lastWindup = {}
local attackUntil = {}
local seenNew = {}

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

local function parryReady()
	local c = myChar()
	if not c or not R.Parry then return false end
	if c:GetAttribute("ParrySpent") == true or c:GetAttribute("Parry") == true then return false end
	if c:GetAttribute("Knocked") == true or c:GetAttribute("IsHooked") == true or c:GetAttribute("IsCarried") == true then return false end
	if not c:FindFirstChild("Parrying Dagger") then return false end
	return true
end

local function doParry(why)
	if os.clock() - lastParry < CFG.PARRY_COOLDOWN then return end
	if not parryReady() then return end
	lastParry = os.clock()
	R.Parry:FireServer(lp.Character)
	if CFG.PLAY_PARRY_ANIM then playAnimOnMe(CFG.PARRY_ANIM) end
	print("[VD] parry (" .. why .. ")")
end

local function passesFilter(plr, kr, mr, d)
	local strict = GUI:Get("anti_fake_hit") -- (Fitur Fake Hit tetap terjaga dan aktif)
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

local function learn(plr, track, id)
	if seenNew[id] or OTHER[id] or WINDUP[id] or SWING[id] then return end
	if track.Looped or track.Length < 0.9 or track.Length > 3.0 then return end
	if track.Priority == Enum.AnimationPriority.Core or track.Priority == Enum.AnimationPriority.Idle
		or track.Priority == Enum.AnimationPriority.Movement then return end
	seenNew[id] = true
	local line = string.format("%s id=%d len=%.2f prio=%s", plr.Name, id, track.Length, tostring(track.Priority))
	print("[VD] animasi killer baru: " + line)
	if appendfile then pcall(appendfile, "VD_NewKillerAnims.txt", line .. "\n") end
end

local hooked = {}
local function hookAnimator(plr, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local function attach(animator)
		if hooked[animator] then return end
		hooked[animator] = true
		connect(animator.AnimationPlayed, function(track)
			if not isKiller(plr) then return end
			local id = idOf(track)
			
			-- Integrasi tambahan deteksi berbasis prioritas SmugLib (sebelum/setelah stun/swing)
			local isActionThreat = (track.Priority.Value >= Enum.AnimationPriority.Action.Value and track.WeightCurrent > 0.05 and track.TimePosition < 0.35)
			
			if (id and WINDUP[id]) or isActionThreat then
				onAttackAnim(plr, char, true)
			elseif id and SWING[id] then
				onAttackAnim(plr, char, false)
			elseif id then
				learn(plr, track, id)
			end
		end)
	end
	local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5)
	if animator then attach(animator) end
	connect(hum.ChildAdded, function(c)
		if c:IsA("Animator") then attach(c) end
	end)
end

local function hookPlayer(plr)
	if plr == lp then return end
	if plr.Character then task.spawn(hookAnimator, plr, plr.Character) end
	connect(plr.CharacterAdded, function(c) task.spawn(hookAnimator, plr, c) end)
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
connect(Players.PlayerAdded, hookPlayer)

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

-- ===== AUTO SKILL (Diperbarui dengan integrasi respons instan/sempurna gaya SmugLib) =====
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

if R.GenEvent and R.GenResult then
	connect(R.GenEvent.OnClientEvent, function(...)
		if not GUI:Get("auto_skill") then return end
		local a = table.pack(...)
		local gen, point, guid = a[1], a[2], a[3]
		if typeof(gen) ~= "Instance" then return end
		task.delay(skillDelay("gen"), function()
			if GUI.Closed or not GUI:Get("auto_skill") then return end
			if type(guid) == "string" then markHandled(guid) end
			R.GenResult:FireServer("success", 1, gen, point, guid or "", lp.Character)
		end)
	end)
end
if R.HealEvent and R.HealResult then
	connect(R.HealEvent.OnClientEvent, function(...)
		if not GUI:Get("auto_skill") then return end
		local a = table.pack(...)
		local target, guid = a[1], a[2]
		if typeof(target) ~= "Instance" then return end
		task.delay(skillDelay("heal"), function()
			if GUI.Closed or not GUI:Get("auto_skill") then return end
			if type(guid) == "string" then markHandled(guid) end
			R.HealResult:FireServer("success", 1, target, guid or "", lp.Character)
		end)
	end)
end

-- ===== FAST VAULT (Diperbarui logika pelacakan track dan penyesuaian kecepatan) =====
local vaultState = nil

local function handler(remote, args)
	if remote == R.Vault and GUI:Get("fast_vault") then
		if args.n >= 5 and type(args[3]) == "string" and args[5] ~= "fast" then
			args[2] = true
			args[5] = "fast"
			vaultState = {guid = args[3], t = os.clock(), part = false}
			task.delay(0.1, function()
				if R.FastVault and vaultState then R.FastVault:FireServer(lp) end
			end)
		end
	elseif remote == R.Traversal and vaultState and GUI:Get("fast_vault") then
		if args[1] == "start" and type(args[2]) == "table" and os.clock() - vaultState.t < 1.2 then
			local p = args[2]
			p.moving = true
			p.speed = 1
			p.power = 1.2
			p.asset = CFG.FAST_ASSET
		elseif args[1] == "finish" and not vaultState.part then
			vaultState.part = true
			if R.VaultPart1 then R.VaultPart1:FireServer(vaultState.guid, lp.Character) end
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
			if m == "FireServer" and not (checkcaller and checkcaller()) then
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
	else
		note("Executor tidak mendukung hookmetamethod: Fast Vault dan blokir skill ganda mati")
	end
end

local function hookMyAnimator(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
	if not animator or hooked[animator] then return end
	hooked[animator] = true
	connect(animator.AnimationPlayed, function(track)
		if not GUI:Get("fast_vault") then return end
		local name = track.Animation and track.Animation.AnimationId or ""
		if not track.Looped and track.Length >= 0.4 then
			pcall(function()
				track:AdjustSpeed(math.clamp(track.Length / CFG.FAST_VAULT_TIME, 1, CFG.FAST_VAULT_MAX_ANIM))
			end)
		end
	end)
end
if lp.Character then task.spawn(hookMyAnimator, lp.Character) end
connect(lp.CharacterAdded, function(c) task.spawn(hookMyAnimator, c) end)

-- ===== SPEED BOOST (Diubah mengadopsi standar multiplikasi WalkSpeed ala SmugLib) =====
local lastSet, gameWS = nil, nil

local function speedBlocked(c)
	for _, k in ipairs({"isvaulting", "Knocked", "IsHooked", "IsCarried", "Immobile", "Crouching", "IsStunned"}) do
		if c:GetAttribute(k) == true then return true end
	end
	local strict = c:GetAttribute("AC_StrictAllowedSpeedUntil")
	if type(strict) == "number" and workspace.DistributedGameTime < strict then return true end
	return false
end

local function speedStep()
	local hum, c = myHum(), myChar()
	if not (hum and c) then return end
	if not GUI:Get("speed_boost") or speedBlocked(c) then
		if lastSet and hum.WalkSpeed == lastSet and gameWS then hum.WalkSpeed = gameWS end
		lastSet = nil
		return
	end
	if lastSet == nil or hum.WalkSpeed ~= lastSet then
		gameWS = hum.WalkSpeed 
	end
	-- Mengganti pendekatan dengan pengali langsung (multiplication style) seperti kerangka SmugLib
	local target = gameWS * CFG.SPEED_FACTOR
	local allowed = c:GetAttribute("AC_AllowedSpeed")
	if type(allowed) == "number" then target = math.min(target, allowed - 0.5) end
	if target < gameWS then target = gameWS end
	lastSet = target
	hum.WalkSpeed = target
end

-- ===== AIMBOT PISTOL =====
local function equippedPistol()
	local c = myChar()
	if not c then return nil end
	for _, t in ipairs(c:GetChildren()) do
		if t:IsA("Tool") then
			local n = t.Name:lower()
			for _, k in ipairs(CFG.PISTOL_KEYWORDS) do
				if n:find(k, 1, true) then return t end
			end
		end
	end
	return nil
end

local function visible(cam, part)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {lp.Character, part.Parent}
	local origin = cam.CFrame.Position
	return workspace:Raycast(origin, part.Position - origin, params) == nil
end

local function pickTarget(cam)
	local best, bestAng
	for _, p in ipairs(Players:GetPlayers()) do
		if isKiller(p) and p.Character and aliveHum(p.Character) then
			local part = p.Character:FindFirstChild(CFG.AIM_PART) or p.Character:FindFirstChild("HumanoidRootPart")
			if part then
				local dir = part.Position - cam.CFrame.Position
				local dist = dir.Magnitude
				if dist > 0.1 and dist <= CFG.AIM_RANGE then
					local ang = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(dir.Unit), -1, 1)))
					if ang <= CFG.AIM_FOV and (not bestAng or ang < bestAng) and visible(cam, part) then
						best, bestAng = part, ang
					end
				end
			end
		end
	end
	return best
end

local function aimStep()
	if not GUI:Get("aim_pistol") or not equippedPistol() then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local part = pickTarget(cam)
	if not part then return end
	local pos = part.Position
	if CFG.AIM_LEAD then
		local dist = (pos - cam.CFrame.Position).Magnitude
		pos = pos + part.AssemblyLinearVelocity * (dist / CFG.BULLET_SPEED)
	end
	cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, pos), CFG.AIM_SMOOTH)
end

-- ===== AUTO JONGKOK =====
local crouchTrack = nil

local function matchesKeyword(plr)
	local function has(s)
		if type(s) ~= "string" then return false end
		local low = s:lower()
		for _, kw in ipairs(CFG.KILLER_KEYWORDS) do
			if low:find(kw, 1, true) then return true end
		end
		return false
	end
	if has(plr.Name) or has(plr.DisplayName) then return true end
	local c = plr.Character
	if c and has(c.Name) then return true end
	if c then
		for _, v in pairs(c:GetAttributes()) do
			if has(v) then return true end
		end
	end
	for _, v in pairs(plr:GetAttributes()) do
		if has(v) then return true end
	end
	return false
end

local function findCrouchButton()
	local gui = lp:FindFirstChild("PlayerGui")
	if not gui then return nil end
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("GuiButton") then
			local n = d.Name:lower()
			if n:find("crouch", 1, true) or n:find("jongkok", 1, true) or n:find("duck", 1, true) then return d end
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

local function setCrouch(on)
	local c = myChar()
	if not c or (c:GetAttribute("Crouching") == true) == on then return end
	local btn = findCrouchButton()
	if btn and pressButton(btn) then return end
	if on then c:SetAttribute("Sprinting", false) end
	c:SetAttribute("Crouching", on)
	if R.ChangeAttr then R.ChangeAttr:FireServer("Crouchingserver", on) end
	local hum = myHum()
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if on and animator and not crouchTrack then
		pcall(function()
			local a = Instance.new("Animation")
			a.AnimationId = CFG.CROUCH_ANIM
			crouchTrack = animator:LoadAnimation(a)
			crouchTrack.Looped = true
			crouchTrack:Play()
		end)
	elseif not on and crouchTrack then
		crouchTrack:Stop()
		crouchTrack = nil
	end
end

local function crouchStep()
	if not GUI:Get("auto_crouch") then return end
	local c, mr = myChar(), myRoot()
	if not (c and mr) then return end
	local nearest
	for _, p in ipairs(Players:GetPlayers()) do
		if isKiller(p) and p.Character and matchesKeyword(p) then
			local kr = p.Character:FindFirstChild("HumanoidRootPart")
			if kr then
				local d = (kr.Position - mr.Position).Magnitude
				if not nearest or d < nearest then nearest = d end
			end
		end
	end
	local crouching = c:GetAttribute("Crouching") == true
	if nearest and nearest <= CFG.CROUCH_RANGE and c:GetAttribute("IsChased") ~= true then
		if not crouching then setCrouch(true) end
	elseif crouching and (not nearest or nearest >= CFG.STAND_RANGE or c:GetAttribute("IsChased") == true) then
		setCrouch(false)
	end
	if crouchTrack and crouching then
		local hum = myHum()
		if hum and hum.WalkSpeed > CFG.CROUCH_SPEED_CAP then hum.WalkSpeed = CFG.CROUCH_SPEED_CAP end
	end
end

-- ===== loop utama =====
local acc = 0
connect(RunService.Heartbeat, function(dt)
	if GUI.Closed then return end
	speedStep()
	acc = acc + dt
	if acc >= 0.05 then
		acc = 0
		sample()
		predictive()
		crouchStep()
	end
end)
connect(RunService.RenderStepped, function()
	if GUI.Closed then return end
	aimStep()
end)

-- ===== bersihkan saat panel ditutup =====
local function cleanup()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	local hum = myHum()
	if hum and lastSet and hum.WalkSpeed == lastSet and gameWS then hum.WalkSpeed = gameWS end
	if crouchTrack then pcall(function() crouchTrack:Stop() end) end
	if env.VD_SURV_HANDLER == handler then env.VD_SURV_HANDLER = nil end
end
env.VD_SURV_CLEANUP = cleanup
GUI:OnClose(cleanup)

print("[VD] Survivor Utility siap. Remote: parry=" .. tostring(R.Parry ~= nil)
	.. " skill=" .. tostring(R.GenEvent ~= nil) .. " vault=" .. tostring(R.Vault ~= nil))
