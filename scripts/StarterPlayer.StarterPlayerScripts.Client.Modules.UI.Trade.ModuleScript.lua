--> Trade (UI, V1.1 Fruit Trading)
-- Shows the server's trade state (Server.Controllers.FruitTrade). Every button is a request:
-- add / remove a Fruit by UID, ready, confirm, cancel. The client never sends Fruit data.
-- Flow: request toast -> trade window (YOUR OFFER | THEIR OFFER) -> both READY -> FINAL TRADE
-- REVIEW (offers frozen) -> both CONFIRM -> short countdown -> server swaps the exact Fruits.
local _L = _G._L

local TweenService = game:GetService("TweenService")

local Services
local Tracker
local Data
local Network
local Audio
local Spr
local UI
local FruitUtility
local FruitStageUtility
local Notifications

local CREAM = Color3.fromRGB(255, 248, 230)
local CREAM_DARK = Color3.fromRGB(242, 228, 200)
local WOOD = Color3.fromRGB(110, 72, 38)
local WOOD_TEXT = Color3.fromRGB(90, 60, 30)
local MUTED = Color3.fromRGB(140, 115, 90)
local GREEN = Color3.fromRGB(110, 190, 80)
local BLUE = Color3.fromRGB(70, 150, 230)
local RED = Color3.fromRGB(215, 95, 80)
local GREY = Color3.fromRGB(175, 165, 145)
local GOLD = Color3.fromRGB(240, 175, 40)
local FONT = Enum.Font.FredokaOne
local RARITY_COLOR = {
	Common = Color3.fromRGB(150, 150, 150), Uncommon = Color3.fromRGB(110, 190, 110), Rare = Color3.fromRGB(70, 140, 230),
	Epic = Color3.fromRGB(165, 85, 220), Legendary = Color3.fromRGB(240, 170, 40), Mythical = Color3.fromRGB(230, 70, 110),
}
local STAGE_COLOR = {[1] = Color3.fromRGB(240, 185, 40), [2] = Color3.fromRGB(110, 210, 240), [3] = Color3.fromRGB(240, 100, 40), [4] = Color3.fromRGB(140, 90, 230), [5] = Color3.fromRGB(255, 120, 200)}
local VALUABLE = {Epic = true, Legendary = true, Mythical = true, Mythic = true, Huge = true, Secret = true, Divine = true}
local ERRORS = {
	daycare = "Fruits in Daycare can't be traded. Withdraw it first.",
	mounted = "Unmount this Fruit before trading.",
	untradeable = "This Fruit can't be traded.",
	ownership = "You don't own that Fruit anymore.",
	locked = "Offers are locked for the final review.",
	full = "You can offer up to 12 Fruits.",
	empty = "Add at least one Fruit to the trade.",
	trading = "That player is already trading.",
	you_trading = "Finish your current trade first.",
	disabled = "That player has trade requests turned off.",
	friends = "That player only accepts trades from friends.",
	expired = "That trade request expired.",
	invalid = "That didn't work. Try again.",
}

local Trade = {name = script.Name}

------------------------------------------------------------ builders
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0, 12)
	c.Parent = p
end
local function stroke(p, t, c)
	local s = Instance.new("UIStroke")
	s.Thickness = t or 3
	s.Color = c or WOOD
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
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
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	corner(b, UDim.new(0, 10))
	stroke(b, 2.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.16, 0)
	pad.PaddingBottom = UDim.new(0.16, 0)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Thickness = 1.5
	ts.Color = Color3.fromRGB(50, 35, 20)
	ts.Parent = b
	b.Parent = parent
	return b
end
local function scroller(parent, props)
	local s = Instance.new("ScrollingFrame")
	s.BackgroundColor3 = CREAM_DARK
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollBarThickness = 6
	for k, v in pairs(props or {}) do
		s[k] = v
	end
	s.Parent = parent
	corner(s, UDim.new(0, 10))
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = s
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(104, 128)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = s
	return s
end
local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end
local function notify(text, color)
	pcall(function()
		Notifications:add({text = text, color = color or Color3.fromRGB(150, 210, 255)})
	end)
end
local function play(name)
	pcall(Audio.Play, {name = name})
end
local function request(remote, ...)
	local ok, success, err, extra = pcall(Network.Remote.Invoke, remote, ...)
	if not ok then
		notify("That didn't work. Try again.", RED)
		return false
	end
	if not success and err and err ~= "busy" then
		if err == "cooldown" then
			notify("Wait " .. tostring(extra or "a few") .. "s before asking this player again.", Color3.fromRGB(255, 170, 90))
		else
			notify(ERRORS[err] or "That didn't work. Try again.", Color3.fromRGB(255, 170, 90))
		end
	end
	return success, err
end

-- a Fruit card: icon, name (with stage prefix), rarity, level and GOLDEN / RAINBOW badges
local function fruitCard(parent, v, order, onClick)
	local card = Instance.new("TextButton")
	card.Text = ""
	card.AutoButtonColor = onClick ~= nil
	card.LayoutOrder = order
	card.BackgroundColor3 = CREAM
	card.Parent = parent
	corner(card, UDim.new(0, 10))
	stroke(card, if (v.stage or 0) >= 1 then 3.5 else 2.5, if (v.stage or 0) >= 1 then STAGE_COLOR[math.min(v.stage, 5)] else (RARITY_COLOR[v.rarity] or WOOD))
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Position = UDim2.fromScale(0.2, 0.04)
	img.Size = UDim2.fromScale(0.6, 0.42)
	img.ScaleType = Enum.ScaleType.Fit
	img.Image = v.image or ""
	img.Parent = card
	label(card, v.display or v.name, {Position = UDim2.fromScale(0.04, 0.47), Size = UDim2.fromScale(0.92, 0.15)})
	label(card, (v.rarity or "") .. "  Lv " .. tostring(v.level or 1), {Position = UDim2.fromScale(0.04, 0.62), Size = UDim2.fromScale(0.92, 0.11), TextColor3 = RARITY_COLOR[v.rarity] or MUTED})
	local badges = {}
	if (v.stage or 0) >= 1 then
		local stageName = ({"GOLDEN", "CRYSTAL", "MAGMA", "GALAXY", "DIVINE"})[math.min(v.stage, 5)]
		table.insert(badges, {stageName, STAGE_COLOR[math.min(v.stage, 5)]})
	end
	if v.tier == "Rainbow" then
		table.insert(badges, {"RAINBOW", Color3.fromRGB(230, 80, 160)})
	end
	if v.equipped then
		table.insert(badges, {"EQUIPPED", Color3.fromRGB(90, 150, 90)})
	end
	for i, b in ipairs(badges) do
		local tag = label(card, b[1], {Position = UDim2.new(0.06, 0, 0.74 + (i - 1) * 0.12, 0), Size = UDim2.fromScale(0.88, 0.11), TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BackgroundColor3 = b[2]})
		corner(tag, UDim.new(0, 6))
		if b[1] == "RAINBOW" then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 70)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 110, 255))})
			g.Parent = tag
		end
	end
	if onClick then
		card.Activated:Connect(onClick)
	end
	return card
end

------------------------------------------------------------ build
function Trade:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FruitTrade"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 7
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = _L.PlayerGui
	self.gui = gui

	-- request toast (top centre, not a full menu)
	local toast = Instance.new("Frame")
	toast.Name = "Request"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 80)
	toast.Size = UDim2.new(0.5, 0, 0, 96)
	toast.BackgroundColor3 = CREAM
	toast.Visible = false
	toast.Parent = gui
	corner(toast, UDim.new(0, 16))
	stroke(toast, 4)
	local tcap = Instance.new("UISizeConstraint")
	tcap.MinSize = Vector2.new(300, 96)
	tcap.MaxSize = Vector2.new(520, 104)
	tcap.Parent = toast
	self._toastText = label(toast, "", {Position = UDim2.fromScale(0.04, 0.06), Size = UDim2.fromScale(0.92, 0.42)})
	self._toastAccept = button(toast, "ACCEPT", GREEN, {Position = UDim2.fromScale(0.04, 0.54), Size = UDim2.fromScale(0.44, 0.38)})
	self._toastDecline = button(toast, "DECLINE", RED, {Position = UDim2.fromScale(0.52, 0.54), Size = UDim2.fromScale(0.44, 0.38)})
	self._toast = toast

	-- "back to trade" pill, shown while a trade is open but its window is hidden
	local resume = button(gui, "🤝 BACK TO TRADE", BLUE, {Name = "Resume", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(240, 48), Visible = false})
	resume.Activated:Connect(function()
		if self._state then
			UI.Open({name = self.name})
		end
	end)
	self._resume = resume

	-- trade window
	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.52)
	main.Size = UDim2.fromScale(0.94, 0.8)
	main.BackgroundColor3 = CREAM
	main.Visible = false
	main.Parent = gui
	corner(main, UDim.new(0, 22))
	stroke(main, 5)
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(880, 540)
	cap.MinSize = Vector2.new(340, 300)
	cap.Parent = main
	self._main = main
	self._title = label(main, "TRADE", {Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(1, -32, 0, 34), TextColor3 = WOOD})
	self._warn = label(main, "", {Position = UDim2.new(0, 16, 0, 42), Size = UDim2.new(1, -32, 0, 22), TextColor3 = Color3.fromRGB(200, 110, 40)})
	label(main, "YOUR OFFER  (tap a Fruit to remove)", {Position = UDim2.new(0, 16, 0, 66), Size = UDim2.new(0.5, -24, 0, 22), TextXAlignment = Enum.TextXAlignment.Left})
	self._theirTitle = label(main, "THEIR OFFER", {Position = UDim2.new(0.5, 8, 0, 66), Size = UDim2.new(0.5, -24, 0, 22), TextXAlignment = Enum.TextXAlignment.Left})
	self._mine = scroller(main, {Position = UDim2.new(0, 16, 0, 92), Size = UDim2.new(0.5, -24, 1, -200)})
	self._theirs = scroller(main, {Position = UDim2.new(0.5, 8, 0, 92), Size = UDim2.new(0.5, -24, 1, -200)})
	self._myStatus = label(main, "", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -66), Size = UDim2.new(0.5, -24, 0, 26)})
	self._theirStatus = label(main, "", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 8, 1, -66), Size = UDim2.new(0.5, -24, 0, 26)})
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 16, 1, -12)
	bar.Size = UDim2.new(1, -32, 0, 50)
	bar.Parent = main
	self._add = button(bar, "+ ADD FRUIT", BLUE, {Size = UDim2.new(0.32, -6, 1, 0)})
	self._ready = button(bar, "READY", GREEN, {Position = UDim2.new(0.34, 0, 0, 0), Size = UDim2.new(0.32, -6, 1, 0)})
	self._cancel = button(bar, "CANCEL", RED, {Position = UDim2.new(0.68, 0, 0, 0), Size = UDim2.new(0.32, 0, 1, 0)})

	-- Fruit picker
	local picker = Instance.new("Frame")
	picker.Name = "Picker"
	picker.Size = UDim2.fromScale(1, 1)
	picker.BackgroundColor3 = CREAM
	picker.Visible = false
	picker.ZIndex = 5
	picker.Parent = main
	corner(picker, UDim.new(0, 22))
	label(picker, "Choose a Fruit to offer", {Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(0.6, 0, 0, 32), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6})
	local back = button(picker, "BACK", GREY, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(100, 40), ZIndex = 6})
	back.Activated:Connect(function()
		picker.Visible = false
	end)
	local search = Instance.new("TextBox")
	search.PlaceholderText = "Search..."
	search.Text = ""
	search.ClearTextOnFocus = false
	search.Font = FONT
	search.TextScaled = true
	search.TextColor3 = WOOD_TEXT
	search.BackgroundColor3 = Color3.new(1, 1, 1)
	search.Position = UDim2.new(0, 16, 0, 52)
	search.Size = UDim2.new(0.34, 0, 0, 36)
	search.ZIndex = 6
	search.Parent = picker
	corner(search, UDim.new(0, 8))
	stroke(search, 2)
	self._search = search
	self._filters = {}
	for i, f in ipairs({{"all", "All"}, {"rare", "Rare+"}, {"golden", "Golden"}, {"rainbow", "Rainbow"}}) do
		local b = button(picker, f[2], GREY, {Position = UDim2.new(0.36 + (i - 1) * 0.155, 0, 0, 52), Size = UDim2.new(0.145, 0, 0, 36), ZIndex = 6})
		b.Activated:Connect(function()
			self._filter = f[1]
			self:_renderPicker()
		end)
		self._filters[f[1]] = b
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		if picker.Visible then
			self:_renderPicker()
		end
	end)
	self._pickList = scroller(picker, {Position = UDim2.new(0, 16, 0, 98), Size = UDim2.new(1, -32, 1, -112), ZIndex = 6})
	self._picker = picker

	-- final review
	local review = Instance.new("Frame")
	review.Name = "Review"
	review.Size = UDim2.fromScale(1, 1)
	review.BackgroundColor3 = CREAM
	review.Visible = false
	review.ZIndex = 8
	review.Parent = main
	corner(review, UDim.new(0, 22))
	label(review, "FINAL TRADE REVIEW", {Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(1, -32, 0, 34), TextColor3 = WOOD, ZIndex = 9})
	self._reviewWarn = label(review, "", {Position = UDim2.new(0, 16, 0, 42), Size = UDim2.new(1, -32, 0, 24), TextColor3 = Color3.fromRGB(200, 90, 40), ZIndex = 9})
	label(review, "YOU GIVE", {Position = UDim2.new(0, 16, 0, 68), Size = UDim2.new(0.5, -24, 0, 22), ZIndex = 9})
	label(review, "YOU RECEIVE", {Position = UDim2.new(0.5, 8, 0, 68), Size = UDim2.new(0.5, -24, 0, 22), ZIndex = 9})
	self._give = scroller(review, {Position = UDim2.new(0, 16, 0, 94), Size = UDim2.new(0.5, -24, 1, -200), ZIndex = 9})
	self._get = scroller(review, {Position = UDim2.new(0.5, 8, 0, 94), Size = UDim2.new(0.5, -24, 1, -200), ZIndex = 9})
	self._reviewStatus = label(review, "", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -66), Size = UDim2.new(1, -32, 0, 28), ZIndex = 9})
	local rbar = Instance.new("Frame")
	rbar.BackgroundTransparency = 1
	rbar.AnchorPoint = Vector2.new(0, 1)
	rbar.Position = UDim2.new(0, 16, 1, -12)
	rbar.Size = UDim2.new(1, -32, 0, 50)
	rbar.ZIndex = 9
	rbar.Parent = review
	self._confirm = button(rbar, "CONFIRM TRADE", GREEN, {Size = UDim2.new(0.49, -4, 1, 0), ZIndex = 10})
	self._back = button(rbar, "BACK", GREY, {Position = UDim2.new(0.51, 0, 0, 0), Size = UDim2.new(0.49, 0, 1, 0), ZIndex = 10})
	self._review = review

	-- buttons -> server requests
	self._add.Activated:Connect(function()
		if self._state and self._state.state == "OPEN" then
			self._filter = self._filter or "all"
			self:_renderPicker()
			self._picker.Visible = true
		end
	end)
	self._ready.Activated:Connect(function()
		if self._state then
			request("S_FTrade_Ready", not self._state.me.ready)
		end
	end)
	self._cancel.Activated:Connect(function()
		request("S_FTrade_Cancel")
	end)
	self._confirm.Activated:Connect(function()
		request("S_FTrade_Confirm")
	end)
	self._back.Activated:Connect(function()
		request("S_FTrade_Ready", false)
	end)
end

------------------------------------------------------------ render
local function summary(give, get)
	local lines = {}
	if #get == 0 and #give > 0 then
		table.insert(lines, "⚠ You are receiving NOTHING in return.")
	elseif #give == 0 and #get > 0 then
		table.insert(lines, "This is a gift to you: you give nothing.")
	elseif #give > 0 then
		table.insert(lines, "You give " .. #give .. " Fruit" .. (#give == 1 and "" or "s") .. ", you receive " .. #get .. ".")
	end
	for _, v in ipairs(give) do
		if (v.stage or 0) >= 1 or v.tier == "Rainbow" or VALUABLE[v.rarity] then
			table.insert(lines, "Rare Fruit involved - check the trade carefully.")
			break
		end
	end
	if #lines < 2 then
		for _, v in ipairs(get) do
			if (v.stage or 0) >= 1 or v.tier == "Rainbow" or VALUABLE[v.rarity] then
				table.insert(lines, "Rare Fruit involved - check the trade carefully.")
				break
			end
		end
	end
	return table.concat(lines, "  ")
end

function Trade:_render()
	local s = self._state
	if not s then
		return
	end
	self._title.Text = "🤝 TRADE with " .. s.them.name
	self._theirTitle.Text = string.upper(s.them.name) .. "'S OFFER"
	clear(self._mine)
	clear(self._theirs)
	for i, v in ipairs(s.me.offer) do
		local uid = v.uid
		fruitCard(self._mine, v, i, function()
			if self._state and self._state.state == "OPEN" then
				request("S_FTrade_Remove", uid)
			end
		end)
	end
	for i, v in ipairs(s.them.offer) do
		fruitCard(self._theirs, v, i)
	end
	self._warn.Text = summary(s.me.offer, s.them.offer)
	self._myStatus.Text = "YOU: " .. (if s.me.ready then "READY ✓" else "NOT READY")
	self._myStatus.TextColor3 = if s.me.ready then GREEN else MUTED
	self._theirStatus.Text = string.upper(s.them.name) .. ": " .. (if s.them.ready then "READY ✓" else "NOT READY")
	self._theirStatus.TextColor3 = if s.them.ready then GREEN else MUTED
	self._ready.Text = if s.me.ready then "NOT READY" else "READY"
	self._ready.BackgroundColor3 = if s.me.ready then GREY else GREEN
	self._add.BackgroundColor3 = if s.state == "OPEN" then BLUE else GREY
	-- final review
	local reviewing = s.state == "LOCKED" or s.state == "COMPLETING"
	self._review.Visible = reviewing
	if reviewing then
		self._picker.Visible = false
		clear(self._give)
		clear(self._get)
		for i, v in ipairs(s.me.offer) do
			fruitCard(self._give, v, i)
		end
		for i, v in ipairs(s.them.offer) do
			fruitCard(self._get, v, i)
		end
		self._reviewWarn.Text = summary(s.me.offer, s.them.offer)
		self._confirm.Text = if s.me.confirmed then "CONFIRMED ✓" else "CONFIRM TRADE"
		self._confirm.BackgroundColor3 = if s.me.confirmed then GREY else GREEN
	end
	self:_tickReview()
end

function Trade:_tickReview()
	local s = self._state
	if not s or not self._review.Visible then
		return
	end
	if s.countdownEnd then
		local left = math.max(0, math.ceil(s.countdownEnd - workspace:GetServerTimeNow()))
		self._reviewStatus.Text = "Both confirmed. Trading in " .. left .. "...  (press BACK to stop)"
		self._reviewStatus.TextColor3 = GREEN
		if left ~= self._lastTick then
			self._lastTick = left
			play("Tick1")
		end
	elseif s.me.confirmed then
		self._reviewStatus.Text = "Waiting for " .. s.them.name .. " to confirm..."
		self._reviewStatus.TextColor3 = MUTED
	else
		self._reviewStatus.Text = if s.them.confirmed then (s.them.name .. " confirmed. Check everything, then CONFIRM.") else "Check both lists, then press CONFIRM TRADE."
		self._reviewStatus.TextColor3 = WOOD_TEXT
	end
end

function Trade:_renderPicker()
	clear(self._pickList)
	for id, b in pairs(self._filters) do
		b.BackgroundColor3 = if id == (self._filter or "all") then BLUE else GREY
	end
	local data = Data.Await()
	local offered = {}
	for _, v in ipairs(self._state and self._state.me.offer or {}) do
		offered[v.uid] = true
	end
	local query = string.lower(self._search.Text or "")
	local mounted = _L.Player:GetAttribute("MountedFruit")
	local list = {}
	for _, f in ipairs(data and data:Get("fruits") or {}) do
		local info = FruitUtility.getInfo(f.name)
		if info and not info.admin_only and not f.daycare and not offered[f.uid] and f.uid ~= mounted then
			local stage = tonumber(f.stage) or 0
			local display = FruitStageUtility.getDisplayName(info.display_name or info.name, stage)
			local rare = VALUABLE[info.rarity] or info.rarity == "Rare"
			local ok = (query == "" or string.find(string.lower(display), query, 1, true) ~= nil)
				and (self._filter == "all" or (self._filter == "rare" and rare) or (self._filter == "golden" and stage >= 1) or (self._filter == "rainbow" and f.tier == "Rainbow"))
			if ok then
				table.insert(list, {uid = f.uid, name = f.name, display = display, rarity = info.rarity, image = info.image, level = f.level, stage = stage, tier = f.tier, equipped = f.equipped})
			end
		end
	end
	if #list == 0 then
		label(self._pickList, "No tradeable Fruits here. (Daycare and mounted Fruits can't be traded.)", {LayoutOrder = 1, ZIndex = 7, TextWrapped = true})
	end
	for i, v in ipairs(list) do
		local uid = v.uid
		local card = fruitCard(self._pickList, v, i, function()
			local ok = request("S_FTrade_Add", uid)
			if ok then
				play("Plop1")
				self._picker.Visible = false
			end
		end)
		card.ZIndex = 7
		for _, d in ipairs(card:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 8
			end
		end
	end
end

------------------------------------------------------------ lifecycle
function Trade:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	UI = _L.Get {"Client", "Modules", "UI"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
	self.is_open = Tracker.new(false)
end

function Trade:_start()
	Notifications = UI.Get("Notifications")
	self:_build()
	self.is_open:Bind(function(value)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)

	-- incoming request: ACCEPT / DECLINE with a countdown
	Network.Remote.Fired("C_FTrade_Request", function(req)
		if typeof(req) ~= "table" then
			return
		end
		self._requestId = req.id
		self._toast.Visible = true
		play("Ding1")
		local id = req.id
		local endsAt = os.clock() + (req.seconds or 15)
		task.spawn(function()
			while self._requestId == id and os.clock() < endsAt do
				self._toastText.Text = tostring(req.name) .. " wants to trade.  (" .. math.ceil(endsAt - os.clock()) .. "s)"
				task.wait(0.25)
			end
			if self._requestId == id then
				self._toast.Visible = false
				self._requestId = nil
			end
		end)
	end)
	Network.Remote.Fired("C_FTrade_RequestClosed", function(info)
		if typeof(info) == "table" and info.id == self._requestId then
			self._toast.Visible = false
			self._requestId = nil
		end
	end)
	self._toastAccept.Activated:Connect(function()
		local id = self._requestId
		self._requestId = nil
		self._toast.Visible = false
		if id then
			request("S_FTrade_Respond", id, true)
		end
	end)
	self._toastDecline.Activated:Connect(function()
		local id = self._requestId
		self._requestId = nil
		self._toast.Visible = false
		if id then
			request("S_FTrade_Respond", id, false)
		end
	end)

	-- the server's trade state
	Network.Remote.Fired("C_FTrade_State", function(state)
		if typeof(state) ~= "table" then
			return
		end
		local before = self._state
		self._state = state
		if not self._main.Visible then
			UI.Open({name = self.name})
		end
		-- feedback: ready reset after an offer change, both ready
		if before and before.id == state.id then
			if (before.me.ready or before.them.ready) and not state.me.ready and not state.them.ready and state.state == "OPEN" then
				notify("Offer changed - READY was reset for both players.", Color3.fromRGB(255, 190, 90))
			end
			if state.state == "LOCKED" and before.state == "OPEN" then
				play("Success1")
			end
		end
		self:_render()
	end)
	Network.Remote.Fired("C_FTrade_Closed", function(info)
		if typeof(info) ~= "table" or not self._state or info.id ~= self._state.id then
			return
		end
		self._state = nil
		self._resume.Visible = false
		UI.Close({name = self.name})
		if info.completed then
			notify("✅ Trade Successful!", Color3.fromRGB(110, 220, 110))
			play("TradeCompleted1")
		else
			local why = ({left = " (the other player left)", reset = " (a player reset)", cancelled = "", error = " (server error, nothing changed)"})[info.reason] or ""
			notify("Trade Cancelled." .. why, Color3.fromRGB(255, 160, 90))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			if self._review and self._review.Visible then
				pcall(self._tickReview, self)
			end
		end
	end)
end

function Trade:Open()
	self._resume.Visible = false
	self._main.Visible = true
	self._picker.Visible = false
	self:_render()
	pcall(function()
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 14})
	end)
end

function Trade:Close()
	self._main.Visible = false
	self._picker.Visible = false
	self._review.Visible = false
	pcall(function()
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 0})
	end)
	-- another menu or pop-up took the screen: the trade keeps going on the server, so offer a
	-- way back (only CANCEL, leaving, a reset or completing ends a trade)
	self._resume.Visible = self._state ~= nil
end

return Trade
