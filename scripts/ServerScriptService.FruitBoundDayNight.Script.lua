-- FruitBoundDayNight: cozy tropical day/night identity.
-- One full day lasts ~12 real minutes. Nights stay soft and readable
-- (never pitch black) so farming feels warm under the lantern light.

local Lighting = game:GetService("Lighting")

local DAY_LENGTH = 720 -- seconds for one full 24h cycle

-- Keyframes: [clockHour] = {Ambient, OutdoorAmbient, Brightness}
-- Warm mornings, golden afternoons, cozy blue-evening nights.
local KEYFRAMES = {
	[0]  = {Vector3.new(0.27, 0.30, 0.43), Vector3.new(0.34, 0.38, 0.53), 1.7},
	[5]  = {Vector3.new(0.33, 0.34, 0.47), Vector3.new(0.42, 0.44, 0.58), 1.8},
	[7]  = {Vector3.new(0.55, 0.47, 0.42), Vector3.new(0.68, 0.60, 0.53), 2.1},
	[9]  = {Vector3.new(0.49, 0.45, 0.41), Vector3.new(0.67, 0.62, 0.56), 2.3},
	[13] = {Vector3.new(0.49, 0.45, 0.41), Vector3.new(0.67, 0.62, 0.56), 2.3},
	[17] = {Vector3.new(0.56, 0.46, 0.38), Vector3.new(0.73, 0.61, 0.50), 2.2},
	[19] = {Vector3.new(0.46, 0.40, 0.45), Vector3.new(0.57, 0.49, 0.53), 1.9},
	[21] = {Vector3.new(0.29, 0.32, 0.45), Vector3.new(0.37, 0.40, 0.54), 1.75},
	[24] = {Vector3.new(0.27, 0.30, 0.43), Vector3.new(0.34, 0.38, 0.53), 1.7},
}

local function sortedHours()
	local hours = {}
	for h in pairs(KEYFRAMES) do
		table.insert(hours, h)
	end
	table.sort(hours)
	return hours
end
local HOURS = sortedHours()

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function sample(clock)
	-- find surrounding keyframes
	local lo, hi = HOURS[1], HOURS[#HOURS]
	for i = 1, #HOURS - 1 do
		if clock >= HOURS[i] and clock <= HOURS[i + 1] then
			lo, hi = HOURS[i], HOURS[i + 1]
			break
		end
	end
	local a, b = KEYFRAMES[lo], KEYFRAMES[hi]
	local span = (hi - lo)
	local t = span > 0 and ((clock - lo) / span) or 0
	return {
		ambient = Vector3.new(lerp(a[1].X, b[1].X, t), lerp(a[1].Y, b[1].Y, t), lerp(a[1].Z, b[1].Z, t)),
		outdoor = Vector3.new(lerp(a[2].X, b[2].X, t), lerp(a[2].Y, b[2].Y, t), lerp(a[2].Z, b[2].Z, t)),
		brightness = lerp(a[3], b[3], t),
	}
end

-- ============================================================
-- OUTDOOR LAMPS (one central controller for every lamp, driven by this clock)
-- Lamps are the Neon lamp parts tagged "OutdoorLamp" (Village, Farm Island, Orchard...).
-- Day: light off + lamp glass dimmed. Night: warm light on + glowing glass. Short fade.
-- To add a lamp: give its glowing part a PointLight/SpotLight and the "OutdoorLamp" tag.
-- ============================================================
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local NIGHT_START = 18.25 -- lamps switch on (clock hour)
local NIGHT_END = 6.5 -- lamps switch off
local LAMP_FADE = TweenInfo.new(1.5, Enum.EasingStyle.Sine)
local DIM_GLASS = Color3.fromRGB(205, 190, 160) -- unlit lamp glass

local function isNight(clock)
	return clock >= NIGHT_START or clock < NIGHT_END
end

local function setLamp(part, on, instant)
	if not part:IsA("BasePart") then
		return
	end
	local litColor = part:GetAttribute("LampColor")
	if typeof(litColor) ~= "Color3" then
		litColor = part.Color
		part:SetAttribute("LampColor", litColor)
	end
	part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	if instant then
		part.Color = if on then litColor else DIM_GLASS
	else
		TweenService:Create(part, LAMP_FADE, {Color = if on then litColor else DIM_GLASS}):Play()
	end
	for _, light in ipairs(part:GetChildren()) do
		if light:IsA("Light") then
			local base = light:GetAttribute("LampBrightness")
			if typeof(base) ~= "number" then
				base = light.Brightness
				light:SetAttribute("LampBrightness", base)
			end
			if on then
				light.Enabled = true
			end
			if instant then
				light.Brightness = if on then base else 0
				light.Enabled = on
			else
				local tween = TweenService:Create(light, LAMP_FADE, {Brightness = if on then base else 0})
				tween.Completed:Connect(function()
					if not on and light.Brightness <= 0.001 then
						light.Enabled = false
					end
				end)
				tween:Play()
			end
		end
	end
end

local lampsOn = nil
local function updateLamps(instant)
	local on = isNight(Lighting.ClockTime)
	if on == lampsOn and not instant then
		return
	end
	lampsOn = on
	for _, part in ipairs(CollectionService:GetTagged("OutdoorLamp")) do
		setLamp(part, on, instant)
	end
end
CollectionService:GetInstanceAddedSignal("OutdoorLamp"):Connect(function(part)
	if lampsOn ~= nil then
		setLamp(part, lampsOn, true)
	end
end)

-- Advance the cycle smoothly
local elapsed = 0
local lastTick = os.clock()

-- Start mid-morning for a welcoming first session
if Lighting.ClockTime < 6 or Lighting.ClockTime > 18 then
	Lighting.ClockTime = 9
end

updateLamps(true)

while true do
	task.wait(1)
	local now = os.clock()
	elapsed += now - lastTick
	lastTick = now

	-- Advance one second's worth of game time (24h over DAY_LENGTH seconds)
	Lighting.ClockTime = (Lighting.ClockTime + (24 / DAY_LENGTH)) % 24

	local s = sample(Lighting.ClockTime)
	Lighting.Ambient = Color3.new(s.ambient.X, s.ambient.Y, s.ambient.Z)
	Lighting.OutdoorAmbient = Color3.new(s.outdoor.X, s.outdoor.Y, s.outdoor.Z)
	Lighting.Brightness = s.brightness
	updateLamps(false)
end