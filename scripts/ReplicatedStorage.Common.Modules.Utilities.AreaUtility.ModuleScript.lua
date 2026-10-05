--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local TrainingAreas
local AttributeUtility
local Constants
local Services
local Network
local NumberUtility
local Zone

--> Constants

---------->
local AreaUtility

AreaUtility = {
	getInfo = function(areaName)
		local _, areaInfo = TableUtility.match(Areas, function(i, v)
			return typeof(v) == "table" and v.name == areaName
		end)

		return areaInfo
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
		Network = _L.Get {"Common", "Library", "Network"}
		Areas = _L.Get {"Common", "Modules", "Databases", "Areas"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
		Zone = _L.Get {"Common", "Library", "Physics", "Zone"}
	end,
}

return AreaUtility