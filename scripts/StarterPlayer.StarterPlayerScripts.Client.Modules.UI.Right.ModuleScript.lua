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
local RobuxMultiplierUtility
local Network

--> Constants

------------->
local Right = {
	name = script.Name
}

function Right:_init()
	Network = _L.Get {"Common", "Library", "Network"}
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"}
	FastTween = _L.Get {"Common", "Library", "Functions", "FastTween"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	UI = _L.Get {"Client", "Modules", "UI"}
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	RobuxMultiplierUtility = _L.Get {"Common", "Modules", "Utilities", "RobuxMultiplierUtility"}
end

function Right:_start()
	self.object = _L.PlayerGui.Main.Right
	
	local electrolyteInstance = self.object.Offers:FindFirstChild("Electrolyte")

	if electrolyteInstance then
		electrolyteInstance.MouseButton1Down:Connect(function()
			UI.Open({name = "Store", props = {
				subject = "Electro",
				subject_callback = function()
					Purchases.PromptProduct("Electrolyte")
				end,
			}})
		end)
	end
	
end

return Right