--> Gardens database
-- id 0 = starter patch at spawn (no requirement).
-- ids 1..19 = the old training areas (requirement + coin multiplier stay in Databases.TrainingAreas).
-- rarity = which food (Databases.Plants) the bushes drop when fully harvested.
-- fruit / leaf = bush colors.

local Gardens = {
	{id = 0, name = "Starter Patch", rarity = "Common", fruit = Color3.fromRGB(235, 60, 70), leaf = Color3.fromRGB(95, 200, 90)},
	{id = 1, name = "Berry Meadow", rarity = "Common", fruit = Color3.fromRGB(150, 70, 220), leaf = Color3.fromRGB(95, 200, 90)},
	{id = 2, name = "Sunny Orchard", rarity = "Common", fruit = Color3.fromRGB(255, 170, 40), leaf = Color3.fromRGB(110, 205, 80)},
	{id = 3, name = "Lemon Grove", rarity = "Common", fruit = Color3.fromRGB(255, 230, 60), leaf = Color3.fromRGB(90, 190, 90)},
	{id = 4, name = "Mango Hills", rarity = "Rare", fruit = Color3.fromRGB(255, 140, 50), leaf = Color3.fromRGB(70, 180, 100)},
	{id = 5, name = "Melon Fields", rarity = "Rare", fruit = Color3.fromRGB(120, 220, 90), leaf = Color3.fromRGB(60, 160, 80)},
	{id = 6, name = "Pineapple Beach", rarity = "Rare", fruit = Color3.fromRGB(250, 200, 60), leaf = Color3.fromRGB(80, 190, 130)},
	{id = 7, name = "Dragon Garden", rarity = "Epic", fruit = Color3.fromRGB(255, 70, 160), leaf = Color3.fromRGB(90, 200, 120)},
	{id = 8, name = "Star Glade", rarity = "Epic", fruit = Color3.fromRGB(255, 240, 120), leaf = Color3.fromRGB(100, 170, 220)},
	{id = 9, name = "Moonlit Grove", rarity = "Epic", fruit = Color3.fromRGB(190, 200, 255), leaf = Color3.fromRGB(80, 110, 190)},
	{id = 10, name = "Golden Orchard", rarity = "Legendary", fruit = Color3.fromRGB(255, 205, 50), leaf = Color3.fromRGB(200, 170, 70)},
	{id = 11, name = "Crystal Grove", rarity = "Legendary", fruit = Color3.fromRGB(120, 230, 255), leaf = Color3.fromRGB(150, 220, 230)},
	{id = 12, name = "Spirit Woods", rarity = "Legendary", fruit = Color3.fromRGB(180, 255, 220), leaf = Color3.fromRGB(90, 200, 170)},
	{id = 13, name = "Lotus Lake", rarity = "Mythical", fruit = Color3.fromRGB(255, 150, 220), leaf = Color3.fromRGB(100, 200, 160)},
	{id = 14, name = "Volcano Garden", rarity = "Mythical", fruit = Color3.fromRGB(255, 90, 30), leaf = Color3.fromRGB(90, 60, 50)},
	{id = 15, name = "World Tree Roots", rarity = "Mythical", fruit = Color3.fromRGB(140, 255, 120), leaf = Color3.fromRGB(50, 140, 60)},
	{id = 16, name = "Sky Islands", rarity = "Huge", fruit = Color3.fromRGB(130, 200, 255), leaf = Color3.fromRGB(240, 250, 255)},
	{id = 17, name = "Ancient Garden", rarity = "Huge", fruit = Color3.fromRGB(220, 180, 110), leaf = Color3.fromRGB(110, 150, 90)},
	{id = 18, name = "Chaos Bloom", rarity = "Secret", fruit = Color3.fromRGB(120, 40, 200), leaf = Color3.fromRGB(40, 30, 60)},
	{id = 19, name = "Cosmic Orchard", rarity = "Divine", fruit = Color3.fromRGB(255, 255, 255), leaf = Color3.fromRGB(60, 40, 140)},
}

return Gardens
