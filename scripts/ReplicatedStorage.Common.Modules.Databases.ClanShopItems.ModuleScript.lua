--> Variables
local _L = _G._L

local Network
local Services
local NumberUtility

--> Constants

---------->
local ClanShop

ClanShop = {
	{
		id = 1,
		price = 3000,
		reward = {{
			name = "Pet",
			props = {
				name = "S1 Clan Trophy",
				value = 1
			}
		}}
	},
	
	{
		id = 2,
		price = 7500,
		reward = {{
			name = "Pet",
			props = {
				name = "Golden Dominus",
				value = 1
			}
		}}
	},
	
	{
		id = 3,
		price = 25000,
		reward = {{
			name = "Pet",
			props = {
				name = "Golden Spirit",
				value = 1
			}
		}}
	},
	
	_init = function()
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	end,
}

return ClanShop