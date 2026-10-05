--> Daycare (UI, V1.1)
-- Opened from the Village Fruit Pen (sign prompt, or a Daycare Fruit's prompt).
-- Shows the Daycare slots (capacity 3): Fruit preview, name, rarity, Gem rate, time in Daycare,
-- Gems ready + COLLECT / WITHDRAW, and "+ ADD FRUIT" for an empty slot.
-- Everything shown is computed from the replicated save with the same FruitFarmUtility the
-- server uses; every action is a server request (the client never sends an amount).

local _L = _G._L

local Services
local Tracker
local Data
local Network
local Audio
local Spr
local UI
local FruitUtility
local FruitStageUtility
local FruitFarmUtility
local Notifications

-- FruitBound look: warm cream, wood outlines, green accents
local CREAM = Color3.fromRGB(255, 248, 230)
local CREAM_DARK = Color3.fromRGB(242, 228, 200)
local WOOD = Color3.fromRGB(110, 72, 38)
local WOOD_TEXT = Color3.fromRGB(90, 60, 30)
local GREEN = Color3.fromRGB(110, 190, 80)
local GEM = Color3.fromRGB(70, 170, 230)
local RED = Color3.fromRGB(215, 95, 80)
local RARITY_COLOR = {
	Common = Color3.fromRGB(150, 150, 150),
	Rare = Color3.fromRGB(70, 140, 230),
	Epic = Color3.fromRGB(165, 85, 220),
	Legendary = Color3.fromRGB(240, 170, 40),
	Mythical = Color3.fromRGB(230, 70, 110),
}
local PREVIEW_CLUTTER = {"ParticleEmitter", "Beam", "Trail", "PointLight", "SpotLight", "SurfaceLight", "BillboardGui", "Fire", "Smoke", "Sparkles", "Sound", "ProximityPrompt"}
local FONT = Enum.Font.FredokaOne

------------->
local Daycare = {
	name = script.Name,
}

------------------------------------------------------------ small builders
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 14)
	c.Parent = parent
	return c
end

local function stroke(parent, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or WOOD
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = WOOD_TEXT
	l.Text = text
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent, text, color, props)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	corner(b, UDim.new(0, 10))
	stroke(b, 2.5, WOOD)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Thickness = 1.5
	ts.Color = Color3.fromRGB(60, 40, 20)
	ts.Parent = b
	b.Parent = parent
	return b
end

local function fruitName(fruitData)
	local info = FruitUtility.getInfo(fruitData.name)
	local base = info and (info.display_name or info.name) or fruitData.name
	local name = FruitStageUtility.getDisplayName(base, fruitData.stage)
	if fruitData.tier == "Rainbow" then
		name = "Rainbow " .. name
	end
	return name
end

local function shortTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return h .. "h " .. m .. "m"
	elseif m > 0 then
		return m .. "m"
	end
	return "<1m"
end

-- real Fruit model, centered and auto-fit in a ViewportFrame
local function preview(parent, fruitData)
	local info = FruitUtility.getInfo(fruitData.name)
	local source = info and info.model and info.model ~= "" and _L.Assets.Models.Fruits:FindFirstChild(info.model)
	if not source then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = info and (info.icon or info.image) or ""
		img.Parent = parent
		return img
	end
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = Color3.fromRGB(200, 200, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	vp.Parent = parent
	local model = source:Clone()
	if model:IsA("BasePart") then
		local holder = Instance.new("Model")
		model.Parent = holder
		holder.PrimaryPart = model
		model = holder
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.PivotOffset = CFrame.new()
		end
	end
	pcall(FruitStageUtility.applyVisuals, model, fruitData.stage or 0)
	for _, d in ipairs(model:GetDescendants()) do
		if table.find(PREVIEW_CLUTTER, d.ClassName) then
			d:Destroy()
		end
	end
	-- fruits face -Z: turn them toward the camera
	model:PivotTo(CFrame.Angles(0, math.pi, 0))
	model.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vp
	vp.CurrentCamera = camera
	local boxCF, size = model:GetBoundingBox()
	local center = boxCF.Position
	local half = math.max(size.X, size.Y, 0.2) / 2
	local distance = (half * 1.18) / math.tan(math.rad(15)) + size.Z / 2
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0, distance), center)
	return vp
end

------------------------------------------------------------ build
function Daycare:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Daycare"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = _L.PlayerGui
	self.object = gui

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.Size = UDim2.fromScale(0.9, 0.78)
	main.BackgroundColor3 = CREAM
	main.Visible = false
	main.Parent = gui
	corner(main, UDim.new(0, 22))
	stroke(main, 5, WOOD)
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(760, 470)
	size.MinSize = Vector2.new(320, 250)
	size.Parent = main

	-- header
	label(main, "🌼 DAYCARE", {
		Name = "Title", Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(0.5, -20, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = WOOD,
	})
	self._capacity = label(main, "0 / 3", {
		Name = "Capacity", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -78, 0, 18),
		Size = UDim2.new(0.3, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Right,
	})
	local close = button(main, "X", RED, {
		Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(52, 52),
	})
	close.Activated:Connect(function()
		UI.Close({name = self.name})
	end)
	label(main, "Fruits here make 💎 Gems over time, even offline. They give no farming boost while they stay.", {
		Name = "Info", Position = UDim2.new(0, 20, 0, 56), Size = UDim2.new(1, -40, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(130, 100, 70),
	})

	-- slots
	local slots = Instance.new("Frame")
	slots.Name = "Slots"
	slots.BackgroundTransparency = 1
	slots.Position = UDim2.new(0, 16, 0, 88)
	slots.Size = UDim2.new(1, -32, 1, -152)
	slots.Parent = main
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = slots
	self._slots = slots

	-- footer: collect all
	local collectAll = button(main, "💎 COLLECT ALL", GEM, {
		Name = "CollectAll", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.42, 0, 0, 46),
	})
	collectAll.Activated:Connect(function()
		self:_collect(nil)
	end)
	self._collectAll = collectAll

	-- picker (choose a Fruit to add)
	local picker = Instance.new("Frame")
	picker.Name = "Picker"
	picker.BackgroundColor3 = CREAM
	picker.Size = UDim2.fromScale(1, 1)
	picker.Visible = false
	picker.ZIndex = 5
	picker.Parent = main
	corner(picker, UDim.new(0, 22))
	label(picker, "Choose a Fruit", {
		Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(0.6, -20, 0, 38), ZIndex = 6,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = WOOD,
	})
	local back = button(picker, "BACK", RED, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(96, 48), ZIndex = 6,
	})
	back.Activated:Connect(function()
		picker.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundColor3 = CREAM_DARK
	list.Position = UDim2.new(0, 16, 0, 66)
	list.Size = UDim2.new(1, -32, 1, -82)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = WOOD
	list.ZIndex = 6
	list.Parent = picker
	corner(list, UDim.new(0, 14))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(150, 172)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = list
	self._picker = picker
	self._pickerList = list
end

------------------------------------------------------------ actions (server decides everything)
local REASONS = {
	full = "Daycare is full (3 / 3).",
	already = "That Fruit is already in Daycare.",
	ownership = "You don't own that Fruit.",
	invalid = "Please wait a moment.",
}

function Daycare:_toast(text, color)
	if Notifications then
		Notifications:add({text = text, color = color or Color3.fromRGB(255, 120, 100)})
	end
end

function Daycare:_collect(uid)
	local ok, result = Network.Remote.Invoke("S_Daycare_Collect", uid)
	if ok then
		pcall(Audio.Play, {name = "Reward1"})
	elseif result == "empty" then
		self:_toast("No Gems ready yet. Come back later!", Color3.fromRGB(255, 190, 90))
	elseif REASONS[result] then
		self:_toast(REASONS[result])
	end
	self:_render()
end

function Daycare:_withdraw(uid)
	local ok, result = Network.Remote.Invoke("S_Daycare_Withdraw", uid)
	if ok then
		pcall(Audio.Play, {name = "Equip1", speed = 1.3})
	elseif REASONS[result] then
		self:_toast(REASONS[result])
	end
	self:_render()
end

function Daycare:_deposit(uid)
	local ok, result = Network.Remote.Invoke("S_Daycare_Deposit", uid)
	if ok then
		self._picker.Visible = false
		pcall(Audio.Play, {name = "Plop1"})
	else
		self:_toast(REASONS[result] or "That Fruit can't go to Daycare.")
	end
	self:_render()
end

------------------------------------------------------------ render
function Daycare:_clear(parent)
	for _, c in ipairs(parent:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function Daycare:_entries()
	local data = Data.Await()
	local list = {}
	local entries = (data:Get("fruit_daycare") or {}).entries or {}
	for uid, entry in pairs(entries) do
		local fruit = FruitUtility.getData(data, uid)
		if fruit then
			table.insert(list, {uid = uid, entry = entry, fruit = fruit})
		end
	end
	table.sort(list, function(a, b)
		return (a.entry.deposited_at or 0) < (b.entry.deposited_at or 0)
	end)
	return list
end

function Daycare:_card(index)
	local card = Instance.new("Frame")
	card.LayoutOrder = index
	card.BackgroundColor3 = CREAM_DARK
	card.Size = UDim2.new(1 / 3, -7, 1, 0)
	card.Parent = self._slots
	corner(card, UDim.new(0, 16))
	stroke(card, 3, WOOD)
	return card
end

function Daycare:_render()
	if not self.object or not self.object.Main.Visible then
		return
	end
	local entries = self:_entries()
	local capacity = FruitFarmUtility.DAYCARE_CAPACITY
	self._capacity.Text = "Capacity: " .. #entries .. " / " .. capacity
	self:_clear(self._slots)
	self._live = {}
	for i = 1, math.max(capacity, #entries) do
		local card = self:_card(i)
		local item = entries[i]
		if item then
			local info = FruitUtility.getInfo(item.fruit.name)
			local rarity = info and info.rarity or "Common"
			local icon = Instance.new("Frame")
			icon.BackgroundColor3 = CREAM
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0.03, 0)
			icon.Size = UDim2.fromScale(0.62, 0.34)
			icon.Parent = card
			corner(icon, UDim.new(0, 12))
			local aspect = Instance.new("UIAspectRatioConstraint")
			aspect.AspectRatio = 1
			aspect.Parent = icon
			preview(icon, item.fruit)
			label(card, fruitName(item.fruit), {Position = UDim2.fromScale(0.05, 0.38), Size = UDim2.fromScale(0.9, 0.08)})
			label(card, rarity, {Position = UDim2.fromScale(0.05, 0.46), Size = UDim2.fromScale(0.9, 0.06), TextColor3 = RARITY_COLOR[rarity] or WOOD_TEXT})
			label(card, "💎 " .. FruitFarmUtility.getGemRate(item.fruit) .. " Gems / hour", {Position = UDim2.fromScale(0.05, 0.53), Size = UDim2.fromScale(0.9, 0.065), TextColor3 = GEM})
			local since = label(card, "", {Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.06), TextColor3 = Color3.fromRGB(130, 100, 70)})
			local ready = label(card, "", {Position = UDim2.fromScale(0.05, 0.67), Size = UDim2.fromScale(0.9, 0.08), TextColor3 = WOOD})
			local collectBtn = button(card, "COLLECT", GREEN, {Position = UDim2.fromScale(0.05, 0.77), Size = UDim2.fromScale(0.9, 0.1)})
			local withdrawBtn = button(card, "WITHDRAW", Color3.fromRGB(190, 140, 90), {Position = UDim2.fromScale(0.05, 0.885), Size = UDim2.fromScale(0.9, 0.09)})
			local uid = item.uid
			collectBtn.Activated:Connect(function()
				self:_collect(uid)
			end)
			withdrawBtn.Activated:Connect(function()
				self:_withdraw(uid)
			end)
			table.insert(self._live, {item = item, since = since, ready = ready, collect = collectBtn})
		else
			label(card, "Empty slot", {Position = UDim2.fromScale(0.05, 0.2), Size = UDim2.fromScale(0.9, 0.1), TextColor3 = Color3.fromRGB(150, 120, 90)})
			local add = button(card, "+ ADD FRUIT", GREEN, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.8, 0.16)})
			add.Activated:Connect(function()
				self:_openPicker()
			end)
		end
	end
	self:_tick()
end

-- live numbers (1x per second while open)
function Daycare:_tick()
	local now = workspace:GetServerTimeNow()
	local total = 0
	for _, row in ipairs(self._live or {}) do
		local gems = FruitFarmUtility.getPending(row.item.entry, row.item.fruit, now)
		total += gems
		row.since.Text = "In Daycare: " .. shortTime(now - (row.item.entry.deposited_at or now))
		row.ready.Text = "Gems ready: 💎 " .. gems
		row.collect.BackgroundColor3 = if gems > 0 then GREEN else Color3.fromRGB(175, 165, 145)
	end
	self._collectAll.Visible = #(self._live or {}) > 0
	self._collectAll.Text = if total > 0 then ("💎 COLLECT ALL (" .. total .. ")") else "💎 COLLECT ALL"
	self._collectAll.BackgroundColor3 = if total > 0 then GEM else Color3.fromRGB(175, 165, 145)
end

function Daycare:_openPicker()
	local data = Data.Await()
	local list = self._pickerList
	self:_clear(list)
	local eligible = {}
	for _, fruit in ipairs(data:Get("fruits") or {}) do
		local info = FruitUtility.getInfo(fruit.name)
		if info and not info.admin_only and not fruit.daycare then
			table.insert(eligible, fruit)
		end
	end
	-- best Gem makers first
	table.sort(eligible, function(a, b)
		return FruitFarmUtility.getGemRate(a) > FruitFarmUtility.getGemRate(b)
	end)
	if #eligible == 0 then
		label(list, "No Fruits available. Hatch an Egg to get more!", {Size = UDim2.fromOffset(300, 60), ZIndex = 7})
	end
	for i, fruit in ipairs(eligible) do
		local info = FruitUtility.getInfo(fruit.name)
		local cell = Instance.new("TextButton")
		cell.Text = ""
		cell.LayoutOrder = i
		cell.BackgroundColor3 = CREAM
		cell.ZIndex = 7
		cell.Parent = list
		corner(cell, UDim.new(0, 14))
		stroke(cell, 2.5, RARITY_COLOR[info.rarity] or WOOD)
		local icon = Instance.new("Frame")
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromScale(0.15, 0.04)
		icon.Size = UDim2.fromScale(0.7, 0.55)
		icon.ZIndex = 7
		icon.Parent = cell
		local vp = preview(icon, fruit)
		vp.ZIndex = 8
		label(cell, fruitName(fruit), {Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.13), ZIndex = 8})
		label(cell, "💎 " .. FruitFarmUtility.getGemRate(fruit) .. " / hour", {Position = UDim2.fromScale(0.05, 0.74), Size = UDim2.fromScale(0.9, 0.11), TextColor3 = GEM, ZIndex = 8})
		if fruit.equipped then
			label(cell, "Equipped (will unequip)", {Position = UDim2.fromScale(0.05, 0.86), Size = UDim2.fromScale(0.9, 0.1), TextColor3 = Color3.fromRGB(70, 140, 60), ZIndex = 8})
		end
		local uid = fruit.uid
		cell.Activated:Connect(function()
			self:_deposit(uid)
		end)
	end
	self._picker.Visible = true
end

------------------------------------------------------------ lifecycle
function Daycare:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	UI = _L.Get {"Client", "Modules", "UI"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
	FruitFarmUtility = _L.Get {"Common", "Modules", "Utilities", "FruitFarmUtility"}
	self.is_open = Tracker.new(false)
end

function Daycare:_start()
	Notifications = UI.Get("Notifications")
	self:_build()
	self.is_open:Bind(function(value)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	local data = Data.Await()
	if data then
		-- redraw when the Daycare or the Fruits change (deposit / withdraw / evolve elsewhere)
		Tracker.Subscribe({data:Track("fruit_daycare"), data:Track("fruits")}, function()
			if self.object.Main.Visible and not self._picker.Visible then
				self:_render()
			end
		end)
	end
end

function Daycare:Open()
	local main = self.object.Main
	main.Visible = true
	self._picker.Visible = false
	self:_render()
	pcall(function()
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 20})
	end)
	local token = {}
	self._token = token
	task.spawn(function()
		while self._token == token and main.Visible do
			task.wait(1)
			if self._token == token and main.Visible then
				pcall(self._tick, self)
			end
		end
	end)
end

function Daycare:Close()
	self._token = nil
	self.object.Main.Visible = false
	self._picker.Visible = false
	pcall(function()
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 0})
	end)
end

return Daycare
