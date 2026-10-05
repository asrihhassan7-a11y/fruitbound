--> Variables
local _L = _G._L

local PlayerRewardUtility
local StatUtility
local PetUtility
local BoostUtility
local EggUtility
local _Stats
local SeasonUtility

--> Constants

---------->
local Seasons

Seasons = {
	{
		id = 1,
		
		tiers = {
			{
				id = 1,
				free = {{name = "Stat", props = {name = "Strength", value = 50}}},
				premium = {{name = "Pet", props = {name = "Ruby Dominus", value = 1}}},
				required = 10*10^1
			},
			
			{
				id = 2,
				free = {{name = "Stat", props = {name = "Strength", value = 100}}},
				premium = {{name = "Pet", props = {name = "Emerald Dominus", value = 1}}},
				required = 11*11^2
			},
			
			{
				id = 3,
				free = {{name = "Boost", props = {name = "Lucky_Potion", value = 1}}},
				premium = {{name = "Boost", props = {name = "x2_Strength", value = 1}}},
				required = 12*12^3
			},
			
			{
				id = 4,
				free = {{name = "Stat", props = {name = "Strength", value = 500}}},
				premium = {{name = "Stat", props = {name = "Strength", value = 10*10^2}}},
				required = 13*13^4
			},
			
			{
				id = 5,
				free = {{name = "Stat", props = {name = "Gems", value = 500*10}}},
				premium = {{name = "Stat", props = {name = "Gems", value = 2500*10}}},
				required = 14*14^5
			},
			
			{
				id = 6,
				free = {{name = "Stat", props = {name = "Strength", value = 5000}}},
				premium = {{name = "Pet", props = {name = "Ruby Dominus", value = 1}}},
				required = 15*15^6
			},
			
			{
				id = 7,
				free = {{name = "Stat", props = {name = "Strength", value = 250}}},
				premium = {{name = "Pet", props = {name = "Emerald Dominus", value = 1}}},
				required = 16*16^7
			},
			
			{
				id = 8,
				free = {{name = "Boost", props = {name = "x2_Strength", value = 1}}},
				premium = {{name = "Boost", props = {name = "x2_Strength", value = 2}}},
				required = 17*17^8
			},
			
			{
				id = 9,
				free = {{name = "Boost", props = {name = "x2_Damage", value = 2}}},
				premium = {{name = "Stat", props = {name = "Gems", value = 10000*10}}},
				required = 18*18^9
			},
			
			{
				id = 10,
				free = {{name = "Stat", props = {name = "Strength", value = 10*10^8}}},
				premium = {{name = "Pet", props = {name = "Ruby Dominus", value = 1}}},
				required = 19*19^10
			},
			
			{
				id = 11,
				free = {{name = "Pet", props = {name = "Toxic Hydra", value = 1}}},
				premium = {{name = "Pet", props = {name = "Toxic Hydra", value = 1}}},
				required = 20*20^11
			},
			
			{
				id = 12,
				free = {{name = "Stat", props = {name = "Strength", value = 10*10^10}}},
				premium = {{name = "Pet", props = {name = "Ruby Dominus", value = 1}}},
				required = 21*21^12
			},
			
			{
				id = 13,
				free = {{name = "Stat", props = {name = "Gems", value = 25000*10}}},
				premium = {{name = "Stat", props = {name = "Strength", value = 10*10^11}}},
				required = 22*22^13
			},
			
			{
				id = 14,
				free = {{name = "Boost", props = {name = "Protection_Potion", value = 3}}},
				premium = {{name = "Boost", props = {name = "x2_Damage", value = 1}}},
				required = 23*23^14
			},
			
			{
				id = 15,
				free = {{name = "Pet", props = {name = "Forest Wyvern", value = 1}}},
				premium = {{name = "Pet", props = {name = "Mega Kraken", value = 1}}},
				required = 24*24^15
			},
		}
	},
	
	_init = function()
		PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
		StatUtility = _L.Get {"Common", "Modules", "Utilities", "StatUtility"}
		PetUtility = _L.Get {"Common", "Modules", "Utilities", "PetUtility"}
		BoostUtility = _L.Get {"Common", "Modules", "Utilities", "BoostUtility"}
		EggUtility = _L.Get {"Common", "Modules", "Utilities", "EggUtility"}
		SeasonUtility = _L.Get {"Common", "Modules", "Utilities", "SeasonUtility"}
	end
}

return Seasons