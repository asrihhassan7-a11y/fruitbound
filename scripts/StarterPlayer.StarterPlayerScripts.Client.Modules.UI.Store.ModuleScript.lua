--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Data
local TableUtility
local NumberUtility
local Spr
local Trove
local Audio
local Shared
local Timer
local FastTween
local cancellableDelay
local Constants
local AttributeUtility
local TrackerUtility
local ArrayUtility
local UI
local Network
local LuckPasses
local Purchases
local ScrollingFrameUtility

--> Constants

------------->
local Store = {
	name = script.Name
}

function Store:_init()
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	Services = _L.Get {"Common", "Library", "Services"}
	Network = _L.Get {"Common", "Library", "Network"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"}
	FastTween = _L.Get {"Common", "Library", "Functions", "FastTween"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	UI = _L.Get {"Client", "Modules", "UI"}
	LuckPasses = _L.Get {"Common", "Modules", "Databases", "LuckPasses"}
	LuckPassUtility = _L.Get {"Common", "Modules", "Utilities", "LuckPassUtility"}
	ScrollingFrameUtility = _L.Get {"Common", "Library", "Utilities", "ScrollingFrameUtility"}
	
	self.is_open = Tracker.new(false)
	self.subject_trove = Trove.new()
	self._final_canvas_position = Tracker.new(nil)
end

function Store:_polish()
	local main = self.object.Main
	main.Size = UDim2.fromScale(0.65, 0.82)

	local sizeConstraint = main:FindFirstChild("ResponsiveSize") or Instance.new("UISizeConstraint")
	sizeConstraint.Name = "ResponsiveSize"
	sizeConstraint.MaxSize = Vector2.new(950, 473)
	sizeConstraint.Parent = main

	main.Middle.ScrollBarThickness = 8
	main.Middle.Strength.Title.Text = "Coins Packs"
	main.Middle.Gems.Title.Text = "Gem Packs"

	local stats = _L.PlayerGui.Main.Top.Stats
	for _, config in ipairs({
		{section = main.Middle.Gems, source = stats.Gems, color = Color3.fromRGB(90, 170, 255)},
		{section = main.Middle.Strength, source = stats.Strength, color = Color3.fromRGB(255, 190, 60)},
	}) do
		for _, descendant in ipairs(config.section:GetDescendants()) do
			if descendant:IsA("ImageLabel") and descendant.Name == "Icon" then
				descendant.Image = config.source.Image
				descendant.ImageColor3 = config.color
			end
		end
	end

	local potions = main.Middle.Potions
	potions.Size = UDim2.fromScale(0.9, 1.55)
	potions.Left.Position = UDim2.fromScale(0.3, 0.52)
	potions.Left.Size = UDim2.fromScale(0.62, 0.86)

	local potionStyles = {
		x2_Strength = {order = 1, color = Color3.fromRGB(255, 211, 95)},
		Lucky_Potion = {order = 2, color = Color3.fromRGB(126, 222, 116)},
		Protection_Potion = {order = 3, color = Color3.fromRGB(110, 190, 255)},
		x2_Damage = {order = 4, color = Color3.fromRGB(255, 126, 126)},
	}

	for potionName, style in pairs(potionStyles) do
		local card = potions.Left:FindFirstChild(potionName)
		if card then
			card.Visible = true
			card.LayoutOrder = style.order
			card.Size = UDim2.fromScale(0.95, 0.205)
			card.BackgroundColor3 = style.color

			local icon = card:FindFirstChild("Icon")
			if icon then
				icon.Position = UDim2.fromScale(0.09, 0.5)
				icon.Size = UDim2.fromScale(0.18, 1.2)
			end

			for _, child in ipairs(card:GetChildren()) do
				if child:IsA("TextLabel") then
					if string.find(child.Text, "Lasts", 1, true) then
						child.Position = UDim2.fromScale(0.33, 0.68)
						child.Size = UDim2.fromScale(0.28, 0.24)
					elseif string.find(child.Text, "Boost", 1, true) or string.find(child.Text, "Double", 1, true) or string.find(child.Text, "Protects", 1, true) then
						child.Position = UDim2.fromScale(0.47, 0.39)
						child.Size = UDim2.fromScale(0.52, 0.22)
					else
						child.Position = UDim2.fromScale(0.27, 0.13)
						child.Size = UDim2.fromScale(0.4, 0.22)
					end
				end
			end

			card.UseBtn.Position = UDim2.fromScale(0.65, 0.7)
			card.UseBtn.Size = UDim2.fromScale(0.23, 0.52)
			card.UseBtn.AutoButtonColor = true

			for _, child in ipairs(card:GetChildren()) do
				if child:IsA("ImageButton") and child ~= card.UseBtn then
					child.Position = UDim2.fromScale(0.88, 0.7)
					child.Size = UDim2.fromScale(0.23, 0.52)
					child.AutoButtonColor = true
				end
			end
		end
	end

	local ultra = potions.Ultra_Potion_Pack
	ultra.Position = UDim2.fromScale(0.82, 0.48)
	ultra.Size = UDim2.fromScale(0.315, 0.46)
	ultra.AutoButtonColor = true
	for _, child in ipairs(ultra:GetChildren()) do
		if child:IsA("TextLabel") then
			if string.find(child.Text, "ULTRA POTION", 1, true) then
				child.Position = UDim2.fromScale(0.5, 0.1)
				child.Size = UDim2.fromScale(0.86, 0.16)
			elseif string.find(child.Text, "Worth", 1, true) then
				child.Text = "500 each • 4 types"
				child.Position = UDim2.fromScale(0.5, 0.215)
				child.Size = UDim2.fromScale(0.86, 0.075)
			elseif string.find(child.Text, "350", 1, true) then
				child.Position = UDim2.fromScale(0.5, 0.91)
				child.Size = UDim2.fromScale(0.86, 0.12)
			end
		elseif child:IsA("ImageLabel") and child.Name == "Icon" then
			child.Position = UDim2.fromScale(0.5, 0.59)
			if child.ZIndex >= 3 then
				child.Size = UDim2.fromScale(0.68, 0.42)
			else
				child.Size = UDim2.fromScale(1.02, 0.63)
			end
		end
	end

	local summary = ultra:FindFirstChild("BundleSummary") or Instance.new("TextLabel")
	summary.Name = "BundleSummary"
	summary.AnchorPoint = Vector2.new(0.5, 0.5)
	summary.Position = UDim2.fromScale(0.5, 0.31)
	summary.Size = UDim2.fromScale(0.86, 0.075)
	summary.BackgroundColor3 = Color3.fromRGB(110, 45, 130)
	summary.BackgroundTransparency = 0.15
	summary.Font = Enum.Font.FredokaOne
	summary.Text = "2,000 POTIONS TOTAL"
	summary.TextColor3 = Color3.new(1, 1, 1)
	summary.TextScaled = true
	summary.ZIndex = 5
	summary.Parent = ultra
	local summaryCorner = summary:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	summaryCorner.CornerRadius = UDim.new(1, 0)
	summaryCorner.Parent = summary
	local summaryPadding = summary:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	summaryPadding.PaddingLeft = UDim.new(0.05, 0)
	summaryPadding.PaddingRight = UDim.new(0.05, 0)
	summaryPadding.Parent = summary

	main.Store.AnchorPoint = Vector2.new(1, 0)
	main.Store.Position = UDim2.new(1, -8, 0, 8)
	main.Store.Size = UDim2.fromOffset(56, 56)

	-- Redesign gamepass cards: custom square images as main product art
	self:_redesignGamepassCards(main)
end

-- V1.1 Store: the Gamepass cards (square product art on top, name / description / price below)
-- are laid out in StarterGui.Store. Here we only keep them responsive and show the real price.
local NARROW_STORE = 560 -- grid width (px) under which the Store shows 2 columns instead of 3
-- (cell height 2000 = no height limit: the grid's UIAspectRatioConstraint sizes each card from its width)

function Store:_redesignGamepassCards(main)
	local grid = main.Middle.Gamepasses.Middle
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if layout then
		local function fit()
			local twoColumns = grid.AbsoluteSize.X > 0 and grid.AbsoluteSize.X < NARROW_STORE
			layout.CellSize = if twoColumns then UDim2.new(0.47, 0, 0, 2000) else UDim2.new(0.31, 0, 0, 2000)
		end
		grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
	end

	local cards = {}
	for _, wrapper in ipairs(grid:GetChildren()) do
		local card = wrapper:IsA("Frame") and wrapper:FindFirstChildWhichIsA("ImageButton")
		if card and card:FindFirstChild("PricePill") then
			cards[card.Name] = card
		end
	end
	self._gamepass_cards = cards

	-- live Roblox price (falls back to the price saved on the card)
	task.spawn(function()
		for name, card in pairs(cards) do
			local info = Purchases.GetGamepassInfoFromName(name)
			local cost = card.PricePill:FindFirstChild("Cost")
			if info and cost then
				local ok, result = pcall(Services.MarketplaceService.GetProductInfo, Services.MarketplaceService, info.id, Enum.InfoType.GamePass)
				if ok and typeof(result) == "table" and typeof(result.PriceInRobux) == "number" then
					card:SetAttribute("FallbackPrice", result.PriceInRobux)
					if not card:GetAttribute("Owned") then
						cost.Text = "R$" .. NumberUtility.commas(result.PriceInRobux)
					end
				end
			end
		end
	end)
end

-- OWNED state on the Gamepass cards (kept in sync with the replicated owned gamepass list)
function Store:_bindOwnedGamepasses(data)
	local cards = self._gamepass_cards or {}
	data:Bind("gamepasses", function(owned)
		owned = owned or {}
		for name, card in pairs(cards) do
			local info = Purchases.GetGamepassInfoFromName(name)
			local isOwned = info ~= nil and table.find(owned, info.id) ~= nil
			card:SetAttribute("Owned", isOwned)
			local pill = card:FindFirstChild("PricePill")
			local cost = pill and pill:FindFirstChild("Cost")
			if cost then
				cost.Text = if isOwned then "OWNED" else "R$" .. NumberUtility.commas(card:GetAttribute("FallbackPrice") or 0)
				pill.BackgroundColor3 = if isOwned then Color3.fromRGB(120, 120, 130) else Color3.fromRGB(46, 160, 67)
			end
		end
	end)
end

function Store:_start()
	self.object = _L.PlayerGui.Store
	self:_polish()
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open(props)
		else
			self:Close()
		end
	end)
	
	local eggIcon = self.object.Main.Middle.Exclusive.Dragon_Egg.Egg
	
	local jump = function()
		Services.TweenService:Create(eggIcon, TweenInfo.new(0.175, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.073, 0.4),
			--Rotation = -15
		}):Play()

		task.wait(0.175)

		Services.TweenService:Create(eggIcon, TweenInfo.new(0.175, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.073, 0.5),
			--Rotation = 15
		}):Play()

		task.wait(0.175)

		Services.TweenService:Create(eggIcon, TweenInfo.new(0.125, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.073, 0.4),
			--Rotation = -15
		}):Play()

		task.wait(0.125)

		Services.TweenService:Create(eggIcon, TweenInfo.new(0.075, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.073, 0.5),
			--Rotation = 0
		}):Play()
	end
	
	local i = 0
	
	Timer.Simple(1.5, function()
		i += 1
		
		if i%3 == 2 then
			jump()
		end
	end)
	
	local data = Data.Await()

	if data then
		self:_bindOwnedGamepasses(data)
		self._instances = {}
		
		for _, boostInstance in pairs(self.object.Main.Middle.Potions.Left:GetChildren()) do
			if boostInstance:IsA("Frame") then
				local boostName = boostInstance.Name
				
				self._instances[boostName] = boostInstance
				
				boostInstance.UseBtn.MouseButton1Down:Connect(function()
					local success = Network.Remote.Invoke("S_Boosts_Use", boostName, 1)
					
					if success then
						Audio.Play({name = "Boost1"})
					end
				end)
			end
		end
		
		data:Bind("boosts", function(value)
			for boostName, boostInstance in pairs(self._instances) do
				local boostData = value[boostName]

				local boostQuantity = boostData.quantity

				boostInstance.UseBtn.TextLabel.Text = "USE ("..NumberUtility.short(boostQuantity)..")"
			end
		end)
		
		--local newTrove = Trove.new()

		--data:Bind("lucky_passes", function(value)
		--	newTrove:Clean()
			
		--	local v = LuckPassUtility.getBestInfo(data)
		--	local nextLuckPassInfo = if v then LuckPassUtility.getNextInfo(v.id) else LuckPassUtility.getInfo(1)
			
		--	for _, luckyPass in pairs(self.object.Main.Middle.Gamepasses.EggLuck:GetChildren()) do
		--		if luckyPass:IsA("Frame") and luckyPass:FindFirstChild("BuyBtn") then
		--			luckyPass.Lock.Visible = if nextLuckPassInfo then tonumber(luckyPass.Name) > nextLuckPassInfo.id else false
					
		--			newTrove:Add(luckyPass.BuyBtn.MouseButton1Down:Connect(function()
		--				if not v or v.id <= 2 then
		--					Purchases.PromptProduct(nextLuckPassInfo.name)
		--				end
		--			end))
		--		end
		--	end
		--end)
	end
	
	local backToTop = Tracker.new(false)
	
	backToTop:Bind(function(value)
		local backToTopInstance = self.object.Main.BackToTop
		
		if value then
			backToTopInstance.Visible = true

			Spr.Stop(backToTopInstance)

			backToTopInstance.Position = UDim2.fromScale(0.5, 0.125)

			Spr.Target(backToTopInstance, 1, 5, {
				Position = UDim2.fromScale(0.5, 0.09)
			})
		else
			backToTopInstance.Visible = false
		end
	end)
	
	Tracker.Subscribe({TrackerUtility.fromPropertySignal(self.object.Main.Middle, "CanvasPosition"), self._final_canvas_position}, function(value)
		local currentPosition = self.object.Main.Middle.CanvasPosition
		local finalPosition = self._final_canvas_position:Get()
		
		if finalPosition and finalPosition.Y == 0 then
			backToTop:Set(false)
		else
			backToTop:Set(currentPosition.Y ~= 0)
		end
	end)
	
	self.object.Main.BackToTop.MouseButton1Down:Connect(function()
		self:scroll({name = self.name, canvas_position = Vector2.new(0, 0)})
	end)

	_L.Player.CharacterAdded:Connect(function()
		self.object.Main.Visible = false
		self.is_open:Set(false)
	end)
end

function Store:Open(props)
	Spr.Stop(self.object.Main)
	
	self.object.Main.Visible = true
	self.object.Main.Position = UDim2.fromScale(0.5, 0.55)
	
	Spr.Target(self.object.Main, 1, 4, {
		Position = UDim2.fromScale(0.5, 0.5)
	})
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 80
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 20
	})
	
	self:scroll(props)
end

function Store:scroll(props)
	if props and (props.subject or props.canvas_position) then
		self.subject_trove:Clean()

		local finalCanvasPosition = props.canvas_position or ScrollingFrameUtility.getCanvasPositionY(self.object.Main.Middle, self.object.Main.Middle:FindFirstChild(props.subject))
		
		self._final_canvas_position:Set(finalCanvasPosition)
		
		local d = math.abs(finalCanvasPosition.Y - self.object.Main.Middle.CanvasPosition.Y)

		local newTween = Services.TweenService:Create(self.object.Main.Middle, TweenInfo.new(math.max((d / 1000) * 0.25, 0.5), Enum.EasingStyle.Quad), {
			CanvasPosition = finalCanvasPosition
		})

		self.object.Main.Middle.ScrollingEnabled = false

		task.spawn(function()
			local isCompleted = false

			self.subject_trove:Add(function()
				if not isCompleted then
					isCompleted = true
					self.object.Main.Middle.ScrollingEnabled = true
					self._final_canvas_position:Set(nil)
					newTween:Cancel()
				end
			end)

			newTween.Completed:Wait()

			if not isCompleted then
				isCompleted = true
				self.object.Main.Middle.ScrollingEnabled = true
				self._final_canvas_position:Set(nil)

				if props.subject_callback then
					props.subject_callback()
				end
			end
		end)

		newTween:Play()
	end
end

function Store:Close()
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
	
	self.subject_trove:Clean()
	
	self.object.Main.Middle.CanvasPosition = Vector2.new(0, 0)
end

return Store