--> Wild Fruits (V1.1)
-- ============================================================
-- Rare Fruits that appear at the spawn points in Workspace.__MAP.V11World.WildFruitSpawns.<Region>.
-- The server picks everything (where, which Fruit, catch roll). No Robux, no paid items.
-- Fruit names must exist in the Fruit database and have a model (same list the Eggs use).
-- ============================================================

local WildFruits = {
	MAX_ACTIVE = 3, -- Wild Fruits in the whole server at once
	LIFETIME = {90, 120}, -- seconds a Wild Fruit stays before it wanders off
	AFTER_FAIL_LIFETIME = 20, -- a Fruit that shook off a catch stays at most this much longer
	ESCAPE_CHANCE = 0.35, -- chance a failed catch makes it run away at once
	WANDER_RADIUS = 6,
	CATCH_DISTANCE = 12, -- studs (server check)
	CATCH_HOLD = 1, -- seconds the catch prompt is held (the "capture attempt")
	ATTEMPT_COOLDOWN = 5, -- seconds between one player's catch attempts
	CATCH_REST = 180, -- after a successful catch the player's net rests this long (keeps Eggs relevant)

	-- catch chance by the Fruit's rarity (Fruit database)
	CATCH_CHANCE = {Common = 0.6, Rare = 0.35, Epic = 0.15, Legendary = 0.08, Mythical = 0.05},

	-- per region: time between spawns (seconds, after the last one left) and a weighted table
	regions = {
		Orchard = {display = "Orchard Grove", respawn = {240, 420}, fruits = {
			{name = "Apple", weight = 40}, {name = "Strawberry", weight = 34}, {name = "Peach", weight = 10},
			{name = "Kiwi", weight = 10}, {name = "Pineapple", weight = 5}, {name = "Dragon Fruit", weight = 1},
		}},
		Meadow = {display = "Sunny Meadow", respawn = {240, 420}, fruits = {
			{name = "Strawberry", weight = 36}, {name = "Lemon", weight = 34}, {name = "Blueberry", weight = 12},
			{name = "Grape", weight = 12}, {name = "Pineapple", weight = 5}, {name = "Dragon Fruit", weight = 1},
		}},
		Riverside = {display = "Riverside", respawn = {240, 420}, fruits = {
			{name = "Mango", weight = 36}, {name = "Lemon", weight = 30}, {name = "Watermelon", weight = 14},
			{name = "Kiwi", weight = 14}, {name = "Pineapple", weight = 5}, {name = "Dragon Fruit", weight = 1},
		}},
		Tropical = {display = "Tropical Cove", respawn = {240, 420}, fruits = {
			{name = "Coconut", weight = 34}, {name = "Banana", weight = 34}, {name = "Orange", weight = 12},
			{name = "Watermelon", weight = 12}, {name = "Pineapple", weight = 6}, {name = "Dragon Fruit", weight = 2},
		}},
		-- the rarest spot: spawns less often, mostly Rare / Epic
		Mystic = {display = "Mystic Glade", respawn = {480, 900}, fruits = {
			{name = "Grape", weight = 30}, {name = "Blueberry", weight = 30}, {name = "Peach", weight = 20},
			{name = "Pineapple", weight = 12}, {name = "Dragon Fruit", weight = 8},
		}},
	},
}

return WildFruits
