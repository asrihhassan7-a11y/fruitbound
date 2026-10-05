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
local Notifications
local Purchases
local StatUtility

--> Constants

------------->
local Rebirth = {
	name = script.Name
}

function Rebirth:_init()
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
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	StatUtility = _L.Get {"Common", "Modules", "Utilities", "StatUtility"}
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function Rebirth:_start()
	Notifications = UI.Get("Notifications")

	self.object = _L.PlayerGui.Rebirth

	-- Wire Auto_Rebirth button in the Left panel
	local autoRebirthFrame = _L.PlayerGui.Main.Left.Auto_Rebirth
	local autoRebirthStateBtn = autoRebirthFrame.Main.StateBtn
	local autoRebirthTitle = autoRebirthFrame.Main.Title

	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	local data = Data.Await()
	
	if data then
		-- Wire Auto_Rebirth button in the Left panel
		autoRebirthStateBtn.Image = Constants.POP_BUTTON_RED
		autoRebirthStateBtn.TextLabel.Text = "Off"

		-- Update visual state based on settings data
		data:Bind("settings", function(value)
			local settingData = value and value["Auto_Rebirth"]
			autoRebirthStateBtn.Image = if settingData then Constants.POP_BUTTON_GREEN else Constants.POP_BUTTON_RED
			autoRebirthStateBtn.TextLabel.Text = if settingData then "On" else "Off"
		end)

		-- Handle click to toggle the setting
		autoRebirthStateBtn.MouseButton1Down:Connect(function()
			local success, err = Network.Remote.Invoke("S_Settings_Toggle", "Auto_Rebirth")

			if not success then
				if err == "owns" then
					UI.Open({name = "Store", props = {
						subject = "Gamepasses",
						subject_callback = function()
							Purchases.PromptGamepass("Auto_Rebirth")
						end,
					}})
				end
			end
		end)

		local progressBar = ProgressBar.new({instance = self.object.Main.ProgressBar, format = function(n1, n2)
			return NumberUtility.short(math.floor(n1)).." / "..NumberUtility.short(math.floor(n2)).." Coins"
		end,})
		
		
		local lastState = Tracker.new(false)

		Tracker.Subscribe({data:Track({"upgrades", "2"}), data:Track({"stats", "Rebirths"}), data:Track({"stats", "Strength"}), data:Track({"stats", "Gems"}), data:Track("tree")}, function(hey)
			local UpgradeTreeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeTreeUtility"}
			local rebirthPower = UpgradeTreeUtility.getRebirthPowerMultiplier(data)
			local purchases = _G.Purchases
			
			local currentRebirths = data:Get({"stats", "Rebirths"})
			local currentStrength = data:Get({"stats", "Strength"})
			local currentGems = data:Get({"stats", "Gems"})
			local nextRebirths = currentRebirths + if purchases and purchases:OwnsGamepass("x2_Rebirths") then 2 else 1
			
			local gemsGiven = math.floor(Shared.GetGemsGivenForRebirth(nextRebirths) * data:Get({"upgrades", "2"}) * UpgradeTreeUtility.getRebirthGemsMultiplier(data))
			
			self.object.Main.BeforeStrength.TextLabel.Text = NumberUtility.short(currentStrength)
			self.object.Main.BeforeGems.TextLabel.Text = NumberUtility.short(currentGems)
			self.object.Main.BeforeBoost.TextLabel.Text = NumberUtility.commas(math.floor(currentRebirths * 10 * rebirthPower)).."%"
			self.object.Main.AfterGems.TextLabel.Text = NumberUtility.short(currentGems + gemsGiven)
			self.object.Main.AfterBoost.TextLabel.Text = NumberUtility.commas(math.floor(nextRebirths * 10 * rebirthPower)).."%"
			
			local strengthRequired

			if currentRebirths then
				strengthRequired = Shared.GetStrengthRequiredForRebirth(nextRebirths) * UpgradeTreeUtility.getRebirthCostMultiplier(data)
				progressBar:Set({currentStrength, strengthRequired})
			else
				progressBar:Set({0, 0})
			end
			
			local canRebirth = not (not strengthRequired or strengthRequired > currentStrength)
			
			lastState:Set(canRebirth)
			
			self.object.Main.RebirthBtn.Image = if canRebirth then Constants.POP_BUTTON_PURPLE else Constants.POP_BUTTON_GRAY
			_L.PlayerGui.Main.Left.Content.Rebirth.Notification.Visible = canRebirth
		end)
		
		lastState:Bind(function(value)
			if value then
				Notifications:add({text = "🔁 You can now rebirth!", color = Color3.fromRGB(255, 80, 150)})
			end
		end)

		self.object.Main.RebirthBtn.MouseButton1Click:Connect(function()
			local success, err = Network.Remote.Invoke("S_Rebirth_Request")

			if success then
				Notifications:add({text = "✅ Successfully rebirthed!", color = Color3.fromRGB(0, 255, 0)})
				progressBar:Shine({audio = {name = "Rebirth1"}})
			elseif err then
				if err == 1 then
					Audio.Play({name = "Fail1"})
					
					UI.Open({name = "Store", props = {
						subject = "Strength",
						subject_callback = function()
							local purchases = _G.Purchases

							local currentRebirths = data:Get({"stats", "Rebirths"})
							local currentStrength = data:Get({"stats", "Strength"})
							local currentGems = data:Get({"stats", "Gems"})
							local nextRebirths = currentRebirths + if purchases and purchases:OwnsGamepass("x2_Rebirths") then 2 else 1
							
							local strengthRequired = if currentRebirths then Shared.GetStrengthRequiredForRebirth(nextRebirths) * _L.Get({"Common", "Modules", "Utilities", "UpgradeTreeUtility"}).getRebirthCostMultiplier(data) else nil

							if strengthRequired then
								Purchases.PromptProduct(StatUtility.closestProduct("Strength", data:Get({"stats", "Strength"}), strengthRequired))
							end
						end,
					}})
				end
			end
		end)
	end
end

function Rebirth:Open()
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
end

function Rebirth:Close()
	
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Rebirth