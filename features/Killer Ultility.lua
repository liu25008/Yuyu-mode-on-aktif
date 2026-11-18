-- features/Killer Ultility.lua
-- Fitur halaman Killer Utility (Aimbot Jeff, Veil, The Cure). Jalankan SETELAH gui.lua.
-- By: @texx-breaker
--
-- Cara kerja:
--  1. Saat tombolnya menyala dan lo main sebagai killer, kamera ditarik pelan ke survivor
--     yang paling dekat dengan crosshair (dalam FOV dan jarak, tanpa terhalang tembok).
--  2. Saat serangan atau skill ditembakkan (remote tercatat di log), kamera dan badan lo
--     langsung dihadapkan ke target, dan arah (Vector3 atau CFrame) di remote skill diarahkan juga.
-- Hanya satu aimbot yang aktif sekaligus (menyalakan satu mematikan yang lain).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local GUI = env.VD_GUI
if not GUI then
	warn("[VD] gui.lua belum dijalankan, jalankan gui.lua dulu")
	return
end
if env.VD_KILL_CLEANUP then pcall(env.VD_KILL_CLEANUP) end

-- ===== pengaturan per killer =====
-- range = jarak maksimum, fov = sudut dari crosshair (derajat), smooth = kekuatan tarikan kamera (0 sampai 1)
-- speed = kecepatan proyektil untuk prediksi gerak (0 = tanpa prediksi). Nilai Veil dan Cure masih TEBAKAN.
local PROFILES = {
	aim_jeff = {label = "Jeff", range = 26, fov = 75, part = "HumanoidRootPart", smooth = 0.45, speed = 0, steer = false,
		snap = {{"Attacks", "Lunge"}, {"Attacks", "BasicAttack"}}},
	aim_veil = {label = "Veil", range = 130, fov = 45, part = "HumanoidRootPart", smooth = 0.35, speed = 100, steer = true,
		snap = {{"Killers", "Veil", "Spearthrow"}}},
	aim_cure = {label = "The Cure", range = 80, fov = 45, part = "HumanoidRootPart", smooth = 0.35, speed = 60, steer = true,
		snap = {{"Killers", "Cure", "ThrowFlask"}}},
}
local ORDER = {"aim_jeff", "aim_veil", "aim_cure"}
local FACE_TIME = 0.45 -- lama badan dikunci menghadap target setelah serangan atau skill (detik)

-- ===== dasar =====
local alive = true
local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local RemotesFolder = RS:WaitForChild("Remotes", 15)
if not RemotesFolder then
	warn("[VD] folder Remotes tidak ketemu")
	return
end
local function remote(path)
	local o = RemotesFolder
	for _, n in ipairs(path) do
		if not o then return nil end
		o = o:FindFirstChild(n)
	end
	return o
end
for _, prof in pairs(PROFILES) do
	prof.remotes = {}
	for _, path in ipairs(prof.snap) do
		local r = remote(path)
		if r then prof.remotes[#prof.remotes + 1] = r end
	end
end

local function aliveHum(c)
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then return h end
	return nil
end

local function imKiller()
	local team = lp.Team
	if team and team.Name == "Killer" then return true end
	local c = lp.Character
	return c ~= nil and c:GetAttribute("Killer") == true
end

local function active()
	for _, id in ipairs(ORDER) do
		if GUI:Get(id) then return id, PROFILES[id] end
	end
	return nil, nil
end

-- survivor yang pantas dibidik (bukan yang sudah jatuh, digantung, atau digendong)
local function validSurvivor(p)
	if p == lp then return false end
	local team = p.Team
	if not team or team.Name ~= "Survivors" then return false end
	local c = p.Character
	if not c or not aliveHum(c) then return false end
	for _, k in ipairs({"Knocked", "IsHooked", "IsCarried", "IsDead", "Iframes"}) do
		if c:GetAttribute(k) == true then return false end
	end
	return true
end

local function visible(cam, part)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {lp.Character, part.Parent}
	local origin = cam.CFrame.Position
	return workspace:Raycast(origin, part.Position - origin, params) == nil
end

-- wide = true dipakai saat snap (FOV selebar layar depan), supaya serangan tetap kena target terdekat
local function pickTarget(cam, prof, wide)
	local best, bestScore
	local fov = wide and 120 or prof.fov
	for _, p in ipairs(Players:GetPlayers()) do
		if validSurvivor(p) then
			local part = p.Character:FindFirstChild(prof.part) or p.Character:FindFirstChild("HumanoidRootPart")
			if part then
				local dir = part.Position - cam.CFrame.Position
				local dist = dir.Magnitude
				if dist > 0.1 and dist <= prof.range then
					local ang = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(dir.Unit), -1, 1)))
					if ang <= fov then
						local score = wide and dist or ang
						if (not bestScore or score < bestScore) and visible(cam, part) then
							best, bestScore = part, score
						end
					end
				end
			end
		end
	end
	return best
end

local function aimPoint(part, prof, from)
	local pos = part.Position
	if prof.speed and prof.speed > 0 then
		local dist = (pos - from).Magnitude
		pos = pos + part.AssemblyLinearVelocity * (dist / prof.speed)
	end
	return pos
end

-- ===== catat bentuk argumen remote skill (buat nyempurnain nanti) =====
local argLogCount = 0
local function logArgs(remoteInst, args)
	if argLogCount >= 40 or not appendfile then return end
	argLogCount = argLogCount + 1
	local parts = {}
	for i = 1, args.n do
		local v = args[i]
		local t = typeof(v)
		if t == "Vector3" then
			parts[i] = string.format("Vector3(mag=%.2f)", v.Magnitude)
		elseif t == "CFrame" then
			parts[i] = "CFrame"
		elseif t == "Instance" then
			parts[i] = "Instance:" .. v.ClassName
		else
			parts[i] = t .. ":" .. tostring(v):sub(1, 24)
		end
	end
	pcall(appendfile, "VD_KillerRemoteArgs.txt", remoteInst.Name .. " (" .. table.concat(parts, ", ") .. ")\n")
end

-- arahkan argumen yang berupa arah (Vector3 panjang 1) atau CFrame ke target
local function steerArgs(args, dir)
	for i = 1, args.n do
		local v = args[i]
		local t = typeof(v)
		if t == "Vector3" and v.Magnitude > 0.9 and v.Magnitude < 1.1 then
			args[i] = dir
		elseif t == "CFrame" then
			args[i] = CFrame.new(v.Position, v.Position + dir)
		end
	end
end

-- ===== snap saat serangan atau skill ditembakkan =====
local faceUntil = 0

local function snap(prof, remoteInst, args)
	local cam = workspace.CurrentCamera
	local c = lp.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not (cam and root) or c:GetAttribute("IsCarrying") == true then return end
	local part = pickTarget(cam, prof, true)
	if not part then return end
	local pos = aimPoint(part, prof, root.Position)
	faceUntil = os.clock() + FACE_TIME
	cam.CFrame = CFrame.new(cam.CFrame.Position, pos)
	root.CFrame = CFrame.new(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
	if prof.steer then
		local delta = pos - root.Position
		if delta.Magnitude > 0.1 then steerArgs(args, delta.Unit) end
	end
	logArgs(remoteInst, args)
end

local function handler(remoteInst, args)
	local _, prof = active()
	if not prof or not imKiller() then return nil end
	for _, r in ipairs(prof.remotes) do
		if r == remoteInst then
			snap(prof, remoteInst, args)
			return nil
		end
	end
	return nil
end
env.VD_KILL_HANDLER = handler

if not env.VD_KILL_HOOKED then
	if hookmetamethod and getnamecallmethod and newcclosure then
		env.VD_KILL_HOOKED = true
		local old
		old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
			local m = getnamecallmethod()
			if m == "FireServer" and not (checkcaller and checkcaller()) then
				local h = env.VD_KILL_HANDLER
				if h and typeof(self) == "Instance" then
					local args = table.pack(...)
					pcall(h, self, args)
					return old(self, table.unpack(args, 1, args.n))
				end
			end
			return old(self, ...)
		end))
	else
		warn("[VD] Executor tidak mendukung hookmetamethod: snap saat serangan mati, aim kamera tetap jalan")
	end
end

-- ===== aim kamera terus-menerus =====
connect(RunService.RenderStepped, function()
	if GUI.Closed then return end
	local _, prof = active()
	if not prof or not imKiller() then return end
	local c = lp.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not (root and cam) or c:GetAttribute("IsCarrying") == true then return end
	local part = pickTarget(cam, prof, false)
	if not part then return end
	local pos = aimPoint(part, prof, cam.CFrame.Position)
	cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, pos), prof.smooth)
	if os.clock() < faceUntil then
		root.CFrame = CFrame.new(root.Position, Vector3.new(pos.X, root.Position.Y, pos.Z))
	end
end)

-- hanya satu aimbot yang boleh menyala
for _, id in ipairs(ORDER) do
	GUI:OnChanged(id, function(on)
		if not alive or not on then return end
		for _, other in ipairs(ORDER) do
			if other ~= id then GUI:Set(other, false) end
		end
	end)
end

-- ===== bersihkan =====
local function cleanup()
	alive = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	if env.VD_KILL_HANDLER == handler then env.VD_KILL_HANDLER = nil end
end
env.VD_KILL_CLEANUP = cleanup
GUI:OnClose(cleanup)

local found = {}
for _, id in ipairs(ORDER) do
	found[#found + 1] = PROFILES[id].label .. "=" .. tostring(#PROFILES[id].remotes) .. " remote"
end
print("[VD] Killer Utility siap. " .. table.concat(found, ", "))
