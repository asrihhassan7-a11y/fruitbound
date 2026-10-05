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
local SettingUtility

SettingUtility = {
	getInfo = function(settingName)
		local _, settingInfo = TableUtility.match(Settings, function(i, v)
			return typeof(v) == "table" and i == settingName
		end)

		return settingInfo
	end,
	_init = function()
		Settings = _L.Get {"Common", "Modules", "Databases", "Settings"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return SettingUtility