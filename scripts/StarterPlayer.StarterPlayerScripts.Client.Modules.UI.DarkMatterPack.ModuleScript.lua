local PROMO_POPUP_ENABLED = false -- FRUITBOUND: the timed promo popup is off for now (the menu itself still works)
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
local DarkMatterPack = {
	name = script.Name
}

function DarkMatterPack:_init()
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
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function DarkMatterPack:_start()
	Notifications = UI.Get("Notifications")
	
	self.object = _L.PlayerGui.DarkMatterPack
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	DarkMatterPack.opened = false
	
	local data = Data.Await()

	if data then
		task.wait(420)
		
		Timer.Simple(60, function()
			-- promotional auto-popup temporarily disabled (set PROMO_POPUP_ENABLED = true to restore)
			if not PROMO_POPUP_ENABLED then return end
			if DarkMatterPack.opened or UI._current:Get() == "Trade" or UI._current:Get() == "Confirm" or UI._current:Get() == "Store" --[[or data:Get("tutorial_marker") <= 2]] then
				return
			end
			
			DarkMatterPack.opened = true
			
			UI.Open({name = self.name})
		end)
	end
end
	
function DarkMatterPack:Open()
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
	
	local bottomBar = _L.PlayerGui.Main:FindFirstChild("Bottom") if bottomBar and bottomBar:FindFirstChild("Toolbar") then bottomBar.Toolbar.Visible = false end
end

function DarkMatterPack:Close()
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
	
	local bottomBar = _L.PlayerGui.Main:FindFirstChild("Bottom") if bottomBar and bottomBar:FindFirstChild("Toolbar") then bottomBar.Toolbar.Visible = true end
end

return DarkMatterPack