--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local RobuxMultipliers
local AttributeUtility
local Constants

--> Constants

---------->
local RobuxMultiplierUtility

RobuxMultiplierUtility = {
	getInfo = function(robuxMultiplierId)
		local _, robuxMultiplierInfo = TableUtility.match(RobuxMultipliers, function(i, v)
			return typeof(v) == "table" and v.id == robuxMultiplierId
		end)

		return robuxMultiplierInfo
	end,
	
	getNextInfo = function(data)
		return RobuxMultiplierUtility.getInfo((data:Get("robux_multiplier") or 0) + 1)
	end,
	
	_init = function()
		RobuxMultipliers = _L.Get {"Common", "Modules", "Databases", "RobuxMultipliers"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return RobuxMultiplierUtility