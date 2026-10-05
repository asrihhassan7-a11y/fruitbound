--> Variables
local _L = _G._L

local Network
local Pool

--> Constants

---------->
return {
	{
		-- Harvesting (kept under the name "Punch" so saves/gamepasses keep working)
		name = "Punch",
		idle_animation = nil,
		click_animation = {},
		click_audio = {name = "Plop1", volume = 0},
		cooldown = 0.35,
		effect = "Harvest"
	},
	
	{
		name = "Fireball",
		idle_animation = nil,
		click_animation = {"punch_right"},
		click_audio = {name = {"Whoosh1", "Whoosh2"}},
		cooldown = 1.5,
		effect = "Fireball"
	}
}