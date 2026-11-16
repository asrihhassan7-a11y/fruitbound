-- Food progression. value = base coins per feed, gravity = arc multiplier (lower = floatier, flies further),
-- zone = highest zone needed before it can be bought.
local C = Color3.fromRGB
local list = {
	{ id = "berries", name = "Dragon Berries", icon = "🍒", cost = 0, zone = 1, value = 1, xp = 1, gravity = 1, size = 0.9, color = C(220, 40, 70), trail = C(255, 140, 160) },
	{ id = "meat", name = "Meat Chunks", icon = "🍖", cost = 300, zone = 1, value = 3, xp = 2, gravity = 1.1, size = 1.1, color = C(196, 92, 70), trail = C(255, 160, 130) },
	{ id = "fireapple", name = "Fire Apples", icon = "🍎", cost = 4000, zone = 2, value = 10, xp = 3, gravity = 1, size = 1.1, color = C(255, 70, 40), trail = C(255, 170, 40), fx = "fire" },
	{ id = "lava", name = "Lava Treats", icon = "🔥", cost = 25000, zone = 3, value = 35, xp = 5, gravity = 1, size = 1.1, color = C(255, 120, 20), trail = C(255, 60, 0), neon = true, fx = "fire" },
	{ id = "goldfish", name = "Golden Fish", icon = "🐟", cost = 120000, zone = 4, value = 120, xp = 8, gravity = 0.95, size = 1.2, color = C(255, 205, 50), trail = C(255, 240, 150), fx = "sparkle" },
	{ id = "crystal", name = "Magic Crystals", icon = "💎", cost = 600000, zone = 5, value = 400, xp = 12, gravity = 0.9, size = 1.1, color = C(90, 220, 255), trail = C(200, 120, 255), neon = true, fx = "sparkle" },
	{ id = "cloud", name = "Cloud Puffs", icon = "☁️", cost = 3000000, zone = 6, value = 1400, xp = 18, gravity = 0.75, size = 1.4, color = C(240, 248, 255), trail = C(170, 220, 255), fx = "sparkle" },
	{ id = "ancient", name = "Ancient Dragon Food", icon = "🍯", cost = 15000000, zone = 7, value = 5000, xp = 26, gravity = 0.9, size = 1.3, color = C(214, 160, 60), trail = C(255, 220, 120), fx = "sparkle" },
	{ id = "shadow", name = "Shadow Plums", icon = "🍇", cost = 75000000, zone = 8, value = 18000, xp = 36, gravity = 0.85, size = 1.2, color = C(90, 30, 140), trail = C(170, 60, 255), neon = true, fx = "shadow" },
	{ id = "celestial", name = "Celestial Nectar", icon = "🌟", cost = 350000000, zone = 9, value = 65000, xp = 50, gravity = 0.7, size = 1.2, color = C(255, 240, 160), trail = C(255, 255, 255), neon = true, fx = "sparkle" },
	{ id = "cosmic", name = "Cosmic Dragon Snacks", icon = "🌠", cost = 1600000000, zone = 10, value = 250000, xp = 70, gravity = 0.6, size = 1.3, color = C(255, 90, 220), trail = C(90, 200, 255), neon = true, fx = "cosmic" },
}
local byId = {}
for i, f in list do
	f.order = i
	byId[f.id] = f
end
return { List = list, ById = byId, Default = "berries" }
