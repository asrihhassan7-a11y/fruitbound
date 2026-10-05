--> Variables
local _L = _G._L

local Services
local Constants

--> Constants

---------->
local Settings

Settings = {
	["Music"] = {
		
		callback = function(client)
			return true
		end,
	},
	
	["SFX"] = {
		callback = function(client)
			return true
		end,
	},
	
	["Other_Pets"] = {
		callback = function(client)
			return true
		end,
	},
	
	["Your_Pets"] = {
		callback = function(client)
			return true
		end,
	},
	
	["Other_Fruits"] = {
		callback = function(client)
			return true
		end,
	},
	
	["Your_Fruits"] = {
		callback = function(client)
			return true
		end,
	},
	
	["Trades"] = {
		callback = function(client)
			return true
		end,
	},

	-- with Trades on: only friends may send you trade requests
	["Trades_Friends_Only"] = {
		callback = function(client)
			return true
		end,
	},
	
	["Auto_Rebirth"] = {
		callback = function(client)
			local success = client.purchases:OwnsGamepass("Auto_Rebirth")
			
			if success then
				return true
			else
				return false, "owns"
			end
		end,
	},
	
	["Popups"] = {
		callback = function(client)
			return true
		end,
	},
	
	["Notifications"] = {
		callback = function(client)
			return true
		end,
	},
	
	-- Show / hide the green Auto-Collect range ring (visual only)
	["Auto_Collect_Zone"] = {
		callback = function(client)
			return true
		end,
	},
}

return Settings