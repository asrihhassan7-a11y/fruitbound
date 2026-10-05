--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local AttributeUtility
local Constants
local PowerComponents

--> Constants

---------->
local PowerComponentUtility

PowerComponentUtility = {
	getInfo = function(powerComponentName)
		local _, powerComponentInfo = TableUtility.match(PowerComponents, function(i, v)
			return typeof(v) == "table" and v.name == powerComponentName
		end)

		return powerComponentInfo
	end,
	
	_init = function()
		PowerComponents = _L.Get {"Common", "Modules", "Databases", "Powers", "Components"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return PowerComponentUtility