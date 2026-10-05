--> Backpack (client)
-- Picked plants go to your backpack instead of giving Coins right away.
--  * Backpack counter on the right (click it to look inside)
--  * Gardener NPCs (tag "Gardener", prompt "SellPrompt") buy your plants for Coins
--  * Keep plants to feed your fruits (Fruits menu > Feed)

local _L = _G._L

local Network
local Audio
local NumberUtility
local BackpackUtility
local Plants

local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local SELL_DISTANCE = 20

local RARITY_COLOR = {
	Common = Color3.fromRGB(200, 200, 200), Rare = Color3.fromRGB(80, 170, 255), Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40), Mythical = Color3.fromRGB(255, 80, 120), Huge = Color3.fromRGB(80, 255, 170),
	Secret = Color3.fromRGB(40, 40, 40), Divine = Color3.fromRGB(255, 255, 255),
}
local RARITY_ORDER = {Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5, Huge = 6, Secret = 7, Divine = 8}

---------->
local Backpack = {}

local function short(n)
	local ok, s = pcall(NumberUtility.short, n)
	return if ok then s else tostring(math.floor(n))
end

local function notify(text, color)
	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		UI.Get("Notifications"):add({text = text, color = color or Color3.fromRGB(120, 230, 120), duration = 3})
	end)
end

local function nearGardener()
	local character = _L.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, npc in ipairs(CollectionService:GetTagged("Gardener")) do
		local ok, pivot = pcall(npc.GetPivot, npc)
		if ok and (pivot.Position - root.Position).Magnitude < SELL_DISTANCE then
			return true
		end
	end
	return false
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, border)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = parent
	return s
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	stroke(l, Color3.fromRGB(30, 30, 30), 1.5)
	return l
end

local function button(parent, text, color, darker)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = text
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	stroke(b, darker, 2.5, true)
	stroke(b, Color3.fromRGB(30, 30, 30), 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end

function Backpack._build(data)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Backpack"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.Parent = _L.PlayerGui

	-- COUNTER: a small inventory indicator at the bottom of the right-side stack
	-- "🧺 433 / 2000" + a thin fill line + a FULL badge. Click to open the backpack.
	local HUD = _L.Get({"Client", "Modules", "Controllers", "Harvest"}).HUD
	local counter = Instance.new("TextButton")
	counter.Name = "Counter"
	counter.Text = ""
	counter.AnchorPoint = Vector2.new(1, 1)
	counter.Size = UDim2.fromOffset(HUD.WIDTH, HUD.BACKPACK_H)
	counter.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
	counter.AutoButtonColor = false
	counter.ClipsDescendants = false
	counter.Parent = gui
	corner(counter, 12)
	local counterStroke = stroke(counter, Color3.fromRGB(90, 60, 30), 2.5, true)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -4)
	track.Size = UDim2.new(1, -20, 0, 4)
	track.BackgroundColor3 = Color3.fromRGB(230, 215, 185)
	track.BorderSizePixel = 0
	track.Parent = counter
	corner(track, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(110, 200, 80)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	corner(fill, 2)
	local counterText = label(counter, {Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 5), ZIndex = 2, TextColor3 = Color3.fromRGB(95, 65, 40), Text = "🧺 0 / 150"})
	local cts = counterText:FindFirstChildOfClass("UIStroke")
	if cts then
		cts:Destroy()
	end
	local fullBadge = Instance.new("TextLabel")
	fullBadge.Name = "FullBadge"
	fullBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	fullBadge.Position = UDim2.new(0, 6, 0, 2)
	fullBadge.Size = UDim2.fromOffset(40, 18)
	fullBadge.BackgroundColor3 = Color3.fromRGB(235, 80, 70)
	fullBadge.Font = Enum.Font.FredokaOne
	fullBadge.TextScaled = true
	fullBadge.TextColor3 = Color3.new(1, 1, 1)
	fullBadge.Text = "FULL"
	fullBadge.Visible = false
	fullBadge.ZIndex = 3
	fullBadge.Parent = counter
	corner(fullBadge, 9)
	local fbp = Instance.new("UIPadding", fullBadge)
	fbp.PaddingTop = UDim.new(0, 2)
	fbp.PaddingBottom = UDim.new(0, 2)
	HUD.track(counter, 0)
	counter.Visible = false

	-- 💰 SELL shortcut: teleports to the existing Crop Market seller (server-side fixed safe spot).
	-- Selling itself is unchanged: you still sell at the Crop Buyer NPC.
	local sellBtn = Instance.new("TextButton")
	sellBtn.Name = "SellShortcut"
	sellBtn.AnchorPoint = Vector2.new(1, 0.5)
	sellBtn.Position = UDim2.new(0, -6, 0.5, 0)
	sellBtn.Size = UDim2.fromOffset(78, 38)
	sellBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	sellBtn.AutoButtonColor = true
	sellBtn.Font = Enum.Font.FredokaOne
	sellBtn.TextScaled = true
	sellBtn.TextColor3 = Color3.fromRGB(95, 60, 20)
	sellBtn.Text = "💰 SELL"
	sellBtn.Parent = counter
	corner(sellBtn, 12)
	local sbs = Instance.new("UIStroke")
	sbs.Color = Color3.fromRGB(150, 100, 30)
	sbs.Thickness = 2
	sbs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sbs.Parent = sellBtn
	local sbp = Instance.new("UIPadding")
	sbp.PaddingTop = UDim.new(0, 7)
	sbp.PaddingBottom = UDim.new(0, 7)
	sbp.PaddingLeft = UDim.new(0, 6)
	sbp.PaddingRight = UDim.new(0, 6)
	sbp.Parent = sellBtn
	local sellBusy = false
	local function goSell()
		if sellBusy then
			return
		end
		sellBusy = true
		local ok = _L.Get({"Common", "Library", "Network"}).Remote.Invoke("S_Farm_Teleport", "crop_market")
		if ok then
			-- tiny puff where you land
			local root = _L.Player.Character and _L.Player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local att = Instance.new("Attachment")
				att.Parent = root
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
				e.Size = NumberSequence.new(0.5, 0)
				e.Lifetime = NumberRange.new(0.4, 0.6)
				e.Speed = NumberRange.new(4, 6)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Enabled = false
				e.Parent = att
				e:Emit(10)
				game:GetService("Debris"):AddItem(att, 1)
			end
		end
		task.wait(1)
		sellBusy = false
	end
	sellBtn.MouseButton1Click:Connect(goSell)
	-- controller shortcut: L2
	game:GetService("ContextActionService"):BindAction("FB_SellTeleport", function(_, state)
		if state == Enum.UserInputState.Begin then
			goSell()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonL2)
	-- hidden while you're already at the seller
	task.spawn(function()
		while sellBtn.Parent do
			sellBtn.Visible = not nearGardener()
			task.wait(0.5)
		end
	end)

	-- WINDOW
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(460, 400)
	window.BackgroundColor3 = Color3.fromRGB(245, 232, 200)
	window.Visible = false
	window.Parent = gui
	corner(window, 16)
	stroke(window, Color3.fromRGB(90, 60, 30), 4, true)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 400)
	sizeLimit.Parent = window
	local aspect = Instance.new("UIScale")
	aspect.Parent = window
	local function applyWindowScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local topLeftInset, bottomRightInset = game:GetService("GuiService"):GetGuiInset()
		local usableViewport = viewport - topLeftInset - bottomRightInset
		aspect.Scale = math.min(1, (usableViewport.X - 24) / 460, (usableViewport.Y - 24) / 400)
	end
	applyWindowScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyWindowScale)
	end

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundColor3 = Color3.fromRGB(240, 180, 50)
	header.Parent = window
	corner(header, 16)
	label(header, {Size = UDim2.new(1, -80, 0, 34), Position = UDim2.fromOffset(16, 4), TextXAlignment = Enum.TextXAlignment.Left, Text = "💰 Crop Seller"})
	local subtitle = label(header, {Size = UDim2.new(1, -80, 0, 16), Position = UDim2.fromOffset(16, 37), TextXAlignment = Enum.TextXAlignment.Left, Text = ""})
	local close = button(header, "X", Color3.fromRGB(230, 70, 70), Color3.fromRGB(120, 25, 25))
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0.5, 0)
	close.Size = UDim2.fromOffset(40, 40)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 66)
	list.Size = UDim2.new(1, -24, 1, -140)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local empty = label(window, {Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 140), TextColor3 = Color3.fromRGB(120, 90, 60), Text = "Your backpack is empty.\nClick plants to pick them!"})
	empty:FindFirstChildOfClass("UIStroke"):Destroy()

	local footer = Instance.new("Frame")
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 12, 1, -10)
	footer.Size = UDim2.new(1, -24, 0, 54)
	footer.BackgroundTransparency = 1
	footer.Parent = window
	local totalText = label(footer, {Size = UDim2.new(0.5, 0, 0, 26), Position = UDim2.fromOffset(0, 2), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 215, 60), Text = "Worth: 0"})
	local hint = label(footer, {Size = UDim2.new(0.55, 0, 0, 18), Position = UDim2.fromOffset(0, 32), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(120, 90, 60), Text = ""})
	hint:FindFirstChildOfClass("UIStroke"):Destroy()
	local sellAll = button(footer, "💰 SELL ALL", Color3.fromRGB(255, 190, 40), Color3.fromRGB(140, 90, 10))
	sellAll.AnchorPoint = Vector2.new(1, 0)
	sellAll.Position = UDim2.new(1, 0, 0, 2)
	sellAll.Size = UDim2.new(0.42, 0, 0, 48)

	local selling = false
	local refresh

	local function doSell(plantName)
		if selling then
			return
		end
		if not nearGardener() then
			notify("Sell crops at the Village Crop Seller", Color3.fromRGB(255, 170, 60))
			return
		end
		selling = true
		local ok, success, total, sold = pcall(Network.Remote.Invoke, "S_Backpack_Sell", plantName)
		selling = false
		if ok and success then
			if Audio then
				Audio.Play({name = "Sell_Coins"})
				task.delay(0.12, function() Audio.Play({name = "Coin"}) end)
			end
			notify("💰 Sold " .. short(sold or 0) .. " plants for " .. short(total or 0) .. " Coins!", Color3.fromRGB(255, 215, 60))
			pcall(function()
				local UI = _L.Get {"Client", "Modules", "UI"}
				UI.Get("HUD"):StatPopup({stat_name = "Strength", stat_value = total})
			end)
		elseif ok and total == "far" then
			notify("Sell crops at the Village Crop Seller", Color3.fromRGB(255, 170, 60))
		end
	end

	refresh = function()
		local count = BackpackUtility.getCount(data)
		local capacity = BackpackUtility.getCapacity(data)
		local full = count >= capacity
		counterText.Text = "🧺 " .. short(count) .. " / " .. short(capacity)
		TweenService:Create(fill, TweenInfo.new(0.2), {Size = UDim2.fromScale(math.clamp(count / capacity, 0, 1), 1)}):Play()
		fill.BackgroundColor3 = if full then Color3.fromRGB(235, 90, 60) elseif count / capacity > 0.8 then Color3.fromRGB(240, 190, 50) else Color3.fromRGB(110, 200, 80)
		counterStroke.Color = if full then Color3.fromRGB(200, 60, 40) else Color3.fromRGB(90, 60, 30)
		if full and not fullBadge.Visible then
			-- small pop when the backpack becomes full
			fullBadge.Size = UDim2.fromOffset(20, 9)
			TweenService:Create(fullBadge, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(40, 18)}):Play()
		end
		fullBadge.Visible = full

		if not window.Visible then
			return
		end

		local canSell = nearGardener()
		subtitle.Text = "✋ Hold  •  🎁 Gift  •  🗑️ Delete  •  💰 Sell"
		hint.Text = if canSell and count > 0 then "Ready to sell!" elseif count == 0 then "" else "Visit the 💰 Crop Seller in the Village to sell."
		sellAll.BackgroundColor3 = if canSell and count > 0 then Color3.fromRGB(255, 190, 40) else Color3.fromRGB(150, 150, 150)

		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end

		local items = {}
		local totalWorth = 0
		for name, n in pairs(data:Get("plants") or {}) do
			if n > 0 then
				local worth = BackpackUtility.getWorth(data, name, n, nil)
				totalWorth += worth
				table.insert(items, {name = name, count = n, worth = worth, rarity = BackpackUtility.getRarity(name)})
			end
		end
		table.sort(items, function(a, b)
			if RARITY_ORDER[a.rarity] ~= RARITY_ORDER[b.rarity] then
				return (RARITY_ORDER[a.rarity] or 0) > (RARITY_ORDER[b.rarity] or 0)
			end
			return a.name < b.name
		end)
		empty.Visible = #items == 0
		totalText.Text = "💰 Worth: " .. short(totalWorth)

		local Items = _L.Get {"Client", "Modules", "Controllers", "Items"}
		local MutationUtility = _L.Get {"Common", "Modules", "Utilities", "MutationUtility"}
		local held = _L.Player:GetAttribute("HeldItem")
		for i, item in ipairs(items) do
			local _, mutation = MutationUtility.split(item.name)
			local color = if mutation then mutation.color else (RARITY_COLOR[item.rarity] or Color3.fromRGB(200, 200, 200))
			local isHeld = held == item.name
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.Size = UDim2.new(1, -8, 0, 50)
			row.BackgroundColor3 = if isHeld then Color3.fromRGB(225, 250, 210) else Color3.fromRGB(255, 248, 228)
			row.Parent = list
			corner(row, 10)
			stroke(row, color, 2.5, true)
			label(row, {Size = UDim2.new(1, -196, 0, 22), Position = UDim2.fromOffset(10, 4), TextXAlignment = Enum.TextXAlignment.Left, Text = (if mutation then "✨ " else "") .. item.name .. "  x" .. short(item.count)})
			label(row, {Size = UDim2.new(1, -196, 0, 16), Position = UDim2.fromOffset(10, 29), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color, Text = (if isHeld then "✋ Holding  •  " elseif mutation then mutation.name .. " x" .. mutation.value .. "  •  " else item.rarity .. "  •  ") .. "💰 " .. short(item.worth)})

			local actions = {
				{text = "✋", color = if isHeld then Color3.fromRGB(110, 200, 80) else Color3.fromRGB(120, 180, 240), dark = if isHeld then Color3.fromRGB(40, 110, 30) else Color3.fromRGB(40, 90, 150), fn = function()
					Items.hold(item.name)
				end},
				{text = "🎁", color = Color3.fromRGB(255, 150, 190), dark = Color3.fromRGB(160, 60, 100), fn = function()
					Items.startGift(nil, item.name)
				end},
				{text = "🗑️", color = Color3.fromRGB(230, 110, 100), dark = Color3.fromRGB(120, 35, 30), fn = function()
					Items.askDelete(item.name)
				end},
				{text = "💰", color = if canSell then Color3.fromRGB(255, 190, 40) else Color3.fromRGB(150, 150, 150), dark = Color3.fromRGB(120, 80, 10), fn = function()
					doSell(item.name)
				end},
			}
			for k, a in ipairs(actions) do
				local b = button(row, a.text, a.color, a.dark)
				b.Name = "Action" .. k
				b.AnchorPoint = Vector2.new(1, 0.5)
				b.Position = UDim2.new(1, -6 - (4 - k) * 46, 0.5, 0)
				b.Size = UDim2.fromOffset(42, 38)
				b.MouseButton1Click:Connect(a.fn)
			end
		end
	end

	local function open()
		local shop = _L.Get {"Client", "Modules", "Controllers", "SeedShop"}
		if shop.Close then
			shop.Close()
		end
		window.Visible = true
		window.Size = UDim2.fromOffset(420, 360)
		TweenService:Create(window, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromOffset(460, 400)}):Play()
		refresh()
	end
	Backpack.open = open

	counter.MouseButton1Click:Connect(function()
		if window.Visible then
			window.Visible = false
		else
			open()
		end
	end)
	close.MouseButton1Click:Connect(function()
		window.Visible = false
	end)
	sellAll.MouseButton1Click:Connect(function()
		doSell(nil)
	end)

	data:Bind("plants", function()
		refresh()
	end)
	_L.Player:GetAttributeChangedSignal("HeldItem"):Connect(function()
		refresh()
	end)
	pcall(function()
		data:Bind({"stats", "Rebirths"}, function()
			refresh()
		end)
	end)

	-- close the window when walking away from the Gardener (only if it was opened by the Gardener)
	task.spawn(function()
		while gui.Parent do
			task.wait(0.5)
			if window.Visible then
				local canSell = nearGardener()
				if canSell ~= Backpack._lastCanSell then
					Backpack._lastCanSell = canSell
					refresh()
				end
			end
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "SellPrompt" then
			open()
		end
	end)

	refresh()
end

function Backpack._init()
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
	Plants = _L.Get {"Common", "Modules", "Databases", "Plants"}
end

function Backpack._start()
	task.spawn(function()
		local Data = _L.Get {"Client", "Library", "Classes", "Data"}
		local data = Data.Await()
		local ok, err = pcall(Backpack._build, data)
		if not ok then
			warn("[Backpack] UI failed:", err)
		end
	end)
end

return Backpack
