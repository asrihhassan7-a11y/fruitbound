--> Variables
local _L = _G._L

local Network
local Services
local NumberUtility

--> Constants

---------->
local Quests

Quests = {
	{
		id = "1", 
		daily_value_range = {100, 400}, 
		daily_reward_range = {500, 1500}, 
		
		weekly_value_range = {600, 1500}, 
		weekly_reward_range = {800, 2250}, 
		
		icon = "rbxassetid://14304116782", 
		description = function(n)
			return "Harvest "..NumberUtility.commas(n).." Fruits"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Crowns",
					value = n
				}
			}}
		end, 
		fetch_format = function(p, n)
			return NumberUtility.commas(p).."/"..NumberUtility.commas(n)
		end, 
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "2", 
		daily_value_range = {15, 60}, 
		daily_reward_range = {500, 1500}, 

		weekly_value_range = {100, 250}, 
		weekly_reward_range = {800, 2250}, 

		icon = "rbxassetid://14304120449", 
		description = function(n)
			return "Collect "..NumberUtility.commas(n).." Food"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Crowns",
					value = n
				}
			}}
		end, 
		fetch_format = function(p, n)
			return NumberUtility.commas(p).."/"..NumberUtility.commas(n)
		end, 
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "3", 
		daily_value_range = {100/2, 400/4}, 
		daily_reward_range = {500/2, 1500/3}, 

		weekly_value_range = {600*2, 1500*3}, 
		weekly_reward_range = {800, 2250*3}, 

		icon = "rbxassetid://14356582980", 
		description = function(n)
			return "Open "..NumberUtility.commas(n).." Eggs"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Crowns",
					value = n
				}
			}}
		end, 
		fetch_format = function(p, n)
			return NumberUtility.commas(p).."/"..NumberUtility.commas(n)
		end, 
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "4", 
		daily_value_range = {50, 100}, 
		daily_reward_range = {1000, 1500}, 

		weekly_value_range = {600, 1500}, 
		weekly_reward_range = {800, 2250}, 

		icon = "rbxassetid://14366828073", 
		description = function(n)
			return "Rebirth "..NumberUtility.commas(n).." Times"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Crowns",
					value = n
				}
			}}
		end, 
		fetch_format = function(p, n)
			return NumberUtility.commas(p).."/"..NumberUtility.commas(n)
		end, 
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "5", 
		daily_value_range = {10, 30}, 
		daily_reward_range = {1000, 1500}, 

		weekly_value_range = {50, 100}, 
		weekly_reward_range = {800, 2250}, 

		icon = "rbxassetid://14213404254", 
		description = function(n)
			return "Feed Your Fruits "..NumberUtility.commas(n).." Times"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Crowns",
					value = n
				}
			}}
		end, 
		fetch_format = function(p, n)
			return NumberUtility.commas(p).."/"..NumberUtility.commas(n)
		end, 
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "6", 
		daily_value_range = {3, 10}, 
		daily_reward_range = {500, 750}, 

		weekly_value_range = {20, 50}, 
		weekly_reward_range = {500, 1500}, 

		icon = "rbxassetid://14377159126", 
		description = function(n)
			return "Level Up Fruits "..NumberUtility.commas(n).." Times"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Crowns",
					value = n
				}
			}}
		end, 
		fetch_format = function(p, n)
			return NumberUtility.commas(p).."/"..NumberUtility.commas(n)
		end, 
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "7", 
		daily_value_range = {10000000, 5000000000000}, 
		daily_reward_range = {500, 1250}, 

		weekly_value_range = {25000000000000000, 500000000000000000000}, 
		weekly_reward_range = {800, 2250}, 

		icon = "rbxassetid://14263657723", 
		description = function(n)
			return "Gain "..NumberUtility.short(n).." Coins"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Crowns",
					value = n
				}
			}}
		end, 
		fetch_format = function(p, n)
			return NumberUtility.short(p).."/"..NumberUtility.short(n)
		end, 
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},

	_init = function()
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	end,
}

return Quests