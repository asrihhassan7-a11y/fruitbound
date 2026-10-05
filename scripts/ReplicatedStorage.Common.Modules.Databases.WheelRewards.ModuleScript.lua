--> Variables
local _L = _G._L

local Services
local Constants

--> Constants

---------->
local WheelRewards

-- Garden Spins (free spin every Constants.WHEEL_TIME_INTERVAL + bought spins). Farming rewards only;
-- chances add up to 100. Potions go to the Boosts inventory (30 min each when used).
-- The Egg slice is never rolled for accounts where paid random items are restricted (Player:_spin_request).
WheelRewards = {
	{id = 1, reward_name = "Stat", name = "Gems", value = 5000, chance = 1, display_name = "Gems JACKPOT"},
	{id = 2, reward_name = "Stat", name = "Gems", value = 150, chance = 25},
	{id = 3, reward_name = "Stat", name = "Strength", value = 1500, chance = 20}, -- Coins
	{id = 4, reward_name = "SeedPack", name = "starter", value = 1, chance = 18},
	{id = 5, reward_name = "Seed", name = "glow_mushroom", value = 1, chance = 12, display_name = "Rare Seed (Glow Mushroom)"},
	{id = 6, reward_name = "Boost", name = "x2_Strength", value = 1, chance = 10},
	{id = 7, reward_name = "Boost", name = "Growth_Speed", value = 1, chance = 8},
	{id = 8, reward_name = "Egg", name = "Farm_Egg", value = 1, chance = 6, display_name = "Farm Egg"},
}

return WheelRewards