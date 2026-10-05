--> FruitCatalog
-- Staging list for NEW fruit pets. Nothing here affects gameplay until a fruit is `enabled = true`
-- AND has all its stats filled in. Then it is appended to Databases.Fruits.Fruits automatically and
-- works everywhere the existing fruits work (inventory, equip, Fruits menu, Fruit Book, followers,
-- fruit pen, hatching rewards once added to FruitEggRewards, selling, trading, leveling ...).
--
-- HOW TO ADD A NEW FRUIT MODEL (e.g. Pomegranate)
--  1. Import the Meshy model into Studio. Name it  Meshy_AI_Pomegranate  (the "_Remesh_..._texture"
--     suffix Meshy adds is fine) and drop it in ReplicatedStorage.Assets.Models.Fruits
--     (or just leave it in Workspace: FruitModelSetup moves it there when the server starts).
--  2. FruitModelSetup (server) then normalizes it: main MeshPart -> "Handle" + PrimaryPart,
--     scaled so its biggest side = `scale` (default 4 studs, same as Apple / Strawberry), upright,
--     centered, non-colliding. Meshy exports lie on their back; they are stood up automatically.
--  3. Optional, for blinking: add 2 Attachments named "Eye" to the Handle on the eyes (-Z out of
--     the face) with attributes Size (Vector2), LidColor (Color3), RefHeight (number) - copy them
--     from Assets.Models.Fruits.Strawberry.Handle. No Eye attachments = the fruit just doesn't blink.
--  4. Fill in the entry below: rarity, boost, max_level, base_exp, exp_curve, description, then
--     set enabled = true.  (Walking / idle hop / collect reaction come from FruitAnimator for every
--     fruit automatically.)
--
-- Fields
--   name          unique id saved in player data - NEVER rename once enabled
--   display_name  shown in menus (defaults to name)
--   model         model name in Assets.Models.Fruits
--   status        "model_ready" / "awaiting_model" (informational only)
--   enabled       false = ignored by the game
--   rarity, boost, max_level, base_exp, exp_curve, description   - required before enabling (no stats are invented here)
--   base_value, icon (rbxassetid), scale (studs, default 4)      - optional

local Catalog = {
	-- ===== imported models (in Assets.Models.Fruits, 4 studs, upright, face -Z) =====
	{name = "Dragon Fruit", display_name = "Dragon Fruit", model = "Meshy_AI_Dragon_Fruit", status = "model_ready", enabled = true,
		rarity = "Epic", boost = 3, max_level = 75, base_exp = 450, exp_curve = 1.18,
		description = "A dragon fruit companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Coconut", display_name = "Coconut", model = "Meshy_AI_Coconut", status = "model_ready", enabled = true,
		rarity = "Common", boost = 0.35, max_level = 50, base_exp = 110, exp_curve = 1.15,
		description = "A coconut companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Mango", display_name = "Mango", model = "Meshy_AI_Mango", status = "model_ready", enabled = true,
		rarity = "Common", boost = 0.4, max_level = 50, base_exp = 120, exp_curve = 1.15,
		description = "A mango companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Lemon", display_name = "Lemon", model = "Meshy_AI_Lemon", status = "model_ready", enabled = true,
		rarity = "Common", boost = 0.35, max_level = 50, base_exp = 110, exp_curve = 1.15,
		description = "A lemon companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Kiwi", display_name = "Kiwi", model = "Meshy_AI_Kiwi", status = "model_ready", enabled = true,
		rarity = "Rare", boost = 0.75, max_level = 60, base_exp = 200, exp_curve = 1.16,
		description = "A kiwi companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Peach", display_name = "Peach", model = "Meshy_AI_Peach", status = "model_ready", enabled = true,
		rarity = "Rare", boost = 0.8, max_level = 60, base_exp = 220, exp_curve = 1.16,
		description = "A peach companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Blueberry", display_name = "Blueberry", model = "Meshy_AI_Blueberry", status = "model_ready", enabled = true,
		rarity = "Rare", boost = 0.85, max_level = 60, base_exp = 240, exp_curve = 1.16,
		description = "A blueberry companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Orange", display_name = "Orange", model = "Meshy_AI_Orange", status = "model_ready", enabled = true,
		rarity = "Common", boost = 0.4, max_level = 50, base_exp = 120, exp_curve = 1.15,
		description = "A orange companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Watermelon", display_name = "Watermelon", model = "Meshy_AI_Watermelon", status = "model_ready", enabled = true,
		rarity = "Rare", boost = 1, max_level = 60, base_exp = 280, exp_curve = 1.16,
		description = "A watermelon companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Banana", display_name = "Banana", model = "Meshy_AI_Banana", status = "model_ready", enabled = true,
		rarity = "Common", boost = 0.45, max_level = 50, base_exp = 130, exp_curve = 1.15,
		description = "A banana companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Grape", display_name = "Grape", model = "Meshy_AI_Grape", status = "model_ready", enabled = true,
		rarity = "Rare", boost = 0.9, max_level = 60, base_exp = 250, exp_curve = 1.16,
		description = "A grape companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	{name = "Pineapple", display_name = "Pineapple", model = "Meshy_AI_Pineapple", status = "model_ready", enabled = true,
		rarity = "Epic", boost = 2, max_level = 75, base_exp = 400, exp_curve = 1.18,
		description = "A pineapple companion that makes your crops grow faster.", can_awaken = false, CanMount = false, scale = 4},
	-- ===== upcoming fruits (model not imported yet) =====
	{name = "Pomegranate", display_name = "Pomegranate", model = "Meshy_AI_Pomegranate", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Rambutan", display_name = "Rambutan", model = "Meshy_AI_Rambutan", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Starfruit", display_name = "Starfruit", model = "Meshy_AI_Starfruit", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Raspberry", display_name = "Raspberry", model = "Meshy_AI_Raspberry", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Mangosteen", display_name = "Mangosteen", model = "Meshy_AI_Mangosteen", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Durian", display_name = "Durian", model = "Meshy_AI_Durian", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Papaya", display_name = "Papaya", model = "Meshy_AI_Papaya", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Fig", display_name = "Fig", model = "Meshy_AI_Fig", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Lime", display_name = "Lime", model = "Meshy_AI_Lime", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Passion Fruit", display_name = "Passion Fruit", model = "Meshy_AI_Passion_Fruit", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Lychee", display_name = "Lychee", model = "Meshy_AI_Lychee", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Cantaloupe", display_name = "Cantaloupe", model = "Meshy_AI_Cantaloupe", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Blackberry", display_name = "Blackberry", model = "Meshy_AI_Blackberry", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
	{name = "Persimmon", display_name = "Persimmon", model = "Meshy_AI_Persimmon", status = "awaiting_model", enabled = false,
		rarity = nil, boost = nil, base_value = nil, icon = nil, scale = nil},
}

local REQUIRED = {"rarity", "boost", "max_level", "base_exp", "exp_curve"}

-- the entries that are ready to be real fruits (used by Databases.Fruits.Fruits)
local function ready()
	local list = {}
	for _, e in ipairs(Catalog) do
		if e.enabled then
			local ok = true
			for _, k in ipairs(REQUIRED) do
				if e[k] == nil then
					ok = false
					warn("[FruitCatalog] " .. tostring(e.name) .. " is enabled but missing '" .. k .. "' - skipped")
					break
				end
			end
			if ok then
				table.insert(list, e)
			end
		end
	end
	return list
end

local function get(model)
	for _, e in ipairs(Catalog) do
		if e.model == model then
			return e
		end
	end
	return nil
end

return {list = Catalog, ready = ready, get = get}
