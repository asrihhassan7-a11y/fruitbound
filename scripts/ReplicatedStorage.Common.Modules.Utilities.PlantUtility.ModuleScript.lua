--> Variables
local _L = _G._L

local Plants
local TableUtility
local Services

--> Constants

---------->
local PlantUtility

PlantUtility = {
	-- Look up a plant by name from the Plants database
	getInfo = function(plantName)
		local _, plantInfo = TableUtility.match(Plants, function(i, v)
			return v.name == plantName
		end)

		-- mutated crops ("Wet Carrot") use the base plant's info
		if not plantInfo and typeof(plantName) == "string" then
			local MutationUtility = _L.Get {"Common", "Modules", "Utilities", "MutationUtility"}
			local baseName, mutation = MutationUtility.split(plantName)
			if mutation then
				_, plantInfo = TableUtility.match(Plants, function(i, v)
					return v.name == baseName
				end)
			end
		end

		return plantInfo
	end,

	-- Get the player's plant inventory as a dictionary { plantName = count }
	getInventory = function(data)
		return data:Get("plants") or {}
	end,

	-- Get the count of a specific plant in the player's inventory
	getCount = function(data, plantName)
		local plants = data:Get("plants") or {}
		return plants[plantName] or 0
	end,

	-- Give plant(s) to a player. plantProps: { name = plantName, value = count }
	give = function(client, plantProps)
		local clientData = client.data

		local plantName = plantProps.name
		local plantValue = plantProps.value or 1

		if clientData and plantName then
			local plants = table.clone(clientData:Get("plants") or {})
			plants[plantName] = (plants[plantName] or 0) + plantValue
			clientData:Set("plants", plants)

			return true, {{
				name = plantName,
				reward_name = "Plant",
				value = plantValue,
			}}
		end

		return false
	end,

	-- Remove plant(s) from a player's inventory
	remove = function(data, plantName, count)
		count = count or 1
		local plants = data:Get("plants") or {}
		local current = plants[plantName] or 0

		plants[plantName] = math.max(0, current - count)
		if plants[plantName] == 0 then
			plants[plantName] = nil
		end

		data:Set("plants", plants)
	end,

	-- Check if the player has at least 'count' of the specified plant
	hasPlant = function(data, plantName, count)
		count = count or 1
		return PlantUtility.getCount(data, plantName) >= count
	end,

	-- Get a sorted list of all plants the player owns (for UI display)
	getOwnedPlants = function(data)
		local plants = data:Get("plants") or {}
		local result = {}
		for plantName, count in pairs(plants) do
			local plantInfo = PlantUtility.getInfo(plantName)
			if plantInfo then
				table.insert(result, {
					name = plantName,
					rarity = plantInfo.rarity,
					exp_value = plantInfo.exp_value,
					count = count,
					image = plantInfo.image,
				})
			end
		end
		return result
	end,

	_init = function()
		Plants = _L.Get {"Common", "Modules", "Databases", "Plants"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
	end
}

return PlantUtility