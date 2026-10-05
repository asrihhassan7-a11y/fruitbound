--> Items (client)
-- HOLD / GIFT / DELETE for backpack items (the server validates everything, see server Items).
--  * Items.hold(name) / Items.unhold()
--  * Items.startGift(targetPlayer?, itemName?)  -> item picker -> player picker -> confirmation
--  * Items.askDelete(name)
--  * "Gift" prompt (key G) on every other player when you have items
--  * "Holding" bar at the bottom with a Put Away button
--  * cute card when somebody gifts you something

local _L = _G._L

local Network
local BackpackUtility
local MutationUtility

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local GIFT_RANGE = 20

local rgb = Color3.fromRGB
local CREAM, BROWN, GREEN = rgb(245, 232, 200), rgb(90, 60, 30), rgb(110, 190, 80)
local RARITY_COLOR = {
	Common = rgb(200, 200, 200), Rare = rgb(80, 170, 255), Epic = rgb(190, 90, 255),
	Legendary = rgb(255, 190, 40), Mythical = rgb(255, 80, 120), Huge = rgb(80, 255, 170),
	Secret = rgb(40, 40, 40), Divine = rgb(255, 255, 255),
}

---------->
local Items = {}

local gui, data
local busy = false

local function sfx(name, props)
	local ok, SoundFX = pcall(_L.Get, {"Client", "Modules", "Controllers", "SoundFX"})
	if ok and SoundFX and SoundFX.play then
		SoundFX.play(name, props)
	end
end

local function notify(text, color)
	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		UI.Get("Notifications"):add({text = text, color = color or rgb(120, 230, 120), duration = 3})
	end)
end

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

local function label(parent, props, outline)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = rgb(255, 255, 255)
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	if outline ~= false then
		stroke(l, rgb(30, 30, 30), 1.5)
	end
	return l
end

local function button(parent, text, color, darker)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = text
	b.TextColor3 = rgb(255, 255, 255)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 10)
	stroke(b, darker, 2.5, true)
	stroke(b, rgb(30, 30, 30), 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end
Items.button = button

local function itemColor(name)
	local _, mutation = MutationUtility.split(name)
	if mutation then
		return mutation.color, mutation
	end
	return RARITY_COLOR[BackpackUtility.getRarity(name)] or RARITY_COLOR.Common, nil
end

------------------------------------------------------------ MODAL
-- one modal at a time: dimmed background + cream card with green title ribbon
local function modal(title, height)
	local old = gui:FindFirstChild("Modal")
	if old then
		old:Destroy()
	end
	local dim = Instance.new("TextButton")
	dim.Name = "Modal"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = rgb(20, 15, 10)
	dim.BackgroundTransparency = 1
	dim.ZIndex = 10
	dim.Parent = gui
	TweenService:Create(dim, TweenInfo.new(0.2), {BackgroundTransparency = 0.55}):Play()

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(360, height)
	card.BackgroundColor3 = CREAM
	card.ZIndex = 11
	card.Parent = dim
	corner(card, 18)
	stroke(card, BROWN, 4, true)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

	local ribbon = Instance.new("Frame")
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.new(0.5, 0, 0, 2)
	ribbon.Size = UDim2.fromOffset(250, 44)
	ribbon.BackgroundColor3 = GREEN
	ribbon.ZIndex = 12
	ribbon.Parent = card
	corner(ribbon, 14)
	stroke(ribbon, rgb(50, 110, 40), 3, true)
	label(ribbon, {Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6), Text = title, ZIndex = 13})

	local close = button(card, "X", rgb(240, 110, 150), rgb(150, 50, 90))
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.Size = UDim2.fromOffset(38, 38)
	close.ZIndex = 13
	local function shut()
		if dim.Parent then
			dim:Destroy()
		end
	end
	close.MouseButton1Click:Connect(shut)
	dim.MouseButton1Click:Connect(shut)
	card.Active = true
	return card, shut
end

local function setZ(root, z)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") and d.ZIndex < z then
			d.ZIndex = z
		end
	end
end

local function scrollList(card, top, bottom)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(14, top)
	list.Size = UDim2.new(1, -28, 1, -(top + bottom))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = BROWN
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 3)
	pad.PaddingRight = UDim.new(0, 3)
	pad.Parent = list
	return list
end

local function rowButton(list, order, color)
	local row = Instance.new("TextButton")
	row.Text = ""
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 50)
	row.BackgroundColor3 = rgb(255, 248, 228)
	row.AutoButtonColor = true
	row.Parent = list
	corner(row, 12)
	stroke(row, color, 2.5, true)
	return row
end

------------------------------------------------------------ CONFIRM (with amount)
-- opts: {title, text, color, max, confirmText, confirmColor, confirmDark}; callback(amount)
function Items.confirm(opts, callback)
	local max = math.max(1, opts.max or 1)
	local card, shut = modal(opts.title, if max > 1 then 250 else 200)
	label(card, {Size = UDim2.new(1, -40, 0, 56), Position = UDim2.fromOffset(20, 36), TextColor3 = rgb(95, 65, 40), Text = opts.text, TextWrapped = true}, false)

	local amount = 1
	local amountLabel
	if max > 1 then
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0)
		row.Position = UDim2.new(0.5, 0, 0, 100)
		row.Size = UDim2.fromOffset(280, 44)
		row.Parent = card
		local minus = button(row, "-", rgb(240, 150, 90), rgb(150, 80, 30))
		minus.Size = UDim2.fromOffset(44, 44)
		amountLabel = label(row, {Size = UDim2.fromOffset(90, 40), Position = UDim2.fromOffset(52, 2), TextColor3 = rgb(95, 65, 40), Text = "x1"}, false)
		local plus = button(row, "+", GREEN, rgb(50, 110, 40))
		plus.Position = UDim2.fromOffset(150, 0)
		plus.Size = UDim2.fromOffset(44, 44)
		local all = button(row, "ALL", rgb(255, 190, 40), rgb(140, 90, 10))
		all.Position = UDim2.fromOffset(204, 0)
		all.Size = UDim2.fromOffset(76, 44)
		local function set(n)
			amount = math.clamp(n, 1, max)
			amountLabel.Text = "x" .. amount
		end
		minus.MouseButton1Click:Connect(function() set(amount - 1) end)
		plus.MouseButton1Click:Connect(function() set(amount + 1) end)
		all.MouseButton1Click:Connect(function() set(max) end)
	end

	local cancel = button(card, "Cancel", rgb(190, 175, 150), rgb(110, 95, 70))
	cancel.AnchorPoint = Vector2.new(0, 1)
	cancel.Position = UDim2.new(0, 20, 1, -16)
	cancel.Size = UDim2.new(0.5, -28, 0, 50)
	local ok = button(card, opts.confirmText or "Confirm", opts.confirmColor or GREEN, opts.confirmDark or rgb(50, 110, 40))
	ok.AnchorPoint = Vector2.new(1, 1)
	ok.Position = UDim2.new(1, -20, 1, -16)
	ok.Size = UDim2.new(0.5, -28, 0, 50)
	cancel.MouseButton1Click:Connect(shut)
	ok.MouseButton1Click:Connect(function()
		shut()
		callback(amount)
	end)
	setZ(card, 12)
end

------------------------------------------------------------ PICKERS
function Items.getItems()
	local list = {}
	for name, n in pairs(data:Get("plants") or {}) do
		if n > 0 then
			table.insert(list, {name = name, count = n})
		end
	end
	table.sort(list, function(a, b)
		local _, ma = MutationUtility.split(a.name)
		local _, mb = MutationUtility.split(b.name)
		if (ma ~= nil) ~= (mb ~= nil) then
			return ma ~= nil
		end
		return a.name < b.name
	end)
	return list
end

function Items.nearbyPlayers()
	local me = _L.Player.Character and _L.Player.Character:FindFirstChild("HumanoidRootPart")
	local list = {}
	if not me then
		return list
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p ~= _L.Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - me.Position).Magnitude
			if d <= GIFT_RANGE then
				table.insert(list, {player = p, distance = d})
			end
		end
	end
	table.sort(list, function(a, b)
		return a.distance < b.distance
	end)
	return list
end

function Items.pickItem(title, callback)
	local card = modal(title, 380)
	local list = scrollList(card, 36, 14)
	local items = Items.getItems()
	if #items == 0 then
		label(card, {Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 140), TextColor3 = rgb(120, 90, 60), Text = "Your backpack is empty.\nPick some crops first!"}, false)
	end
	for i, item in ipairs(items) do
		local color, mutation = itemColor(item.name)
		local row = rowButton(list, i, color)
		label(row, {Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(12, 4), TextXAlignment = Enum.TextXAlignment.Left, Text = (if mutation then "✨ " else "") .. item.name})
		label(row, {Size = UDim2.new(1, -90, 0, 16), Position = UDim2.fromOffset(12, 29), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color, Text = if mutation then mutation.name .. " x" .. mutation.value else BackpackUtility.getRarity(item.name)})
		label(row, {AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(70, 26), Position = UDim2.new(1, -12, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = rgb(95, 65, 40), Text = "x" .. item.count}, false)
		row.MouseButton1Click:Connect(function()
			callback(item.name)
		end)
	end
	setZ(card, 12)
end

function Items.pickPlayer(itemName, callback)
	local card = modal("🎁 Gift to...", 360)
	local list = scrollList(card, 36, 14)
	local nearby = Items.nearbyPlayers()
	if #nearby == 0 then
		label(card, {Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromOffset(20, 130), TextColor3 = rgb(120, 90, 60), Text = "Nobody is nearby.\nWalk up to a friend to gift them " .. itemName .. "!", TextWrapped = true}, false)
	end
	for i, entry in ipairs(nearby) do
		local p = entry.player
		local row = rowButton(list, i, GREEN)
		row.Size = UDim2.new(1, -8, 0, 58)
		local head = Instance.new("ImageLabel")
		head.Size = UDim2.fromOffset(46, 46)
		head.Position = UDim2.fromOffset(6, 6)
		head.BackgroundColor3 = rgb(230, 215, 180)
		head.Parent = row
		corner(head, 23)
		task.spawn(function()
			local ok, img = pcall(Players.GetUserThumbnailAsync, Players, p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			if ok then
				head.Image = img
			end
		end)
		label(row, {Size = UDim2.new(1, -150, 0, 26), Position = UDim2.fromOffset(60, 6), TextXAlignment = Enum.TextXAlignment.Left, Text = p.DisplayName})
		label(row, {Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(60, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rgb(140, 110, 80), Text = "@" .. p.Name}, false)
		local pick = button(row, "🎁", rgb(255, 150, 190), rgb(160, 60, 100))
		pick.AnchorPoint = Vector2.new(1, 0.5)
		pick.Position = UDim2.new(1, -8, 0.5, 0)
		pick.Size = UDim2.fromOffset(60, 42)
		local function go()
			callback(p)
		end
		row.MouseButton1Click:Connect(go)
		pick.MouseButton1Click:Connect(go)
	end
	setZ(card, 12)
end

------------------------------------------------------------ ACTIONS
function Items.hold(name)
	if busy then
		return
	end
	busy = true
	local ok, success, result = pcall(Network.Remote.Invoke, "S_Item_Hold", name)
	busy = false
	if ok and success then
		sfx(if result then "Harvest_Pick" else "UI_Close")
	elseif ok and result == "missing" then
		notify("You don't have that item anymore.", rgb(255, 170, 60))
	end
end

function Items.unhold()
	pcall(Network.Remote.Invoke, "S_Item_Unhold")
	sfx("UI_Close")
end

function Items.askDelete(name)
	local have = (data:Get("plants") or {})[name] or 0
	if have <= 0 then
		return
	end
	Items.confirm({
		title = "🗑️ Delete",
		text = "Throw away " .. name .. "?\nThis can't be undone.",
		max = have,
		confirmText = "🗑️ Delete",
		confirmColor = rgb(230, 80, 80),
		confirmDark = rgb(120, 25, 25),
	}, function(amount)
		local ok, success, n = pcall(Network.Remote.Invoke, "S_Item_Delete", name, amount)
		if ok and success then
			sfx("UI_Close")
			notify("🗑️ Threw away " .. tostring(n) .. "x " .. name, rgb(230, 160, 120))
		end
	end)
end

local GIFT_ERRORS = {
	missing = "You don't have that item anymore.",
	target = "That player isn't here anymore.",
	far = "Get closer to them to give a gift!",
	full = "Their backpack is full!",
	cooldown = "Slow down a little!",
	self = "You can't gift yourself!",
}

local function confirmGift(target, name)
	local have = (data:Get("plants") or {})[name] or 0
	if have <= 0 then
		notify(GIFT_ERRORS.missing, rgb(255, 170, 60))
		return
	end
	Items.confirm({
		title = "🎁 Send Gift",
		text = "Give " .. name .. " to " .. target.DisplayName .. "?",
		max = have,
		confirmText = "🎁 Gift!",
		confirmColor = rgb(255, 150, 190),
		confirmDark = rgb(160, 60, 100),
	}, function(amount)
		if busy then
			return
		end
		busy = true
		local ok, success, result = pcall(Network.Remote.Invoke, "S_Item_Gift", target.UserId, name, amount)
		busy = false
		if ok and success then
			sfx("Harvest_Collect", {speed = 1.25})
			sfx("Mutation", {volume = 0.3})
			notify("🎁 You gave " .. tostring(result) .. "x " .. name .. " to " .. target.DisplayName .. "!", rgb(255, 160, 200))
		else
			notify("🎁 " .. (GIFT_ERRORS[ok and result] or "The gift didn't go through."), rgb(255, 170, 60))
		end
	end)
end

-- start the gift flow; any missing piece is asked for
function Items.startGift(target, name)
	if name and target then
		confirmGift(target, name)
	elseif name then
		Items.pickPlayer(name, function(p)
			confirmGift(p, name)
		end)
	else
		Items.pickItem("🎁 Pick a gift" .. (if target then " for " .. target.DisplayName else ""), function(itemName)
			Items.startGift(target, itemName)
		end)
	end
end

------------------------------------------------------------ HUD: holding bar
local function buildHoldBar()
	local bar = Instance.new("Frame")
	bar.Name = "HoldBar"
	-- right side, just above the Auto Collect button (same stack as the Backpack counter)
	bar.AnchorPoint = Vector2.new(1, 1)
	bar.Size = UDim2.fromOffset(300, 42)
	local HUD = _L.Get({"Client", "Modules", "Controllers", "Harvest"}).HUD
	HUD.track(bar, HUD.HOLD_Y)
	bar.BackgroundColor3 = CREAM
	bar.Visible = false
	bar.Parent = gui
	corner(bar, 25)
	local barStroke = stroke(bar, BROWN, 3, true)
	local text = label(bar, {Size = UDim2.new(1, -168, 0, 26), Position = UDim2.fromOffset(14, 12), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rgb(95, 65, 40), Text = ""}, false)
	local gift = button(bar, "🎁", rgb(255, 150, 190), rgb(160, 60, 100))
	gift.AnchorPoint = Vector2.new(1, 0.5)
	gift.Position = UDim2.new(1, -112, 0.5, 0)
	gift.Size = UDim2.fromOffset(44, 38)
	local away = button(bar, "Put away", rgb(240, 150, 90), rgb(150, 80, 30))
	away.AnchorPoint = Vector2.new(1, 0.5)
	away.Position = UDim2.new(1, -8, 0.5, 0)
	away.Size = UDim2.fromOffset(98, 38)
	away.MouseButton1Click:Connect(Items.unhold)
	gift.MouseButton1Click:Connect(function()
		local held = _L.Player:GetAttribute("HeldItem")
		if held then
			Items.startGift(nil, held)
		end
	end)

	local function update()
		local held = _L.Player:GetAttribute("HeldItem")
		if held then
			local color, mutation = itemColor(held)
			text.Text = "✋ " .. (if mutation then "✨ " else "") .. held
			barStroke.Color = if mutation then color else BROWN
			if not bar.Visible then
				bar.Visible = true
				local k = HUD.scale()
				local goal = UDim2.new(1, -HUD.MARGIN, HUD.anchorY(), HUD.HOLD_Y * k)
				bar.Position = goal + UDim2.fromOffset(340, 0)
				TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = goal}):Play()
			end
		else
			bar.Visible = false
		end
	end
	_L.Player:GetAttributeChangedSignal("HeldItem"):Connect(update)
	update()
end

------------------------------------------------------------ Gift prompts on other players
local function hasItems()
	for _, n in pairs(data:Get("plants") or {}) do
		if n > 0 then
			return true
		end
	end
	return false
end

local prompts = {}
local function addPrompt(player, character)
	if player == _L.Player then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GiftPrompt"
	prompt.ActionText = "🎁 Gift"
	prompt.ObjectText = player.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	-- shown beside the player (to the right, chest height), never on top of their name / health billboard
	prompt:SetAttribute("PromptOffset", Vector3.new(3.6, -0.3, 0))
	prompt.Enabled = hasItems()
	prompt.Parent = root
	prompts[player] = prompt
	prompt.Triggered:Connect(function()
		Items.startGift(player, _L.Player:GetAttribute("HeldItem"))
	end)
end

local function watchPlayer(player)
	if player == _L.Player then
		return
	end
	player.CharacterAdded:Connect(function(c)
		addPrompt(player, c)
	end)
	if player.Character then
		task.spawn(addPrompt, player, player.Character)
	end
end

------------------------------------------------------------ Gift received card
local function giftReceived(info)
	if typeof(info) ~= "table" then
		return
	end
	sfx(if info.rare then "Mutation_Rare" else "Mutation")
	sfx("Harvest_Collect", {speed = 1.2})
	local color = itemColor(info.name)
	local card = Instance.new("Frame")
	card.Name = "GiftCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, -120)
	card.Size = UDim2.fromOffset(380, 84)
	card.BackgroundColor3 = CREAM
	card.Parent = gui
	corner(card, 20)
	stroke(card, color, 4, true)
	local head = Instance.new("ImageLabel")
	head.Size = UDim2.fromOffset(62, 62)
	head.Position = UDim2.fromOffset(11, 11)
	head.BackgroundColor3 = rgb(255, 200, 225)
	head.Parent = card
	corner(head, 31)
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, info.fromId or 1, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok then
			head.Image = img
		end
	end)
	label(card, {Size = UDim2.new(1, -96, 0, 30), Position = UDim2.fromOffset(84, 12), TextXAlignment = Enum.TextXAlignment.Left, Text = "🎁 Gift from " .. tostring(info.from)})
	label(card, {Size = UDim2.new(1, -96, 0, 26), Position = UDim2.fromOffset(84, 46), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rgb(95, 65, 40), Text = tostring(info.amount) .. "x " .. tostring(info.name) .. " → Backpack"}, false)
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 120)}):Play()
	task.delay(4, function()
		local out = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0, -120)})
		out.Completed:Connect(function()
			card:Destroy()
		end)
		out:Play()
	end)
end

------------------------------------------------------------
function Items._init()
	Network = _L.Get {"Common", "Library", "Network"}
	BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
	MutationUtility = _L.Get {"Common", "Modules", "Utilities", "MutationUtility"}
end

function Items._start()
	Network.Remote.Fired("C_Gift_Received", giftReceived)
	task.spawn(function()
		local Data = _L.Get {"Client", "Library", "Classes", "Data"}
		data = Data.Await()

		gui = Instance.new("ScreenGui")
		gui.Name = "Items"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 8
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = _L.PlayerGui

		local ok, err = pcall(buildHoldBar)
		if not ok then
			warn("[Items] hold bar failed:", err)
		 end
		for _, p in ipairs(Players:GetPlayers()) do
			watchPlayer(p)
		end
		Players.PlayerAdded:Connect(watchPlayer)
		Players.PlayerRemoving:Connect(function(p)
			prompts[p] = nil
		end)
		data:Bind("plants", function()
			local enabled = hasItems()
			for p, prompt in pairs(prompts) do
				if prompt.Parent then
					prompt.Enabled = enabled
				else
					prompts[p] = nil
				end
			end
		end)
	end)
end

return Items
