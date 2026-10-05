--> Variables
local _L = _G._L

--> Constants

---------->
local Eggs

Eggs = {
	{
		name = "Farm_Egg",
		display_name = "Farm Star",
		
		pets = {
			{name = "Krill", chance = 54},
			{name = "Gohan", chance = 27},
			{name = "Trunks", chance = 11},
			{name = "Josuke", chance = 4.5},
			{name = "Kura", chance = 3},
			{name = "Kurapika", chance = 0.5}
		},
		
		price = 750,
		
		luck = 0.1
	},
	
	{
		name = "Desert_Egg",
		display_name = "Desert Star",

		pets = {
			{name = "Roger", chance = 55},
			{name = "Ronie", chance = 28},
			{name = "Tanji", chance = 12},
			{name = "Tanji+", chance = 3.8},
			{name = "Hisoka", chance = 1},
			{name = "Hisoka+", chance = 0.2}
		},

		price = 3000,
		
		luck = 0.1
	},
	
	{
		name = "Void_Egg",
		display_name = "Void Star",

		pets = {
			{name = "Gruh", chance = 50},
			{name = "Buhin", chance = 28},
			{name = "Buhan", chance = 17},
			{name = "Hawks", chance = 4.4},
			{name = "Gon", chance = 0.55},
			{name = "Gon+", chance = 0.05}
		},

		price = 3500*25,
		
		luck = 0.1
	},
	
	{
		name = "Dragon_Egg",
		display_name = "Dragon Egg",
		
		is_exclusive = true,
		
		pets = {
			{name = "Renito", chance = 45},
			{name = "Muzan", chance = 35},
			{name = "Renato", chance = 16},
			{name = "Black Beard", chance = 3.5},
			{name = "Aries", chance = 0.5}
		},
		
		luck = 0.1
	},
	
	{
		name = "Galaxy_Egg",
		display_name = "Galaxy Egg",
		
		is_exclusive = true,
		
		pets = {
			{name = "Galaxy Cat", chance = 45},
			{name = "Galaxy Dragon", chance = 35},
			{name = "Galactic Alien", chance = 16},
			{name = "Cosmic Cyborg", chance = 3.5},
			{name = "Galaxy Beast", chance = 0.5}
		},
		
		luck = 0.1
	},
	{
		name = "Jungle_Egg",
		display_name = "Jungle Star",

		pets = {
			{name = "Ginx", chance = 45},
			{name = "Ginx+", chance = 35},
			{name = "Killa", chance = 16},
			{name = "Killa+", chance = 3.92},
			{name = "Rengage", chance = 0.08}
		},

		price = 10000,
		luck = 0.1
	},
	--{
	--	name = "250K_Event_Egg",
	--	display_name = "250K Event Egg",

	--	pets = {
	--		{name = "250k Dragon", chance = 45},
	--		{name = "Dark Spirit", chance = 35},
	--		{name = "Wisp Dragon", chance = 16},
	--		{name = "Raged Beast", chance = 3.5},
	--		{name = "Holy Dominus", chance = 0.5}
	--	},

	--	price = 1500
	--},
	--{
	--	name = "500K_Event",
	--	display_name = "500k Event Egg",
	--
	--	pets = {
	--		{name = "500k Bull", chance = 45},
	--		{name = "Hell Wisp", chance = 35},
	--		{name = "Deadly Dominus", chance = 16},
	--		{name = "Holy Kraken", chance = 3.5},
	--		{name = "Dark Dominus", chance = 0.5}
	--	},

	--	price = 750000,
	--	luck = 0.1
	--},
	--{
	--	name = "1M_Event",
	--	display_name = "1M Event Egg",
	--	
	--	pets = {
	--		{name = "1M Lion", chance = 45},
	--		{name = "Lava Angel", chance = 35},
	--		{name = "Lava Dragon", chance = 16},
	--		{name = "Storm Wyvern", chance = 3.5},
	--		{name = "Storm Dragon", chance = 0.5}
	--	},

	--	price = 250000,
	--	luck = 0.01
	--},
	{
		name = "Toxic_Egg",
		display_name = "Toxic Egg",

		pets = {
			{name = "Radioactive Cat", chance = 45},
			{name = "Toxic Cactus Boi", chance = 35},
			{name = "Toxic Dragon", chance = 19},	
			{name = "Toxic Phoenix", chance = 0.9945},
			{name = "Toxic Alien", chance = 0.005},
			{name = "SLIME BOY", chance = 0.0005}
		},

		price = 350000,
		
		luck = 0.001
	},
	{
		name = "2M_Event",
		display_name = "2M Event Egg",

		pets = {
			{name = "Gift", chance = 60},
			{name = "Bat", chance = 25},
			{name = "Bee", chance = 14.5},	
			{name = "Ice Scorpion", chance = 0.4989},
			{name = "Evil Spirit", chance = 0.001},
			{name = "2M Serpent", chance = 0.0001}
		},

		price = 500000,

		luck = 0.001
	},
	{
		name = "3M_Event",
		display_name = "3M Event Egg",

		pets = {
			{name = "Molten Creature", chance = 60},
			{name = "Molten Scorpion", chance = 30},
			{name = "Molten Wyvern", chance = 9.5},	
			{name = "Molten Wisp", chance = 0.4999},
			{name = "Molten Alien", chance = 0.0001}
		},

		price = 750000,

		luck = 0.001
	},
	{
		name = "Midnight_Egg",
		display_name = "Midnight Egg",

		is_exclusive = true,

		pets = {
			{name = "Soldier", chance = 45},
			{name = "Super Ares", chance = 35},
			{name = "Smite", chance = 16},
			{name = "Big", chance = 3.5},
			{name = "Big Sun", chance = 0.5}
		},

		luck = 0.1
	},

}

return Eggs