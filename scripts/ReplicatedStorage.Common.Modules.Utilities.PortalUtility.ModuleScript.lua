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
local PortalUtility

PortalUtility = {
	getInfo = function(portalName)
		local _, portalInfo = TableUtility.match(Portals, function(i, v)
			return typeof(v) == "table" and v.name == portalName
		end)

		return portalInfo
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
		Network = _L.Get {"Common", "Library", "Network"}
		Portals = _L.Get {"Common", "Modules", "Databases", "Portals"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
		Zone = _L.Get {"Common", "Library", "Physics", "Zone"}
	end,
}

return PortalUtility