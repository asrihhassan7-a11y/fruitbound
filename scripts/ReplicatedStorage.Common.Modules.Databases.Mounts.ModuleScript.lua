--> Mounts (database)
-- Every rideable mount lives here. To add a mount: add an entry + a model in
-- ReplicatedStorage.Assets.Models.Mounts (named like `model`). Nothing else needs to change.
--
--   id           unique key, saved in player data (never rename it once released!)
--   name         display name
--   emoji        icon used in menus / notifications (used when there's no `image`)
--   image        optional rbxassetid icon
--   model        model name in Assets.Models.Mounts
--   rarity       Common / Rare / Epic / Legendary / Mythical / Secret ...
--   speed        extra WalkSpeed while riding (0 = same as walking)
--   seat_height  optional override of the model's "SeatHeight" attribute (studs above the ground)
--   gait         leg-animation tuning: walk_rate, run_rate, run_speed (WalkSpeed where it starts galloping)
--   anim_set     AnimationPack clip set ("Deer" -> Deer_Idle / Deer_Walk ...; missing clips use Mount_*)
--   source       where it comes from: "code", "shop", "event", "limited", "robux", "quest", "achievement"
--   tradeable    reserved for a future trading system
--   hidden       true = not shown in the menu unless owned

local Mounts = {
	{
		id = "forest_deer",
		name = "Forest Deer",
		emoji = "🦌",
		model = "Forest Deer",
		rarity = "Rare",
		speed = 6,
		gait = {walk_rate = 1.1, run_rate = 1.6, run_speed = 20}, -- riding speed is 22: gallops at full speed
		anim_set = "Deer",
		source = "code",
		description = "A gentle deer from the forest. Carries you around your farm!",
		tradeable = false,
	},
}

local byId = {}
for i, info in ipairs(Mounts) do
	info.order = i
	byId[info.id] = info
end

return setmetatable({
	list = Mounts,
	getInfo = function(id)
		return byId[id]
	end,
}, {__index = byId})
