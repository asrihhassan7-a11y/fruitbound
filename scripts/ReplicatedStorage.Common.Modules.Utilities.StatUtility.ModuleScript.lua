--> Variables
local _L = _G._L

local _Stats
local TableUtility
local Products

--> Constants

---------->
local StatUtility

StatUtility = {
	getInfo = function(statName)
		local _, statInfo = TableUtility.match(_Stats, function(i, v)
			return v.name == statName
		end)

		return statInfo
	end,

	give = function(client, statProps)
		local clientData = client.data

		local statName = statProps.name
		local statValue = statProps.value

		if clientData and statName and statValue then
			local currentStatValue = clientData:Get({"stats", statName})

			clientData:Set({"stats", statName}, currentStatValue + statValue)

			return true, {{
				name = statName,
				reward_name = "Stat",
				value = statValue
			}}
		end

		return false
	end,
	
	closestProduct = function(statName, current, need)
		local i, v = TableUtility.min(ArrayUtility.filter(Products, function(i, v) return typeof(v) == "table" and v.tag == statName and v.value >= need - current end), function(i, v)
			return v.value
		end)
		
		if v then
			return v.name
		else
			local i, v = TableUtility.max(ArrayUtility.filter(Products, function(i, v) return typeof(v) == "table" and v.tag == statName end), function(i, v)
				return v.value
			end)
			
			return v.name
		end
	end,

	_init = function()
		_Stats = _L.Get {"Common", "Modules", "Databases", "Stats"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		Products = _L.Get {"Common", "Modules", "Databases", "Products"}
	end
}

return StatUtility