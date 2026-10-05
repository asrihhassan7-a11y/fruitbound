--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Data
local TableUtility
local NumberUtility
local cancellableDelay
local Trove
local Timer
local Spr
local GIF
local _Stats
local UI
local ProgressBar
local Audio
local _Boosts
local TimeString
local LuckPassUtility

--> Constants

------------->
local Boosts = {
	name = script.Name
}

function Boosts:_init()
	Audio = _L.Get {"Common", "Library", "Audio"}
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	GIF = _L.Get {"Client", "Modules", "Classes", "GIF"}
	_Stats = _L.Get {"Common", "Modules", "Databases", "Stats"}
	UI = _L.Get {"Client", "Modules", "UI"}
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	_Boosts = _L.Get {"Common", "Modules", "Databases", "Boosts"}
	TimeString = _L.Get {"Common", "Library", "Functions", "TimeString"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	LuckPassUtility = _L.Get {"Common", "Modules", "Utilities", "LuckPassUtility"}
end

function Boosts:_start()
	self.object = _L.PlayerGui.Main.Boosts
	
	local data = Data.Await()
	
	if data then
		self._instances = {}
		
		for _, boostInfo in pairs(_Boosts) do
			local newBoostInstance = _L.Assets.UI.Boosts.Boost:Clone()
			local boostName = boostInfo.name
			
			newBoostInstance.Icon.Image = boostInfo.image
			newBoostInstance.Parent = self.object
			
			self._instances[boostName] = newBoostInstance
		end
		
		data:Bind("boosts", function(value)
			for boostName, boostInstance in pairs(self._instances) do
				local boostData = value[boostName]
				
				local boostTimeLeft = boostData.time_left
				local boostQuantity = boostData.quantity
				
				boostInstance.Visible = boostTimeLeft > 0
				
				if 86400 <= boostTimeLeft then
					boostInstance.TimeLeft.Text = TimeString(boostTimeLeft)
				else
					boostInstance.TimeLeft.Text = os.date("!%X", boostTimeLeft)
				end
			end
		end)
		
		task.spawn(function()
			AttributeUtility.waitFor(_L.Player, "friends_in_game")
			
			TrackerUtility.fromAttributeSignal(_L.Player, "friends_in_game"):Bind(function(value)
				self.object.Friends.Value.Text = "x"..NumberUtility.decimal(value * 0.5, 1)
			end)
		end)
		
		data:Bind({"stats", "Rebirths"}, function(value)
			self.object.Rebirth.Value.Text = "x"..NumberUtility.decimal(value / 10, 1)
		end)
		
		data:Bind("lucky_passes", function(i, v)
			local bestLuckPassInfo = LuckPassUtility.getBestInfo(data)
			
			for _, instance in pairs(self.object:GetChildren()) do
				if not instance:IsA("Frame") then
					continue
				end
				
				if instance.Name == "Lucky_1" or instance.Name == "Lucky_2" or instance.Name == "Lucky_3" then
					instance.Visible = bestLuckPassInfo and instance.Name == bestLuckPassInfo.name
				end
			end
		end)
	end
end

return Boosts