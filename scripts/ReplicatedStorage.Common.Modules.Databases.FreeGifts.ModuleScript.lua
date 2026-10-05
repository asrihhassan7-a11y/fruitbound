--> Variables
local _L = _G._L

local Services
local Constants

--> Constants

---------->
local FreeGifts

FreeGifts = {
	{
		id = "1",
		
		reward_name = "Stat",
		name = "Strength",
		value = 100,
		
		time = 75
	},
	
	{
		id = "2",

		reward_name = "Stat",
		name = "Gems",
		value = 100,
		
		time = 195
	},
	
	{
		id = "3",

		reward_name = "Boost",
		name = "x2_Strength",
		value = 1,

		time = 315
	},
	
	{
		id = "4",

		reward_name = "Stat",
		name = "Gems",
		value = 150,

		time = 7 * 60 + 15
	},
	
	{
		id = "5",

		reward_name = "Boost",
		name = "Lucky_Potion",
		value = 1,

		time = 10 * 60 + 15
	},
	
	{
		id = "6",

		reward_name = "Stat",
		name = "Gems",
		value = 300,

		time = 15 * 60 + 15
	},
	
	{
		id = "7",

		reward_name = "Boost",
		name = "x2_Strength",
		value = 2,

		time = 20 * 60 + 15
	},
	
	{
		id = "8",

		reward_name = "Stat",
		name = "Strength",
		value = 2500,

		time = 25 * 60 + 15
	},
	
	{
		id = "9",

		reward_name = "Stat",
		name = "Gems",
		value = 600,

		time = 30 * 60 + 15
	},

	{
		id = "10",

		reward_name = "Boost",
		name = "Growth_Speed",
		value = 1,

		time = 45 * 60 + 15
	},

	{
		id = "11",

		reward_name = "Stat",
		name = "Gems",
		value = 600,

		time = 60 * 60 + 15
	},

	{
		id = "12",

		reward_name = "Boost",
		name = "x2_Strength",
		value = 1,

		time = 60 * 60 + 15 * 60 + 15
	},
	
	{
		id = "13",

		reward_name = "Stat",
		name = "Gems",
		value = 750,

		time = 70 * 60 + 30 * 60
	},
	
	{
		id = "14",

		reward_name = "Stat",
		name = "Gems",
		value = 1000,

		time = 90 * 60 + 45 * 60
	},
	
	{
		id = "15",

		reward_name = "Stat",
		name = "Crowns",
		value = 250,

		time = 90 * 60 + 60 * 60
	},
}

return FreeGifts