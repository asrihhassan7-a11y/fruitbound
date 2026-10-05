--> Variables
local _L = _G._L

local Network
local Services
local NumberUtility

--> Constants

---------->
local TutorialQuests

TutorialQuests = {
	{
		id = "1",
		reward_image = "rbxassetid://13784127821",
		icon = "rbxassetid://14356582980", 
		description = function(n)
			return "Open "..NumberUtility.commas(n).." Eggs"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Gems",
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
		reward_image = "rbxassetid://13784127821",
		icon = "rbxassetid://14366828073", 
		description = function(n)
			return "Rebirth "..NumberUtility.commas(n).." Times"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Gems",
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
		reward_image = "rbxassetid://13784127821",
		icon = "rbxassetid://14263657723", 
		description = function(n)
			return "Gain "..NumberUtility.short(n).." Coins"
		end,
		reward = function(n)
			return {{
				name = "Stat",
				props = {
					name = "Gems",
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

return TutorialQuests