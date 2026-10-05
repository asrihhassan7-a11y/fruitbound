--> Second Garden Floor (V1.1)
-- ============================================================
-- An optional raised farm deck on every player's plot, bought once with Coins.
-- Saved as data.garden_floor2 (true once bought). Crops planted on it are normal Seed crops
-- in seed_crops (plot-space x / z like the ground, plus floor = 2); the deck soil never sits
-- above ground soil, so a plot-space x / z always belongs to exactly one bed.
--
-- Plot space = studs from the plot centre, like FarmUpgrades (`at`, +z = entrance side).
-- The deck stands over the Lily Pond spot (between the Pond and the Golden Fountain), with an
-- open skylight over the pond, and is reached by the Garden Lift at the front.
-- ============================================================

local GardenFloor = {
	id = "garden_floor2",
	name = "Second Garden Floor",
	icon = "🪜",
	COST = 750000, -- Coins (stats.Strength). Between the Lily Pond (700K) and the Second Helper (1.1M)
	HEIGHT = 16, -- deck surface is HEIGHT + 1 above the plot base (same `+1` as FarmUpgrades.at)

	-- the whole deck (plot space centre / size)
	deck = {at = Vector3.new(0, 16, 8), size = Vector3.new(44, 0, 30)},
	-- skylight over the pond (no planks here)
	opening = {at = Vector3.new(0, 16, 8), size = Vector3.new(10, 0, 14)},
	-- plantable soil beds (same rules as FarmUpgrades.soil)
	beds = {
		{id = "garden_floor2_west", at = Vector3.new(-14.5, 16, 8), soil = Vector3.new(13, 0, 26)},
		{id = "garden_floor2_east", at = Vector3.new(14.5, 16, 8), soil = Vector3.new(13, 0, 26)},
	},
	-- the Garden Lift tower (ground pad and top landing share x / z)
	lift = {at = Vector3.new(0, 0, 29), size = Vector3.new(6, 0, 5)},
	-- ground footprints players' decorations may not use (support pillars + lift tower)
	pillars = {
		Vector3.new(-21.5, 0, -6.5), Vector3.new(21.5, 0, -6.5),
		Vector3.new(-21.5, 0, 8), Vector3.new(21.5, 0, 8),
		Vector3.new(-21.5, 0, 22.5), Vector3.new(21.5, 0, 22.5),
	},
	PILLAR_SIZE = 1.8,
}

return GardenFloor
