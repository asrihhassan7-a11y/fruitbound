-- Zones are islands laid out along +X. mult = reward multiplier for dragons in that zone.
local C = Color3.fromRGB
local list = {
	{ name = "Dragon Valley", icon = "🌄", cost = 0, mult = 1, ground = C(110, 200, 90), edge = C(140, 105, 70), decor = "meadow", tint = C(255, 255, 255), fog = C(190, 230, 255), accent = C(255, 220, 120) },
	{ name = "Forest Kingdom", icon = "🌲", cost = 1500, mult = 1.5, ground = C(60, 150, 70), edge = C(100, 75, 50), decor = "forest", tint = C(235, 255, 235), fog = C(170, 220, 180), accent = C(140, 255, 120) },
	{ name = "Volcano Island", icon = "🌋", cost = 12000, mult = 2.2, ground = C(70, 50, 50), edge = C(40, 30, 30), decor = "volcano", tint = C(255, 225, 205), fog = C(255, 160, 110), accent = C(255, 110, 30) },
	{ name = "Frozen Peaks", icon = "🏔️", cost = 70000, mult = 3.2, ground = C(225, 240, 255), edge = C(150, 190, 225), decor = "frozen", tint = C(230, 245, 255), fog = C(210, 235, 255), accent = C(140, 220, 255) },
	{ name = "Crystal Caverns", icon = "💠", cost = 350000, mult = 4.6, ground = C(70, 60, 120), edge = C(45, 35, 80), decor = "crystal", tint = C(240, 225, 255), fog = C(150, 110, 220), accent = C(110, 230, 255) },
	{ name = "Sky Kingdom", icon = "☁️", cost = 1800000, mult = 6.5, ground = C(245, 250, 255), edge = C(200, 215, 240), decor = "sky", tint = C(255, 255, 255), fog = C(200, 230, 255), accent = C(255, 230, 120) },
	{ name = "Ancient Dragon Lands", icon = "🏛️", cost = 9000000, mult = 9, ground = C(220, 190, 130), edge = C(160, 130, 80), decor = "ancient", tint = C(255, 240, 215), fog = C(240, 210, 160), accent = C(255, 200, 80) },
	{ name = "Shadow Realm", icon = "🌑", cost = 45000000, mult = 13, ground = C(45, 35, 60), edge = C(25, 20, 35), decor = "shadow", tint = C(215, 200, 240), fog = C(70, 40, 110), accent = C(180, 70, 255) },
	{ name = "Celestial Islands", icon = "✨", cost = 220000000, mult = 18, ground = C(255, 245, 220), edge = C(230, 200, 150), decor = "celestial", tint = C(255, 250, 230), fog = C(255, 235, 200), accent = C(255, 220, 90) },
	{ name = "Cosmic Dimension", icon = "🌌", cost = 1000000000, mult = 25, ground = C(30, 20, 60), edge = C(15, 10, 35), decor = "cosmic", tint = C(225, 210, 255), fog = C(40, 20, 90), accent = C(255, 90, 220) },
}

-- Layout: player farm plots sit in a row along X at z in [-PLOT_D, 0], facing +Z.
-- The shared throwing field lies in front of them; each zone is a band further away (zone 1 nearest).
-- Players can't walk into the field: they throw from their plot, and dragons come to the food.
local Zones = {
	List = list,
	PLOTS = 8,
	PLOT_W = 64,
	PLOT_D = 56,
	FIELD_START = 14, -- grass strip between fence (z=0) and zone 1
	BAND = 32, -- depth of each zone band
}
Zones.FIELD_W = Zones.PLOTS * Zones.PLOT_W
for i, z in list do
	z.index = i
end

-- z range of zone i
function Zones.band(i: number): (number, number)
	local z0 = Zones.FIELD_START + (i - 1) * Zones.BAND
	return z0, z0 + Zones.BAND
end

function Zones.center(i: number): Vector3
	local z0, z1 = Zones.band(i)
	return Vector3.new(0, 0, (z0 + z1) / 2)
end

-- Zone index of a field position, or nil.
function Zones.fromPosition(pos: Vector3): number?
	if math.abs(pos.X) > Zones.FIELD_W / 2 or pos.Z < Zones.FIELD_START then
		return nil
	end
	local i = math.floor((pos.Z - Zones.FIELD_START) / Zones.BAND) + 1
	if i > #list then
		return nil
	end
	return i
end

-- Plot i (1..PLOTS) centre on the ground.
function Zones.plotCenter(i: number): Vector3
	return Vector3.new((i - (Zones.PLOTS + 1) / 2) * Zones.PLOT_W, 0, -Zones.PLOT_D / 2)
end

-- Where the player stands to throw (front of the plot, facing the field).
function Zones.plotSpawn(i: number): CFrame
	local c = Zones.plotCenter(i)
	local p = Vector3.new(c.X, 4, -7)
	return CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
end

return Zones
