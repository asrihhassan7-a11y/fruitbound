--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local AttributeUtility
local Constants
local PowerEffects

--> Constants

---------->
local PowerEffectUtility

PowerEffectUtility = {
	getInfo = function(powerEffectName)
		local _, powerEffectInfo = TableUtility.match(PowerEffects, function(i, v)
			return typeof(v) == "table" and v.name == powerEffectName
		end)

		return powerEffectInfo
	end,
	
	_init = function()
		PowerEffects = _L.Get {"Common", "Modules", "Databases", "Powers", "Effects"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return PowerEffectUtility