--> Variables
local _L = _G._L

local PlayerRewardUtility
local StatUtility
local PetUtility
local BoostUtility
local EggUtility
local _Stats
local PowerUtility

--> Constants

---------->
local Upgrades

Upgrades = {
	{id = "1", color = "Green", predicate = function(self, client)
		return true
	end, callback = function(self, client)
		return true
	end, max_stages = 6, cost = function(x)
		return x * 15000*10
	end},
	{id = "2", color = "Pink", predicate = function(self, client)
		return true
	end, callback = function(self, client)
		return true
	end, max_stages = 5, cost = function(x)
		return x * 45000*10
	end},
	{id = "3", color = "Teal", predicate = function(self, client)
		return true
	end, callback = function(self, client)
		return true
	end, max_stages = 4, cost = function(x)
		return x * 60000*10
	end},
	{id = "4", color = "Red", predicate = function(self, client)
		return true
	end, callback = function(self, client)
		return true
	end, max_stages = 3, cost = function(x)
		return x * 75000*10
	end},
}

return Upgrades