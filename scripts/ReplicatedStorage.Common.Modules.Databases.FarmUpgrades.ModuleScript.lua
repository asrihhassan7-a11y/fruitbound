--> Farm upgrades (tycoon)
-- ============================================================
-- Bought in this order. Each one physically builds something on the player's farm
-- (built by ServerStorage.FarmBuilder) and can give an effect.
--
--   id, name, icon, cost (Coins), description
--   id is saved in player data (farm.upgrades) -- never rename an id. `name` is display only.
--   kind      what FarmBuilder builds: "starter", "field", "orchard", "helper_hut", "helper",
--             "path", "sprinklers", "market", "pond", "barn", "windmill", "greenhouse",
--             "fountain", "gate"
--   at        where on the plot (x, z) in studs from the plot centre. +z = entrance side.
--   soil      land plots only: size (x, z) of the EMPTY planting soil, centred on `at`.
--             Players plant their own Seeds anywhere on owned soil (FarmingV2 validates it).
--   effect    farm-wide bonuses:
--               farm_value = +x coins on all crop harvests (0.5 = +50%)
--               growth     = crops grow this much faster (0.4 = +40% growth speed)
--               helpers    = +1 helper
--               helper_speed = helpers earn +x
--               storage    = storage crate holds x minutes of helper income
--               title      = title id given when bought
-- ============================================================

local FarmUpgrades = {
	{id = "starter", name = "Starter Plot", icon = "🌱", cost = 0, kind = "starter", at = Vector3.new(0, 0, 42), soil = Vector3.new(20, 0, 14),
		description = "Your first patch of soil. Plant your Seeds here!"},

	{id = "strawberry_field", name = "Meadow Plot", icon = "🌾", cost = 1500, kind = "field", at = Vector3.new(-42, 0, 42), soil = Vector3.new(34, 0, 22),
		description = "A big empty field of soil. Room for many more crops!"},

	{id = "helper_hut", name = "Helper Hut", icon = "🧑‍🌾", cost = 4000, kind = "helper_hut", at = Vector3.new(34, 0, 60),
		description = "Hire your first garden helper! It earns Coins into your storage crate.",
		effect = {helpers = 1, storage = 3}},

	{id = "mango_garden", name = "Orchard Plot", icon = "🌳", cost = 12000, kind = "orchard", at = Vector3.new(42, 0, 42), soil = Vector3.new(24, 0, 14),
		description = "A grassy orchard corner with a fresh soil bed."},

	{id = "flower_path", name = "Flower Paths", icon = "🌷", cost = 25000, kind = "path", at = Vector3.new(-21, 0, 12),
		description = "Stone paths lined with colourful flowers."},

	{id = "watermelon_field", name = "Riverside Plot", icon = "💧", cost = 50000, kind = "field", at = Vector3.new(-42, 0, 12), soil = Vector3.new(34, 0, 22),
		description = "Rich riverside soil with space for lots of crops."},

	{id = "sprinklers", name = "Sprinklers", icon = "💦", cost = 100000, kind = "sprinklers", at = Vector3.new(21, 0, 27),
		description = "Water everything! Your crops grow 40% faster.",
		effect = {growth = 0.4}},

	{id = "market_stand", name = "Market Stand", icon = "🏪", cost = 200000, kind = "market", at = Vector3.new(-30, 0, 60),
		description = "Sell your crops for more! +50% Coins from all crop harvests.",
		effect = {farm_value = 0.5}},

	{id = "tropical_garden", name = "Tropical Plot", icon = "🌴", cost = 400000, kind = "orchard", at = Vector3.new(42, 0, 12), soil = Vector3.new(24, 0, 14),
		description = "A sunny tropical corner with a fresh soil bed."},

	{id = "pond", name = "Lily Pond", icon = "🪷", cost = 700000, kind = "pond", at = Vector3.new(0, 0, 12),
		description = "A peaceful pond with lily pads and lotus flowers."},

	{id = "helper_2", name = "Second Helper", icon = "🧑‍🌾", cost = 1100000, kind = "helper", at = Vector3.new(50, 0, 60),
		description = "Another helper joins your farm.",
		effect = {helpers = 1}},

	{id = "barn", name = "Big Red Barn", icon = "🏚️", cost = 1700000, kind = "barn", at = Vector3.new(-42, 0, -48),
		description = "Huge storage! Holds 15 minutes of helper work, helpers earn +50%.",
		effect = {storage = 15, helper_speed = 0.5}},

	{id = "cherry_grove", name = "Blossom Plot", icon = "🌸", cost = 2600000, kind = "orchard", at = Vector3.new(-42, 0, -18), soil = Vector3.new(24, 0, 14),
		description = "A pretty blossom corner with a fresh soil bed."},

	{id = "windmill", name = "Windmill", icon = "🌬️", cost = 4000000, kind = "windmill", at = Vector3.new(-60, 0, 62),
		description = "A cozy windmill. Helpers work 50% faster.",
		effect = {helper_speed = 0.5}},

	{id = "greenhouse", name = "Greenhouse Plot", icon = "🏡", cost = 6000000, kind = "greenhouse", at = Vector3.new(42, 0, -18), soil = Vector3.new(28, 0, 18),
		description = "A glass greenhouse with warm soil inside."},

	{id = "golden_fountain", name = "Golden Fountain", icon = "⛲", cost = 9000000, kind = "fountain", at = Vector3.new(0, 0, -18),
		description = "A magical fountain. +100% Coins from all crop harvests.",
		effect = {farm_value = 1}},

	{id = "helper_3", name = "Third Helper", icon = "🧑‍🌾", cost = 13000000, kind = "helper", at = Vector3.new(62, 0, -3),
		description = "A third helper joins, plus a friendly scarecrow.",
		effect = {helpers = 1}},

	{id = "crystal_orchard", name = "Mystic Plot", icon = "✨", cost = 20000000, kind = "orchard", at = Vector3.new(42, 0, -48), soil = Vector3.new(24, 0, 14),
		description = "A sparkling mystic corner with a fresh soil bed."},

	{id = "rainbow_garden", name = "Golden Plot", icon = "🌟", cost = 30000000, kind = "field", at = Vector3.new(0, 0, -48), soil = Vector3.new(34, 0, 22),
		description = "The finest soil on the island. Room for a huge harvest!"},

	{id = "paradise_gate", name = "Paradise Gate", icon = "✨", cost = 45000000, kind = "gate", at = Vector3.new(0, 0, 64),
		description = "Your farm becomes a true Fruitbound Paradise! +100% crop Coins and the Paradise Farmer title.",
		effect = {farm_value = 1, title = "paradise_farmer"}},
}

return FarmUpgrades
