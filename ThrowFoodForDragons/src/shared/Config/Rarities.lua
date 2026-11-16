-- Rarity tiers. mult = feeding reward multiplier, scale = model size, weight = wild spawn weight.
local C = Color3.fromRGB
local Rarities = {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
	Info = {
		Common = { rank = 1, color = C(196, 206, 214), mult = 1, scale = 1, weight = 60 },
		Uncommon = { rank = 2, color = C(96, 222, 110), mult = 1.6, scale = 1.12, weight = 25 },
		Rare = { rank = 3, color = C(70, 162, 255), mult = 2.6, scale = 1.28, weight = 10 },
		Epic = { rank = 4, color = C(186, 92, 255), mult = 4.5, scale = 1.45, weight = 4 },
		Legendary = { rank = 5, color = C(255, 194, 40), mult = 8, scale = 1.7, weight = 1.2 },
		Mythic = { rank = 6, color = C(255, 64, 120), mult = 18, scale = 2.15, weight = 0 },
		Secret = { rank = 7, color = C(255, 255, 255), mult = 45, scale = 2.45, weight = 0, rainbow = true },
	},
}
return Rarities
