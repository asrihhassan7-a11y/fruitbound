-- // VARIABLES // --
local FruitEggRewards = {
	{
		egg_name = "Farm_Egg",
		currency = "Gems",
		price = 750,
		fruits = {
			{name = "Apple", rarity = "Common", chance = 50},
			{name = "Strawberry", rarity = "Common", chance = 50},
		},
	},
	{
		egg_name = "Desert_Egg",
		currency = "Gems",
		price = 3000,
		fruits = {
			{name = "Coconut", rarity = "Common", chance = 20},
			{name = "Mango", rarity = "Common", chance = 20},
			{name = "Lemon", rarity = "Common", chance = 20},
			{name = "Kiwi", rarity = "Rare", chance = 20},
			{name = "Peach", rarity = "Rare", chance = 12},
			{name = "Blueberry", rarity = "Rare", chance = 8},
		},
	},

	{
		egg_name = "Jungle_Egg",
		currency = "Gems",
		price = 10000,
		fruits = {
			{name = "Orange", rarity = "Common", chance = 25},
			{name = "Banana", rarity = "Common", chance = 25},
			{name = "Watermelon", rarity = "Rare", chance = 22},
			{name = "Grape", rarity = "Rare", chance = 18},
			{name = "Pineapple", rarity = "Epic", chance = 8},
			{name = "Dragon Fruit", rarity = "Epic", chance = 2},
		},
	},
}

-- // INITIALIZATION // --
return FruitEggRewards
