--> FruitBook (client)
-- 📖 Fruit Book: every fruit in Databases.Fruits.Fruits, discovered ones revealed, the rest "???".
-- Discovery comes only from the server (data "discovered_fruits" + C_Fruit_Discovered), see server FruitBook.
--   FruitBook.open() / FruitBook.close()   (opened from More > Other > Fruit Book)
-- Built once, refreshed only when discovered_fruits / fruits change while the book is open.

local _L = _G._L

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Network
local FruitUtility
local Fruits
local Rarities

local rgb = Color3.fromRGB
local CREAM, CREAM2, BROWN, GREEN = rgb(255, 248, 230), rgb(245, 232, 200), rgb(90, 60, 30), rgb(110, 190, 80)
local RARITY_COLOR = {
	Common = rgb(170, 170, 170), Rare = rgb(80, 170, 255), Epic = rgb(190, 90, 255), Legendary = rgb(255, 190, 40),
	Mythical = rgb(255, 80, 120), Huge = rgb(60, 220, 150), Secret = rgb(120, 90, 200), Divine = rgb(255, 215, 120),
}
-- no fruit images exist yet: a themed emoji per fruit (3D model when the fruit has one)
local ICONS = {
	{"Apple", "🍎"}, {"Strawberry", "🍓"}, {"Dragon", "🐉"}, {"Phoenix", "🦅"}, {"Absolute Zero", "❄️"},
	{"Winter", "❄️"}, {"Flame", "🔥"}, {"Inferno", "🔥"}, {"Magma", "🌋"}, {"Volcano", "🌋"}, {"Eruption", "🌋"},
	{"Ice", "❄️"}, {"Glacier", "🧊"}, {"Tundra", "🧊"}, {"Spark", "⚡"}, {"Lightning", "⚡"}, {"Thunder", "🌩️"},
	{"Storm", "⛈️"}, {"Tempest", "🌪️"}, {"Wind", "🍃"}, {"Cyclone", "🌪️"}, {"Stone", "🗿"}, {"Boulder", "🗿"},
	{"Soul", "👻"}, {"Void", "🌑"}, {"Celestial", "🌟"}, {"Ancient", "🏺"}, {"Primordial", "🌌"},
	{"Reality", "🔮"}, {"Chaos", "🌀"}, {"Eternal", "♾️"}, {"Genesis", "✨"}, {"Apocalypse", "☄️"},
}

local FruitBook = {}

local data
local gui, panel, grid, countLabel, fill, filterBar, detail
local cards = {}
local filter = "ALL"
local isOpen = false
local toastQueue, toastBusy = {}, false

------------------------------------------------------------ helpers
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
end
local function stroke(p, color, t, border)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.LineJoinMode = Enum.LineJoinMode.Round
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = p
	return s
end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = BROWN
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end
local function sfx(name)
	local ok, SoundFX = pcall(_L.Get, {"Client", "Modules", "Controllers", "SoundFX"})
	if ok and SoundFX and SoundFX.play then
		SoundFX.play(name)
	end
end

local function allFruits()
	local list = {}
	for _, info in ipairs(Fruits) do
		if typeof(info) == "table" and info.name and not info.admin_only and not info.hidden then
			table.insert(list, info)
		end
	end
	return list
end

local function rarityOrder(name)
	for i, r in ipairs(Rarities) do
		if r.name == name then
			return i
		end
	end
	return 99
end

local function iconFor(info)
	local name = info.display_name or info.name
	for _, pair in ipairs(ICONS) do
		if name:find(pair[1], 1, true) then
			return pair[2]
		end
	end
	return "🍏"
end

local function discovered()
	return (data and data:Get("discovered_fruits")) or {}
end

-- 3D model if the fruit has one, emoji otherwise. dark = undiscovered silhouette
local function makeIcon(parent, info, dark, size)
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = size
	holder.Parent = parent
	local source = _L.Assets.Models.Fruits:FindFirstChild(info.model or info.name)
	if info.icon and info.icon ~= "" then
		-- a dedicated icon (FruitCatalog `icon`) wins over the 3D model
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = info.icon
		img.ImageColor3 = if dark then rgb(60, 45, 35) else rgb(255, 255, 255)
		img.Parent = holder
	elseif source then
		local vp = Instance.new("ViewportFrame")
		vp.BackgroundTransparency = 1
		vp.Size = UDim2.fromScale(1, 1)
		vp.Ambient = if dark then rgb(0, 0, 0) else rgb(200, 200, 200)
		vp.LightColor = if dark then rgb(0, 0, 0) else rgb(255, 250, 235)
		vp.ImageColor3 = if dark then rgb(60, 45, 35) else rgb(255, 255, 255)
		vp.Parent = holder
		local model = source:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.PivotOffset = CFrame.new()
				d.Anchored = true
			end
		end
		model:PivotTo(CFrame.new())
		model.Parent = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local ext = model:GetExtentsSize()
		cam.CFrame = CFrame.lookAt(Vector3.new(0, ext.Y * 0.1, -ext.Magnitude * 2.1), Vector3.new(0, 0, 0))
		cam.Parent = vp
		vp.CurrentCamera = cam
	else
		label(holder, {Size = UDim2.fromScale(1, 1), Text = if dark then "❔" else iconFor(info), TextTransparency = if dark then 0.35 else 0})
	end
	return holder
end

------------------------------------------------------------ details (tap a discovered card)
local function showDetail(info)
	if detail then
		detail:Destroy()
	end
	local known = discovered()[info.name]
	detail = Instance.new("TextButton") -- dim layer inside the panel, tap to close
	detail.Name = "Detail"
	detail.Text = ""
	detail.AutoButtonColor = false
	detail.BackgroundColor3 = rgb(40, 30, 20)
	detail.BackgroundTransparency = 0.45
	detail.Size = UDim2.fromScale(1, 1)
	detail.ZIndex = 20
	detail.Parent = panel
	corner(detail, 18)
	detail.MouseButton1Click:Connect(function()
		detail:Destroy()
		detail = nil
	end)
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(300, 330)
	card.BackgroundColor3 = CREAM
	card.ZIndex = 21
	card.Parent = detail
	corner(card, 16)
	stroke(card, RARITY_COLOR[info.rarity] or BROWN, 4, true)
	local function z(g)
		for _, d in ipairs(g:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 22
			end
		end
	end
	makeIcon(card, info, not known, UDim2.fromOffset(110, 110)).Position = UDim2.fromOffset(95, 10)
	label(card, {Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 124), Text = if known then (info.display_name or info.name) else "???"})
	local rl = label(card, {Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 156), Text = string.upper(info.rarity or ""), TextColor3 = RARITY_COLOR[info.rarity] or BROWN})
	stroke(rl, rgb(60, 40, 25), 1.5)

	local lines = {}
	if known then
		local owned, bestLevel = 0, 0
		for _, f in ipairs(data:Get("fruits") or {}) do
			if f.name == info.name then
				owned += 1
				bestLevel = math.max(bestLevel, f.level or 1)
			end
		end
		table.insert(lines, "✔ Discovered")
		table.insert(lines, "🎒 Owned: " .. owned .. (if owned > 0 then "   •   ⭐ Best Lv " .. bestLevel else ""))
		local ok, level = pcall(function()
			local MasteryUtility = _L.Get {"Common", "Modules", "Utilities", "MasteryUtility"}
			local Mastery = _L.Get {"Common", "Modules", "Databases", "Mastery"}
			local xp = MasteryUtility.getXp(data, "fruits", info.name)
			if xp <= 0 then
				return nil
			end
			return MasteryUtility.getLevelFromXp(Mastery.fruit, xp)
		end)
		if ok and level then
			table.insert(lines, "🎯 Mastery Lv " .. level)
		end
		if info.max_level then
			table.insert(lines, "📈 Max Lv " .. info.max_level)
		end
		if info.description then
			table.insert(lines, info.description)
		end
	else
		table.insert(lines, "🔒 Not discovered yet")
		table.insert(lines, "Hatch eggs to find it!")
	end
	local body = label(card, {Size = UDim2.new(1, -28, 0, 130), Position = UDim2.fromOffset(14, 184), Text = table.concat(lines, "\n"), TextScaled = true, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.GothamBold, TextColor3 = rgb(110, 80, 50)})
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = 17
	lim.Parent = body
	z(detail)
	card.ZIndex = 21
	local sc = Instance.new("UIScale")
	sc.Scale = 0.85
	sc.Parent = card
	TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	sfx("UI_Click")
end

------------------------------------------------------------ grid
local function refresh()
	if not panel then
		return
	end
	local found = discovered()
	local list = allFruits()
	local total, have = #list, 0
	for _, info in ipairs(list) do
		if found[info.name] then
			have += 1
		end
	end
	countLabel.Text = have .. " / " .. total .. " DISCOVERED"
	TweenService:Create(fill, TweenInfo.new(0.3), {Size = UDim2.fromScale(if total > 0 then have / total else 0, 1)}):Play()

	for _, c in pairs(cards) do
		c:Destroy()
	end
	table.clear(cards)
	for i, info in ipairs(list) do
		if filter == "ALL" or info.rarity == filter then
			local known = found[info.name]
			local color = RARITY_COLOR[info.rarity] or BROWN
			local card = Instance.new("TextButton")
			card.Name = info.name
			card.LayoutOrder = rarityOrder(info.rarity) * 100 + i
			card.Text = ""
			card.AutoButtonColor = true
			card.Selectable = true
			card.BackgroundColor3 = if known then CREAM else rgb(225, 212, 185)
			card.Parent = grid
			corner(card, 12)
			stroke(card, color, if known then 3 else 2, true)
			makeIcon(card, info, not known, UDim2.new(1, -16, 0, 56)).Position = UDim2.fromOffset(8, 6)
			label(card, {Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 64), Text = if known then (info.display_name or (info.name:gsub(" Fruit$", ""))) else "???"})
			local r = label(card, {Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 84), Text = string.upper(info.rarity or ""), TextColor3 = color})
			stroke(r, rgb(60, 40, 25), 1)
			card.MouseButton1Click:Connect(function()
				showDetail(info)
			end)
			cards[info.name] = card
		end
	end
end

local function buildFilters()
	for _, c in ipairs(filterBar:GetChildren()) do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	-- only rarities that really have fruits
	local present = {}
	for _, info in ipairs(allFruits()) do
		present[info.rarity] = true
	end
	local order = {"ALL"}
	for _, r in ipairs(Rarities) do
		if present[r.name] then
			table.insert(order, r.name)
		end
	end
	for i, name in ipairs(order) do
		local b = Instance.new("TextButton")
		b.Name = name
		b.LayoutOrder = i
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 30)
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 15
		b.Text = string.upper(name)
		b.TextColor3 = rgb(255, 255, 255)
		b.BackgroundColor3 = if name == "ALL" then GREEN else (RARITY_COLOR[name] or BROWN)
		b.Parent = filterBar
		corner(b, 10)
		stroke(b, rgb(60, 40, 25), 1.5)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = b
		local sel = stroke(b, rgb(255, 255, 255), 0, true)
		sel.Name = "Sel"
		b.MouseButton1Click:Connect(function()
			filter = name
			for _, o in ipairs(filterBar:GetChildren()) do
				if o:IsA("GuiButton") then
					o.Sel.Thickness = if o.Name == filter then 3 else 0
				end
			end
			sfx("UI_Click")
			refresh()
		end)
	end
	local first = filterBar:FindFirstChild("ALL")
	if first then
		first.Sel.Thickness = 3
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "FruitBookUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = _L.PlayerGui

	local dim = Instance.new("TextButton")
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = rgb(20, 40, 20)
	dim.BackgroundTransparency = 0.55
	dim.Selectable = false
	dim.Parent = gui
	dim.MouseButton1Click:Connect(function()
		FruitBook.close()
	end)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromOffset(620, 470)
	panel.BackgroundColor3 = CREAM2
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, rgb(70, 140, 60), 5, true)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		local inset = GuiService:GetGuiInset()
		scale.Scale = math.clamp(math.min((vp.X - 24) / 620, (vp.Y - inset.Y - 24) / 470), 0.45, 1.15)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundColor3 = rgb(110, 200, 90)
	header.Parent = panel
	corner(header, 18)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(rgb(140, 225, 100), rgb(80, 175, 80))
	grad.Rotation = 90
	grad.Parent = header
	local title = label(header, {Size = UDim2.new(1, -150, 0, 36), Position = UDim2.fromOffset(16, 10), Text = "🍓 FRUIT COLLECTION", TextColor3 = rgb(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left})
	stroke(title, rgb(35, 90, 30), 2.5)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0.5, 0)
	close.Size = UDim2.fromOffset(42, 42)
	close.BackgroundColor3 = rgb(235, 80, 80)
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.Text = "X"
	close.TextColor3 = rgb(255, 255, 255)
	close.Parent = header
	corner(close, 12)
	stroke(close, rgb(120, 25, 25), 2.5, true)
	close.MouseButton1Click:Connect(function()
		FruitBook.close()
	end)

	-- progress
	countLabel = label(panel, {Size = UDim2.fromOffset(260, 22), Position = UDim2.fromOffset(16, 64), Text = "0 / 0 DISCOVERED", TextXAlignment = Enum.TextXAlignment.Left})
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 280, 0, 68)
	bar.Size = UDim2.new(1, -296, 0, 14)
	bar.BackgroundColor3 = rgb(220, 205, 175)
	bar.Parent = panel
	corner(bar, 7)
	fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GREEN
	fill.Parent = bar
	corner(fill, 7)

	-- rarity filters (scrolls sideways on small screens)
	filterBar = Instance.new("ScrollingFrame")
	filterBar.Position = UDim2.fromOffset(12, 92)
	filterBar.Size = UDim2.new(1, -24, 0, 40)
	filterBar.BackgroundTransparency = 1
	filterBar.BorderSizePixel = 0
	filterBar.ScrollBarThickness = 0
	filterBar.ScrollingDirection = Enum.ScrollingDirection.X
	filterBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	filterBar.CanvasSize = UDim2.new()
	filterBar.Parent = panel
	local fl = Instance.new("UIListLayout")
	fl.FillDirection = Enum.FillDirection.Horizontal
	fl.Padding = UDim.new(0, 6)
	fl.SortOrder = Enum.SortOrder.LayoutOrder
	fl.VerticalAlignment = Enum.VerticalAlignment.Center
	fl.Parent = filterBar
	local fpad = Instance.new("UIPadding")
	fpad.PaddingLeft = UDim.new(0, 3)
	fpad.PaddingRight = UDim.new(0, 3)
	fpad.Parent = filterBar

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(12, 138)
	grid.Size = UDim2.new(1, -24, 1, -150)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = rgb(160, 120, 80)
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(104, 104)
	gl.CellPadding = UDim2.fromOffset(8, 8)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.Parent = grid
	local gpad = Instance.new("UIPadding")
	gpad.PaddingTop = UDim.new(0, 4)
	gpad.PaddingBottom = UDim.new(0, 8)
	gpad.Parent = grid

	buildFilters()
end

function FruitBook.open()
	if not data then
		return
	end
	if not gui then
		build()
	end
	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		local cur = UI._current:Get()
		if cur then
			UI.Close({name = cur})
		end
	end)
	isOpen = true
	refresh()
	gui.Enabled = true
	local sc = panel:FindFirstChildOfClass("UIScale")
	local target = sc.Scale
	sc.Scale = target * 0.85
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = target}):Play()
	sfx("UI_Open")
	-- controller: start on the first card
	if UserInputService.GamepadEnabled then
		task.defer(function()
			local first
			for _, c in pairs(cards) do
				if not first or c.LayoutOrder < first.LayoutOrder then
					first = c
				end
			end
			GuiService.SelectedObject = first
		end)
	end
end

function FruitBook.close()
	if not isOpen then
		return
	end
	isOpen = false
	if detail then
		detail:Destroy()
		detail = nil
	end
	gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	sfx("UI_Close")
end

------------------------------------------------------------ "NEW FRUIT DISCOVERED!" toast
local function playToast(name)
	local info = FruitUtility.getInfo(name)
	if not info then
		return
	end
	local tg = _L.PlayerGui:FindFirstChild("FruitDiscoveryToast")
	if not tg then
		tg = Instance.new("ScreenGui")
		tg.Name = "FruitDiscoveryToast"
		tg.ResetOnSpawn = false
		tg.DisplayOrder = 12
		tg.Parent = _L.PlayerGui
	end
	local color = RARITY_COLOR[info.rarity] or GREEN
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 124) -- below the currency + harvest chip
	card.Size = UDim2.fromOffset(300, 84)
	card.BackgroundColor3 = CREAM
	card.Parent = tg
	corner(card, 16)
	stroke(card, color, 4, true)
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = card
	makeIcon(card, info, false, UDim2.fromOffset(64, 64)).Position = UDim2.fromOffset(10, 10)
	local head = label(card, {Size = UDim2.new(1, -90, 0, 26), Position = UDim2.fromOffset(80, 10), Text = "✨ NEW FRUIT DISCOVERED!", TextColor3 = rgb(255, 190, 40)})
	stroke(head, rgb(90, 55, 20), 2)
	label(card, {Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(80, 38), Text = info.display_name or info.name})
	local rl = label(card, {Size = UDim2.new(1, -90, 0, 14), Position = UDim2.fromOffset(80, 62), Text = string.upper(info.rarity or ""), TextColor3 = color})
	stroke(rl, rgb(60, 40, 25), 1)
	-- a few sparkles flying out
	for i = 1, 6 do
		local s = label(tg, {Text = "✨", Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 166)})
		local a = (i / 6) * math.pi * 2
		TweenService:Create(s, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(a) * 180, 0, 166 + math.sin(a) * 60), TextTransparency = 1,
		}):Play()
		task.delay(0.75, function()
			s:Destroy()
		end)
	end
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	sfx("Mutation")
	task.wait(2.4)
	TweenService:Create(sc, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
	task.wait(0.22)
	card:Destroy()
end

local function queueToasts(names)
	for _, n in ipairs(names) do
		table.insert(toastQueue, n)
	end
	if toastBusy then
		return
	end
	toastBusy = true
	task.spawn(function()
		task.wait(1.6) -- let the egg opening finish first
		while #toastQueue > 0 do
			pcall(playToast, table.remove(toastQueue, 1))
		end
		toastBusy = false
	end)
end

------------------------------------------------------------
function FruitBook._init()
	Network = _L.Get {"Common", "Library", "Network"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	Fruits = _L.Get {"Common", "Modules", "Databases", "Fruits", "Fruits"}
	Rarities = _L.Get {"Common", "Modules", "Databases", "Fruits", "Rarities"}
end

function FruitBook._start()
	Network.Remote.Fired("C_Fruit_Discovered", function(names)
		if typeof(names) == "table" then
			queueToasts(names)
		end
	end)
	task.spawn(function()
		local Data = _L.Get {"Client", "Library", "Classes", "Data"}
		data = Data.Await()
		data:Bind("discovered_fruits", function()
			if isOpen then
				refresh()
			end
		end)
	end)
	-- another menu opening closes the book
	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		UI._current:Bind(function(v)
			if v and isOpen then
				FruitBook.close()
			end
		end)
	end)
end

return FruitBook
