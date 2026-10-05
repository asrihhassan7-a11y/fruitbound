--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local AttributeUtility
local Constants
local Powers

--> Constants

---------->
local PowerUtility

PowerUtility = {
	give = function(client, powerProps)
		local clientData = client.data

		local powerName = powerProps.name

		if clientData and powerName then
			local currentPowerData = TableUtility.deep.clone(clientData:Get("owned_powers"))

			if not table.find(currentPowerData, powerName) then
				table.insert(currentPowerData, powerName)
			end

			clientData:Set("owned_powers", currentPowerData)
			
			if client.player_controller then
				client.player_controller:_update_toolbar_data()
			end

			return true, {{
				name = powerName,
				reward_name = "Power"
			}}
		end

		return false
	end,
	
	getInfo = function(powerName)
		local _, powerInfo = TableUtility.match(Powers, function(i, v)
			return typeof(v) == "table" and v.name == powerName
		end)

		return powerInfo
	end,
	
	getHealth = function(powerName)
		local powerInfo = PowerUtility.getInfo(powerName)
		local powerHealth = powerInfo.damage * 10
		return powerHealth
	end,
	
	_init = function()
		Powers = _L.Get {"Common", "Modules", "Databases", "Powers", "Powers"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return PowerUtility