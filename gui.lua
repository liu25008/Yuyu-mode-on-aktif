-- gui.lua | GUI + semua fitur (ESP, Killer Utility, Survivor Utility) dalam satu file
-- By: @texx-breaker
--
-- Satu loadstring saja, tidak perlu folder features. Cara pakai dari script lain:
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
			{kind = "toggle", id = "speed_boost", label = "Speed Boost", desc = "Tambahan kecepatan jalan"},
			{kind = "slider", id = "speed_value", label = "Kecepatan tambahan", min = 0.1, max = 3, step = 0.1, default = 1.0, indent = true},
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
			{kind = "toggle", id = "esp_objects", label = "Pallet", desc = "Hanya di dalam match", color = Color3.fromRGB(194, 98, 10)},
			{kind = "toggle", id = "esp_window", label = "Window", desc = "Hanya di dalam match", color = Color3.fromRGB(0, 200, 230)},
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

local function buildSlider(parent, spec, order)
	local size = spec.indent and UDim2.new(1, -16, 0, 54) or UDim2.new(1, 0, 0, 54)
	local row = new("Frame", {Size = size, BackgroundColor3 = T.surface, BorderSizePixel = 0, LayoutOrder = order}, parent)
	round(row, 9)
	stroke(row, T.line, 1)
	new("TextLabel", {
		Size = UDim2.new(1, -80, 0, 18), Position = UDim2.fromOffset(12, 7), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = spec.label,
	}, row)
	local valLbl = new("TextLabel", {
		Size = UDim2.fromOffset(60, 18), Position = UDim2.new(1, -72, 0, 7), BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Right, Text = "",
	}, row)
	local bar = new("TextButton", {
		Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 27), BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, row)
	local rail = new("Frame", {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3), BackgroundColor3 = T.off, BorderSizePixel = 0}, bar)
	round(rail, 3)
	local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0}, rail)
	round(fill, 3)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = T.text, BorderSizePixel = 0, ZIndex = 2,
	}, rail)
	round(knob, 7)

	register(spec.id, spec.default, function(v, instant)
		local frac = (v - spec.min) / (spec.max - spec.min)
		local t = instant and 0 or 0.06
		tween(fill, t, {Size = UDim2.new(frac, 0, 1, 0)})
		tween(knob, t, {Position = UDim2.new(frac, 0, 0.5, 0)})
		valLbl.Text = string.format("%.1f", v)
	end)

	local dragging = false
	local function apply(x)
		local frac = math.clamp((x - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
		local v = spec.min + frac * (spec.max - spec.min)
		v = math.floor(v / spec.step + 0.5) * spec.step
		v = math.clamp(math.floor(v * 100 + 0.5) / 100, spec.min, spec.max)
		GUI:Set(spec.id, v)
	end
	connect(bar.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			parent.ScrollingEnabled = false
			apply(i.Position.X)
		end
	end)
	connect(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			apply(i.Position.X)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			parent.ScrollingEnabled = true
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
		elseif spec.kind == "slider" then
			buildSlider(scroll, spec, order)
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
-- Killer, Survivor, Pallet, Window (kotak cyan), JTrap, Zombie, Generator dengan progres. Jarak tampil di label pemain.
-- =====================================================================
local function featureESP()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Tags = game:GetService("CollectionService")
local lp = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

local GUI = env.VD_GUI
if not GUI then return end
if env.VD_ESP_CLEANUP then pcall(env.VD_ESP_CLEANUP) end

-- ===== pengaturan =====
local CFG = {
	UPDATE = 0.1,            -- detik antar pembaruan label dan jarak
	OBJ_MAX_DIST = 300,      -- jarak maksimum untuk objek (pallet, window, generator, dll)
	OBJ_FILL = 0.35,         -- transparansi warna di badan objek (0 = pekat, 1 = bening)
	GEN_TEXT_SIZE = 16,      -- ukuran tulisan nama dan progres generator
	MAX_HIGHLIGHTS = 30,     -- Roblox hanya menggambar sekitar 31 highlight sekaligus, objek terdekat didahulukan
	WINDOW_COLOR = Color3.fromRGB(0, 200, 230), -- warna window kalau GUI belum punya tombol esp_window
	WINDOW_FILL = 0.45,      -- transparansi kotak window
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

local function makeLabel(adornee, yOff, textSize)
	local ts = textSize or 13
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, ts + 10)
	bb.StudsOffset = Vector3.new(0, yOff, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = math.huge
	bb.LightInfluence = 0
	bb.Adornee = adornee
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamMedium
	tl.TextSize = ts
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
-- Pallet, generator, jtrap, zombie: Highlight di badan objek. Window: kotak di part VaultTrigger.
-- Tulisan hanya untuk generator, window, jtrap, zombie, tanpa jarak.
local KINDS = {
	gen = {toggle = "esp_generator", name = "Generator", y = 3, label = true, size = CFG.GEN_TEXT_SIZE},
	pallet = {toggle = "esp_objects", name = "Pallet"},
	window = {toggle = "esp_window", fallback = "esp_objects", name = "Window", y = 2, label = true, size = 13},
	trap = {toggle = "esp_jtrap", name = "JTrap", y = 2, label = true, size = 13},
	zombie = {toggle = "esp_zombie", name = "Zombie", y = 3.2, label = true, size = 13},
}

-- window memakai tombol esp_window kalau ada di GUI, kalau tidak pakai esp_objects
local function toggleOf(cfg)
	if cfg.fallback and GUI.State[cfg.toggle] == nil then return cfg.fallback end
	return cfg.toggle
end

local function colorOf(kind, cfg)
	local t = toggleOf(cfg)
	if kind == "window" and t ~= cfg.toggle then return CFG.WINDOW_COLOR end
	return GUI:Get(t .. "_color")
end

local entities = {}
local windowSeen = {}
local diagWritten = false

local function hideObject(e)
	if e.hl then pcall(function() e.hl:Destroy() end) e.hl = nil end
	if e.bb then pcall(function() e.bb:Destroy() end) e.bb = nil end
	if e.fx then
		for _, o in ipairs(e.fx) do pcall(function() o:Destroy() end) end
		e.fx = nil
	end
	e.label = nil
	e.color = nil
end

local function dropObject(model)
	local e = entities[model]
	if not e then return end
	hideObject(e)
	if e.conn then pcall(function() e.conn:Disconnect() end) end
	entities[model] = nil
end

local function addObject(kind, model, trigger, labelled)
	if entities[model] or not model.Parent then return end
	local e = {kind = kind, model = model, nextProg = 0, trigger = trigger, part = trigger, labelled = labelled}
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

-- hitung jarak objek, sembunyikan kalau tidak perlu tampil; hasilnya jarak atau nil
local function objectDistance(model, e, myR, match)
	local cfg = KINDS[e.kind]
	if not (match and GUI:Get(toggleOf(cfg))) or not model:IsDescendantOf(workspace) then
		hideObject(e)
		return nil
	end
	local part = e.part
	if not part or not part.Parent then
		part = mainPart(model)
		e.part = part
	end
	if not part then
		hideObject(e)
		return nil
	end
	local d = myR and (part.Position - myR.Position).Magnitude or 0
	if d > CFG.OBJ_MAX_DIST then
		hideObject(e)
		return nil
	end
	return d
end

-- Highlight hanya menggambar bagian yang kelihatan. Kalau model cuma berisi pemicu transparan,
-- naik ke induk yang punya bentuk kelihatan.
local function hasVisible(m)
	if m:IsA("BasePart") and m.Transparency < 0.9 then return true end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 then return true end
	end
	return false
end

local noVisLogged = false
local function resolveAdornee(model)
	if hasVisible(model) then return model end
	local p = model.Parent
	for _ = 1, 3 do
		if not p or p == workspace or not p:IsA("Model") then break end
		if p:GetExtentsSize().Magnitude <= 40 and hasVisible(p) then return p end
		p = p.Parent
	end
	if not noVisLogged and appendfile then
		noVisLogged = true
		local lines = {"tanpa bagian kelihatan: " .. model:GetFullName()}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				lines[#lines + 1] = d.ClassName .. " " .. d.Name .. " transparansi=" .. tostring(d.Transparency)
			end
		end
		pcall(appendfile, "VD_NoVisible.txt", table.concat(lines, "\n") .. "\n")
	end
	return model
end

-- window: kotak di part VaultTrigger (part itu transparan, jadi Highlight tidak kelihatan)
local function showWindow(e, cfg, color)
	local trig = e.trigger
	if not (trig and trig.Parent) then return end
	if not e.fx then
		local box = Instance.new("BoxHandleAdornment")
		box.Adornee = trig
		box.Size = trig.Size + Vector3.new(0.2, 0.2, 0.2)
		box.AlwaysOnTop = true
		box.ZIndex = 5
		box.Transparency = CFG.WINDOW_FILL
		box.Parent = folder
		local sel = Instance.new("SelectionBox")
		sel.Adornee = trig
		sel.LineThickness = 0.05
		sel.Parent = folder
		e.fx = {box, sel}
		e.color = nil
		if e.labelled then
			local bb, tl = makeLabel(trig, cfg.y, cfg.size)
			tl.Text = cfg.name
			e.bb, e.label = bb, tl
		end
	end
	if e.color ~= color then
		e.color = color
		e.fx[1].Color3 = color
		e.fx[2].Color3 = color
		if e.label then e.label.TextColor3 = labelColor(color) end
	end
end

local function showObject(model, e)
	local cfg = KINDS[e.kind]
	local color = colorOf(e.kind, cfg)
	if e.kind == "window" then
		showWindow(e, cfg, color)
		return
	end
	if not e.hl then
		local hl = Instance.new("Highlight")
		hl.Adornee = resolveAdornee(model)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = CFG.OBJ_FILL
		hl.OutlineTransparency = 0
		hl.Parent = folder
		e.hl = hl
		if cfg.label then
			local bb, tl = makeLabel(e.part, cfg.y, cfg.size)
			e.bb, e.label = bb, tl
		end
		e.color = nil
	end
	if e.color ~= color then
		e.color = color
		e.hl.FillColor = color
		e.hl.OutlineColor = color
		if e.label then e.label.TextColor3 = labelColor(color) end
	end
	if not e.label then return end
	local text = cfg.name
	if e.kind == "gen" then
		local direct = model:GetAttribute("RepairProgress")
		if type(direct) == "number" then
			-- atribut asli generator di game: RepairProgress (0 sampai 100), Completed, PlayersRepairingCount
			if model:GetAttribute("Completed") == true or direct >= 100 then
				text = cfg.name .. " selesai"
			else
				text = string.format("%s %d%%", cfg.name, math.floor(direct + 0.5))
			end
			e.label.Text = text
			return
		end
		if not e.src and os.clock() >= e.nextProg then
			e.nextProg = os.clock() + 3
			e.src = findProgressSource(model)
			if not e.src then writeDiag(model) end
		end
		local pct = readProgress(e.src)
		if pct then text = string.format("%s %d%%", cfg.name, math.floor(pct + 0.5)) end
	end
	e.label.Text = text
end

-- jatah highlight dibagi bergantian antar jenis, tiap jenis dari yang terdekat.
-- window tidak memakai highlight, jadi tidak memakan jatah.
local function updateObjects(myR, match, budget)
	local byKind = {}
	for model, e in pairs(entities) do
		local d = objectDistance(model, e, myR, match)
		if d then
			local l = byKind[e.kind]
			if not l then
				l = {}
				byKind[e.kind] = l
			end
			l[#l + 1] = {model = model, e = e, d = d}
		end
	end
	local lists = {}
	for _, l in pairs(byKind) do
		table.sort(l, function(a, b) return a.d < b.d end)
		lists[#lists + 1] = {items = l, i = 1}
	end
	local shown = 0
	local progress = true
	while progress do
		progress = false
		for _, L in ipairs(lists) do
			local it = L.items[L.i]
			if it then
				L.i = L.i + 1
				progress = true
				if it.e.kind == "window" then
					showObject(it.model, it.e)
				elseif shown < budget then
					shown = shown + 1
					showObject(it.model, it.e)
				else
					hideObject(it.e)
				end
			end
		end
	end
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
			-- jaga-jaga: kalau yang ketemu model raksasa (bukan pallet), pakai induk langsung
			if m and m:IsA("Model") and m:GetExtentsSize().Magnitude > 40 and inst.Parent and inst.Parent:IsA("Model") then m = inst.Parent end
			if m and m:IsA("Model") then addObject("pallet", m) end
		elseif n == "VaultTrigger" then
			-- tiap part VaultTrigger jadi satu entri (satu window punya dua trigger); label hanya di yang pertama
			local par = inst.Parent
			if par and not entities[inst] then
				windowSeen[par] = (windowSeen[par] or 0) + 1
				addObject("window", inst, inst, windowSeen[par] == 1)
			end
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

-- game memberi tag "window" dan "pallet" pada objeknya; tag lebih andal daripada mencari lewat nama
local function registerWindow(obj)
	if obj:IsA("BasePart") then
		local par = obj.Parent or obj
		windowSeen[par] = (windowSeen[par] or 0) + 1
		addObject("window", obj, obj, windowSeen[par] == 1)
		return
	end
	local found = false
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "VaultTrigger" then
			found = true
			windowSeen[obj] = (windowSeen[obj] or 0) + 1
			addObject("window", d, d, windowSeen[obj] == 1)
		end
	end
	if not found then
		local p = mainPart(obj)
		if p then
			windowSeen[obj] = (windowSeen[obj] or 0) + 1
			addObject("window", p, p, windowSeen[obj] == 1)
		end
	end
end

local function registerPallet(obj)
	local m = obj
	if not obj:IsA("Model") then m = obj:FindFirstAncestorOfClass("Model") or obj end
	if m:IsA("Model") and m:GetExtentsSize().Magnitude > 40 then return end
	addObject("pallet", m)
end

for _, o in ipairs(Tags:GetTagged("window")) do pcall(registerWindow, o) end
for _, o in ipairs(Tags:GetTagged("pallet")) do pcall(registerPallet, o) end
connect(Tags:GetInstanceAddedSignal("window"), function(o) pcall(registerWindow, o) end)
connect(Tags:GetInstanceAddedSignal("pallet"), function(o) pcall(registerPallet, o) end)

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
	local used = 0
	for _ in pairs(players) do used = used + 1 end
	updateObjects(myR, match, math.max(0, CFG.MAX_HIGHLIGHTS - used))
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
-- FITUR: Killer Utility
-- Aimbot Jeff, Veil, The Cure. Hanya satu aimbot yang aktif sekaligus.
-- =====================================================================
local function featureKiller()
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
end

-- =====================================================================
-- FITUR: Survivor Utility
-- Auto Parry, Anti Fake Hit, Fast Vault, Speed Boost, Auto Skill, Aimbot Pistol, Auto Jongkok. Data diagnosa ke VD_Diag.txt.
-- =====================================================================
local function featureSurvivor()
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
	DIAG = true,               -- catat data diagnosa ke VD_Diag.txt (skill check, parry, vault)
	PARRY_NATIVE_CALL = true,  -- panggil fungsi Parry() milik pengendali dagger asli (tombol dan cooldown ikut jalan)
	SKILL_ALLOW_KEY = false,   -- tekan Space untuk skill check hanya di PC; di HP Space membatalkan repair dan mengunci gerak
	FAST_VISUAL = true,        -- tampilkan animasi fast vault bawaan game (bukan animasi medium yang dipercepat) saat lari ditekan
	SKILL_CENTER = 109,        -- sudut Line terhadap Goal yang disetel tepat sebelum input skill check
	PARRY_NATIVE = false,      -- jalur tombol item/tombol layar; belum terbukti di Delta, jadi mati. Parry lewat remote seperti semula
	-- parry
	MAX_DIST = 14,             -- jarak maksimum killer (tanpa Anti Fake Hit)
	FAKE_MAX_DIST = 11.5,      -- jarak maksimum (dengan Anti Fake Hit)
	FAKE_MIN_FACING = 0.1,     -- killer harus menghadap ke arah lo (1 = lurus, 0 = menyamping)
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
	PARRY_ANIMS = {
		"rbxassetid://109133187196613",
		"rbxassetid://81793464499285",
	},
	-- fast vault
	FAST_ASSET = "rbxassetid://83873880822918",
	FAST_VAULT_TIME = 0.6,     -- durasi vault fast bawaan sekitar 0.6 detik; dipakai untuk menyamakan lintasan gerak
	FAST_VAULT_MAX_ANIM = 3,   -- batas percepatan lintasan gerak
	VAULT_ATTR = 1.4,          -- atribut vaultspeed minimum selama Fast Vault menyala; 1.4 membuat vault medium selesai sekitar 0.6 detik
	-- auto skill
	SKILL_WIN = {105, 113},    -- selisih Line dan Goal (derajat) yang dihitung perfect, dari pengendali bawaan game
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

local FAST_ID = tonumber(CFG.FAST_ASSET:match("(%d+)$"))

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

-- ketukan layar (bukan keyboard): di HP, Space dibaca sebagai lompat sehingga repair dibatalkan dan gerak terkunci
local touchId = 91
local function sendTouchTap()
	if not VIM then error("VirtualInputManager tidak tersedia") end
	local point = worldInputPoint()
	if not point then error("tidak ada titik layar yang kosong", 0) end
	VIM:SendTouchEvent(touchId, 0, point.X, point.Y)
	task.delay(0.05, function()
		pcall(function() VIM:SendTouchEvent(touchId, 2, point.X, point.Y) end)
	end)
	return point
end

-- ===== diagnosa: semua data dicatat ke VD_Diag.txt =====
local CAS = game:GetService("ContextActionService")
local diagCount = 0
local function diag(tag, text)
	if not CFG.DIAG or diagCount >= 600 or not appendfile then return end
	diagCount = diagCount + 1
	pcall(appendfile, "VD_Diag.txt", string.format("[%.2f][%s] %s\n", os.clock() % 100000, tag, text))
end
if CFG.DIAG and writefile then pcall(writefile, "VD_Diag.txt", "") end

local function controlsEnabled()
	local ps = lp:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if not pm then return "?" end
	local ok, mod = pcall(require, pm)
	if not ok or type(mod) ~= "table" or not mod.GetControls then return "?" end
	local ok2, ctrl = pcall(mod.GetControls, mod)
	if not ok2 or not ctrl then return "?" end
	local ok3, v = pcall(function() return ctrl.controlsEnabled end)
	return ok3 and tostring(v) or "?"
end

local function boundActions()
	local names = {}
	pcall(function()
		for name, info in pairs(CAS:GetAllBoundActionInfo()) do
			names[#names + 1] = name .. "(" .. tostring(info.priority) .. ")"
		end
	end)
	table.sort(names)
	return table.concat(names, ",")
end

local function snapshotState(tag)
	local hum, ch, root = myHum(), myChar(), myRoot()
	local parts = {}
	if hum then
		parts[#parts + 1] = string.format("WalkSpeed=%.2f PlatformStand=%s AutoRotate=%s Gerak=%.2f",
			hum.WalkSpeed, tostring(hum.PlatformStand), tostring(hum.AutoRotate), hum.MoveDirection.Magnitude)
	end
	if root then parts[#parts + 1] = "Anchored=" .. tostring(root.Anchored) end
	if ch then
		for _, k in ipairs({"Immobile", "MovementLocked", "IsStunned", "Rooted", "Crouching", "Sprinting", "lock_repair", "lock_heal"}) do
			local v = ch:GetAttribute(k)
			if v ~= nil then parts[#parts + 1] = k .. "=" .. tostring(v) end
		end
		local controller = ch:FindFirstChild("CheckInterractable")
		if controller then
			parts[#parts + 1] = "isRepairing=" .. tostring(controller:GetAttribute("isRepairing"))
			parts[#parts + 1] = "isHealing=" .. tostring(controller:GetAttribute("isHealing"))
		end
	end
	parts[#parts + 1] = "controlsEnabled=" .. controlsEnabled()
	parts[#parts + 1] = "CAS=" .. boundActions()
	diag(tag, table.concat(parts, " | "))
end

diag("info", "VIM=" .. tostring(VIM ~= nil) .. " getgc=" .. tostring(type(getgc) == "function")
	.. " getconnections=" .. tostring(getconnections ~= nil) .. " firesignal=" .. tostring(firesignal ~= nil)
	.. " hookmetamethod=" .. tostring(hookmetamethod ~= nil) .. " checkcaller=" .. tostring(checkcaller ~= nil)
	.. " appendfile=" .. tostring(appendfile ~= nil))

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

local parryCtl, nextParryScan, parryApiLogged = nil, 0, false
local function findParryController()
	local ch = lp.Character
	if parryCtl and parryCtl.character == ch and parryCtl.tool and parryCtl.tool:IsDescendantOf(ch) then return parryCtl end
	parryCtl = nil
	if not ch or os.clock() < nextParryScan then return nil end
	nextParryScan = os.clock() + 10
	parryCtl = scanGc(function(t)
		return rawget(t, "character") == ch and rawget(t, "parryEvent") ~= nil and rawget(t, "tool") ~= nil
	end)
	if parryCtl then
		print("[VD] pengendali dagger asli ketemu")
		if not parryApiLogged then
			parryApiLogged = true
			dumpApi(parryCtl, "VD_ParryApi.txt")
		end
	end
	return parryCtl
end

local moveCtl, nextMoveScan = nil, 0
local function findMovement()
	local ch = lp.Character
	if moveCtl and moveCtl.character == ch then return moveCtl end
	moveCtl = nil
	if not ch or os.clock() < nextMoveScan then return nil end
	nextMoveScan = os.clock() + 10
	moveCtl = scanGc(function(t)
		return rawget(t, "character") == ch and rawget(t, "normalWalkSpeed") ~= nil and rawget(t, "_movement") ~= nil
	end)
	return moveCtl
end

-- dagger dikenali dari pengendalinya atau dari nama item (skin lain bisa memakai nama model berbeda)
local function hasDagger(c)
	if c:FindFirstChild("Parrying Dagger") then return true end
	if parryCtl and parryCtl.character == c and parryCtl.tool and parryCtl.tool:IsDescendantOf(c) then return true end
	for _, child in ipairs(c:GetChildren()) do
		if (child:IsA("Tool") or child:IsA("Model")) and hasWord(child.Name, {"dagger", "parry"}) then return true end
	end
	return false
end

-- pindai memori (getgc) hanya saat ronde aktif dan pengendalinya belum ada; hasilnya disimpan untuk dipakai berikutnya
local function ensureControllers()
	local c = lp.Character
	if not c or c:GetAttribute("RoundScriptsActive") ~= true then return end
	if GUI:Get("fast_vault") and not (moveCtl and moveCtl.character == c) and os.clock() >= nextMoveScan then
		pcall(findMovement)
	end
	if GUI:Get("auto_parry") and CFG.PARRY_NATIVE_CALL and not (parryCtl and parryCtl.character == c)
		and hasDagger(c) and os.clock() >= nextParryScan then
		pcall(findParryController)
	end
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
	local chosenId = assetId
	if not chosenId and CFG.PARRY_ANIMS and #CFG.PARRY_ANIMS > 0 then
		chosenId = CFG.PARRY_ANIMS[math.random(1, #CFG.PARRY_ANIMS)]
	end
	if not chosenId then return end
	pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = chosenId
		local tr = animator:LoadAnimation(a)
		tr.Priority = Enum.AnimationPriority.Action
		tr:Play()
	end)
end

local function parryReady()
	local c = myChar()
	if not c or not R.Parry then return false, "remote parry tidak ada" end
	if c:GetAttribute("ParrySpent") == true or c:GetAttribute("Parry") == true then return false, "parry sedang aktif atau sudah terpakai" end
	if c:GetAttribute("Knocked") == true or c:GetAttribute("IsHooked") == true or c:GetAttribute("IsCarried") == true then return false, "karakter tidak bisa bertindak" end
	if not hasDagger(c) then return false, "dagger tidak dipegang" end
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
	local ready, reason = parryReady()
	if not ready then
		diag("parry", "ditolak (" .. why .. "): " .. tostring(reason))
		return
	end
	lastParry = os.clock()
	local c = lp.Character
	if CFG.PARRY_NATIVE then
		local pressed = false
		if VIM then pressed = pcall(pressBinding, "item") end
		if not pressed then
			local btn = findParryButton()
			if btn then pressed = pressGui(btn) end
		end
		if pressed then
			diag("parry", "lewat tombol bawaan (" .. why .. ")")
			task.delay(0.2, function()
				if not parryUsed(c) then fire(R.Parry, c) end
			end)
			return
		end
	end
	-- jalur utama: fungsi Parry() milik pengendali dagger asli, supaya tombol di layar ikut masuk cooldown
	if CFG.PARRY_NATIVE_CALL and parryCtl and parryCtl.character == c and type(parryCtl.Parry) == "function" then
		local ctl = parryCtl
		local ok, err = pcall(ctl.Parry, ctl)
		diag("parry", "ctl:Parry() ok=" .. tostring(ok) .. (ok and "" or (" err=" .. tostring(err))) .. " (" .. why .. ")")
		if ok then
			task.delay(0.07, function()
				local used = ctl.isParryOnCooldown == true or ctl.isParryResolving == true or parryUsed(c)
				if used then
					diag("parry", "native diterima; cooldown=" .. tostring(ctl.isParryOnCooldown) .. " resolving=" .. tostring(ctl.isParryResolving))
				else
					fire(R.Parry, c)
					if CFG.PLAY_PARRY_ANIM then playAnimOnMe() end
					diag("parry", "native tidak mengubah status, kirim remote")
				end
			end)
			return
		end
	end
	-- cadangan yang terbukti berfungsi: remote langsung, tanpa jeda
	fire(R.Parry, c)
	if CFG.PLAY_PARRY_ANIM then playAnimOnMe() end
	print("[VD] parry via remote (" .. why .. ")")
	diag("parry", "kirim remote (" .. why .. ")")
	task.delay(0.25, function()
		diag("parry", "hasil: Parry=" .. tostring(c and c:GetAttribute("Parry")) .. " ParrySpent=" .. tostring(c and c:GetAttribute("ParrySpent")))
	end)
end

local function logParrySkip(plr, kr, mr, d, reason)
	local facing = -1
	if kr and mr then
		local toMe = mr.Position - kr.Position
		if toMe.Magnitude > 0.1 then
			facing = kr.CFrame.LookVector:Dot(toMe.Unit)
		end
	end
	local prev = distBefore(plr, 0.25)
	local delta = (prev and d) and (d - prev) or 0
	diag("parry-skip", string.format(
		"killer=%s alasan=%s dist=%.2f (max=%.1f) facing=%.2f (min=%.2f) delta0.25=%.2f antiFake=%s",
		plr.Name, reason, d or -1,
		GUI:Get("anti_fake_hit") and CFG.FAKE_MAX_DIST or CFG.MAX_DIST,
		facing, CFG.FAKE_MIN_FACING, delta, tostring(GUI:Get("anti_fake_hit"))
	))
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
	if not (mr and kr) then
		diag("parry-skip", "killer=" .. plr.Name .. " alasan=no_root")
		return
	end
	local d = (kr.Position - mr.Position).Magnitude
	local strict = GUI:Get("anti_fake_hit")
	local maxD = strict and CFG.FAKE_MAX_DIST or CFG.MAX_DIST
	if d > maxD then
		logParrySkip(plr, kr, mr, d, "too_far")
		return
	end
	if strict then
		local toMe = mr.Position - kr.Position
		local facing = toMe.Magnitude > 0.1 and kr.CFrame.LookVector:Dot(toMe.Unit) or 1
		if facing < CFG.FAKE_MIN_FACING then
			logParrySkip(plr, kr, mr, d, "low_facing")
			return
		end
		local prev = distBefore(plr, 0.25)
		if prev and (d - prev) > CFG.FAKE_OPENING then
			logParrySkip(plr, kr, mr, d, "opening_gap")
			return
		end
	end
	doParry(isWindup and "aba-aba" or "pukulan")
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
-- Urutan menekan: tombol bawaan lewat VirtualInputManager, lalu kalau skill check masih tampil setelah 0.3 detik,
-- ketuk lewat sambungan event script skill check. Semua langkah dan keadaan karakter dicatat ke VD_Diag.txt.
local lastPress = 0
local qtePressed = false
local qteSeen, qteDelay = nil, 0
local qteAnnounced = false
local qteShownAt = 0
local tapPrints = 0

local function skillParts()
	local pg = lp:FindFirstChild("PlayerGui")
	local g = pg and pg:FindFirstChild("SkillCheckPromptGui")
	local check = g and g:FindFirstChild("Check")
	if not check then return nil end
	return {gui = g, check = check, line = check:FindFirstChild("Line"), goal = check:FindFirstChild("Goal")}
end

local function skillVisible()
	local sp = skillParts()
	return sp ~= nil and sp.gui.Enabled and sp.check.Visible
end

-- ketukan pemain sendiri dicatat bersama sudut jarum: ini data asli untuk mengkalibrasi zona perfect
connect(UIS.InputBegan, function(input)
	if os.clock() - lastPress < 1 or not skillVisible() then return end
	local sp = skillParts()
	if sp and sp.line and sp.goal then
		diag("skill", string.format("ketukan pemain: Line-Goal=%.1f (%s)", (sp.line.Rotation - sp.goal.Rotation) % 360, tostring(input.UserInputType)))
	end
end)

-- ketuk lewat sambungan event milik script skill check
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
		if fn and hasWord(scriptNameOf(fn), {"skillcheck", "skill", "localscript"}) then
			if pcall(c.Fire, c, fake, false) then fired = true end
		end
	end
	return fired
end

local function pressSkill()
	qtePressed = true
	lastPress = os.clock()
	local sp = skillParts()
	local before = "?"
	if sp and sp.line and sp.goal then
		before = string.format("%.1f", (sp.line.Rotation - sp.goal.Rotation) % 360)
		-- samakan jarum dengan tengah zona perfect tepat sebelum input, supaya jeda input tidak membuat meleset
		sp.line.Rotation = sp.goal.Rotation + CFG.SKILL_CENTER
	end
	-- sambungan event dipanggil langsung (sinkron), jadi game menilai pada saat yang sama dengan yang kita lihat
	local fired = tapSkillCheck()
	local how = fired and "sambungan event (sinkron)" or "tidak ada sambungan"
	if not fired and VIM then
		if UIS.TouchEnabled then
			local ok, err = pcall(sendTouchTap)
			how = ok and "ketuk layar" or ("ketuk layar gagal: " .. tostring(err))
		elseif CFG.SKILL_ALLOW_KEY or not UIS.TouchEnabled then
			local ok, name = pcall(pressBinding, "skillcheck")
			how = ok and ("tombol " .. tostring(name)) or "tombol gagal"
		end
	end
	diag("skill", "tekan lewat " .. how .. "; Line-Goal sebelum disetel=" .. before)
	task.delay(0.2, function()
		diag("skill", "0.2 detik setelah ditekan, skill check masih tampil=" .. tostring(skillVisible()))
	end)
end

local function announceSkill()
	diag("skill", "skill check muncul; auto=" .. tostring(GUI:Get("auto_skill")) .. " mode=" .. tostring(GUI:Get("auto_skill_mode"))
		.. " kb_skillcheck=" .. tostring(lp:GetAttribute("kb_skillcheck")))
	local names, seen = {}, {}
	for _, c in ipairs(connectionsOf(UIS.InputBegan)) do
		local fn = nil
		pcall(function() fn = c.Function end)
		local n = fn and scriptNameOf(fn) or ""
		if n ~= "" and not seen[n] then
			seen[n] = true
			names[#names + 1] = n
		end
	end
	diag("skill", "pemegang UIS.InputBegan: " .. table.concat(names, " | "))
	snapshotState("skill+0")
	for _, dt in ipairs({0.6, 1.5, 3.0}) do
		task.delay(dt, function() snapshotState("skill+" .. tostring(dt)) end)
	end
end

local function qteStep()
	local sp = skillParts()
	local shown = sp ~= nil and sp.gui.Enabled and sp.check.Visible
	if not shown then
		if qteAnnounced then
			diag("skill", string.format("skill check hilang setelah %.2f detik", os.clock() - qteShownAt))
			snapshotState("skill-selesai")
		end
		qteAnnounced, qteSeen, qtePressed = false, nil, false
		return
	end
	if not qteAnnounced then
		qteAnnounced = true
		qteShownAt = os.clock()
		announceSkill() -- dicatat juga saat Auto Skill mati, sebagai pembanding
	end
	if not GUI:Get("auto_skill") or not (sp.line and sp.goal) then return end
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

-- pengaman: kalau setelah skill check repair sudah berhenti tapi WalkSpeed tertinggal 0 (gerak macet), pulihkan
local stuckSince = nil
local function unstickStep()
	if not GUI:Get("auto_skill") or os.clock() - lastPress > 10 then
		stuckSince = nil
		return
	end
	local hum, ch, root = myHum(), myChar(), myRoot()
	if not (hum and ch and root) then return end
	local controller = ch:FindFirstChild("CheckInterractable")
	local busy = controller and (controller:GetAttribute("isRepairing") or controller:GetAttribute("isHealing"))
	local blocked = false
	for _, k in ipairs({"Knocked", "IsHooked", "IsCarried", "IsStunned", "Immobile", "Rooted", "MovementLocked", "Trapped", "Chained"}) do
		if ch:GetAttribute(k) == true then blocked = true end
	end
	if busy or blocked or root.Anchored or hum.WalkSpeed > 0.5 or skillVisible() then
		stuckSince = nil
		return
	end
	stuckSince = stuckSince or os.clock()
	if os.clock() - stuckSince >= 0.4 then
		local base = tonumber(ch:GetAttribute("Speed")) or 17
		hum.WalkSpeed = base * (tonumber(ch:GetAttribute("speedboost")) or 1)
		hum.AutoRotate = true
		diag("skill", string.format("gerak macet terdeteksi setelah skill check, WalkSpeed dipulihkan ke %.1f", hum.WalkSpeed))
		stuckSince = nil
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
			local originalTier = args[5]
			args[2] = true
			args[5] = "fast"
			vaultState = {guid = args[3], t = os.clock(), part = false}
			diag("vault", "tier diubah ke fast (asli: " .. tostring(originalTier) .. ")")
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
		if args.n >= 2 then
			diag("skill", string.format("hasil dari game: %s nilai=%s (%.2f detik setelah script menekan)",
				tostring(args[1]), tostring(args[2]), os.clock() - lastPress))
		end
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

-- percepat animasi vault lewat pengendali gerak asli. Pengendali dicari sekali saat vault pertama dimulai
-- (di luar jalur kritis); per frame hanya memakai hasil yang sudah ada, tanpa memindai memori.
local vaultReported = false
local function vaultSpeedStep()
	if not GUI:Get("fast_vault") then
		restoreVaultAttr()
		restoreVaultTracks()
		return
	end
	local ch = lp.Character
	if not ch then return end
	setVaultAttr(ch)
	local mv = moveCtl
	if not mv or mv.character ~= ch then return end
	local track = mv.isVaulting and mv.activeVaultTrack
	if not track then return end
	local playing = false
	pcall(function() playing = track.IsPlaying end)
	if not playing then return end
	local len = track.Length or (track.Track and track.Track.Length) or 1.5
	local current = trackSpeedOf(track)
	if type(current) ~= "number" then return end
	if not vaultTracks[track] then vaultTracks[track] = {original = current} end
	local target = math.clamp(len / CFG.FAST_VAULT_TIME, 1, CFG.FAST_VAULT_MAX_ANIM)
	if current < target - 0.05 then
		pcall(function() track:AdjustSpeed(target) end)
		if not vaultReported then
			vaultReported = true
			diag("vault", string.format("kecepatan animasi vault dinaikkan %.2f -> %.2f (panjang %.2f)", current, target, len))
		end
	end
end

-- cadangan: percepat animasi vault milik sendiri tanpa pengendali gerak, dan catat durasi tiap vault
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

-- tampilkan animasi fast vault bawaan game; animasi medium bawaan disembunyikan (bobot 0) tapi tetap berjalan,
-- jadi alur gerak bawaan tidak terganggu
local fastVisualTrack = nil
local function swapToFastVisual(animator)
	local ch = lp.Character
	if not ch or not GUI:Get("fast_vault") then return end
	if ch:GetAttribute("VaultTier") == "fast" then return end -- sudah fast bawaan
	if ch:GetAttribute("Sprinting") ~= true then return end   -- syarat: tombol lari ditekan
	if fastVisualTrack and fastVisualTrack.IsPlaying then return end
	for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
		local prio = tr.Priority
		if idOf(tr) ~= FAST_ID and not tr.Looped and tr.Length >= 0.8 and prio ~= Enum.AnimationPriority.Core
			and prio ~= Enum.AnimationPriority.Idle and prio ~= Enum.AnimationPriority.Movement then
			pcall(function() tr:AdjustWeight(0) end)
		end
	end
	local ok, tr = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = CFG.FAST_ASSET
		return animator:LoadAnimation(a)
	end)
	if ok and tr then
		tr.Priority = Enum.AnimationPriority.Action4
		tr.Looped = false
		tr:Play(0.05)
		fastVisualTrack = tr
		diag("vault", string.format("animasi fast vault bawaan diputar (panjang %.2f)", tr.Length))
	end
end

local function hookMyAnimator(char)
	local hum = char:WaitForChild("Humanoid", 10)
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 5))
	if not animator or hooked[animator] then return end
	hooked[animator] = true
	connect(animator.AnimationPlayed, function(track)
		if not GUI:Get("fast_vault") then return end
		if idOf(track) == FAST_ID then return end
		if track.Looped or track.Length < 0.8 then return end
		local prio = track.Priority
		if prio == Enum.AnimationPriority.Core or prio == Enum.AnimationPriority.Idle or prio == Enum.AnimationPriority.Movement then return end
		local vaulting = (vaultState and os.clock() - vaultState.t < 0.8) or char:GetAttribute("isvaulting") == true or nearVault()
		if not vaulting then return end
		vaultWindow = math.max(vaultWindow, os.clock() + 2)
		track:AdjustSpeed(math.clamp(track.Length / CFG.FAST_VAULT_TIME, 1, CFG.FAST_VAULT_MAX_ANIM))
		if CFG.FAST_VISUAL then swapToFastVisual(animator) end
	end)
	connect(char:GetAttributeChangedSignal("isvaulting"), function()
		if char:GetAttribute("isvaulting") ~= true then
			if vaultStartAt then
				local line = string.format("durasi vault %.2f detik, tier=%s, vaultspeed=%s, fast_vault=%s",
					os.clock() - vaultStartAt, tostring(char:GetAttribute("VaultTier")),
					tostring(char:GetAttribute("vaultspeed")), tostring(GUI:Get("fast_vault")))
				logLine("VD_VaultLog.txt", line)
				diag("vault", line)
				vaultStartAt = nil
			end
			return
		end
		vaultStartAt = os.clock()
		vaultWindow = os.clock() + 2
		diag("vault", "vault mulai; fast_vault=" .. tostring(GUI:Get("fast_vault")) .. " pengendali=" .. tostring(moveCtl ~= nil)
			.. " tier=" .. tostring(char:GetAttribute("VaultTier")) .. " vaultspeed=" .. tostring(char:GetAttribute("vaultspeed")))
		if CFG.FAST_VISUAL and GUI:Get("fast_vault") then
			task.delay(0.03, function() swapToFastVisual(animator) end)
			task.delay(0.12, function() swapToFastVisual(animator) end)
		end
		if not moveCtl then task.spawn(function() pcall(findMovement) end) end
		if not GUI:Get("fast_vault") then return end
		for _, dt in ipairs({0, 0.05, 0.15}) do
			task.delay(dt, function()
				if animator.Parent then boostVaultAnims(animator) end
			end)
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
	safe(unstickStep, "unstick")
	acc = acc + dt
	if acc >= 0.05 then
		acc = 0
		sample()
		predictive()
		crouchStep()
		safe(ensureControllers, "kontrol")
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
