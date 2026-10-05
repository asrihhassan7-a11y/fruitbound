--> Variables
local _L = _G._L

local Boosts
local TableUtility
local Services

--> Constants
local DEFAULT_BOOST_TIME = 30 * 60

---------->
local BoostUtility

BoostUtility = {
	getInfo = function(boostName)
		local _, boostInfo = TableUtility.match(Boosts, function(i, v)
			return v.name == boostName
		end)

		return boostInfo
	end,
	
	has = function(data, boostName)
		local boostsData = data:Get("boosts")
		local boostData = boostsData[boostName]
		
		local boostTimeLeft = boostData.time_left
		
		return boostTimeLeft > 0
	end,
	
	use = function(client, boostProps)
		local clientData = client.data
		
		local boostName = boostProps.name
		local boostValue = boostProps.value or 1
		local boostIgnoreRequirement = boostProps.ignore_requirement
		
		if clientData and boostName and boostValue then
			local newBoostsData = TableUtility.deep.clone(clientData:Get("boosts"))
			
			local boostData = newBoostsData[boostName]
			
			local boostQuantity = boostData.quantity
			local boostTimeLeft = boostData.time_left
			
			if not boostIgnoreRequirement then
				if boostQuantity - boostValue < 0 then
					return false
				end
				
				boostData.quantity -= boostValue
			end
			
			boostData.time_left += DEFAULT_BOOST_TIME * boostValue
			
			clientData:Set("boosts", newBoostsData)
			
			return true
		end

		return false
	end,

	give = function(client, boostProps)
		local clientData = client.data

		local boostName = boostProps.name
		local boostValue = boostProps.value or 1

		if clientData and boostName and boostValue then
			local newBoostsData = TableUtility.deep.clone(clientData:Get("boosts"))
			
			local boostData = newBoostsData[boostName]
			
			local boostQuantity = boostData.quantity 
			local boostTimeLeft = boostData.time_left
			
			local boostInfo = BoostUtility.getInfo(boostName)
			if boostInfo and boostInfo.auto_use then
				-- starts right away (the HUD shows the time left); never sits in the inventory
				boostData.time_left += DEFAULT_BOOST_TIME * boostValue
			else
				boostData.quantity += boostValue
			end
			
			clientData:Set("boosts", newBoostsData)

			return true, {{
				name = boostName,
				reward_name = "Boost",
				value = boostValue
			}}
		end

		return false
	end,

	_init = function()
		Boosts = _L.Get {"Common", "Modules", "Databases", "Boosts"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
	end
}

return BoostUtility