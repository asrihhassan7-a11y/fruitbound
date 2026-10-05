--> Variables
local _L = _G._L

local Services
local Constants

--> Constants

---------->
local InviteRewards

InviteRewards = {
	{
		id = "1",
		required = 1,
		reward = {{
			name = "Stat",
			props = {
				name = "Crowns",
				value = 750
			}
		}},
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "2",
		required = 2,
		reward = {{
			name = "Pet",
			props = {
				name = "Fiery Phoenix",
				value = 1
			}
		}},
		reward_image = "rbxassetid://14461285648",
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "3",
		required = 3,
		reward = {{
			name = "Stat",
			props = {
				name = "Crowns",
				value = 1500
			}
		}},
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "4",
		required = 4,
		reward = {{
			name = "Pet",
			props = {
				name = "Candy Dragon",
				value = 1
			}
		}},
		reward_image = "rbxassetid://14461328680",
		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	{
		id = "5",
		required = 5,
		reward = {{
			name = "Pet",
			props = {
				name = "Snowy Wyvern",
				value = 1
			}
		}},
		reward_image = "rbxassetid://14389173342",

		reward_format = function(n)
			return NumberUtility.commas(n)
		end
	},
	
	_init = function()
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	end,
}

return InviteRewards