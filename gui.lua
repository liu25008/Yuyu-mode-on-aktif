-- gui.lua | GUI + semua fitur dalam satu file (ESP, Killer Utility, Survivor Utility)
-- By: @texx-breaker
--
-- Satu loadstring saja, tidak perlu main.lua dan tidak perlu folder features.
--
-- Cara pakai dari script lain:
--   local GUI = getgenv().VD_GUI            (atau hasil loadstring gui.lua)
--   GUI:OnChanged("auto_parry", function(on) ... end)
--   GUI:Get("auto_skill_mode")              -> "Perfect" atau "Instan"
--   GUI:Get("esp_killer_color")             -> Color3 (warna bawaan kalau belum diatur)
--   GUI:Set("fast_vault", true)             -> ubah dari kode (ikut update tampilan)
--   GUI:OnClose(function() ... end)         -> dipanggil saat tombol X ditekan

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local env = (getgenv and getgenv()) or _G
if env.VD_GUI and env.VD_GUI.Destroy then
	pcall(function() env.VD_GUI:Destroy() end)
end

-- ===== tema: hitam dan hijau tua =====
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

-- ===== daftar halaman dan tombol =====
local PAGES = {
	{
		name = "Survivor", title = "Survivor Utility", sub = "Fitur untuk sisi survivor", icon = "person",
		rows = {
			{kind = "toggle", id = "auto_parry", label = "Auto Parry (Dagger)", desc = "Tangkis serangan killer otomatis"},
			{kind = "segment", id = "auto_parry_mode", label = "Mode parry", options = {"Hemat", "Prediktif"}, default = "Hemat", indent = true},
			{kind = "toggle", id = "anti_fake_hit", label = "Anti Fake Hit", desc = "Abaikan serangan palsu atau meleset"},
			{kind = "toggle", id = "fast_vault", label = "Fast Vault", desc = "Lewati jendela lebih cepat"},
			{kind = "toggle", id = "speed_boost", label = "Speed Boost"},
			{kind = "toggle", id = "auto_skill", label = "Auto Skill", desc = "Skill check generator dan heal"},
			{kind = "segment", id = "auto_skill_mode", label = "Mode auto skill", options = {"Perfect", "Instan"}, default = "Perfect", indent = true},
			{kind = "toggle", id = "aim_pistol", label = "Aimbot Pistol", desc = "Untuk survivor yang memakai pistol"},
			{kind = "toggle", id = "auto_crouch", label = "Auto Jongkok", desc = "Khusus killer Abbyswalker"},
		},
	},
	{
		name = "Killer", title = "Killer Utility", sub = "Fitur untuk sisi killer", icon = "target",
		rows = {
			{kind = "toggle", id = "aim_jeff", label = "Aimbot Jeff"},
			{kind = "toggle", id = "aim_veil", label = "Aimbot Veil"},
			{kind = "toggle", id = "aim_cure", label = "Aimbot The Cure"},
		},
	},
	{
		name = "ESP", title = "ESP", sub = "Ketuk kotak warna untuk mengubah warna", icon = "eye",
		rows = {
			{kind = "toggle", id = "esp_killer", label = "Killer", color = Color3.fromRGB(139, 26, 26)},
			{kind = "toggle", id = "esp_survivor", label = "Survivor", color = Color3.fromRGB(26, 52, 139)},
			{kind = "toggle", id = "esp_objects", label = "Pallet dan Window", desc = "Hanya di dalam match", color = Color3.fromRGB(194, 98, 10)},
			{kind = "toggle", id = "esp_jtrap", label = "JTrap", color = Color3.fromRGB(106, 40, 160)},
			{kind = "toggle", id = "esp_zombie", label = "Zombie", color = Color3.fromRGB(34, 120, 56)},
			{kind = "toggle", id = "esp_generator", label = "Generator dan progres", desc = "Termasuk persen progres", color = Color3.fromRGB(222, 100, 160)},
		},
	},
}

local PALETTE = {
	Color3.fromRGB(139, 26, 26), Color3.fromRGB(178, 60, 40), Color3.fromRGB(194, 98, 10), Color3.fromRGB(176, 142, 30),
	Color3.fromRGB(34, 120, 56), Color3.fromRGB(20, 110, 110), Color3.fromRGB(26, 52, 139), Color3.fromRGB(60, 90, 170),
	Color3.fromRGB(106, 40, 160), Color3.fromRGB(200, 90, 150), Color3.fromRGB(222, 226, 222), Color3.fromRGB(120, 128, 122),
}

-- ===== helper =====
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

local function round(o, r)
	return new("UICorner", {CornerRadius = UDim.new(0, r)}, o)
end

local function stroke(o, color, th)
	return new("UIStroke", {Color = color, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o)
end

local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

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

-- ikon digambar dari bentuk sederhana (tanpa emoji dan tanpa asset)
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
	elseif kind == "target" then
		ring(UDim2.fromOffset(12, 12), UDim2.fromOffset(3, 3), 6, 2)
		part(UDim2.fromOffset(2, 4), UDim2.fromOffset(8, 0))
		part(UDim2.fromOffset(2, 4), UDim2.fromOffset(8, 14))
		part(UDim2.fromOffset(4, 2), UDim2.fromOffset(0, 8))
		part(UDim2.fromOffset(4, 2), UDim2.fromOffset(14, 8))
	else
		ring(UDim2.fromOffset(18, 10), UDim2.fromOffset(0, 4), 5, 2)
		part(UDim2.fromOffset(6, 6), UDim2.fromOffset(6, 6), 3)
	end
	local function setColor(c)
		for _, d in ipairs(box:GetDescendants()) do
			if d:IsA("UIStroke") then
				d.Color = c
			elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
				d.BackgroundColor3 = c
			end
		end
	end
	return box, setColor
end

local function parseHex(s)
	s = tostring(s):gsub("[#%s]", "")
	if #s == 6 and s:match("^%x+$") then
		return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
	end
	return nil
end

local function toHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- ===== state dan API =====
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

function GUI:OnAny(fn) table.insert(anyListeners, fn) end
function GUI:OnClose(fn) table.insert(closeListeners, fn) end

-- ===== ukuran window (menyesuaikan layar) =====
local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(800, 450)
local W = math.clamp(math.floor(vp.X - 24), 300, 500)
local H = math.clamp(math.floor(vp.Y - 24), 240, 330)
local sideW = W < 400 and 96 or 124
local STACK = W < 420

-- ===== window =====
local parentGui = (gethui and gethui()) or CoreGui
local oldGui = parentGui:FindFirstChild("VDHub")
if oldGui then oldGui:Destroy() end

local gui = new("ScreenGui", {
	Name = "VDHub", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
}, parentGui)

local root = new("Frame", {
	Name = "Root", Size = UDim2.fromOffset(W, H),
	Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2), BackgroundTransparency = 1,
}, gui)

local shadow = new("Frame", {
	Size = UDim2.new(1, 16, 1, 16), Position = UDim2.fromOffset(-8, -5),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 1,
}, root)
round(shadow, 18)

local main = new("Frame", {
	Name = "Main", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.bg,
	BorderSizePixel = 0, ZIndex = 2, ClipsDescendants = true,
}, root)
round(main, 12)
stroke(main, T.line, 1)

-- header
local header = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1}, main)
new("TextLabel", {
	Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = T.text,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "VD Utility",
}, header)
new("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.line, BorderSizePixel = 0}, header)

local function headerBtn(kind, xOff, cb)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(30, 26), Position = UDim2.new(1, xOff, 0, 7),
		BackgroundColor3 = T.surface, AutoButtonColor = false, Text = "", BorderSizePixel = 0,
	}, header)
	round(b, 7)
	if kind == "min" then
		new("Frame", {Size = UDim2.fromOffset(12, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = T.text, BorderSizePixel = 0}, b)
		hover(b, "BackgroundColor3", T.surface, T.surfaceHi)
	else
		for _, r in ipairs({45, -45}) do
			new("Frame", {Size = UDim2.fromOffset(14, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Rotation = r, BackgroundColor3 = T.text, BorderSizePixel = 0}, b)
		end
		hover(b, "BackgroundColor3", T.surface, T.danger)
	end
	connect(b.MouseButton1Click, cb)
	return b
end

-- sidebar
local side = new("Frame", {Size = UDim2.new(0, sideW, 1, -40), Position = UDim2.fromOffset(0, 40), BackgroundColor3 = T.side, BorderSizePixel = 0}, main)
new("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = T.line, BorderSizePixel = 0}, side)
local indicator = new("Frame", {Size = UDim2.fromOffset(3, 22), Position = UDim2.fromOffset(0, 19), BackgroundColor3 = T.accentSoft, BorderSizePixel = 0}, side)
round(indicator, 2)

-- area isi
local content = new("Frame", {Size = UDim2.new(1, -sideW, 1, -40), Position = UDim2.new(0, sideW, 0, 40), BackgroundTransparency = 1}, main)

-- popup warna
local picking = nil
local overlay = new("TextButton", {
	Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
	Text = "", AutoButtonColor = false, Visible = false, ZIndex = 30, BorderSizePixel = 0,
}, main)
local pop = new("Frame", {
	Size = UDim2.fromOffset(232, 152), Position = UDim2.new(0.5, -116, 0.5, -76),
	BackgroundColor3 = T.surface, BorderSizePixel = 0, Active = true,
}, overlay)
round(pop, 12)
stroke(pop, T.line, 1)
local popTitle = new("TextLabel", {
	Size = UDim2.new(1, -28, 0, 20), Position = UDim2.fromOffset(14, 10), BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = "Warna",
}, pop)
local grid = new("Frame", {Size = UDim2.fromOffset(204, 62), Position = UDim2.fromOffset(14, 38), BackgroundTransparency = 1}, pop)
new("UIGridLayout", {CellSize = UDim2.fromOffset(28, 28), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder}, grid)

local hexBox = new("TextBox", {
	Size = UDim2.fromOffset(90, 26), Position = UDim2.fromOffset(14, 112), BackgroundColor3 = T.bg,
	Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.text, PlaceholderText = "#RRGGBB",
	PlaceholderColor3 = T.muted, Text = "", ClearTextOnFocus = false, BorderSizePixel = 0,
}, pop)
round(hexBox, 7)
stroke(hexBox, T.line, 1)

local function popBtn(text, x, w)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(w, 26), Position = UDim2.fromOffset(x, 112), BackgroundColor3 = T.surfaceHi,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.text, Text = text, AutoButtonColor = false, BorderSizePixel = 0,
	}, pop)
	round(b, 7)
	hover(b, "BackgroundColor3", T.surfaceHi, T.accent)
	return b
end
local resetBtn = popBtn("Default", 110, 62)
local closeBtn = popBtn("Tutup", 178, 40)

local function closePicker()
	overlay.Visible = false
	picking = nil
end

local function openPicker(id, title)
	picking = id
	popTitle.Text = "Warna " .. title
	hexBox.Text = toHex(GUI.State[id])
	overlay.Visible = true
end

for i, c in ipairs(PALETTE) do
	local s = new("TextButton", {BackgroundColor3 = c, Text = "", AutoButtonColor = false, LayoutOrder = i, BorderSizePixel = 0}, grid)
	round(s, 7)
	connect(s.MouseButton1Click, function()
		if picking then
			GUI:Set(picking, c)
			hexBox.Text = toHex(c)
		end
	end)
end

connect(hexBox.FocusLost, function()
	local c = parseHex(hexBox.Text)
	if c and picking then
		GUI:Set(picking, c)
		hexBox.Text = toHex(c)
	elseif picking then
		hexBox.Text = toHex(GUI.State[picking])
	end
end)
connect(resetBtn.MouseButton1Click, function()
	if picking then
		GUI:Set(picking, GUI.Defaults[picking])
		hexBox.Text = toHex(GUI.State[picking])
	end
end)
connect(closeBtn.MouseButton1Click, closePicker)
connect(overlay.MouseButton1Click, closePicker)

-- ===== pembuat baris =====
local function buildToggle(parent, spec, order)
	local hasDesc = spec.desc ~= nil
	local h = hasDesc and 48 or 40
	local rightPad = spec.color and 100 or 66
	local row = new("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = T.surface, BorderSizePixel = 0, LayoutOrder = order}, parent)
	round(row, 9)
	stroke(row, T.line, 1)
	local hit = new("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 1}, row)
	connect(hit.MouseEnter, function() tween(row, 0.12, {BackgroundColor3 = T.surfaceHi}) end)
	connect(hit.MouseLeave, function() tween(row, 0.12, {BackgroundColor3 = T.surface}) end)

	new("TextLabel", {
		Size = UDim2.new(1, -rightPad, 0, 18), Position = UDim2.fromOffset(12, hasDesc and 7 or 11),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = spec.label, ZIndex = 2,
	}, row)
	if hasDesc then
		new("TextLabel", {
			Size = UDim2.new(1, -rightPad, 0, 14), Position = UDim2.fromOffset(12, 26),
			BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.muted,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = spec.desc, ZIndex = 2,
		}, row)
	end

	local track = new("Frame", {Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -50, 0.5, -10), BackgroundColor3 = T.off, BorderSizePixel = 0, ZIndex = 2}, row)
	round(track, 10)
	local knob = new("Frame", {Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = T.knob, BorderSizePixel = 0, ZIndex = 3}, track)
	round(knob, 7)

	register(spec.id, false, function(v, instant)
		local t = instant and 0 or 0.15
		tween(track, t, {BackgroundColor3 = v and T.accent or T.off})
		tween(knob, t, {Position = v and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3), BackgroundColor3 = v and T.text or T.knob})
	end)
	connect(hit.MouseButton1Click, function()
		GUI:Set(spec.id, not GUI.State[spec.id])
	end)

	if spec.color then
		local cid = spec.id .. "_color"
		local sw = new("TextButton", {
			Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -86, 0.5, -12), BackgroundColor3 = spec.color,
			Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 3,
		}, row)
		round(sw, 7)
		stroke(sw, T.line, 1)
		register(cid, spec.color, function(v, instant)
			tween(sw, instant and 0 or 0.15, {BackgroundColor3 = v})
		end)
		connect(sw.MouseButton1Click, function()
			openPicker(cid, spec.label)
		end)
	end
end

local function buildSegment(parent, spec, order)
	local n = #spec.options
	local bw = 62
	local h = STACK and 62 or 40
	local size = spec.indent and UDim2.new(1, -16, 0, h) or UDim2.new(1, 0, 0, h)
	local row = new("Frame", {Size = size, BackgroundColor3 = T.surface, BorderSizePixel = 0, LayoutOrder = order}, parent)
	round(row, 9)
	stroke(row, T.line, 1)

	local lblW = STACK and -24 or -(n * bw + 36)
	new("TextLabel", {
		Size = UDim2.new(1, lblW, 0, 18), Position = UDim2.fromOffset(12, STACK and 7 or 11),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = spec.label,
	}, row)

	local seg = new("Frame", {
		Size = UDim2.fromOffset(n * bw + 4, 26),
		Position = STACK and UDim2.fromOffset(12, 30) or UDim2.new(1, -(n * bw + 16), 0.5, -13),
		BackgroundColor3 = T.bg, BorderSizePixel = 0,
	}, row)
	round(seg, 8)
	stroke(seg, T.line, 1)
	local thumb = new("Frame", {Size = UDim2.fromOffset(bw, 22), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = T.accent, BorderSizePixel = 0}, seg)
	round(thumb, 6)

	local btns = {}
	for i, o in ipairs(spec.options) do
		local b = new("TextButton", {
			Size = UDim2.fromOffset(bw, 26), Position = UDim2.fromOffset(2 + (i - 1) * bw, 0), BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.muted, Text = o, AutoButtonColor = false, ZIndex = 2,
		}, seg)
		btns[i] = b
		connect(b.MouseButton1Click, function()
			GUI:Set(spec.id, o)
		end)
	end

	register(spec.id, spec.default, function(v, instant)
		for i, o in ipairs(spec.options) do
			if o == v then
				tween(thumb, instant and 0 or 0.16, {Position = UDim2.fromOffset(2 + (i - 1) * bw, 2)})
				btns[i].TextColor3 = T.text
			else
				btns[i].TextColor3 = T.muted
			end
		end
	end)
end

-- ===== bikin halaman dan tab =====
local pageObjs = {}

for idx, page in ipairs(PAGES) do
	local pg = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false}, content)
	new("TextLabel", {
		Size = UDim2.new(1, -32, 0, 20), Position = UDim2.fromOffset(16, 10), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, Text = page.title,
	}, pg)
	new("TextLabel", {
		Size = UDim2.new(1, -32, 0, 16), Position = UDim2.fromOffset(16, 31), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = page.sub,
	}, pg)

	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 1, -64), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = T.accent, CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, pg)
	new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right}, scroll)
	new("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8)}, scroll)

	for order, spec in ipairs(page.rows) do
		if spec.kind == "toggle" then
			buildToggle(scroll, spec, order)
		else
			buildSegment(scroll, spec, order)
		end
	end

	local tabY = 10 + (idx - 1) * 46
	local tab = new("TextButton", {
		Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, tabY), BackgroundColor3 = T.surface,
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, side)
	round(tab, 9)
	local iconBox, setIcon = drawIcon(page.icon, tab, T.muted)
	iconBox.Position = UDim2.fromOffset(12, 11)
	local lbl = new("TextLabel", {
		Size = UDim2.new(1, -42, 1, 0), Position = UDim2.fromOffset(38, 0), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left, Text = page.name,
	}, tab)

	pageObjs[idx] = {frame = pg, tab = tab, label = lbl, setIcon = setIcon, y = tabY}
end

local function selectPage(i)
	for k, p in ipairs(pageObjs) do
		local on = (k == i)
		p.frame.Visible = on
		tween(p.tab, 0.15, {BackgroundTransparency = on and 0 or 1})
		p.label.TextColor3 = on and T.text or T.muted
		p.setIcon(on and T.accentSoft or T.muted)
	end
	tween(indicator, 0.2, {Position = UDim2.fromOffset(0, pageObjs[i].y + 9)})
end

for i, p in ipairs(pageObjs) do
	connect(p.tab.MouseButton1Click, function() selectPage(i) end)
end

-- ===== sembunyi (-) dan tutup (X) =====
local pill = new("TextButton", {
	Size = UDim2.fromOffset(46, 30), Position = UDim2.new(0, 16, 0.5, -15), BackgroundColor3 = T.bg,
	Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.text, Text = "VD",
	AutoButtonColor = false, Visible = false, BorderSizePixel = 0,
}, gui)
round(pill, 9)
stroke(pill, T.accent, 1.5)
local pillDrag = makeDraggable(pill, pill)

local function setHidden(h)
	root.Visible = not h
	pill.Visible = h
	if h then closePicker() end
end

connect(pill.MouseButton1Click, function()
	if not pillDrag.moved then setHidden(false) end
end)

function GUI:Show() setHidden(false) end
function GUI:Hide() setHidden(true) end
function GUI:Toggle() setHidden(root.Visible) end

function GUI:Destroy()
	if self.Closed then return end
	self.Closed = true
	for _, fn in ipairs(closeListeners) do pcall(fn) end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	if gui then gui:Destroy() end
	if env.VD_GUI == self then env.VD_GUI = nil end
end

headerBtn("min", -68, function() setHidden(true) end)
headerBtn("close", -34, function() GUI:Destroy() end)

connect(UIS.InputBegan, function(i, gpe)
	if not gpe and i.KeyCode == Enum.KeyCode.RightShift then
		setHidden(root.Visible)
	end
end)

makeDraggable(header, root)
selectPage(1)

env.VD_GUI = GUI

-- =====================================================================
-- FITUR: ESP
-- Killer, Survivor, Pallet dan Window, JTrap, Zombie, Generator (dengan progres persen).
-- Jarak killer dan survivor tampil di label tiap pemain.
-- =====================================================================
local function featureESP()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local GUI = env.VD_GUI
if not GUI then return end
if env.VD_ESP_CLEANUP then pcall(env.VD_ESP_CLEANUP) end

-- ===== pengaturan =====
local CFG = {
	UPDATE = 0.1,            -- detik antar pembaruan label dan jarak
	OBJ_MAX_DIST = 300,      -- jarak maksimum untuk objek (pallet, window, generator, dll)
	PROG_WORDS = {"progress", "percent", "repair", "charge", "completion"}, -- nama sumber progres generator
}

local alive = true
local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

-- ===== folder tempat semua visual (lokal, tidak terlihat server) =====
local parentGui = (gethui and gethui()) or CoreGui
local oldFolder = parentGui:FindFirstChild("VDESP")
if oldFolder then oldFolder:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "VDESP"
folder.Parent = parentGui

local function labelColor(c)
	return c:Lerp(Color3.new(1, 1, 1), 0.4)
end

local function makeLabel(adornee, yOff)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 20)
	bb.StudsOffset = Vector3.new(0, yOff, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = math.huge
	bb.LightInfluence = 0
	bb.Adornee = adornee
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamMedium
	tl.TextSize = 13
	tl.TextStrokeTransparency = 0.35
	tl.TextStrokeColor3 = Color3.new(0, 0, 0)
	tl.Text = ""
	tl.Parent = bb
	bb.Parent = folder
	return bb, tl
end

local function myRoot()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function inMatch()
	local t = lp.Team
	return t ~= nil and (t.Name == "Survivors" or t.Name == "Killer")
end

-- ===== ESP pemain (killer dan survivor, lengkap dengan jarak) =====
local players = {}

local function dropPlayer(p)
	local e = players[p]
	if not e then return end
	pcall(function() e.hl:Destroy() end)
	pcall(function() e.bb:Destroy() end)
	players[p] = nil
end

local function updatePlayer(p, myR)
	local kind
	local team = p.Team
	if p ~= lp and team then
		if team.Name == "Killer" then
			kind = "killer"
		elseif team.Name == "Survivors" then
			kind = "survivor"
		end
	end
	local c = p.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (kind and GUI:Get("esp_" .. kind) and root and c.Parent and hum and hum.Health > 0) then
		dropPlayer(p)
		return
	end
	local e = players[p]
	if e and (e.char ~= c or e.kind ~= kind) then
		dropPlayer(p)
		e = nil
	end
	local color = GUI:Get("esp_" .. kind .. "_color")
	if not e then
		local hl = Instance.new("Highlight")
		hl.Adornee = c
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = 0.6
		hl.OutlineTransparency = 0
		hl.Parent = c
		local bb, tl = makeLabel(c:FindFirstChild("Head") or root, 2.6)
		e = {char = c, kind = kind, hl = hl, bb = bb, label = tl, color = nil}
		players[p] = e
	end
	if e.color ~= color then
		e.color = color
		e.hl.FillColor = color
		e.hl.OutlineColor = color
		e.label.TextColor3 = labelColor(color)
	end
	local prefix = (kind == "killer") and "Killer  " or ""
	if myR then
		local d = (root.Position - myR.Position).Magnitude
		e.label.Text = string.format("%s%s  %dm", prefix, p.Name, math.floor(d + 0.5))
	else
		e.label.Text = prefix .. p.Name
	end
end

-- ===== ESP objek (generator, pallet, window, jtrap, zombie) =====
local KINDS = {
	gen = {toggle = "esp_generator", name = "Generator", y = 3},
	pallet = {toggle = "esp_objects", name = "Pallet", y = 2},
	window = {toggle = "esp_objects", name = "Window", y = 2},
	trap = {toggle = "esp_jtrap", name = "JTrap", y = 2},
	zombie = {toggle = "esp_zombie", name = "Zombie", y = 3.2},
}
local entities = {}
local diagWritten = false

local function hideObject(e)
	if e.box then pcall(function() e.box:Destroy() end) e.box = nil end
	if e.bb then pcall(function() e.bb:Destroy() end) e.bb = nil end
	e.color = nil
end

local function dropObject(model)
	local e = entities[model]
	if not e then return end
	hideObject(e)
	if e.conn then pcall(function() e.conn:Disconnect() end) end
	entities[model] = nil
end

local function addObject(kind, model)
	if entities[model] or not model.Parent then return end
	local e = {kind = kind, model = model, nextProg = 0}
	entities[model] = e
	e.conn = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then dropObject(model) end
	end)
end

local function mainPart(model)
	if model:IsA("BasePart") then return model end
	if model:IsA("Model") then
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

-- progres generator: nilai bisa berupa atribut, NumberValue, atau teks berisi persen
local function looksLikeProgress(n)
	n = n:lower()
	for _, w in ipairs(CFG.PROG_WORDS) do
		if n:find(w, 1, true) then return true end
	end
	return false
end

local function toPercent(v)
	if type(v) ~= "number" then return nil end
	if v >= 0 and v <= 1.0001 then return v * 100 end
	if v > 1 and v <= 100 then return v end
	return nil
end

local function findProgressSource(model)
	for k, v in pairs(model:GetAttributes()) do
		if looksLikeProgress(k) and toPercent(v) then return {t = "attr", inst = model, key = k} end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("NumberValue") or d:IsA("IntValue")) and looksLikeProgress(d.Name) then
			return {t = "val", inst = d}
		end
		for k, v in pairs(d:GetAttributes()) do
			if looksLikeProgress(k) and toPercent(v) then return {t = "attr", inst = d, key = k} end
		end
		if d:IsA("TextLabel") and d.Text:match("%d+%.?%d*%%") then
			return {t = "text", inst = d}
		end
	end
	return nil
end

local function readProgress(src)
	if not src or not src.inst or not src.inst.Parent then return nil end
	if src.t == "attr" then return toPercent(src.inst:GetAttribute(src.key)) end
	if src.t == "val" then return toPercent(src.inst.Value) end
	local n = tonumber(src.inst.Text:match("(%d+%.?%d*)%%"))
	if n and n <= 100 then return n end
	return nil
end

-- kalau sumber progres tidak ketemu, simpan isi generator pertama biar bisa dicocokkan
local function writeDiag(model)
	if diagWritten or not writefile then return end
	diagWritten = true
	local lines = {"Generator: " .. model:GetFullName()}
	for k, v in pairs(model:GetAttributes()) do lines[#lines + 1] = "attr " .. k .. "=" .. tostring(v) end
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		n = n + 1
		if n > 80 then break end
		local extra = ""
		if d:IsA("ValueBase") then extra = " = " .. tostring(d.Value) end
		if d:IsA("TextLabel") then extra = " text=" .. d.Text end
		lines[#lines + 1] = d.ClassName .. " " .. d.Name .. extra
		for k, v in pairs(d:GetAttributes()) do lines[#lines + 1] = "  attr " .. k .. "=" .. tostring(v) end
	end
	pcall(writefile, "VD_GenInfo.txt", table.concat(lines, "\n"))
end

local function updateObject(model, e, myR, match)
	local cfg = KINDS[e.kind]
	if not (match and GUI:Get(cfg.toggle)) or not model:IsDescendantOf(workspace) then
		hideObject(e)
		return
	end
	local part = e.part
	if not part or not part.Parent then
		part = mainPart(model)
		e.part = part
	end
	if not part then return end
	local d = myR and (part.Position - myR.Position).Magnitude or 0
	if d > CFG.OBJ_MAX_DIST then
		hideObject(e)
		return
	end
	local color = GUI:Get(cfg.toggle .. "_color")
	if not e.box then
		local sb = Instance.new("SelectionBox")
		sb.Adornee = model:IsA("PVInstance") and model or part
		sb.LineThickness = 0.04
		sb.SurfaceTransparency = 0.8
		sb.Parent = folder
		e.box = sb
		local bb, tl = makeLabel(part, cfg.y)
		e.bb, e.label = bb, tl
	end
	if e.color ~= color then
		e.color = color
		e.box.Color3 = color
		e.box.SurfaceColor3 = color
		e.label.TextColor3 = labelColor(color)
	end
	local text = cfg.name
	if e.kind == "gen" then
		if not e.src and os.clock() >= e.nextProg then
			e.nextProg = os.clock() + 3
			e.src = findProgressSource(model)
			if not e.src then writeDiag(model) end
		end
		local pct = readProgress(e.src)
		if pct then text = string.format("%s %d%%", cfg.name, math.floor(pct + 0.5)) end
	end
	e.label.Text = string.format("%s  %dm", text, math.floor(d + 0.5))
end

-- ===== deteksi objek di map =====
local seenNames = {}
local nameLog = 0
local function logName(inst)
	local full = inst:GetFullName()
	if seenNames[full] or nameLog >= 30 or not appendfile then return end
	seenNames[full] = true
	nameLog = nameLog + 1
	pcall(appendfile, "VD_ESP_Names.txt", inst.ClassName .. " " .. full .. "\n")
end

local function onInstance(inst)
	if inst:IsA("BasePart") then
		local n = inst.Name
		if n:sub(1, 14) == "GeneratorPoint" then
			local m = inst.Parent
			if m and m:IsA("Model") then addObject("gen", m) end
		elseif n == "PalletPoint" then
			local m = inst:FindFirstAncestor("Newpallet") or (inst.Parent and inst.Parent.Parent)
			if m and m:IsA("Model") then addObject("pallet", m) end
		elseif n == "VaultTrigger" then
			local m = inst.Parent
			if m and m:IsA("Model") then addObject("window", m) end
		end
	elseif inst:IsA("Model") then
		local ln = inst.Name:lower()
		if ln:find("jtrap", 1, true) or (ln:find("trap", 1, true) and inst:GetFullName():lower():find("jason", 1, true)) then
			addObject("trap", inst)
		end
		if ln:find("trap", 1, true) or ln:find("zombie", 1, true) or ln:find("jason", 1, true) then logName(inst) end
	elseif inst:IsA("Humanoid") then
		local m = inst.Parent
		if m and m:IsA("Model") and m.Name:lower():find("zombie", 1, true) and not Players:GetPlayerFromCharacter(m) then
			addObject("zombie", m)
		end
	end
end

task.spawn(function()
	local n = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if not alive then return end
		onInstance(d)
		n = n + 1
		if n % 3000 == 0 then task.wait() end
	end
end)
connect(workspace.DescendantAdded, onInstance)
connect(Players.PlayerRemoving, dropPlayer)

-- ===== loop pembaruan =====
local acc = 0
connect(RunService.Heartbeat, function(dt)
	if GUI.Closed then return end
	acc = acc + dt
	if acc < CFG.UPDATE then return end
	acc = 0
	local myR = myRoot()
	local match = inMatch()
	for _, p in ipairs(Players:GetPlayers()) do updatePlayer(p, myR) end
	for model, e in pairs(entities) do updateObject(model, e, myR, match) end
end)

-- ===== bersihkan =====
local function cleanup()
	alive = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	conns = {}
	for p in pairs(players) do dropPlayer(p) end
	for model in pairs(entities) do dropObject(model) end
	pcall(function() folder:Destroy() end)
end
env.VD_ESP_CLEANUP = cleanup
GUI:OnClose(cleanup)

print("[VD] ESP siap")
end

-- =====================================================================
-- FITUR: Killer Utility (Aimbot Jeff, Veil, The Cure)
--
-- Cara kerja:
--  1. Saat tombolnya menyala dan lo main sebagai killer, kamera ditarik pelan ke survivor
--     yang paling dekat dengan crosshair (dalam FOV dan jarak, tanpa terhalang tembok).
--  2. Saat serangan atau skill ditembakkan (remote tercatat di log), kamera dan badan lo
--     langsung dihadapkan ke target, dan arah (Vector3 atau CFrame) di remote skill diarahkan juga.
-- Hanya satu aimbot yang aktif sekaligus (menyalakan satu mematikan yang lain).
-- =====================================================================
local function featureKiller()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local GUI = env.VD_GUI
if not GUI then return end
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
end

-- =====================================================================
-- FITUR: Survivor Utility
-- Isi: Auto Parry (Dagger) + mode, Anti Fake Hit, Fast Vault, Speed Boost,
--      Auto Skill (Perfect / Instan), Aimbot Pistol, Auto Jongkok.
-- Semua nilai yang bisa disetel ada di tabel CFG.
-- =====================================================================
local function featureSurvivor()
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
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
	PLAY_PARRY_ANIM = true,
	PARRY_ANIM = "rbxassetid://109133187196613",
	-- fast vault
	FAST_ASSET = "rbxassetid://83873880822918",
	FAST_VAULT_TIME = 0.65,    -- target durasi animasi vault (detik)
	FAST_VAULT_MAX_ANIM = 2.2, -- batas percepatan animasi
	-- speed boost
	SPEED_FACTOR = 1.08,
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
		if typeof(gen) ~= "Instance" or type(guid) ~= "string" then return end
		task.delay(skillDelay("gen"), function()
			if GUI.Closed or not GUI:Get("auto_skill") then return end
			markHandled(guid)
			R.GenResult:FireServer("success", 1, gen, point, guid, lp.Character)
		end)
	end)
end
if R.HealEvent and R.HealResult then
	connect(R.HealEvent.OnClientEvent, function(...)
		if not GUI:Get("auto_skill") then return end
		local a = table.pack(...)
		local target, guid = a[1], a[2]
		if typeof(target) ~= "Instance" or type(guid) ~= "string" then return end
		task.delay(skillDelay("heal"), function()
			if GUI.Closed or not GUI:Get("auto_skill") then return end
			markHandled(guid)
			R.HealResult:FireServer("success", 1, target, guid, lp.Character)
		end)
	end)
end

-- ===== FAST VAULT dan blokir hasil ganda auto skill (lewat hook remote) =====
local vaultState = nil

local function handler(remote, args)
	-- Fast Vault: ubah tier vault jadi "fast", sama seperti urutan yang tercatat di log
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
	-- Auto Skill: buang hasil dari game untuk skill check yang sudah kita jawab
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

-- percepat animasi vault milik sendiri
local function hookMyAnimator(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
	if not animator or hooked[animator] then return end
	hooked[animator] = true
	connect(animator.AnimationPlayed, function(track)
		if not (vaultState and GUI:Get("fast_vault")) then return end
		if os.clock() - vaultState.t > 0.8 or track.Looped or track.Length < 0.8 then return end
		local prio = track.Priority
		if prio == Enum.AnimationPriority.Core or prio == Enum.AnimationPriority.Idle or prio == Enum.AnimationPriority.Movement then return end
		track:AdjustSpeed(math.clamp(track.Length / CFG.FAST_VAULT_TIME, 1, CFG.FAST_VAULT_MAX_ANIM))
	end)
end
if lp.Character then task.spawn(hookMyAnimator, lp.Character) end
connect(lp.CharacterAdded, function(c) task.spawn(hookMyAnimator, c) end)

-- ===== SPEED BOOST =====
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
		gameWS = hum.WalkSpeed -- nilai asli dari game
	end
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
	-- cadangan: meniru urutan yang tercatat di log
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
end

-- ===== jalankan semua fitur (masing-masing terpisah, error satu tidak mematikan yang lain) =====
local FEATURES = {
	{"ESP", featureESP},
	{"Killer Utility", featureKiller},
	{"Survivor Utility", featureSurvivor},
}
for _, f in ipairs(FEATURES) do
	task.spawn(function()
		local ok, err = pcall(f[2])
		if not ok then warn("[VD] fitur " .. f[1] .. " gagal: " .. tostring(err)) end
	end)
end

return GUI
