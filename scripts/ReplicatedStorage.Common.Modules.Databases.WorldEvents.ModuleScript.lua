--> WorldEvents database
-- Day/night cycle, random world events and crop mutations. Add new entries here, nothing else needed.

local WorldEvents = {}

-- ============================================================
-- DAY / NIGHT (one full day in seconds, and the phases in ClockTime hours)
-- ============================================================
WorldEvents.DAY_LENGTH = 16 * 60 -- 16 real minutes per in-game day
WorldEvents.PHASES = {
	{id = "Morning", from = 5, to = 9, emoji = "🌅"},
	{id = "Day", from = 9, to = 17, emoji = "☀️"},
	{id = "Evening", from = 17, to = 20.5, emoji = "🌇"},
	{id = "Night", from = 20.5, to = 29, emoji = "🌙"}, -- 29 = 5 next morning
}

-- ============================================================
-- EVENTS
--   weight        how often it is picked (higher = more common)
--   when          "any", "day" or "night"
--   duration      {min, max} seconds
--   growth        crops regrow this much faster (1.5 = 50% faster)
--   mutations     {mutationId = chance per crop per roll}  (rolled every ROLL_EVERY seconds)
--   audio         optional client audio while the event runs (SoundFX):
--                   AmbientSound  looping sound name in Assets.Sounds (layers over the music)
--                   Volume        multiplier for that sound (1 = its own volume)
--                   FadeTime      seconds to fade in/out (default 3)
--                   MusicVolume   music multiplier during the event (1 = unchanged)
--                   MusicOverride sound name that replaces day/night music for the event
-- ============================================================
WorldEvents.FIRST_EVENT_DELAY = {240, 420} -- seconds after the server starts
WorldEvents.TIME_BETWEEN = {480, 900} -- 8-15 minutes between events
WorldEvents.ROLL_EVERY = 10

WorldEvents.Events = {
	{
		id = "Rain", name = "Rain", emoji = "🌧️",
		description = "Growing crops can become Wet!",
		color = Color3.fromRGB(110, 170, 240),
		weight = 40, when = "any", duration = {120, 180},
		mutations = {Wet = 0.05},
		audio = {AmbientSound = "Amb_Rain", Volume = 1, FadeTime = 4, MusicVolume = 0.75},
	},
	{
		id = "Storm", name = "Thunderstorm", emoji = "⛈️",
		description = "Lightning can Shock your crops!",
		color = Color3.fromRGB(120, 110, 200),
		weight = 15, when = "any", duration = {90, 140},
		mutations = {Wet = 0.05, Shocked = 0.025},
		audio = {AmbientSound = "Amb_Rain", Volume = 1.4, FadeTime = 3, MusicVolume = 0.7},
	},
	{
		id = "Sunny", name = "Sunny Skies", emoji = "☀️",
		description = "Crops grow 50% faster!",
		color = Color3.fromRGB(255, 200, 60),
		weight = 30, when = "day", duration = {150, 210},
		growth = 1.5,
		mutations = {Sunkissed = 0.02},
	},
	{
		id = "Moonlight", name = "Moonlight", emoji = "🌙",
		description = "The moon blesses crops: Moonlit mutations!",
		color = Color3.fromRGB(170, 190, 255),
		weight = 25, when = "night", duration = {120, 180},
		mutations = {Moonlit = 0.03},
	},
	{
		id = "Rainbow", name = "Rainbow", emoji = "🌈",
		description = "A rare Rainbow! Crops can turn Rainbow!",
		color = Color3.fromRGB(255, 130, 200),
		weight = 6, when = "day", duration = {75, 110},
		mutations = {Rainbow = 0.015},
	},
}

-- ============================================================
-- MUTATIONS
--   tier   a crop only changes to a HIGHER tier (Wet -> Rainbow, never back)
--   value  selling price multiplier of picked crops
--   effect client visual: "drops", "sparks", "glow", "rainbow", "sun"
-- ============================================================
WorldEvents.Mutations = {
	Wet = {id = "Wet", name = "Wet", tier = 1, value = 2, color = Color3.fromRGB(90, 170, 255), effect = "drops"},
	Sunkissed = {id = "Sunkissed", name = "Sunkissed", tier = 2, value = 3, color = Color3.fromRGB(255, 200, 60), effect = "sun"},
	Shocked = {id = "Shocked", name = "Shocked", tier = 3, value = 5, color = Color3.fromRGB(255, 240, 90), effect = "sparks"},
	Moonlit = {id = "Moonlit", name = "Moonlit", tier = 4, value = 6, color = Color3.fromRGB(180, 200, 255), effect = "glow"},
	Rainbow = {id = "Rainbow", name = "Rainbow", tier = 5, value = 12, color = Color3.fromRGB(255, 120, 220), effect = "rainbow"},
}

return WorldEvents
