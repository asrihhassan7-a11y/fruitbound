--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local WheelRewards
local AttributeUtility
local Constants

--> Constants

---------->
local UpgradeUtility

UpgradeUtility = {
	getInfo = function(upgradeId)
		local _, upgradeInfo = TableUtility.match(Upgrades, function(i, v)
			return typeof(v) == "table" and v.id == upgradeId
		end)

		return upgradeInfo
	end,
	
	getCost = function(upgradeId, currentUpgradeStage)
		local upgradeInfo = UpgradeUtility.getInfo(upgradeId)
		return upgradeInfo.cost(currentUpgradeStage)
	end,
	
	_init = function()
		Upgrades = _L.Get {"Common", "Modules", "Databases", "Upgrades"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return UpgradeUtility