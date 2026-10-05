--> Variables
local _L = _G._L

local NumberUtility

--> Constants

---------->
return {
	["Gems"] = {
		name = "Gems",
		
		grab_callback = function(client)
			return client.data:Get({"stats", "Gems"})
		end,
	},
	
	["Strength"] = {
		name = "Strength",

		grab_callback = function(client)
			return client.data:Get({"stats", "Strength"})
		end,
	},
	
	["Rebirths"] = {
		name = "Rebirths",

		grab_callback = function(client)
			return client.data:Get({"stats", "Rebirths"})
		end,
	},
	["Kills"] = {
		name = "Kills",

		grab_callback = function(client)
			return client.data:Get({"stats", "Kills"})
		end,
	},
	["Time"] = {
		name = "Time",

		grab_callback = function(client)
			return client.data:Get({"stats", "Total_Time"})
		end,
		
		format_callback = function(n)
			return NumberUtility.timer.short.auto(n)
		end,
	},
	_init = function()
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	end,
}