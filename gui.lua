-- gui.lua | tampilan saja, belum ada fitur
-- By: @texx-breaker
--
-- Cara pakai dari features.lua:
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
return GUI
