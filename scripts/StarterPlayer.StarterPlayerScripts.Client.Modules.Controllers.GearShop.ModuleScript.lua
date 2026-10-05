--> GearShop (client, V1.1)
-- Gear Shop window (opened by the Village Gear Shop prompt) and the Watering Can tool feel.
-- Everything here is visual / a request: stock, prices, ownership and watering are all decided
-- by the server (Server.Controllers.GearShop + FarmingV2.waterCrop).
local _L = _G._L

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Network
local Gears
local NumberUtility
local UI

local TOOL_ATTRIBUTE = "FruitBoundGear"
local CREAM = Color3.fromRGB(255, 248, 230)
local WOOD = Color3.fromRGB(139, 96, 60)
local BROWN = Color3.fromRGB(95, 65, 40)
local GREEN = Color3.fromRGB(80, 185, 95)
local GREY = Color3.fromRGB(165, 155, 145)

local GearShop = {}

local gui, window, list, restockLabel
local state, clockOffset = nil, 0
local cards = {}

local function notify(text, color)
	pcall(function()
		UI.Get("Notifications"):add({text = text, color = color or Color3.fromRGB(255, 200, 80), duration = 2})
	end)
end

local function serverNow()
	return os.time() + clockOffset
end

local function clockText(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function textLabel(parent, name, text, size, pos, maxText, color, align)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = text
	t.Size = size
	t.Position = pos
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color or BROWN
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxText
	c.MinTextSize = 10
	c.Parent = t
	t.Parent = parent
	return t
end

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0, 12)
	c.Parent = inst
end

local function stroke(inst, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "GearShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Enabled = false
	gui.Parent = _L.PlayerGui

	window = Instance.new("Frame")
	window.Name = "Window"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.6, 0.62)
	window.BackgroundColor3 = CREAM
	window.Parent = gui
	corner(window, UDim.new(0, 18))
	stroke(window, WOOD, 4)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(300, 240)
	limit.MaxSize = Vector2.new(620, 430)
	limit.Parent = window

	textLabel(window, "Title", "🪣 GEAR SHOP", UDim2.new(0.7, 0, 0, 36), UDim2.new(0.05, 0, 0, 12), 30, BROWN)
	restockLabel = textLabel(window, "Restock", "NEXT RESTOCK --:--", UDim2.new(0.6, 0, 0, 20), UDim2.new(0.05, 0, 0, 48), 18, Color3.fromRGB(70, 130, 55))

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(230, 95, 80)
	close.Font = Enum.Font.FredokaOne
	close.Text = "X"
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = window
	corner(close, UDim.new(1, 0))
	close.MouseButton1Click:Connect(function()
		GearShop.Close()
	end)

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.new(0.04, 0, 0, 78)
	list.Size = UDim2.new(0.92, 0, 1, -90)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = window
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
end

local function render()
	for _, card in pairs(cards) do
		card:Destroy()
	end
	table.clear(cards)
	if not state then
		return
	end
	for index, info in ipairs(state.gears) do
		local card = Instance.new("Frame")
		card.Name = info.gear_id
		card.LayoutOrder = index
		card.Size = UDim2.new(1, -8, 0, 92)
		card.BackgroundColor3 = Color3.new(1, 1, 1)
		card.Parent = list
		corner(card, UDim.new(0, 12))
		stroke(card, Gears.RARITY_COLORS[info.rarity] or GREEN, 3)

		local icon = textLabel(card, "Icon", info.icon or "🧰", UDim2.fromOffset(70, 70), UDim2.fromOffset(10, 11), 52, BROWN, Enum.TextXAlignment.Center)
		icon.BackgroundTransparency = 0
		icon.BackgroundColor3 = Color3.fromRGB(235, 245, 255)
		corner(icon, UDim.new(0, 10))

		textLabel(card, "Name", info.name, UDim2.new(1, -230, 0, 24), UDim2.fromOffset(90, 8), 22, BROWN)
		textLabel(card, "Rarity", info.rarity .. (if info.owned then "" else "  •  " .. (if info.stock > 0 then "x" .. info.stock .. " in stock" else "out of stock")),
			UDim2.new(1, -230, 0, 16), UDim2.fromOffset(90, 33), 15, Gears.RARITY_COLORS[info.rarity] or GREEN)
		textLabel(card, "Description", info.description or "", UDim2.new(1, -230, 0, 36), UDim2.fromOffset(90, 51), 14, Color3.fromRGB(130, 100, 70))

		local button = Instance.new("TextButton")
		button.Name = "Buy"
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -10, 0.5, 0)
		button.Size = UDim2.fromOffset(122, 50)
		button.Font = Enum.Font.FredokaOne
		button.TextScaled = true
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Parent = card
		corner(button, UDim.new(0, 10))
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = button
		if info.owned then
			button.Text = "OWNED"
			button.BackgroundColor3 = GREY
			button.AutoButtonColor = false
		elseif info.stock <= 0 then
			button.Text = "SOLD OUT"
			button.BackgroundColor3 = GREY
			button.AutoButtonColor = false
		else
			button.Text = "💰 " .. NumberUtility.short(info.price)
			button.BackgroundColor3 = GREEN
			local pending = false
			button.MouseButton1Click:Connect(function()
				if pending then
					return
				end
				pending = true
				local ok, success, err = pcall(Network.Remote.Invoke, "S_GearShop_Buy", info.gear_id)
				pending = false
				if ok and success then
					notify("🪣 " .. info.name .. " unlocked! Equip it from your hotbar.", GREEN)
				else
					local reasons = {afford = "Not enough Coins!", stock = "Sold out! Wait for the next restock.", owned = "You already own this.", distance = "Walk closer to the Gear Shop."}
					notify(reasons[err] or "Couldn't buy that right now.")
				end
				GearShop.Refresh()
			end)
		end
		cards[info.gear_id] = card
	end
end

function GearShop.Refresh()
	local ok, result = pcall(Network.Remote.Invoke, "S_GearShop_Get")
	if ok and typeof(result) == "table" then
		state = result
		clockOffset = (result.now or os.time()) - os.time()
		render()
	end
end

function GearShop.Open()
	if not gui then
		build()
	end
	gui.Enabled = true
	GearShop.Refresh()
end

function GearShop.Close()
	if gui then
		gui.Enabled = false
	end
end

-- ============================================================
-- WATERING CAN
-- ============================================================

-- crop parts are not queryable, so pick the closest crop to the tapped ground point
-- (same 4.5 stud tap radius as harvesting)
local TAP_RADIUS = 4.5
local function cropAt(point)
	local best, bestDist = nil, TAP_RADIUS
	for _, model in ipairs(game:GetService("CollectionService"):GetTagged("SeedCrop")) do
		if model:IsA("Model") and model.Parent then
			local p = model:GetPivot().Position
			local flat = Vector3.new(p.X - point.X, 0, p.Z - point.Z).Magnitude
			if flat <= bestDist and math.abs(p.Y - point.Y) <= 8 then
				best, bestDist = model, flat
			end
		end
	end
	return best
end

local function splash(model, removed)
	local pivot = model:GetPivot()
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 2.5, 0))
	anchor.Parent = workspace
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drops.Color = ColorSequence.new(Color3.fromRGB(110, 190, 255))
	drops.LightEmission = 0.3
	drops.Size = NumberSequence.new(0.35, 0.1)
	drops.Transparency = NumberSequence.new(0.1, 1)
	drops.Lifetime = NumberRange.new(0.5, 0.8)
	drops.Speed = NumberRange.new(3, 6)
	drops.SpreadAngle = Vector2.new(25, 25)
	drops.Acceleration = Vector3.new(0, -25, 0)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Rate = 0
	drops.Parent = attachment
	drops:Emit(18)
	-- subtle splash ring on the soil
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Glass
	ring.Color = Color3.fromRGB(120, 195, 255)
	ring.Transparency = 0.45
	ring.Size = Vector3.new(0.1, 1, 1)
	ring.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {Size = Vector3.new(0.1, 4, 4), Transparency = 1}):Play()
	-- "-4m 48s" feedback
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(150, 34)
	board.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Adornee = anchor
	board.Parent = anchor
	local seconds = math.max(0, math.floor(tonumber(removed) or 0))
	local text = if seconds >= 60 then string.format("-%dm %02ds", seconds // 60, seconds % 60) else "-" .. seconds .. "s"
	local label = textLabel(board, "Saved", "💧 " .. text, UDim2.fromScale(1, 1), UDim2.new(), 22, Color3.fromRGB(80, 170, 255), Enum.TextXAlignment.Center)
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Thickness = 2
	labelStroke.Color = Color3.new(1, 1, 1)
	labelStroke.Parent = label
	TweenService:Create(board, TweenInfo.new(1.2), {StudsOffsetWorldSpace = Vector3.new(0, 6, 0)}):Play()
	Debris:AddItem(anchor, 1.4)
	Debris:AddItem(ring, 0.7)
end

local function tilt(tool)
	local base = tool.Grip
	tool.Grip = base * CFrame.Angles(math.rad(-35), 0, 0)
	task.delay(0.45, function()
		if tool.Parent then
			tool.Grip = base
		end
	end)
end

local function hookTool(tool)
	if not tool:IsA("Tool") or tool:GetAttribute(TOOL_ATTRIBUTE) ~= "watering_can" or tool:GetAttribute("_hooked") then
		return
	end
	tool:SetAttribute("_hooked", true)
	local busy = false
	tool.Activated:Connect(function()
		if busy then
			return
		end
		local mouse = _L.Player:GetMouse()
		local crop = mouse.Hit and cropAt(mouse.Hit.Position)
		if not crop then
			notify("Tap one of your growing crops to water it.")
			return
		end
		if crop:GetAttribute("Owner") ~= _L.Player.UserId then
			notify("You can only water your own crops.")
			return
		end
		busy = true
		tilt(tool)
		local ok, success, result, extra = pcall(Network.Remote.Invoke, "S_Gear_Water", crop:GetAttribute("SeedCropSlot"))
		busy = false
		if ok and success then
			splash(crop, result)
		elseif ok then
			local reasons = {
				mature = "This crop is ready to harvest!",
				max = "This crop has had enough water for now.",
				cooldown = "Water it again in " .. clockText(tonumber(extra) or 0) .. ".",
				distance = "Walk closer to the crop.",
				equip = "Hold the Watering Can to water.",
			}
			notify(reasons[result] or "You can't water that.")
		end
	end)
end

function GearShop._init()
	Network = _L.Get {"Common", "Library", "Network"}
	Gears = _L.Get {"Common", "Modules", "Databases", "Gears"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	UI = _L.Get {"Client", "Modules", "UI"}
end

function GearShop._start()
	Network.Remote.Fired("C_GearShop_Open", function()
		GearShop.Open()
	end)

	-- restock countdown (only while the window is open)
	task.spawn(function()
		while true do
			task.wait(1)
			if gui and gui.Enabled and state then
				local left = (state.next_restock or 0) - serverNow()
				restockLabel.Text = "NEXT RESTOCK " .. clockText(left)
				if left <= 0 then
					GearShop.Refresh()
				end
			end
		end
	end)

	local function watch(container)
		if not container then
			return
		end
		for _, item in ipairs(container:GetChildren()) do
			hookTool(item)
		end
		container.ChildAdded:Connect(hookTool)
	end
	watch(_L.Player:WaitForChild("Backpack", 30))
	if _L.Player.Character then
		watch(_L.Player.Character)
	end
	_L.Player.CharacterAdded:Connect(function(character)
		watch(character)
		watch(_L.Player:WaitForChild("Backpack", 30))
	end)

	-- close the shop when walking away
	task.spawn(function()
		while true do
			task.wait(0.5)
			if gui and gui.Enabled then
				local root = _L.Player.Character and _L.Player.Character:FindFirstChild("HumanoidRootPart")
				local shop = _L.Map:FindFirstChild("Village") and _L.Map.Village:FindFirstChild("Shops") and _L.Map.Village.Shops:FindFirstChild("Gear Shop")
				if root and shop and (shop:GetPivot().Position - root.Position).Magnitude > 30 then
					GearShop.Close()
				end
			end
		end
	end)
end

return GearShop
