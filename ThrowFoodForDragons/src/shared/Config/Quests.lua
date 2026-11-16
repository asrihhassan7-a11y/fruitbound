-- Daily quest templates, achievements and the 7-day daily reward track.
-- Coin rewards are expressed in "minutes of income" for the player's best zone so they stay meaningful.
local Quests = {}

-- kind is the tracked event: "feed", "coins", "throw", "rarefeed", "discover", "hatch"
Quests.Templates = {
	{ kind = "feed", text = "Feed %s dragons", amount = function(z) return 40 + z * 10 end, minutes = 3 },
	{ kind = "throw", text = "Throw %s food", amount = function(z) return 80 + z * 15 end, minutes = 2.5 },
	{ kind = "coins", text = "Earn %s coins", amount = "income8", minutes = 3 },
	{ kind = "rarefeed", text = "Feed Rare or better dragons %s times", amount = function(z) return 8 + z * 2 end, minutes = 4 },
	{ kind = "hatch", text = "Hatch %s companion eggs", amount = function() return 3 end, minutes = 3 },
}
Quests.PerDay = 3

-- stat = which profile.Stats counter (or special) to check
Quests.Achievements = {
	{ id = "feed100", name = "Snack Time", icon = "🍖", stat = "Feeds", goal = 100, coins = 2000 },
	{ id = "feed1k", name = "Dragon Chef", icon = "👨‍🍳", stat = "Feeds", goal = 1000, coins = 60000 },
	{ id = "feed10k", name = "Feeding Frenzy", icon = "🍽️", stat = "Feeds", goal = 10000, coins = 5000000 },
	{ id = "feed100k", name = "Dragon Whisperer", icon = "🐉", stat = "Feeds", goal = 100000, coins = 2000000000 },
	{ id = "throw500", name = "Warm Up", icon = "🎯", stat = "Throws", goal = 500, coins = 3000 },
	{ id = "throw5k", name = "Sharpshooter", icon = "🏹", stat = "Throws", goal = 5000, coins = 400000 },
	{ id = "disc5", name = "Explorer", icon = "🧭", stat = "Discovered", goal = 5, coins = 1500 },
	{ id = "disc15", name = "Collector", icon = "📖", stat = "Discovered", goal = 15, coins = 150000 },
	{ id = "disc30", name = "Dragonologist", icon = "🔬", stat = "Discovered", goal = 30, coins = 40000000 },
	{ id = "disc50", name = "Living Legend", icon = "🏆", stat = "Discovered", goal = 50, coins = 5000000000 },
	{ id = "zone3", name = "Into the Fire", icon = "🌋", stat = "MaxZone", goal = 3, coins = 8000 },
	{ id = "zone6", name = "Head in the Clouds", icon = "☁️", stat = "MaxZone", goal = 6, coins = 1500000 },
	{ id = "zone10", name = "Cosmic Traveler", icon = "🌌", stat = "MaxZone", goal = 10, coins = 3000000000 },
	{ id = "rare50", name = "Rare Hunter", icon = "💠", stat = "RareFeeds", goal = 50, coins = 20000 },
	{ id = "mythic1", name = "Myth Made Real", icon = "🌟", stat = "MythicFeeds", goal = 1, coins = 500000 },
	{ id = "hatch10", name = "Egg Enthusiast", icon = "🥚", stat = "Hatches", goal = 10, coins = 10000 },
	{ id = "hatch100", name = "Hatchery Master", icon = "🐣", stat = "Hatches", goal = 100, coins = 10000000 },
	{ id = "level25", name = "Seasoned Feeder", icon = "⭐", stat = "Level", goal = 25, coins = 2500000 },
}

-- 7-day streak. minutes = income minutes; boost = { name, seconds }
Quests.Daily = {
	{ minutes = 5 },
	{ minutes = 8 },
	{ minutes = 10, boost = { "Lucky", 600 } },
	{ minutes = 14 },
	{ minutes = 18 },
	{ minutes = 22, boost = { "Coins2x", 600 } },
	{ minutes = 35, boost = { "Coins2x", 1200 } },
}
Quests.DailyCooldown = 20 * 3600
Quests.DailyResetAfter = 48 * 3600

return Quests
