--!strict
-- FruitBoundAmbience: cozy day/night ambient audio identity.
-- Birds sing through the tropical day, crickets and frogs take over at night,
-- crossfading smoothly with the FruitBoundDayNight cycle (reads Lighting.ClockTime).
-- This script is the only owner of the bird / night loops; music and weather layers
-- (day/night music, Rain) are handled by the SoundFX controller.

local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local BIRD_VOLUME = 0.18
local NIGHT_VOLUME = 0.15
local FADE_FLOOR = 0.02 -- never fully silent, keeps the world alive

local birds = SoundService:FindFirstChild("AmbientBirds")
local night = SoundService:FindFirstChild("AmbientNight")

-- follow the Ambient volume slider (Settings) like every other ambience loop
local ambientGroup = SoundService:FindFirstChild("AmbientGroup")
if ambientGroup and ambientGroup:IsA("SoundGroup") then
	for _, s in ipairs({birds, night}) do
		if s and s:IsA("Sound") then
			s.SoundGroup = ambientGroup
		end
	end
end

-- birds go quiet while it rains (the rain loop itself is layered by SoundFX)
local WET_EVENTS = {Rain = true, Storm = true}

if birds and birds:IsA("Sound") then
	birds.Looped = true
	if not birds.IsPlaying then
		birds:Play()
	end
end

if night and night:IsA("Sound") then
	night.Looped = true
	if not night.IsPlaying then
		night:Play()
	end
end

-- Smooth daylight factor: 1 at noon, 0 at midnight, eased at dawn/dusk.
local function getDayness(): number
	local clockTime = Lighting.ClockTime
	return math.max(0, math.cos((clockTime - 12) / 24 * 2 * math.pi))
end

-- Crossfade loop
while task.wait(2) do
	if birds and birds:IsA("Sound") and night and night:IsA("Sound") then
		local dayness = getDayness()
		local wet = WET_EVENTS[workspace:GetAttribute("Event") :: any] == true
		local targetBirds = FADE_FLOOR + BIRD_VOLUME * dayness * (if wet then 0.15 else 1)
		local targetNight = FADE_FLOOR + NIGHT_VOLUME * (1 - dayness)

		-- Ease toward targets so the fade is gentle
		birds.Volume = birds.Volume + (targetBirds - birds.Volume) * 0.35
		night.Volume = night.Volume + (targetNight - night.Volume) * 0.35
	end
end
