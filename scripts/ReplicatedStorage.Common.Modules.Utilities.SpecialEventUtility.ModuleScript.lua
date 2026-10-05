--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local ClanQuests
local AttributeUtility
local Constants
local SpecialEvents

--> Constants

---------->
local SpecialEventUtility

SpecialEventUtility = {
	getInfo = function(specialEventId)
		local _, specialEventInfo = TableUtility.match(SpecialEvents, function(i, v)
			return typeof(v) == "table" and v.id == specialEventId
		end)

		return specialEventInfo
	end,
	
	getRandomInfo = function()
		local i, v = ArrayUtility.random(SpecialEvents)
		return v
	end,
	
	_init = function()
		SpecialEvents = _L.Get {"Common", "Modules", "Databases", "SpecialEvents"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return SpecialEventUtility