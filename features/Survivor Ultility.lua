-- features/Survivor Ultility.lua
-- Isi file ini sama dengan blok featureSurvivor di gui.lua. Boleh dijalankan sebagai file sendiri
-- setelah gui.lua, atau ditempel di dalam: local function featureSurvivor() ... end
-- By: @texx-breaker
--
-- Perubahan terbaru (dipelajari dari script lain yang lo kasih, bukan disalin):
--  * Auto Skill: jarum dibaca dari tampilan (Line dikurangi Goal), lalu tombol skill check bawaan game
--    ditekan lewat VirtualInputManager tepat di zona perfect. Game sendiri yang mengirim hasilnya,
--    jadi tampilan, kunci gerak, dan hasil di server berjalan normal.
--  * Auto Parry: dicoba lewat tombol item bawaan (kb_item), jadi cooldown dan tombol di layar ikut jalan.
--    Pengendali dagger asli dibaca lewat getgc dan dipakai untuk mengecek CanUse().
--  * Fast Vault: memakai pengendali gerak asli (isVaulting dan activeVaultTrack) dan atribut vaultspeed,
--    ditambah tier fast di remote. Durasi tiap vault dicatat ke VD_VaultLog.txt supaya bisa dicek.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local GUI = env.VD_GUI
if not GUI then return end
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
	PARRY_COOLDOWN = 1.0,      -- jeda minimum antar kiriman parry
	PARRY_USE_BUTTON = true,   -- cadangan: tekan tombol dagger di layar kalau tombol item bawaan tidak jalan
	PARRY_WORDS = {"parry", "dagger", "tangkis"},
	PLAY_PARRY_ANIM = true,    -- hanya dipakai kalau parry lewat remote
	PARRY_ANIM = "rbxassetid://109133187196613",
	-- fast vault
	FAST_ASSET = "rbxassetid://83873880822918",
	FAST_VAULT_TIME = 0.62,    -- target durasi vault (detik); vault fast bawaan sekitar 0.6 detik
	FAST_VAULT_MAX_ANIM = 3,   -- batas percepatan animasi
	VAULT_ATTR = 1.5,          -- atribut vaultspeed minimum selama Fast Vault menyala (1 = tidak diubah)
	-- auto skill
	SKILL_WIN = {104, 114},    -- selisih Line dan Goal (derajat) yang dihitung perfect, dari pengendali bawaan game
	SKILL_INSTAN = {0.05, 0.12}, -- mode Instan: jeda sejak skill check muncul sampai tombol ditekan (detik)
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

-- ID animasi serangan killer (dari log). Tambah sendiri kalau ada killer baru.
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
	GenResult = remote("Generator", "SkillCheckResultEvent"),
	HealResult = remote("Healing", "SkillCheckResultEvent"),
	Parry = remote("Items", "Parrying Dagger", "parry"),
	Vault = remote("Window", "VaultEvent"),
	FastVault = remote("Window", "fastvault"),
	VaultPart1 = remote("Window", "VaultCompleteEventpart1"),
	Traversal = remote("Mechanics", "TraversalRemote"),
	ChangeAttr = remote("Mechanics", "ChangeAttribute"),
}

-- kirim remote tanpa melewati hook __namecall milik script ini
local function fire(rem, ...)
	if not rem then return end
	local ok, err = pcall(rem.FireServer, rem, ...)
	if not ok then warn("[VD] gagal kirim " .. rem.Name .. ": " .. tostring(err)) end
end

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

local function hasWord(s, words)
	s = s:lower()
	for _, w in ipairs(words) do
		if s:find(w, 1, true) then return true end
	end
	return false
end

-- nama script pemilik sebuah fungsi (untuk mencari pemegang tombol dan input)
local function scriptNameOf(fn)
	local ok, e = pcall(getfenv, fn)
	if ok and type(e) == "table" then
		local ok2, s = pcall(function() return e.script end)
		if ok2 and typeof(s) == "Instance" then return s:GetFullName():lower() end
	end
	return ""
end

local function connectionsOf(sig)
	if not getconnections then return {} end
	local ok, list = pcall(getconnections, sig)
	if ok and list then return list end
	return {}
end

local function ownedBy(sig, words)
	for _, c in ipairs(connectionsOf(sig)) do
		local fn = nil
		pcall(function() fn = c.Function end)
		if fn and hasWord(scriptNameOf(fn), words) then return true end
	end
	return false
end

-- ===== input bawaan game (lewat VirtualInputManager) =====
-- Game membaca tombol dari atribut kb_<aksi> milik pemain: kb_skillcheck, kb_item, kb_interact, dst.
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local function worldInputPoint()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local pg = lp:FindFirstChild("PlayerGui")
	for _, fraction in ipairs({Vector2.new(0.88, 0.42), Vector2.new(0.12, 0.42), Vector2.new(0.88, 0.25)}) do
		local point = Vector2.new(math.floor(size.X * fraction.X), math.floor(size.Y * fraction.Y))
		local blocked = false
		if pg then
			for _, g in ipairs(pg:GetGuiObjectsAtPosition(point.X, point.Y)) do
				if g:IsA("GuiButton") or g:IsA("TextBox") then blocked = true break end
			end
		end
		if not blocked then return point end
	end
	return nil
end

local function sendBinding(name, down, position)
	if not VIM then error("VirtualInputManager tidak tersedia") end
	if name == "MouseButton1" or name == "MouseButton2" then
		local point = position or worldInputPoint()
		if not point then error("tidak ada titik layar yang kosong", 0) end
		if down then VIM:SendMouseMoveEvent(point.X, point.Y, game) end
		VIM:SendMouseButtonEvent(point.X, point.Y, name == "MouseButton1" and 0 or 1, down, game, 0)
	else
		local ok, key = pcall(function() return Enum.KeyCode[name] end)
		if not ok or not key then error("tombol tidak dikenal: " .. tostring(name)) end
		VIM:SendKeyEvent(down, key, false, game)
	end
end

local function pressBinding(action)
	local default = (action == "item") and "MouseButton2" or "Space"
	local name = lp:GetAttribute("kb_" .. action) or default
	if name == "MouseButton1" or name == "MouseButton2" then
		local point = worldInputPoint()
		if not point then error("tidak ada titik layar yang kosong", 0) end
		sendBinding(name, true, point)
		task.delay(0.06, function() pcall(sendBinding, name, false, point) end)
	else
		sendBinding(name, true)
		sendBinding(name, false)
	end
	return name
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

-- ===== pengendali asli dari memori game (getgc) =====
local function dumpApi(t, file)
	if not appendfile then return end
	local lines = {"pengendali: kunci tabel"}
	for k, v in pairs(t) do lines[#lines + 1] = tostring(k) .. " = " .. typeof(v) end
	local mt = getmetatable(t)
	if type(mt) == "table" and type(mt.__index) == "table" then
		lines[#lines + 1] = "metatable.__index:"
		for k, v in pairs(mt.__index) do lines[#lines + 1] = tostring(k) .. " = " .. typeof(v) end
	end
	pcall(appendfile, file, table.concat(lines, "\n") .. "\n")
end

local function scanGc(predicate)
	if type(getgc) ~= "function" then return nil end
	local ok, list = pcall(getgc, true)
	if not ok or type(list) ~= "table" then return nil end
	for _, t in ipairs(list) do
		if type(t) == "table" and predicate(t) then return t end
	end
	return nil
end

local parryCtl, nextParryScan = nil, 0
local function findParryController()
	local ch = lp.Character
	if parryCtl and parryCtl.character == ch and parryCtl.tool and parryCtl.tool:IsDescendantOf(ch) then return parryCtl end
	parryCtl = nil
	if not ch or os.clock() < nextParryScan then return nil end
	nextParryScan = os.clock() + 4
	parryCtl = scanGc(function(t)
		return rawget(t, "character") == ch and rawget(t, "parryEvent") ~= nil and rawget(t, "tool") ~= nil
	end)
	if parryCtl then
		print("[VD] pengendali dagger asli ketemu")
		dumpApi(parryCtl, "VD_ParryApi.txt")
	end
	return parryCtl
end

local moveCtl, nextMoveScan = nil, 0
local function findMovement()
	local ch = lp.Character
	if moveCtl and moveCtl.character == ch then return moveCtl end
	moveCtl = nil
	if not ch or os.clock() < nextMoveScan then return nil end
	nextMoveScan = os.clock() + 5
	moveCtl = scanGc(function(t)
		return rawget(t, "character") == ch and rawget(t, "normalWalkSpeed") ~= nil and rawget(t, "_movement") ~= nil
	end)
	return moveCtl
end

-- ===== AUTO PARRY =====
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
	if c:GetAttribute("Parry") == true then return false end
	if c:GetAttribute("Knocked") == true or c:GetAttribute("IsHooked") == true or c:GetAttribute("IsCarried") == true then return false end
	local ctl = findParryController()
	if ctl then
		-- CanUse() adalah cek cooldown dan status item milik game sendiri
		if type(ctl.CanUse) == "function" then
			local ok, can = pcall(ctl.CanUse, ctl)
			if ok and not can then return false end
		end
		return true
	end
	if c:GetAttribute("ParrySpent") == true then return false end
	if not c:FindFirstChild("Parrying Dagger") then return false end
	return true
end

-- cari tombol dagger di layar: dari nama, atau dari script pemegangnya (nama script mengandung parry atau dagger)
local parryBtn, nextBtnScan, parryBtnLogged = nil, 0, false
local function findParryButton()
	if parryBtn and parryBtn.Parent then return parryBtn end
	if os.clock() < nextBtnScan then return nil end
	nextBtnScan = os.clock() + 3
	local pg = lp:FindFirstChild("PlayerGui")
	if not pg then return nil end
	local named, owned
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("GuiButton") then
			if hasWord(d.Name, CFG.PARRY_WORDS) or (d.Parent and hasWord(d.Parent.Name, CFG.PARRY_WORDS)) then
				named = named or d
			elseif not owned and d.Visible
				and (ownedBy(d.Activated, CFG.PARRY_WORDS) or ownedBy(d.MouseButton1Click, CFG.PARRY_WORDS)
					or ownedBy(d.MouseButton1Down, CFG.PARRY_WORDS)) then
				owned = d
			end
		end
	end
	parryBtn = named or owned
	if parryBtn and not parryBtnLogged then
		parryBtnLogged = true
		print("[VD] tombol parry ketemu: " .. parryBtn:GetFullName())
	end
	return parryBtn
end

-- tekan tombol lewat sambungan eventnya (tombol sungguhan, jadi cooldown dan tampilannya ikut jalan)
local function pressGui(obj)
	local fired = false
	local pos = obj.AbsolutePosition + obj.AbsoluteSize / 2
	local fake = {
		UserInputType = Enum.UserInputType.Touch,
		UserInputState = Enum.UserInputState.Begin,
		KeyCode = Enum.KeyCode.Unknown,
		Position = Vector3.new(pos.X, pos.Y, 0),
		Delta = Vector3.new(0, 0, 0),
	}
	local list = {
		{obj.MouseButton1Down, pos.X, pos.Y},
		{obj.MouseButton1Click},
		{obj.Activated, fake, 1},
		{obj.TouchTap, {Vector2.new(pos.X, pos.Y)}},
	}
	for _, item in ipairs(list) do
		local sig = item[1]
		if getconnections then
			for _, c in ipairs(connectionsOf(sig)) do
				if pcall(c.Fire, c, item[2], item[3]) then fired = true end
			end
		elseif firesignal then
			if pcall(firesignal, sig, item[2], item[3]) then fired = true end
		end
	end
	return fired
end

local function parryUsed(c)
	return c and (c:GetAttribute("Parry") == true or c:GetAttribute("ParrySpent") == true)
end

local function doParry(why)
	if os.clock() - lastParry < CFG.PARRY_COOLDOWN then return end
	if not parryReady() then return end
	lastParry = os.clock()
	local c = lp.Character
	local method = nil
	-- 1) tombol item bawaan game (jalur yang sama dengan pemain)
	if VIM then
		local ok = pcall(pressBinding, "item")
		if ok then method = "tombol item" end
	end
	-- 2) tombol dagger di layar
	if not method and CFG.PARRY_USE_BUTTON then
		local btn = findParryButton()
		if btn and pressGui(btn) then method = "tombol layar" end
	end
	if method then
		print("[VD] parry via " .. method .. " (" .. why .. ")")
		task.delay(0.2, function()
			if parryUsed(c) then return end
			fire(R.Parry, c)
			print("[VD] " .. method .. " tidak merespons, kirim remote")
		end)
	else
		fire(R.Parry, c)
		if CFG.PLAY_PARRY_ANIM then playAnimOnMe(CFG.PARRY_ANIM) end
		print("[VD] parry via remote (" .. why .. ")")
	end
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
		return -- aba-aba sudah ditangani
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
	print("[VD] animasi killer baru: " .. line)
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
			if not id then return end
			if WINDUP[id] then
				onAttackAnim(plr, char, true)
			elseif SWING[id] then
				onAttackAnim(plr, char, false)
			else
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

-- ===== AUTO SKILL =====
-- Tampilan: SkillCheckPromptGui.Check berisi Line (jarum) dan Goal (zona). Pengendali bawaan game menilai perfect
-- kalau (Line.Rotation - Goal.Rotation) ada di sekitar 104 sampai 114 derajat saat tombol skill check ditekan.
-- Mode Perfect menekan tombol itu tepat di zona. Mode Instan menekan segera, lalu hasil yang bukan success
-- diubah jadi success saat dikirim game (lihat handler).
local lastPress = 0
local qtePressed = false
local qteSeen, qteDelay = nil, 0
local tapPrints = 0

local function skillParts()
	local pg = lp:FindFirstChild("PlayerGui")
	local g = pg and pg:FindFirstChild("SkillCheckPromptGui")
	local check = g and g:FindFirstChild("Check")
	if not check then return nil end
	return {gui = g, check = check, line = check:FindFirstChild("Line"), goal = check:FindFirstChild("Goal")}
end

-- cadangan kalau VirtualInputManager tidak ada: ketuk lewat sambungan event milik script skill check
local function tapSkillCheck()
	local sp = skillParts()
	if not sp or not getconnections then return false end
	local center = sp.check.AbsolutePosition + sp.check.AbsoluteSize / 2
	local fake = {
		UserInputType = Enum.UserInputType.Touch,
		UserInputState = Enum.UserInputState.Begin,
		KeyCode = Enum.KeyCode.Unknown,
		Position = Vector3.new(center.X, center.Y, 0),
		Delta = Vector3.new(0, 0, 0),
	}
	local fired = false
	for _, c in ipairs(connectionsOf(UIS.InputBegan)) do
		local fn = nil
		pcall(function() fn = c.Function end)
		if fn and hasWord(scriptNameOf(fn), {"skillcheck", "skill"}) then
			if pcall(c.Fire, c, fake, false) then fired = true end
		end
	end
	if tapPrints < 3 then
		tapPrints = tapPrints + 1
		print("[VD] ketuk skill check (cadangan): " .. (fired and "terkirim" or "tidak ada sambungan"))
	end
	return fired
end

local function pressSkill()
	local pressed = false
	if VIM then
		local ok, name = pcall(pressBinding, "skillcheck")
		if ok then pressed = true end
	end
	if not pressed then pressed = tapSkillCheck() end
	if pressed then
		lastPress = os.clock()
		qtePressed = true
	end
end

local function qteStep()
	if not GUI:Get("auto_skill") then qteSeen = nil; return end
	local sp = skillParts()
	local g = sp and sp.gui
	if not (sp and g.Enabled and sp.check.Visible and sp.line and sp.goal) then
		qteSeen = nil
		qtePressed = false
		return
	end
	local ch = lp.Character
	local controller = ch and ch:FindFirstChild("CheckInterractable")
	if not controller or not (controller:GetAttribute("isRepairing") or controller:GetAttribute("isHealing")) then return end
	if qtePressed then return end
	if GUI:Get("auto_skill_mode") == "Instan" then
		if not qteSeen then
			qteSeen = os.clock()
			qteDelay = rand(CFG.SKILL_INSTAN)
		end
		if os.clock() - qteSeen >= qteDelay then pressSkill() end
	else
		local d = (sp.line.Rotation - sp.goal.Rotation) % 360
		if d >= CFG.SKILL_WIN[1] and d <= CFG.SKILL_WIN[2] then pressSkill() end
	end
end

-- ===== FAST VAULT dan ubah hasil skill check (lewat hook remote) =====
local vaultState = nil
local vaultWindow = 0 -- selama jendela ini aktif, remote vault dicatat ke VD_VaultLog.txt
local vaultLogN = 0

local function logLine(file, text)
	if vaultLogN >= 200 or not appendfile then return end
	vaultLogN = vaultLogN + 1
	pcall(appendfile, file, text .. "\n")
end

local function logVault(tag, rem, args, file)
	if hasWord(rem.Name, {"pushremote", "updatecharacterlook", "getping", "echovoid"}) then return end
	local parts = {}
	for i = 1, args.n do
		local v = args[i]
		local t = typeof(v)
		if t == "string" or t == "number" or t == "boolean" then
			parts[i] = t .. ":" .. tostring(v):sub(1, 24)
		elseif t == "Instance" then
			parts[i] = "Instance:" .. v.ClassName
		elseif t == "table" then
			local ks = {}
			for k, val in pairs(v) do ks[#ks + 1] = tostring(k) .. "=" .. tostring(val):sub(1, 20) end
			parts[i] = "table{" .. table.concat(ks, ",") .. "}"
		else
			parts[i] = t
		end
	end
	logLine(file or "VD_VaultLog.txt", string.format("%s %s (%s)", tag, rem.Name, table.concat(parts, ", ")))
end

local function handler(rem, args)
	if GUI:Get("fast_vault") and (rem == R.Vault or rem == R.Traversal or rem == R.FastVault or rem == R.VaultPart1
		or (os.clock() < vaultWindow and rem.Parent and rem.Parent.Name ~= "Remotes")) then
		logVault("kirim", rem, args)
	end
	-- Fast Vault: ubah tier vault jadi "fast", sama seperti urutan yang tercatat di log
	if rem == R.Vault and GUI:Get("fast_vault") then
		if args.n >= 5 and type(args[3]) == "string" and args[5] ~= "fast" then
			args[2] = true
			args[5] = "fast"
			vaultState = {guid = args[3], t = os.clock(), part = false}
			vaultWindow = os.clock() + 2
			task.delay(0.1, function()
				if R.FastVault and vaultState then fire(R.FastVault, lp) end
			end)
		end
	elseif rem == R.Traversal and GUI:Get("fast_vault") and (vaultState or os.clock() < vaultWindow) then
		if args[1] == "start" and type(args[2]) == "table"
			and ((vaultState and os.clock() - vaultState.t < 1.2) or os.clock() < vaultWindow) then
			local p = args[2]
			p.moving = true
			p.speed = 1
			p.power = 1.2
			p.asset = CFG.FAST_ASSET
		elseif args[1] == "finish" and vaultState and not vaultState.part then
			vaultState.part = true
			if R.VaultPart1 then fire(R.VaultPart1, vaultState.guid, lp.Character) end
		end
	-- Auto Skill: kalau kita yang baru menekan tombol skill check, hasil yang bukan sukses diubah jadi sukses
	elseif rem == R.GenResult or rem == R.HealResult then
		if GUI:Get("auto_skill") and args.n >= 2 and os.clock() - lastPress < 1.6 then
			logVault("skill", rem, args, "VD_SkillLog.txt")
			if args[1] ~= "success" then
				args[1] = "success"
				args[2] = 1
			end
		end
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
			if m == "FireServer" and typeof(self) == "Instance" then
				local h = env.VD_SURV_HANDLER
				if h then
					local args = table.pack(...)
					pcall(h, self, args)
					return old(self, table.unpack(args, 1, args.n))
				end
			end
			return old(self, ...)
		end))
	else
		note("Executor tidak mendukung hookmetamethod: tier Fast Vault dan hasil Auto Skill tidak bisa diubah")
	end
end

-- apakah lo lagi dekat pemicu window (dipakai kalau pengendali gerak tidak ketemu)
local function nearVault()
	local mr = myRoot()
	if not mr then return false end
	local ok, found = pcall(workspace.GetPartBoundsInRadius, workspace, mr.Position, 7)
	if not ok then return false end
	for _, p in ipairs(found) do
		if p.Name == "VaultTrigger" then return true end
	end
	return false
end

-- atribut vaultspeed dibaca pengendali gerak bawaan; dinaikkan selama Fast Vault menyala dan dikembalikan setelahnya
local vaultAttrOrig, vaultAttrLast = nil, nil
local function setVaultAttr(ch)
	local cur = ch:GetAttribute("vaultspeed")
	if type(cur) ~= "number" then return end
	if vaultAttrLast == nil or cur ~= vaultAttrLast then vaultAttrOrig = cur end
	if cur < CFG.VAULT_ATTR then
		ch:SetAttribute("vaultspeed", CFG.VAULT_ATTR)
		vaultAttrLast = CFG.VAULT_ATTR
	else
		vaultAttrLast = nil
	end
end

local function restoreVaultAttr()
	local ch = lp.Character
	if ch and vaultAttrOrig ~= nil and vaultAttrLast ~= nil and ch:GetAttribute("vaultspeed") == vaultAttrLast then
		ch:SetAttribute("vaultspeed", vaultAttrOrig)
	end
	vaultAttrOrig, vaultAttrLast = nil, nil
end

local function trackSpeedOf(track)
	return track.CurrentSpeed or (track.Track and track.Track.Speed) or track.Speed
end

local vaultTracks = {}
local function restoreVaultTracks()
	for track, row in pairs(vaultTracks) do
		pcall(function()
			if track.IsPlaying then track:AdjustSpeed(row.original) end
		end)
	end
	vaultTracks = {}
end

-- percepat animasi vault lewat pengendali gerak asli (isVaulting dan activeVaultTrack)
local function vaultSpeedStep()
	if not GUI:Get("fast_vault") then
		restoreVaultAttr()
		restoreVaultTracks()
		return
	end
	local ch = lp.Character
	if not ch then return end
	setVaultAttr(ch)
	local mv = findMovement()
	local track = mv and mv.isVaulting and mv.activeVaultTrack
	if not track then return end
	local playing = false
	pcall(function() playing = track.IsPlaying end)
	if not playing then return end
	local len = track.Length or (track.Track and track.Track.Length) or 1.5
	local current = trackSpeedOf(track)
	if type(current) ~= "number" then return end
	local row = vaultTracks[track]
	if not row then
		row = {original = current}
		vaultTracks[track] = row
	end
	local target = math.clamp(len / CFG.FAST_VAULT_TIME, 1, CFG.FAST_VAULT_MAX_ANIM)
	if current < target - 0.05 then
		pcall(function() track:AdjustSpeed(target) end)
	end
end

-- percepat animasi vault milik sendiri (cadangan kalau pengendali gerak tidak ketemu) dan catat durasi vault
local vaultStartAt = nil
local function boostVaultAnims(animator)
	for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
		local prio = tr.Priority
		if not tr.Looped and tr.Length >= 0.8 and prio ~= Enum.AnimationPriority.Core
			and prio ~= Enum.AnimationPriority.Idle and prio ~= Enum.AnimationPriority.Movement then
			tr:AdjustSpeed(math.clamp(tr.Length / CFG.FAST_VAULT_TIME, 1, CFG.FAST_VAULT_MAX_ANIM))
		end
	end
end

local function hookMyAnimator(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
	if not animator or hooked[animator] then return end
	hooked[animator] = true
	connect(animator.AnimationPlayed, function(track)
		if not GUI:Get("fast_vault") or moveCtl then return end
		if track.Looped or track.Length < 0.8 then return end
		local prio = track.Priority
		if prio == Enum.AnimationPriority.Core or prio == Enum.AnimationPriority.Idle or prio == Enum.AnimationPriority.Movement then return end
		local vaulting = (vaultState and os.clock() - vaultState.t < 0.8) or char:GetAttribute("isvaulting") == true or nearVault()
		if not vaulting then return end
		vaultWindow = math.max(vaultWindow, os.clock() + 2)
		track:AdjustSpeed(math.clamp(track.Length / CFG.FAST_VAULT_TIME, 1, CFG.FAST_VAULT_MAX_ANIM))
	end)
	connect(char:GetAttributeChangedSignal("isvaulting"), function()
		if char:GetAttribute("isvaulting") ~= true then
			if vaultStartAt then
				logLine("VD_VaultLog.txt", string.format("durasi vault %.2f detik, tier=%s, vaultspeed=%s, fast_vault=%s",
					os.clock() - vaultStartAt, tostring(char:GetAttribute("VaultTier")),
					tostring(char:GetAttribute("vaultspeed")), tostring(GUI:Get("fast_vault"))))
				vaultStartAt = nil
			end
			return
		end
		vaultStartAt = os.clock()
		vaultWindow = os.clock() + 2
		if not GUI:Get("fast_vault") then return end
		if not moveCtl then
			for _, dt in ipairs({0, 0.05, 0.15}) do
				task.delay(dt, function()
					if animator.Parent then boostVaultAnims(animator) end
				end)
			end
		end
		-- kalau hook remote tidak menangkap event vault, tetap kirim sinyal fast vault
		if R.FastVault and not (vaultState and os.clock() - vaultState.t < 1.5) then
			task.delay(0.1, function() fire(R.FastVault, lp) end)
		end
	end)
end
if lp.Character then task.spawn(hookMyAnimator, lp.Character) end
connect(lp.CharacterAdded, function(c) task.spawn(hookMyAnimator, c) end)

-- ===== SPEED BOOST =====
local lastSet, gameWS = nil, nil
-- WalkSpeed disimpan sebagai float32, jadi 16.1 kembali sebagai 16.100000381. Bandingkan dengan toleransi,
-- kalau tidak, tambahan kecepatan menumpuk tiap frame.
local function sameSpeed(a, b)
	return b ~= nil and math.abs(a - b) < 0.02
end

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
		if lastSet and sameSpeed(hum.WalkSpeed, lastSet) and gameWS then hum.WalkSpeed = gameWS end
		lastSet = nil
		return
	end
	if lastSet == nil or not sameSpeed(hum.WalkSpeed, lastSet) then
		gameWS = hum.WalkSpeed -- nilai asli dari game
	end
	local target = gameWS + (tonumber(GUI:Get("speed_value")) or 1)
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
		return hasWord(s, CFG.KILLER_KEYWORDS)
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
	local pg = lp:FindFirstChild("PlayerGui")
	if not pg then return nil end
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("GuiButton") then
			local n = d.Name:lower()
			if n:find("crouch", 1, true) or n:find("jongkok", 1, true) or n:find("duck", 1, true) then return d end
		end
	end
	return nil
end

local function setCrouch(on)
	local c = myChar()
	if not c or (c:GetAttribute("Crouching") == true) == on then return end
	local btn = findCrouchButton()
	if btn and pressGui(btn) then return end
	-- cadangan: meniru urutan yang tercatat di log
	if on then c:SetAttribute("Sprinting", false) end
	c:SetAttribute("Crouching", on)
	fire(R.ChangeAttr, "Crouchingserver", on)
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
local function safe(fn, label)
	local ok, err = pcall(fn)
	if not ok then warn("[VD] " .. label .. ": " .. tostring(err)) end
end

connect(RunService.Heartbeat, function(dt)
	if GUI.Closed then return end
	speedStep()
	safe(vaultSpeedStep, "vault")
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
	safe(qteStep, "skill check")
end)

-- ===== bersihkan saat panel ditutup =====
local function cleanup()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	local hum = myHum()
	if hum and lastSet and sameSpeed(hum.WalkSpeed, lastSet) and gameWS then hum.WalkSpeed = gameWS end
	restoreVaultAttr()
	restoreVaultTracks()
	if crouchTrack then pcall(function() crouchTrack:Stop() end) end
	if env.VD_SURV_HANDLER == handler then env.VD_SURV_HANDLER = nil end
end
env.VD_SURV_CLEANUP = cleanup
GUI:OnClose(cleanup)

print("[VD] Survivor Utility siap. Remote: parry=" .. tostring(R.Parry ~= nil)
	.. " vault=" .. tostring(R.Vault ~= nil) .. " VIM=" .. tostring(VIM ~= nil) .. " getgc=" .. tostring(type(getgc) == "function"))
