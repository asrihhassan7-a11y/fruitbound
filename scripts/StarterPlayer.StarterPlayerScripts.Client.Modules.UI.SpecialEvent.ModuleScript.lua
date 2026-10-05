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
local PlayerRewardUtility
local FreeGiftUtility
local FreeGifts
local ProgressBar
local Notifications

--> Constants

------------->
local SpecialEvent = {
	name = script.Name
}

function SpecialEvent:_init()
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
	FreeGifts = _L.Get {"Common", "Modules", "Databases", "FreeGifts"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	FreeGiftUtility = _L.Get {"Common", "Modules", "Utilities", "FreeGiftUtility"}
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	SpecialEventUtility = _L.Get {"Common", "Modules", "Utilities", "SpecialEventUtility"}
	
	self.trove = Trove.new()
end

function SpecialEvent:_start()
	Notifications = UI.Get("Notifications")
	
	self.object = _L.PlayerGui.SpecialEvent
	
	local data = Data.Await()

	if data then
		AttributeUtility.waitFor(workspace, "special_event")
		
		local specialEvent = {tracker = TrackerUtility.fromAttributeSignal(workspace, "special_event"), trove = Trove.new()}
		
		specialEvent.tracker:Bind(function(value)
			specialEvent.trove:Clean()
			
			if not value then
				return
			end
			
			value = tostring(value)
			
			local specialEventInfo = SpecialEventUtility.getInfo(value)
			
			Audio.Play({name = "SpecialEventStart1"})
			
			self:Open({
				title = "SPECIAL EVENT!",
				description = specialEventInfo.start_description,
				icon = specialEventInfo.icon
			})
			
			specialEvent.trove:Add(function()
				Audio.Play({name = "SpecialEventStop1"})
				
				self:Open({
					title = "EVENT OVER!",
					description = specialEventInfo.end_description,
					icon = specialEventInfo.icon
				})
			end)
		end)
	end
end

function SpecialEvent:Open(props)
	self.trove:Clean()
	
	Spr.Stop(self.object.Main)
	
	self.object.Main.Position = UDim2.fromScale(0.5, -0.5)
	
	Spr.Target(self.object.Main, 0.5, 4, {
		Position = UDim2.fromScale(0.5, 0.5)
	})
	
	self.object.Main.Time.Text = props.title
	self.object.Main.Time.Time.Text = props.title
	self.object.Main.Description.Text = props.description
	self.object.Main.Icon.Image = props.icon or "rbxassetid://"
	
	self.trove:Add(cancellableDelay(5, function()
		self:Close()
	end))
end

function SpecialEvent:Close()
	self.trove:Clean()
	
	Spr.Target(self.object.Main, 0.5, 4, {
		Position = UDim2.fromScale(0.5, -0.5)
	})
end

return SpecialEvent