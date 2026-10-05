--> Farm decorations (placed by players on their own farm plot)
-- ============================================================
-- Bought with Coins at the Decorate bench on your farm, placed anywhere free on your plot,
-- picked up again for a full refund. Built by ServerStorage.FarmBuilder (FarmBuilder.decor).
--
--   id, name, icon, cost (Coins)
--   size       footprint in studs (x = width, z = depth) before rotation
--   height     rough height (only used for the placement preview)
--   crop       optional: harvestable plants on it {style, fruit, leaf, count, rarity, value}
--   max        optional: max number of this item per farm
-- ============================================================

local rgb = Color3.fromRGB

local FarmDecor = {}

FarmDecor.MAX_TOTAL = 40

FarmDecor.Items = {
	{id = "fence", name = "Fence", icon = "🚧", cost = 60, size = Vector3.new(8, 0, 1), height = 3},
	{id = "flower_pot", name = "Flower Pot", icon = "🌼", cost = 150, size = Vector3.new(3, 0, 3), height = 3},
	{id = "hay_bale", name = "Hay Bale", icon = "🌾", cost = 300, size = Vector3.new(4, 0, 3), height = 3},
	{id = "lantern", name = "Lantern", icon = "🏮", cost = 500, size = Vector3.new(2, 0, 2), height = 7, max = 8},
	{id = "crate", name = "Veggie Crate", icon = "📦", cost = 700, size = Vector3.new(3, 0, 3), height = 3},
	{id = "bench", name = "Bench", icon = "🪑", cost = 900, size = Vector3.new(6, 0, 3), height = 3},
	{id = "veggie_patch", name = "Veggie Patch", icon = "🥕", cost = 1200, size = Vector3.new(9, 0, 6), height = 3, max = 8,
		crop = {style = "Veggie", fruit = rgb(255, 140, 50), leaf = rgb(95, 200, 90), count = 2, rarity = "Common", value = 1}},
	{id = "wheelbarrow", name = "Wheelbarrow", icon = "🛒", cost = 1500, size = Vector3.new(7, 0, 3), height = 3},
	{id = "scarecrow", name = "Scarecrow", icon = "👒", cost = 2500, size = Vector3.new(6, 0, 2), height = 10},
	{id = "bird_bath", name = "Bird Bath", icon = "🐦", cost = 4000, size = Vector3.new(4, 0, 4), height = 4},
	{id = "berry_patch", name = "Berry Patch", icon = "🍓", cost = 6000, size = Vector3.new(9, 0, 6), height = 3, max = 6,
		crop = {style = "Berry", fruit = rgb(235, 45, 65), leaf = rgb(80, 190, 80), count = 2, rarity = "Common", value = 1.5}},
	{id = "fruit_pen", name = "Fruit Pen", icon = "🐾", cost = 5000, size = Vector3.new(18, 0, 14), height = 3, max = 1},
	{id = "apple_tree", name = "Apple Tree", icon = "🍎", cost = 20000, size = Vector3.new(8, 0, 8), height = 12, max = 4,
		crop = {style = "Tree", fruit = rgb(225, 45, 45), leaf = rgb(90, 185, 80), count = 1, rarity = "Rare", value = 2}},
}

FarmDecor.ById = {}
for i, item in ipairs(FarmDecor.Items) do
	item.order = i
	FarmDecor.ById[item.id] = item
end

-- footprint after rotating by r degrees (multiples of 90)
function FarmDecor.footprint(item, r)
	local s = item.size
	if (math.floor((r or 0) / 90 + 0.5) % 2) == 1 then
		return Vector3.new(s.Z, 0, s.X)
	end
	return Vector3.new(s.X, 0, s.Z)
end

return FarmDecor
