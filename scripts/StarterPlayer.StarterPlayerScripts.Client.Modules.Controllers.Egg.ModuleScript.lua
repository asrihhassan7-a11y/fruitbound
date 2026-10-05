--> Variables
local _L = _G._L

local Services
local Maid
local Network
local Audio
local TableUtils
local Character
local Shared
local RandomUtility
local Timer
local Create
local NumberUtility
local TableUtility
local Tags
local DictionaryUtility
local cancellableDelay
local Tracker
local AttributeUtility
local FruitUtility
local EggUtility
local Eggs
local Notifications
local Purchases
local StatUtility

--> Constants
local EGG_UI_DISTANCE = 10
local HATCH_NOTICE_COOLDOWN = 8 -- seconds between repeated "unavailable" notices (no x5 spam)

-- Shared by every egg stand: once the server says this account may not hatch paid random
-- items, stop asking it (the server still enforces the policy on every request).
local hatchRestricted = false
local lastHatchNotice = 0
local RESTRICTED_NOTICE = {text = "Egg hatching is unavailable for this account.", color = Color3.fromRGB(255, 120, 80), audio = {name = "Fail1"}}
local POLICY_NOTICE = {text = "Hatching is temporarily unavailable. Please try again.", color = Color3.fromRGB(255, 120, 80), audio = {name = "Fail1"}}

-- one clear notice per burst of attempts (single, triple and auto all share it)
local function hatchNotice(notice)
	local now = os.clock()
	if now - lastHatchNotice < HATCH_NOTICE_COOLDOWN then
		return nil
	end
	lastHatchNotice = now
	return notice
end

------------->
local Egg = {_objects = {}}
Egg.__index = Egg

function Egg._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"} 
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Character = _L.Get {"Client", "Modules", "Controllers", "Character"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Shared = _L.Get {"Common", "Modules", "Shared"}
	RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	DictionaryUtility = _L.Get {"Common", "Library", "Utilities", "DictionaryUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	UI = _L.Get {"Client", "Modules", "UI"}
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	StatUtility = _L.Get {"Common", "Modules", "Utilities", "StatUtility"}
	EggUtility = _L.Get {"Common", "Modules", "Utilities", "EggUtility"}
end

function Egg._start()
	Eggs = UI.Get("Eggs")
	Notifications = UI.Get("Notifications")
	
	local closest
	
	Services.RunService.RenderStepped:Connect(function()
		local cloestEggInstance, closestEgg = TableUtility.min(TableUtility.filter(Egg._objects, function(i, v)
			local mag = v:_get_distance()
			
			if mag and mag <= EGG_UI_DISTANCE then
				return true
			else
				return false
			end
		end), function(i, v)
			return v:_get_distance()
		end)
		
		if closestEgg then
			for eggInstance, egg in pairs(Egg._objects) do
				task.spawn(function()
					if egg == closestEgg then
						closest = egg
						egg:_render(true)
					else
						egg:_render(false)
					end
				end)
			end
		else
			closest = nil
			
			for eggInstance, egg in pairs(Egg._objects) do
				task.spawn(function()
					egg:_render(false)
				end)
			end
		end
	end)
	
	Services.ContextActionService:BindAction("Auto", function(actionName, inputState, _inputObject)
		if closest then
			if inputState == Enum.UserInputState.Begin then
				closest:_auto_open()
			end

		end
	end, false, Enum.KeyCode.T, Enum.KeyCode.ButtonY) -- controller: Y
	
	Services.ContextActionService:BindAction("Open_1", function(actionName, inputState, _inputObject)
		if closest then
			if inputState == Enum.UserInputState.Begin then
				closest:_open_1(true)
			end
			
		end
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR1) -- controller: RB

	Services.ContextActionService:BindAction("Open_3", function(actionName, inputState, _inputObject)
		if closest then
			if inputState == Enum.UserInputState.Begin then
				closest:_open_3(true)
			end
			
		end
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonL1) -- controller: LB
end

function Egg.new(props)
	local self = setmetatable({}, Egg)
	
	self._instance = props.instance
	self._player_controller = props.player_controller
	
	self._name = self._instance.name
	self._info = EggUtility.getInfo(self._name)
	
	self._billboard = nil
	
	self._visible = Tracker.new(false)
	self._auto = {tracker = Tracker.new(false), trove = Trove.new()}
	self._requesting = false
	self._dismissed = false

	self._trove = Trove.new()
	self._trove:Add(self._auto.trove)
	self._trove:Add(self._visible)
	self._trove:Add(self._auto.tracker)
	self._characterTrove = Trove.new()
	self._trove:Add(self._characterTrove)
	local function bindCharacter(character)
		self._characterTrove:Clean()
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if humanoid and character == _L.Player.Character then
			self._characterTrove:Add(humanoid.Died:Connect(function()
				self._auto.tracker:Set(false)
				self._requesting = false
				Eggs:Close()
			end))
		end
	end
	self._trove:Add(_L.Player.CharacterAdded:Connect(bindCharacter))
	if _L.Player.Character then
		task.spawn(bindCharacter, _L.Player.Character)
	end
	self._trove:Add(_L.Player.CharacterRemoving:Connect(function()
		self._auto.tracker:Set(false)
		self._requesting = false
		self._dismissed = false
		Eggs:Close()
	end))

	self:_construct()

	return self
end

function Egg:_construct()
	self:_setup()

	Egg._objects[self._instance] = self

	self._trove:Add(function()
		Egg._objects[self._instance] = nil
	end)
end

function Egg:_setup()
	task.spawn(function()
		repeat task.wait() until EggUtility

		self:_create_billboard()

		local trove = Trove.new()

		Tracker.Subscribe({self._visible, Eggs.is_opening}, function()
			trove:Clean()

			local visible = self._visible:Get()

			Spr.Stop(self._billboard.Main.UIScale)

			if visible and not Eggs.is_opening:Get() then
				self._billboard.Main.UIScale.Scale = 0.5

				Spr.Target(self._billboard.Main.UIScale, 0.8, 4, {
					Scale = 1
				})
			else
				self._billboard.Main.UIScale.Scale = 0
			end
		end)

		self._auto.tracker:Bind(function(value)
			self._auto.trove:Clean()
			
			if not value then
				if self._started and not self._quiet_stop then
					Notifications:add({text = "Auto Open is now disabled", color = Color3.fromRGB(255, 0, 0),})
				end
				self._quiet_stop = false
				return
			end
			
			self._started = true
			
			self._auto.trove:Add(Timer.Simple(1, function()
				self:_try_auto_open()
			end))

			self:_try_auto_open()
		end)
	end)
end

-- stops Auto Hatch without the extra "disabled" notice (the hatch notice already explains why)
function Egg:_stop_auto_quietly()
	if self._auto.tracker:Get() then
		self._quiet_stop = true
		self._auto.tracker:Set(false)
	end
end

function Egg:_try_auto_open()
	local success3, err3, notiErr3 = self:_open_3()

	if success3 == false and (err3 == "restricted" or err3 == "policy") then
		self:_stop_auto_quietly()
		if notiErr3 then
			Notifications:add(notiErr3)
		end
		return
	end

	if success3 == false then
		local success1, err1, notiErr1 = self:_open_1()
		
		if success1 == false then
			if err1 == "restricted" or err1 == "policy" then
				self:_stop_auto_quietly()
			end
			if notiErr1 then
				Notifications:add(notiErr1)
				self._auto.tracker:Set(false)
			end
		end
	end
end

function Egg:_create_billboard()
	self._billboard = _L.Assets.UI.EggBillboard:Clone()
	
	local fruitRewards = EggUtility.getFruitRewards(self._name) or {}
	for _, fruitReward in ipairs(fruitRewards) do
		local fruitName = fruitReward.name
		local fruitInfo = FruitUtility.getInfo(fruitName)
		if not fruitInfo then
			continue
		end

		local newFruitInstance = _L.Assets.UI.Eggs.Pet:Clone()
		local gradientInstance = _L.Assets.Gradients.FruitRarities:FindFirstChild(fruitInfo.rarity)
		if gradientInstance then
			gradientInstance:Clone().Parent = newFruitInstance
		end

		newFruitInstance.Icon.Image = fruitInfo.image or ""
		newFruitInstance.Icon.Visible = newFruitInstance.Icon.Image ~= ""
		newFruitInstance.Chance.Text = tostring(fruitReward.chance).."%"
		newFruitInstance.Pet.Text = fruitInfo.display_name or fruitInfo.name
		newFruitInstance.MouseButton1Down:Connect(function()
			Network.Remote.Fire("S_Egg_Auto_Delete_Toggle", fruitName)
		end)
		newFruitInstance.Parent = self._billboard.Main.Frame

		self._trove:Add(self._player_controller._data:Bind({"auto_delete", fruitName}, function(value)
			newFruitInstance.Delete.Visible = value ~= nil
		end))
	end
	
	self._billboard.Main.Open_1.MouseButton1Down:Connect(function()
		self:_open_1(true)
	end)
	
	self._billboard.Main.Open_3.MouseButton1Down:Connect(function()
		self:_open_3(true)
	end)
	
	self._billboard.Main.Auto.MouseButton1Down:Connect(function()
		self:_auto_open()
	end)

	for buttonName, buttonText in pairs({Open_1 = "Hatch 1", Open_3 = "Hatch 3", Auto = "Auto Hatch"}) do
		for _, descendant in ipairs(self._billboard.Main[buttonName]:GetDescendants()) do
			if descendant:IsA("TextLabel") and descendant.Text ~= "E" and descendant.Text ~= "R" and descendant.Text ~= "T" then
				descendant.Text = buttonText
			end
		end
	end

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
	closeButton.Position = UDim2.fromScale(0.94, 0.06)
	closeButton.Size = UDim2.fromOffset(48, 48)
	closeButton.BackgroundColor3 = Color3.fromRGB(245, 95, 115)
	closeButton.Font = Enum.Font.FredokaOne
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextScaled = true
	closeButton.ZIndex = 10
	closeButton.Parent = self._billboard.Main
	Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0.25, 0)
	local closeStroke = Instance.new("UIStroke", closeButton)
	closeStroke.Color = Color3.fromRGB(70, 45, 40)
	closeStroke.Thickness = 3
	self._trove:Add(closeButton.MouseButton1Down:Connect(function()
		self._dismissed = true
		self._auto.tracker:Set(false)
		Eggs:Close()
		self:_render(false)
	end))

	-- Accounts where paid random items are restricted hatch a fixed order chosen by the server:
	-- show the exact next Fruit before purchase instead of chances
	local guaranteedLabel = Instance.new("TextLabel")
	guaranteedLabel.Name = "GuaranteedNext"
	guaranteedLabel.AnchorPoint = Vector2.new(0.5, 1)
	guaranteedLabel.Position = UDim2.fromScale(0.5, -0.01)
	guaranteedLabel.Size = UDim2.fromScale(0.95, 0.11)
	guaranteedLabel.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
	guaranteedLabel.Font = Enum.Font.FredokaOne
	guaranteedLabel.TextColor3 = Color3.fromRGB(90, 60, 35)
	guaranteedLabel.TextScaled = true
	guaranteedLabel.Visible = false
	guaranteedLabel.ZIndex = 10
	guaranteedLabel.Parent = self._billboard.Main
	Instance.new("UICorner", guaranteedLabel).CornerRadius = UDim.new(0.3, 0)
	local guaranteedStroke = Instance.new("UIStroke", guaranteedLabel)
	guaranteedStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	guaranteedStroke.Color = Color3.fromRGB(70, 45, 40)
	guaranteedStroke.Thickness = 3
	local guaranteedPadding = Instance.new("UIPadding", guaranteedLabel)
	guaranteedPadding.PaddingLeft = UDim.new(0.04, 0)
	guaranteedPadding.PaddingRight = UDim.new(0.04, 0)
	local function refreshGuaranteed()
		-- (Eggs without a Fruit pool are "Hatching Paused" and have no order to show)
		local guaranteedMode = _L.Player:GetAttribute("GuaranteedHatch") == true and EggUtility.getGuaranteedSequence(self._name) ~= nil
		guaranteedLabel.Visible = guaranteedMode
		for _, fruitInstance in ipairs(self._billboard.Main.Frame:GetChildren()) do
			local chanceLabel = fruitInstance:FindFirstChild("Chance")
			if chanceLabel and chanceLabel:IsA("TextLabel") then
				if chanceLabel:GetAttribute("ChanceText") == nil then
					chanceLabel:SetAttribute("ChanceText", chanceLabel.Text)
				end
				chanceLabel.Text = if guaranteedMode then "" else chanceLabel:GetAttribute("ChanceText")
			end
		end
		if guaranteedMode then
			local nextFruit = EggUtility.getGuaranteedNext(self._player_controller._data, self._name, 0)
			local nextInfo = nextFruit and FruitUtility.getInfo(nextFruit)
			guaranteedLabel.Text = "Guaranteed next Fruit: " .. (nextInfo and (nextInfo.display_name or nextInfo.name) or tostring(nextFruit or "?"))
		end
	end
	self._trove:Add(_L.Player:GetAttributeChangedSignal("GuaranteedHatch"):Connect(refreshGuaranteed))
	self._trove:Add(self._player_controller._data:Bind({"restricted_hatch", self._name}, function()
		refreshGuaranteed()
	end))
	refreshGuaranteed()

	self._billboard.Main.Icon.Price.Text = NumberUtility.short(self._info.price)
	-- the stand's own price sign was static text in the map: keep it equal to the real price
	local standPrice = self._instance:FindFirstChild("PriceGui", true)
	local standAmount = standPrice and standPrice:FindFirstChild("Amount", true)
	if standAmount and standAmount:IsA("TextLabel") then
		standAmount.Text = NumberUtility.short(self._info.price)
	end
	self._billboard.Main.Title.Text = if EggUtility.isContentApproved(self._name) then self._info.display_name else "Hatching Paused"
	self._billboard.Adornee = self._instance.Egg
	-- fixed on-screen size: sized in studs, the panel grew past the screen edges (Hatch buttons
	-- off-screen) whenever the camera was pushed in close by the orchard trees around the stands
	local camera = workspace.CurrentCamera
	local function fitToScreen()
		local viewport = camera.ViewportSize
		local px = math.clamp(math.min(viewport.X, viewport.Y) * 0.62, 220, 430)
		self._billboard.Size = UDim2.fromOffset(px, px)
	end
	fitToScreen()
	self._trove:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen))
	self._billboard.Parent = _L.PlayerGui
	self._trove:Add(self._billboard)
end

function Egg:_render(visible)
	if not visible then
		local distance = self:_get_distance()
		if not distance or distance > EGG_UI_DISTANCE then
			self._dismissed = false
		end
		self._auto.tracker:Set(false)
	end

	self._visible:Set(visible and not self._dismissed)
end

function Egg:_auto_open()
	self._auto.tracker:Set(not self._auto.tracker:Get())
end

function Egg:_open_1(s)
	if not EggUtility.isContentApproved(self._name) then
		self._auto.tracker:Set(false)
		local notice = {text = "Hatching is paused while the real Fruit rewards are prepared.", color = Color3.fromRGB(255, 190, 80), audio = {name = "Fail1"}}
		if s then
			Notifications:add(notice)
		end
		Eggs:Close()
		return false, "content", notice
	end

	if Eggs.is_opening:Get() or self._requesting then
		return
	end

	if hatchRestricted then
		self:_stop_auto_quietly()
		Eggs:Close()
		local notice = hatchNotice(RESTRICTED_NOTICE)
		if notice and s then
			Notifications:add(notice)
		end
		return false, "restricted", notice
	end

	self._requesting = true
	local callSuccess, success, err = pcall(Network.Remote.Invoke, "S_Egg_Open_1", self._name)
	self._requesting = false
	if not callSuccess then
		success = false
		err = "error"
	end
	if not success then
		Eggs:Close()
	end
	
	local notiErr
	
	if err == "afford" then
		notiErr = {
			text = "You need "..NumberUtility.short(self._info.price-self._player_controller._data:Get({"stats", "Gems"})).." more Gems to buy this egg!",
			color = Color3.fromRGB(255, 0, 0),
			audio = {name = "Fail1"}
		}
		
		UI.Open({name = "Store", props = {
			subject = "Gems",
			subject_callback = function()
				Purchases.PromptProduct(StatUtility.closestProduct("Gems", self._player_controller._data:Get({"stats", "Gems"}), self._info.price))
			end,
		}})
	elseif err == "space" then
		notiErr = {
			text = "You need more Fruit Inventory Space to hatch this egg!",
			color = Color3.fromRGB(255, 0, 0),
			audio = {name = "Fail1"}
		}
	elseif err == "distance" then
		notiErr = {text = "Move closer to this Egg to hatch it!", color = Color3.fromRGB(255, 120, 80), audio = {name = "Fail1"}}
	elseif err == "restricted" then
		hatchRestricted = true
		self:_stop_auto_quietly()
		notiErr = hatchNotice(RESTRICTED_NOTICE)
	elseif err == "policy" or err == "error" then
		self:_stop_auto_quietly()
		notiErr = hatchNotice(POLICY_NOTICE)
	end
	
	if notiErr and s then
		Notifications:add(notiErr)
	end
	
	return success, err, notiErr
end

function Egg:_open_3(s)
	if not EggUtility.isContentApproved(self._name) then
		local notice = {text = "Hatching is paused while the real Fruit rewards are prepared.", color = Color3.fromRGB(255, 190, 80), audio = {name = "Fail1"}}
		if s then
			Notifications:add(notice)
		end
		Eggs:Close()
		return false, "content", notice
	end

	if Eggs.is_opening:Get() or self._requesting then
		return
	end

	if hatchRestricted then
		self:_stop_auto_quietly()
		Eggs:Close()
		local notice = hatchNotice(RESTRICTED_NOTICE)
		if notice and s then
			Notifications:add(notice)
		end
		return false, "restricted", notice
	end

	self._requesting = true
	local callSuccess, success, err = pcall(Network.Remote.Invoke, "S_Egg_Open_3", self._name, s)
	self._requesting = false
	if not callSuccess then
		success = false
		err = "error"
	end
	if not success then
		Eggs:Close()
	end
	
	local notiErr
	
	if err == "afford" and not s then
		notiErr = {
			text = "You need "..NumberUtility.short(self._info.price*3-self._player_controller._data:Get({"stats", "Gems"})).." more Gems to buy this egg!",
			color = Color3.fromRGB(255, 0, 0),
			audio = {name = "Fail1"}
		}
		
		UI.Open({name = "Store", props = {
			subject = "Gems",
			subject_callback = function()
				Purchases.PromptProduct(StatUtility.closestProduct("Gems", self._player_controller._data:Get({"stats", "Gems"}), self._info.price*3))
			end,
		}})
	elseif err == "space" then
		notiErr = {
			text = "You need more Fruit Inventory Space to hatch this egg!",
			color = Color3.fromRGB(255, 0, 0),
			audio = {name = "Fail1"}
		}
	elseif err == "distance" then
		notiErr = {text = "Move closer to this Egg to hatch it!", color = Color3.fromRGB(255, 120, 80), audio = {name = "Fail1"}}
	elseif err == "restricted" then
		hatchRestricted = true
		self:_stop_auto_quietly()
		notiErr = hatchNotice(RESTRICTED_NOTICE)
	elseif err == "policy" or err == "error" then
		self:_stop_auto_quietly()
		notiErr = hatchNotice(POLICY_NOTICE)
	end
	
	if notiErr and s then
		Notifications:add(notiErr)
	end
	
	return success, err, notiErr
end

function Egg:_get_distance()
	local characterController = self._player_controller._character_controller
	
	if characterController and characterController._root then
		return (characterController._root.Position - self._instance.Egg:GetPivot().Position).Magnitude
	end
end

function Egg:Destroy()
	Eggs:Close()
	self._trove:Destroy()
end

return Egg