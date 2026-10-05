--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Data
local TableUtility
local AttributeUtility
local NumberUtility
local Spr
local Trove
local Audio
local Shared
local Network
local TrackerUtility
local Powers
local Wheel
local Free
local Store
local Notifications
local Rebirth

--> Constants
local KEYCODES = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine
}

------------->
local Toolbar = {
	name = script.Name
}

function Toolbar:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Powers = _L.Get {"Common", "Modules", "Databases", "Powers", "Powers"}
	UI = _L.Get {"Client", "Modules", "UI"}
	Constants = _L.Get {"Common", "Modules", "Constants"} 
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
end

function Toolbar:_start()
	Wheel = UI.Get("Wheel")
	Free = UI.Get("Free")
	Store = UI.Get("Store")
	Notifications = UI.Get("Notifications")
	Rebirth = UI.Get("Rebirth")
	Season = UI.Get("Season")
	
	-- the bottom bar was removed from the HUD (key 1 / harvest slot is handled elsewhere)
	local bottomBar = _L.PlayerGui.Main:FindFirstChild("Bottom")
	if not (bottomBar and bottomBar:FindFirstChild("Toolbar")) then
		return
	end
	self.object = bottomBar.Toolbar
	
	self._buttons = {}
	
	AttributeUtility.waitFor(_L.Player, "toolbar_data")
	
	local moreButtonInstance = self.object:FindFirstChild("MoreButton")
	
	-- FRUITBOUND: no combat powers to buy any more
	if moreButtonInstance then
		moreButtonInstance.Visible = false
	end
	
	if moreButtonInstance then
		moreButtonInstance.MouseButton1Down:Connect(function()
			UI.Open({name = "Store", props = {
				subject = "Electro",
				subject_callback = function()
					Purchases.PromptProduct("Electro_Pack")
				end,
			}})
		end)
	end
	
	local data = Data.Await()

	if data then
		self._tutorial_trove = Trove.new()
		
		Tracker.Subscribe({data:Track("tutorial_marker"), UI._current}, function()
			self._tutorial_trove:Clean()
			
			-- HUD polish: the harvest slot is always equipped, so the bottom toolbar is hidden
			-- (key 1 still works).
			-- The old bouncing tutorial texts are replaced by the Guide arrows.
			_L.PlayerGui.Main.Bottom.Toolbar.Visible = false
			
			if false then
				if data:Get({"tutorial_marker"}) == 1 then
					local strengthTxt = self.object.Parent.StrengthTxt

					self._tutorial_trove:Add(Services.RunService.Heartbeat:Connect(function()
						strengthTxt.Position = UDim2.fromScale(0.5, 0.15 + math.sin(tick() * 10) / 40)
					end))

					strengthTxt.Visible = true

					self._tutorial_trove:Add(function()
						strengthTxt.Visible = false
					end)
				elseif data:Get({"tutorial_marker"}) == 2 then
					local strengthTxt = _L.PlayerGui.Main.Top.ProgressBar.StrengthTxt

					self._tutorial_trove:Add(Services.RunService.Heartbeat:Connect(function()
						strengthTxt.Position = UDim2.fromScale(0.5, 2.8 - 3 * math.sin(tick() * 10) / 40)
					end))

					strengthTxt.Visible = true

					self._tutorial_trove:Add(function()
						strengthTxt.Visible = false
					end)
				end
			else
				self._tutorial_trove:Clean()
			end
		end)
		
		local toolbarData = TrackerUtility.fromAttributeSignal(_L.Player, "toolbar_data")

		toolbarData:Bind(function(value)
			self:_update(value, data)
		end)
	end
end

function Toolbar:_update(toolbarData, data)
	for _, toolbarButton in pairs(self._buttons) do
		if not table.find(toolbarData, toolbarButton.power_name) then
			toolbarButton.trove:Destroy()
		end
	end
	
	for i, powerName in pairs(toolbarData) do
		-- FRUITBOUND: only the harvest slot (internally "Punch") is shown, fireballs are gone
		if powerName ~= "Punch" then
			continue
		end
		
		local _, button = TableUtility.match(self._buttons, function(i, v)
			return v.power_name == powerName
		end)
		
		if not button then
			local _, powerInfo = TableUtility.match(Powers, function(i, v)
				return v.name == powerName
			end)
			
			if powerInfo then
				local newTrove = Trove.new()

				local newToolbarButtonInstance = _L.Assets.UI.Toolbar.ToolbarButton:Clone()

				newTrove:Add(newToolbarButtonInstance)
				
				newToolbarButtonInstance.Icon.Image = ""
				local harvestIcon = Instance.new("TextLabel")
				harvestIcon.Name = "HarvestIcon"
				harvestIcon.Text = "🧺"
				harvestIcon.Font = Enum.Font.FredokaOne
				harvestIcon.TextScaled = true
				harvestIcon.BackgroundTransparency = 1
				harvestIcon.AnchorPoint = newToolbarButtonInstance.Icon.AnchorPoint
				harvestIcon.Position = newToolbarButtonInstance.Icon.Position
				harvestIcon.Size = newToolbarButtonInstance.Icon.Size
				harvestIcon.ZIndex = newToolbarButtonInstance.Icon.ZIndex
				harvestIcon.Parent = newToolbarButtonInstance
				newToolbarButtonInstance.Parent = self.object

				local toolbarButton = {
					power_name = powerName,
					instance = newToolbarButtonInstance,
					trove = newTrove,
					click = function()
						if data:Get("auto_punch") then
							Notifications:add({
								text = "❌ Disable auto mode first!",
								color = Color3.fromRGB(255, 0, 0),
								audio = {name = "Fail1"}
							})

							return
						end

						Network.Remote.Fire("S_Toolbar_Toggle_Power", powerName)
					end,
				}
				
				if powerName == "Punch" then
					data:Bind("auto_punch", function(value)
						newToolbarButtonInstance.AutoPunchBtn.Image = if value then Constants.POP_BUTTON_GREEN else Constants.POP_BUTTON_RED
					end)

					newToolbarButtonInstance.AutoPunchBtn.MouseButton1Down:Connect(function()
						local success = Network.Remote.Invoke("S_Auto_Punch_Toggle")

						if success then
							Audio.Play({name = "Toggle1"})
						end
					end)
				end
				
				newTrove:Add(function()
					local i, button = TableUtility.match(self._buttons, function(i, v)
						return v.power_name == powerName
					end)

					table.remove(self._buttons, i)
				end)

				table.insert(self._buttons, toolbarButton)

				local currentPower = newTrove:Add(TrackerUtility.fromAttributeSignal(_L.Player, "current_power"))

				newTrove:Add(currentPower:Bind(function(value)
					if value == powerName then
						if powerName == "Punch" then
							newToolbarButtonInstance.AutoPunchBtn.Visible = true

						end
						
						newToolbarButtonInstance.BackgroundColor3 = Color3.fromRGB(81, 250, 57)
						newToolbarButtonInstance.UIStroke.Color = Color3.fromRGB(1, 103, 0)
					else
						newToolbarButtonInstance.AutoPunchBtn.Visible = false
						newToolbarButtonInstance.BackgroundColor3 = Color3.fromRGB(46, 182, 255)
						newToolbarButtonInstance.UIStroke.Color = Color3.fromRGB(27, 64, 104)
					end
				end))

				newTrove:Add(currentPower)
				
				newToolbarButtonInstance.MouseButton1Down:Connect(function()
					toolbarButton.click()
				end)
			end
		end
	end
	
	-- sort
	
	for i = 1, 9 do
		Services.ContextActionService:UnbindAction(tostring(i))
	end
	
	for i, button in pairs(self._buttons) do
		Services.ContextActionService:BindAction(tostring(i), function(actionName, inputState, _inputObject)
			if inputState == Enum.UserInputState.Begin then
				button.click()
			end
		end, false, KEYCODES[i])
		
		button.instance.Indicator.TextLabel.Text = i
	end
end

return Toolbar