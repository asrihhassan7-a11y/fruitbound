-- SmashMaps (ModuleScript dans ReplicatedStorage)
-- Liste des arènes. Coordonnées relatives à Config.ARENA_ORIGIN (Y = 0 = dessus de la scène principale).
-- kind = "solid" (sol), "platform" (traversable par-dessous), "deco" (sans collision)
-- move = { offset = Vector3, period = secondes } : la pièce fait des allers-retours
-- hazards = pièges : { type = "geyser", x = ..., interval = ... } ou { type = "icicle", interval = ... }

local V = Vector3.new
local C = Color3.fromRGB
local M = Enum.Material


-- Options des pièces : shape = "Ball" / "Cylinder" / "Wedge" • rot = Vector3 (degrés)
-- transparency, reflect, light = { color, range, brightness }, fire = taille, particles = Color3

----------------------------------------------------------------------
-- Petits constructeurs de décor
----------------------------------------------------------------------
local function add(list, t)
	t.kind = t.kind or "deco"
	table.insert(list, t)
	return t
end

local function tree(list, x, y, z, s, trunk, leaf, leafMat)
	s = s or 1
	add(list, { shape = "Cylinder", size = V(10 * s, 1.8 * s, 1.8 * s), pos = V(x, y + 5 * s, z), rot = V(0, 0, 90), color = trunk, material = M.Wood })
	add(list, { shape = "Ball", size = V(9, 9, 9) * s, pos = V(x, y + 11 * s, z), color = leaf, material = leafMat or M.Grass })
	add(list, { shape = "Ball", size = V(7, 7, 7) * s, pos = V(x - 3.5 * s, y + 9 * s, z + 1), color = leaf, material = leafMat or M.Grass })
	add(list, { shape = "Ball", size = V(7, 7, 7) * s, pos = V(x + 3.5 * s, y + 9.5 * s, z - 1), color = leaf, material = leafMat or M.Grass })
end

local function palm(list, x, y, z, s)
	s = s or 1
	add(list, { shape = "Cylinder", size = V(14 * s, 1.4 * s, 1.4 * s), pos = V(x + 1.5 * s, y + 7 * s, z), rot = V(0, 0, 80), color = C(150, 110, 70), material = M.Wood })
	local top = V(x + 2.8 * s, y + 14 * s, z)
	for i = 0, 5 do
		add(list, { size = V(9 * s, 0.4, 2.2 * s), pos = top + V(math.cos(i * 1.05) * 3.5 * s, -1 * s, math.sin(i * 1.05) * 3.5 * s),
			rot = V(0, -math.deg(i * 1.05), -25), color = C(60, 170, 70), material = M.Grass })
	end
	add(list, { shape = "Ball", size = V(1.4, 1.4, 1.4) * s, pos = top + V(0, -1 * s, 0.8), color = C(110, 80, 40), material = M.Wood })
end

local function building(list, x, z, w, h, color, windows, baseY)
	baseY = baseY or -60
	local cy = baseY + h / 2
	add(list, { size = V(w, h, 10), pos = V(x, cy, z), color = color, material = M.Concrete })
	for fy = baseY + 6, baseY + h - 4, 6 do
		add(list, { size = V(w - 2, 1.2, 0.3), pos = V(x, fy, z + 5.1), color = windows, material = M.Neon, transparency = 0.15 })
	end
	add(list, { shape = "Cylinder", size = V(6, 0.4, 0.4), pos = V(x + w / 4, baseY + h + 3, z), rot = V(0, 0, 90), color = C(90, 90, 100), material = M.Metal })
	add(list, { shape = "Ball", size = V(0.9, 0.9, 0.9), pos = V(x + w / 4, baseY + h + 6.2, z), color = C(255, 50, 50), material = M.Neon })
end

local function lantern(list, x, y, z, color, h)
	h = h or 6
	add(list, { shape = "Cylinder", size = V(h, 0.5, 0.5), pos = V(x, y + h / 2, z), rot = V(0, 0, 90), color = C(60, 50, 45), material = M.Metal })
	add(list, { size = V(1.6, 2, 1.6), pos = V(x, y + h + 0.8, z), color = color, material = M.Neon, light = { color = color, range = 14 } })
	add(list, { shape = "Wedge", size = V(2.4, 0.8, 1.2), pos = V(x, y + h + 2.2, z + 0.6), rot = V(0, 180, 0), color = C(60, 50, 45), material = M.Metal })
	add(list, { shape = "Wedge", size = V(2.4, 0.8, 1.2), pos = V(x, y + h + 2.2, z - 0.6), color = C(60, 50, 45), material = M.Metal })
end

local function crystal(list, x, y, z, s, color)
	add(list, { size = V(2.5, 8, 2.5) * s, pos = V(x, y + 3 * s, z), rot = V(0, 45, 12), color = color, material = M.Glass, transparency = 0.2, light = { color = color, range = 10 } })
	add(list, { size = V(1.6, 5, 1.6) * s, pos = V(x + 2 * s, y + 2 * s, z + 1), rot = V(0, 20, -25), color = color, material = M.Neon, transparency = 0.3 })
end

local function mushroom(list, x, y, z, s, cap, stem)
	s = s or 1
	add(list, { shape = "Cylinder", size = V(5 * s, 1.6 * s, 1.6 * s), pos = V(x, y + 2.5 * s, z), rot = V(0, 0, 90), color = stem or C(240, 230, 210), material = M.SmoothPlastic })
	add(list, { shape = "Cylinder", size = V(1.6 * s, 7 * s, 7 * s), pos = V(x, y + 5.5 * s, z), rot = V(0, 0, 90), color = cap, material = M.Neon, transparency = 0.1, light = { color = cap, range = 10 * s } })
end

local function torii(list, x, y, z, s, color)
	s = s or 1
	for _, dx in ipairs({ -6, 6 }) do
		add(list, { shape = "Cylinder", size = V(16 * s, 1.4 * s, 1.4 * s), pos = V(x + dx * s, y + 8 * s, z), rot = V(0, 0, 90), color = color, material = M.SmoothPlastic })
	end
	add(list, { size = V(18 * s, 1.4 * s, 1.8 * s), pos = V(x, y + 16.5 * s, z), color = C(30, 20, 20), material = M.SmoothPlastic })
	add(list, { size = V(15 * s, 1 * s, 1.2 * s), pos = V(x, y + 13.5 * s, z), color = color, material = M.SmoothPlastic })
end

local function pyramid(list, x, y, z, s, color)
	add(list, { shape = "Wedge", size = V(s * 2, s, s), pos = V(x, y + s / 2, z + s / 2), rot = V(0, 180, 0), color = color, material = M.Sandstone })
	add(list, { shape = "Wedge", size = V(s * 2, s, s), pos = V(x, y + s / 2, z - s / 2), color = color, material = M.Sandstone })
end

local function tower(list, x, y, z, w, h, color, roof)
	add(list, { shape = "Cylinder", size = V(h, w, w), pos = V(x, y + h / 2, z), rot = V(0, 0, 90), color = color, material = M.Cobblestone })
	add(list, { shape = "Wedge", size = V(w + 2, w, (w + 2) / 2), pos = V(x, y + h + w / 2, z + (w + 2) / 4), rot = V(0, 180, 0), color = roof, material = M.Slate })
	add(list, { shape = "Wedge", size = V(w + 2, w, (w + 2) / 2), pos = V(x, y + h + w / 2, z - (w + 2) / 4), color = roof, material = M.Slate })
	add(list, { size = V(1.2, 2, 0.3), pos = V(x, y + h * 0.7, z + w / 2 + 0.1), color = C(255, 200, 90), material = M.Neon, light = { color = C(255, 180, 80), range = 10 } })
end

local Maps = {}

Maps[1] = {
	name = "Temple du Ciel",
	bg = "clouds", -- style du fond animé (clouds, stars, sunset, lava, snow)
	desc = "Classique : une scène et 3 plateformes",
	icon = C(120, 200, 255),
	blast = { x = 95, top = 85, bottom = 60 },
	camRangeX = 35,
	theme = { clock = 14, ambient = C(140, 150, 180), backdrop = C(110, 170, 235), fog = C(170, 210, 255) },
	spawns = { V(-20, 4, 0), V(20, 4, 0), V(-8, 4, 0), V(8, 4, 0), V(-17, 16, 0), V(17, 16, 0) },
	respawn = V(0, 30, 0),
	parts = {
		{ kind = "solid", size = V(60, 6, 16), pos = V(0, -3, 0), color = C(225, 225, 235), material = M.Marble },
		{ kind = "deco", size = V(60.4, 0.6, 16.4), pos = V(0, -0.2, 0), color = C(120, 200, 255), material = M.Neon },
		{ kind = "deco", size = V(40, 10, 12), pos = V(0, -11, 0), color = C(190, 190, 205), material = M.Marble },
		{ kind = "deco", size = V(20, 10, 8), pos = V(0, -20, 0), color = C(170, 170, 190), material = M.Marble },
		{ kind = "platform", size = V(16, 1, 10), pos = V(-17, 12, 0), color = C(255, 220, 120), material = M.SmoothPlastic },
		{ kind = "platform", size = V(16, 1, 10), pos = V(17, 12, 0), color = C(255, 220, 120), material = M.SmoothPlastic },
		{ kind = "platform", size = V(14, 1, 10), pos = V(0, 23, 0), color = C(255, 220, 120), material = M.SmoothPlastic,
			move = { offset = V(0, 6, 0), period = 7 } },
		{ kind = "deco", size = V(3, 30, 3), pos = V(-40, -10, -30), color = C(240, 240, 250), material = M.Marble },
		{ kind = "deco", size = V(3, 30, 3), pos = V(40, -10, -30), color = C(240, 240, 250), material = M.Marble },
	},
}

Maps[2] = {
	name = "Plateau Final",
	bg = "stars", -- style du fond animé (clouds, stars, sunset, lava, snow)
	desc = "Plat, sans plateformes : duel pur",
	icon = C(160, 90, 255),
	blast = { x = 100, top = 85, bottom = 60 },
	camRangeX = 40,
	theme = { clock = 0, ambient = C(90, 60, 140), backdrop = C(20, 10, 45), fog = C(40, 20, 80) },
	spawns = { V(-28, 4, 0), V(28, 4, 0), V(-12, 4, 0), V(12, 4, 0), V(-36, 4, 0), V(36, 4, 0) },
	respawn = V(0, 28, 0),
	parts = {
		{ kind = "solid", size = V(80, 6, 16), pos = V(0, -3, 0), color = C(40, 30, 70), material = M.Glass },
		{ kind = "deco", size = V(80.4, 0.6, 16.4), pos = V(0, -0.2, 0), color = C(180, 100, 255), material = M.Neon },
		{ kind = "deco", size = V(50, 8, 12), pos = V(0, -10, 0), color = C(30, 20, 55), material = M.Glass },
		{ kind = "deco", size = V(24, 8, 8), pos = V(0, -18, 0), color = C(25, 15, 45), material = M.Glass },
		{ kind = "deco", size = V(4, 4, 4), pos = V(0, -24, 0), color = C(200, 120, 255), material = M.Neon },
	},
}

Maps[3] = {
	name = "Îles Jumelles",
	bg = "sunset", -- style du fond animé (clouds, stars, sunset, lava, snow)
	desc = "Deux îles séparées par un vide",
	icon = C(90, 220, 120),
	blast = { x = 110, top = 85, bottom = 55 },
	camRangeX = 45,
	theme = { clock = 17.5, ambient = C(170, 140, 110), backdrop = C(255, 170, 110), fog = C(255, 200, 150) },
	spawns = { V(-30, 4, 0), V(30, 4, 0), V(-20, 4, 0), V(20, 4, 0), V(-26, 18, 0), V(26, 18, 0) },
	respawn = V(0, 30, 0),
	parts = {
		{ kind = "solid", size = V(34, 6, 16), pos = V(-26, -3, 0), color = C(110, 190, 90), material = M.Grass },
		{ kind = "solid", size = V(34, 6, 16), pos = V(26, -3, 0), color = C(110, 190, 90), material = M.Grass },
		{ kind = "deco", size = V(26, 14, 12), pos = V(-26, -13, 0), color = C(130, 95, 70), material = M.Rock },
		{ kind = "deco", size = V(26, 14, 12), pos = V(26, -13, 0), color = C(130, 95, 70), material = M.Rock },
		{ kind = "platform", size = V(14, 1, 10), pos = V(0, 8, 0), color = C(160, 110, 70), material = M.Wood,
			move = { offset = V(16, 0, 0), period = 9 } },
		{ kind = "platform", size = V(12, 1, 10), pos = V(-26, 14, 0), color = C(160, 110, 70), material = M.Wood },
		{ kind = "platform", size = V(12, 1, 10), pos = V(26, 14, 0), color = C(160, 110, 70), material = M.Wood },
		{ kind = "deco", size = V(2, 10, 2), pos = V(-36, 5, -5), color = C(120, 80, 50), material = M.Wood },
		{ kind = "deco", size = V(8, 8, 8), pos = V(-36, 12, -5), color = C(60, 160, 60), material = M.Grass },
		{ kind = "deco", size = V(2, 10, 2), pos = V(36, 5, -5), color = C(120, 80, 50), material = M.Wood },
		{ kind = "deco", size = V(8, 8, 8), pos = V(36, 12, -5), color = C(60, 160, 60), material = M.Grass },
	},
}

Maps[4] = {
	name = "Volcan",
	bg = "lava", -- style du fond animé (clouds, stars, sunset, lava, snow)
	desc = "Petite scène, plateformes en escalier",
	icon = C(255, 100, 40),
	blast = { x = 85, top = 85, bottom = 40 },
	camRangeX = 30,
	theme = { clock = 20, ambient = C(150, 70, 40), backdrop = C(70, 20, 15), fog = C(120, 40, 20) },
	spawns = { V(-15, 4, 0), V(15, 4, 0), V(-5, 4, 0), V(5, 4, 0), V(-14, 13, 0), V(14, 13, 0) },
	respawn = V(0, 30, 0),
	parts = {
		{ kind = "solid", size = V(44, 6, 16), pos = V(0, -3, 0), color = C(60, 50, 50), material = M.Basalt },
		{ kind = "deco", size = V(44.4, 0.6, 16.4), pos = V(0, -0.2, 0), color = C(255, 110, 30), material = M.Neon },
		{ kind = "deco", size = V(30, 12, 12), pos = V(0, -12, 0), color = C(50, 40, 40), material = M.Basalt },
		{ kind = "platform", size = V(11, 1, 10), pos = V(-14, 9, 0), color = C(90, 70, 65), material = M.Basalt },
		{ kind = "platform", size = V(11, 1, 10), pos = V(14, 9, 0), color = C(90, 70, 65), material = M.Basalt },
		{ kind = "platform", size = V(11, 1, 10), pos = V(0, 18, 0), color = C(90, 70, 65), material = M.Basalt },
		{ kind = "deco", size = V(300, 2, 120), pos = V(0, -36, 0), color = C(255, 90, 20), material = M.Neon },
	},
	hazards = {
		{ type = "geyser", x = -12, interval = 9, offset = 0 },
		{ type = "geyser", x = 12, interval = 9, offset = 4.5 },
	},
}

Maps[5] = {
	name = "Glacier",
	bg = "snow", -- style du fond animé (clouds, stars, sunset, lava, snow)
	desc = "Grande scène gelée et plateformes hautes",
	icon = C(180, 240, 255),
	blast = { x = 100, top = 90, bottom = 60 },
	camRangeX = 40,
	theme = { clock = 9, ambient = C(170, 200, 230), backdrop = C(200, 230, 250), fog = C(220, 240, 255) },
	spawns = { V(-24, 4, 0), V(24, 4, 0), V(-10, 4, 0), V(10, 4, 0), V(-20, 15, 0), V(20, 15, 0) },
	respawn = V(0, 32, 0),
	parts = {
		{ kind = "solid", size = V(66, 6, 16), pos = V(0, -3, 0), color = C(190, 230, 255), material = M.Ice },
		{ kind = "deco", size = V(46, 10, 12), pos = V(0, -11, 0), color = C(160, 210, 240), material = M.Ice },
		{ kind = "platform", size = V(12, 1, 10), pos = V(-22, 11, 0), color = C(230, 245, 255), material = M.Glacier },
		{ kind = "platform", size = V(12, 1, 10), pos = V(22, 11, 0), color = C(230, 245, 255), material = M.Glacier },
		{ kind = "platform", size = V(12, 1, 10), pos = V(-8, 20, 0), color = C(230, 245, 255), material = M.Glacier },
		{ kind = "platform", size = V(12, 1, 10), pos = V(8, 20, 0), color = C(230, 245, 255), material = M.Glacier },
		{ kind = "deco", size = V(6, 18, 6), pos = V(-45, 2, -25), color = C(200, 235, 255), material = M.Ice },
		{ kind = "deco", size = V(6, 24, 6), pos = V(48, 5, -30), color = C(200, 235, 255), material = M.Ice },
	},
	hazards = {
		{ type = "icicle", interval = 5, minX = -30, maxX = 30 },
	},
}


----------------------------------------------------------------------
-- 6. Cité Néon
----------------------------------------------------------------------
do
	local parts = {
		{ kind = "solid", size = V(64, 6, 16), pos = V(0, -3, 0), color = C(35, 35, 50), material = M.DiamondPlate },
		{ size = V(44, 60, 14), pos = V(0, -36, 0), color = C(30, 30, 45), material = M.Concrete },
		{ kind = "platform", size = V(14, 1, 10), pos = V(-19, 11, 0), color = C(255, 60, 180), material = M.SmoothPlastic },
		{ kind = "platform", size = V(14, 1, 10), pos = V(19, 11, 0), color = C(60, 220, 255), material = M.SmoothPlastic },
		{ kind = "platform", size = V(12, 1, 10), pos = V(0, 19, 0), color = C(255, 230, 80), material = M.SmoothPlastic,
			move = { offset = V(0, 5, 0), period = 6 } },
		-- panneaux néon sur la façade sous la scène
		{ size = V(12, 3, 0.3), pos = V(-10, -14, 7.2), color = C(255, 60, 180), material = M.Neon, light = { color = C(255, 60, 180), range = 16 } },
		{ size = V(10, 3, 0.3), pos = V(12, -22, 7.2), color = C(60, 220, 255), material = M.Neon, light = { color = C(60, 220, 255), range = 16 } },
		-- climatiseurs et antennes sur le toit (derrière)
		{ size = V(4, 3, 4), pos = V(-24, 1.5, -6), color = C(120, 120, 130), material = M.Metal },
		{ size = V(4, 3, 4), pos = V(22, 1.5, -6), color = C(120, 120, 130), material = M.Metal },
		{ shape = "Cylinder", size = V(12, 0.5, 0.5), pos = V(28, 6, -6), rot = V(0, 0, 90), color = C(100, 100, 110), material = M.Metal },
		{ shape = "Ball", size = V(1, 1, 1), pos = V(28, 12.5, -6), color = C(255, 40, 40), material = M.Neon, light = { color = C(255, 40, 40), range = 8 } },
	}
	local colors = { C(255, 60, 180), C(60, 220, 255), C(255, 230, 80), C(150, 90, 255) }
	for i = -4, 4 do
		local h = 70 + ((i * 37) % 5) * 12
		building(parts, i * 22, -38 - (i % 2) * 10, 16, h, C(25, 25, 40), colors[(i % 4) + 1], -65)
	end
	Maps[#Maps + 1] = {
		name = "Cité Néon",
		bg = "city",
		desc = "Toit d'immeuble, ascenseur et néons",
		icon = C(255, 60, 180),
		blast = { x = 98, top = 85, bottom = 60 },
		camRangeX = 38,
		theme = { clock = 0, ambient = C(90, 60, 130), backdrop = C(20, 10, 40), fog = C(60, 30, 90) },
		spawns = { V(-22, 4, 0), V(22, 4, 0), V(-8, 4, 0), V(8, 4, 0), V(-19, 15, 0), V(19, 15, 0) },
		respawn = V(0, 30, 0),
		parts = parts,
	}
end

----------------------------------------------------------------------
-- 7. Forêt Enchantée
----------------------------------------------------------------------
do
	local parts = {
		{ kind = "solid", size = V(62, 6, 16), pos = V(0, -3, 0), color = C(80, 160, 70), material = M.Grass },
		{ size = V(54, 10, 13), pos = V(0, -11, 0), color = C(100, 70, 45), material = M.Ground },
		{ size = V(36, 10, 10), pos = V(0, -20, 0), color = C(90, 60, 40), material = M.Ground },
		{ kind = "platform", size = V(13, 1, 10), pos = V(-18, 10, 0), color = C(230, 70, 90), material = M.SmoothPlastic },
		{ kind = "platform", size = V(13, 1, 10), pos = V(18, 10, 0), color = C(120, 90, 230), material = M.SmoothPlastic },
		{ kind = "platform", size = V(13, 1, 10), pos = V(0, 20, 0), color = C(70, 200, 160), material = M.SmoothPlastic },
		-- tiges des champignons-plateformes (derrière)
		{ shape = "Cylinder", size = V(10, 2, 2), pos = V(-18, 5, -3), rot = V(0, 0, 90), color = C(240, 230, 210) },
		{ shape = "Cylinder", size = V(10, 2, 2), pos = V(18, 5, -3), rot = V(0, 0, 90), color = C(240, 230, 210) },
		{ shape = "Cylinder", size = V(20, 2, 2), pos = V(0, 10, -3), rot = V(0, 0, 90), color = C(240, 230, 210) },
		-- racines qui pendent
		{ shape = "Cylinder", size = V(12, 1, 1), pos = V(-15, -22, 4), rot = V(0, 0, 80), color = C(110, 80, 50), material = M.Wood },
		{ shape = "Cylinder", size = V(10, 1, 1), pos = V(14, -20, 4), rot = V(0, 0, 100), color = C(110, 80, 50), material = M.Wood },
	}
	tree(parts, -40, -2, -18, 2.2, C(90, 60, 40), C(40, 120, 60))
	tree(parts, 42, -2, -20, 2.5, C(90, 60, 40), C(50, 140, 70))
	tree(parts, -15, -2, -32, 2.8, C(80, 55, 35), C(35, 105, 55))
	tree(parts, 20, -2, -35, 3, C(80, 55, 35), C(45, 125, 65))
	mushroom(parts, -26, 0, -5, 0.8, C(255, 90, 140))
	mushroom(parts, 27, 0, -6, 1, C(120, 220, 255))
	mushroom(parts, 8, 0, -7, 0.6, C(255, 220, 90))
	crystal(parts, -8, 0, -6, 0.7, C(160, 120, 255))
	Maps[#Maps + 1] = {
		name = "Forêt Enchantée",
		bg = "forest",
		desc = "Champignons lumineux et lucioles",
		icon = C(90, 220, 140),
		blast = { x = 96, top = 85, bottom = 60 },
		camRangeX = 36,
		theme = { clock = 21, ambient = C(80, 120, 110), backdrop = C(20, 45, 40), fog = C(40, 90, 80) },
		spawns = { V(-22, 4, 0), V(22, 4, 0), V(-8, 4, 0), V(8, 4, 0), V(-18, 14, 0), V(18, 14, 0) },
		respawn = V(0, 32, 0),
		parts = parts,
	}
end

----------------------------------------------------------------------
-- 8. Plage Tropicale
----------------------------------------------------------------------
do
	local parts = {
		{ kind = "solid", size = V(70, 6, 16), pos = V(0, -3, 0), color = C(240, 215, 150), material = M.Sand },
		{ size = V(60, 8, 13), pos = V(0, -10, 0), color = C(200, 170, 110), material = M.Sandstone },
		{ size = V(400, 1, 200), pos = V(0, -18, 0), color = C(40, 160, 220), material = M.Glass, transparency = 0.25, reflect = 0.2 },
		{ kind = "platform", size = V(14, 1, 10), pos = V(-22, 10, 0), color = C(170, 120, 75), material = M.WoodPlanks },
		{ kind = "platform", size = V(14, 1, 10), pos = V(22, 10, 0), color = C(170, 120, 75), material = M.WoodPlanks },
		{ kind = "platform", size = V(16, 1, 10), pos = V(0, 17, 0), color = C(250, 250, 250), material = M.SmoothPlastic,
			move = { offset = V(14, 0, 0), period = 8 } },
		-- pieds des pontons
		{ shape = "Cylinder", size = V(10, 1, 1), pos = V(-27, 5, -3), rot = V(0, 0, 90), color = C(130, 90, 55), material = M.Wood },
		{ shape = "Cylinder", size = V(10, 1, 1), pos = V(-17, 5, -3), rot = V(0, 0, 90), color = C(130, 90, 55), material = M.Wood },
		{ shape = "Cylinder", size = V(10, 1, 1), pos = V(17, 5, -3), rot = V(0, 0, 90), color = C(130, 90, 55), material = M.Wood },
		{ shape = "Cylinder", size = V(10, 1, 1), pos = V(27, 5, -3), rot = V(0, 0, 90), color = C(130, 90, 55), material = M.Wood },
		-- parasol + serviette
		{ shape = "Cylinder", size = V(8, 0.4, 0.4), pos = V(10, 4, -5), rot = V(0, 0, 90), color = C(240, 240, 240) },
		{ shape = "Cylinder", size = V(0.6, 8, 8), pos = V(10, 8, -5), rot = V(0, 0, 90), color = C(255, 90, 90) },
		{ size = V(3, 0.2, 6), pos = V(13, 0.1, -4), color = C(80, 160, 255) },
		-- château de sable
		{ size = V(3, 2, 3), pos = V(-8, 1, -5), color = C(230, 200, 130), material = M.Sand },
		{ size = V(1.5, 1.5, 1.5), pos = V(-8, 2.7, -5), color = C(230, 200, 130), material = M.Sand },
	}
	palm(parts, -30, 0, -5, 1)
	palm(parts, 32, 0, -6, 1.2)
	palm(parts, -50, -14, -30, 1.8)
	palm(parts, 55, -14, -35, 2)
	Maps[#Maps + 1] = {
		name = "Plage Tropicale",
		bg = "beach",
		desc = "Sable chaud, pontons et bateau qui navigue",
		icon = C(255, 210, 100),
		blast = { x = 105, top = 85, bottom = 50 },
		camRangeX = 42,
		theme = { clock = 13, ambient = C(180, 170, 150), backdrop = C(120, 200, 255), fog = C(190, 230, 255) },
		spawns = { V(-26, 4, 0), V(26, 4, 0), V(-10, 4, 0), V(10, 4, 0), V(-22, 14, 0), V(22, 14, 0) },
		respawn = V(0, 30, 0),
		parts = parts,
	}
end

----------------------------------------------------------------------
-- 9. Château Hanté
----------------------------------------------------------------------
do
	local parts = {
		{ kind = "solid", size = V(58, 6, 16), pos = V(0, -3, 0), color = C(90, 85, 100), material = M.Cobblestone },
		{ size = V(48, 14, 13), pos = V(0, -13, 0), color = C(70, 65, 80), material = M.Brick },
		{ kind = "platform", size = V(13, 1, 10), pos = V(-16, 11, 0), color = C(110, 100, 120), material = M.Slate },
		{ kind = "platform", size = V(13, 1, 10), pos = V(16, 11, 0), color = C(110, 100, 120), material = M.Slate },
		{ kind = "platform", size = V(12, 1, 10), pos = V(0, 21, 0), color = C(110, 100, 120), material = M.Slate },
		-- créneaux derrière la scène
		{ size = V(3, 3, 2), pos = V(-24, 1.5, -7), color = C(80, 75, 90), material = M.Cobblestone },
		{ size = V(3, 3, 2), pos = V(-12, 1.5, -7), color = C(80, 75, 90), material = M.Cobblestone },
		{ size = V(3, 3, 2), pos = V(12, 1.5, -7), color = C(80, 75, 90), material = M.Cobblestone },
		{ size = V(3, 3, 2), pos = V(24, 1.5, -7), color = C(80, 75, 90), material = M.Cobblestone },
		-- torches
		{ size = V(0.6, 2, 0.6), pos = V(-22, -8, 6.8), color = C(90, 60, 40), material = M.Wood, fire = 3 },
		{ size = V(0.6, 2, 0.6), pos = V(22, -8, 6.8), color = C(90, 60, 40), material = M.Wood, fire = 3 },
		-- vitrail
		{ size = V(4, 7, 0.3), pos = V(0, -12, 6.7), color = C(170, 80, 255), material = M.Neon, transparency = 0.3, light = { color = C(170, 80, 255), range = 14 } },
		-- tombes
		{ size = V(2, 3, 0.8), pos = V(-6, 1.5, -5), color = C(130, 130, 140), material = M.Slate },
		{ size = V(2, 2.5, 0.8), pos = V(5, 1.25, -6), color = C(130, 130, 140), material = M.Slate },
	}
	tower(parts, -36, -30, -12, 10, 50, C(80, 75, 90), C(60, 30, 90))
	tower(parts, 36, -30, -14, 10, 56, C(80, 75, 90), C(60, 30, 90))
	tower(parts, 0, -30, -40, 14, 70, C(70, 65, 80), C(50, 25, 80))
	Maps[#Maps + 1] = {
		name = "Château Hanté",
		bg = "spooky",
		desc = "Fantômes, chauves-souris et pleine lune",
		icon = C(170, 80, 255),
		blast = { x = 95, top = 85, bottom = 60 },
		camRangeX = 34,
		theme = { clock = 0, ambient = C(80, 60, 110), backdrop = C(25, 15, 40), fog = C(50, 30, 70) },
		spawns = { V(-20, 4, 0), V(20, 4, 0), V(-8, 4, 0), V(8, 4, 0), V(-16, 15, 0), V(16, 15, 0) },
		respawn = V(0, 32, 0),
		parts = parts,
	}
end

----------------------------------------------------------------------
-- 10. Station Spatiale (gravité faible !)
----------------------------------------------------------------------
do
	local parts = {
		{ kind = "solid", size = V(56, 4, 14), pos = V(0, -2, 0), color = C(180, 185, 195), material = M.DiamondPlate },
		{ size = V(40, 8, 10), pos = V(0, -8, 0), color = C(120, 125, 140), material = M.Metal },
		{ shape = "Cylinder", size = V(6, 6, 6), pos = V(-12, -14, 0), rot = V(0, 0, 90), color = C(90, 95, 110), material = M.Metal },
		{ shape = "Cylinder", size = V(6, 6, 6), pos = V(12, -14, 0), rot = V(0, 0, 90), color = C(90, 95, 110), material = M.Metal },
		{ size = V(3, 3, 3), pos = V(-12, -18, 0), color = C(80, 200, 255), material = M.Neon, particles = C(120, 220, 255), light = { color = C(80, 200, 255), range = 16 } },
		{ size = V(3, 3, 3), pos = V(12, -18, 0), color = C(80, 200, 255), material = M.Neon, particles = C(120, 220, 255), light = { color = C(80, 200, 255), range = 16 } },
		{ kind = "platform", size = V(12, 1, 10), pos = V(-18, 10, 0), color = C(80, 200, 255), material = M.Glass, transparency = 0.2,
			move = { offset = V(0, 4, 0), period = 5 } },
		{ kind = "platform", size = V(12, 1, 10), pos = V(18, 10, 0), color = C(80, 200, 255), material = M.Glass, transparency = 0.2,
			move = { offset = V(0, -4, 0), period = 5 } },
		{ kind = "platform", size = V(10, 1, 10), pos = V(0, 20, 0), color = C(255, 200, 80), material = M.Glass, transparency = 0.2 },
		-- panneaux solaires
		{ size = V(30, 0.4, 10), pos = V(-50, 0, -25), rot = V(0, 0, 15), color = C(30, 50, 120), material = M.Glass, reflect = 0.4 },
		{ size = V(30, 0.4, 10), pos = V(50, 0, -25), rot = V(0, 0, -15), color = C(30, 50, 120), material = M.Glass, reflect = 0.4 },
		{ shape = "Cylinder", size = V(70, 1.2, 1.2), pos = V(0, -2, -25), color = C(150, 150, 160), material = M.Metal },
		-- antenne
		{ shape = "Cylinder", size = V(14, 0.5, 0.5), pos = V(24, 7, -5), rot = V(0, 0, 90), color = C(200, 200, 210), material = M.Metal },
		{ shape = "Ball", size = V(1.2, 1.2, 1.2), pos = V(24, 14.5, -5), color = C(255, 60, 60), material = M.Neon, light = { color = C(255, 60, 60), range = 10 } },
	}
	Maps[#Maps + 1] = {
		name = "Station Spatiale",
		bg = "space",
		desc = "Gravité faible : on vole plus loin !",
		icon = C(80, 200, 255),
		gravity = 95,
		blast = { x = 100, top = 95, bottom = 60 },
		camRangeX = 38,
		theme = { clock = 0, ambient = C(120, 130, 160), backdrop = C(5, 5, 15), fog = C(10, 10, 30) },
		spawns = { V(-20, 4, 0), V(20, 4, 0), V(-7, 4, 0), V(7, 4, 0), V(-18, 15, 0), V(18, 15, 0) },
		respawn = V(0, 32, 0),
		parts = parts,
	}
end

----------------------------------------------------------------------
-- 11. Temple Sakura
----------------------------------------------------------------------
do
	local parts = {
		{ kind = "solid", size = V(60, 6, 16), pos = V(0, -3, 0), color = C(150, 95, 60), material = M.WoodPlanks },
		{ size = V(50, 12, 13), pos = V(0, -12, 0), color = C(140, 140, 135), material = M.Slate },
		{ kind = "platform", size = V(14, 1, 10), pos = V(-17, 11, 0), color = C(190, 50, 50), material = M.WoodPlanks },
		{ kind = "platform", size = V(14, 1, 10), pos = V(17, 11, 0), color = C(190, 50, 50), material = M.WoodPlanks },
		{ kind = "platform", size = V(12, 1, 10), pos = V(0, 21, 0), color = C(190, 50, 50), material = M.WoodPlanks },
		-- pagode au fond
		{ size = V(18, 10, 12), pos = V(0, -5, -45), color = C(200, 60, 50), material = M.SmoothPlastic },
		{ size = V(26, 1.5, 18), pos = V(0, 1, -45), color = C(40, 35, 35), material = M.Slate },
		{ size = V(14, 8, 10), pos = V(0, 6, -45), color = C(200, 60, 50), material = M.SmoothPlastic },
		{ size = V(22, 1.5, 15), pos = V(0, 11, -45), color = C(40, 35, 35), material = M.Slate },
		{ size = V(10, 7, 8), pos = V(0, 15, -45), color = C(200, 60, 50), material = M.SmoothPlastic },
		{ size = V(16, 1.5, 12), pos = V(0, 19.5, -45), color = C(40, 35, 35), material = M.Slate },
		{ shape = "Cylinder", size = V(8, 0.6, 0.6), pos = V(0, 24, -45), rot = V(0, 0, 90), color = C(220, 180, 60), material = M.Metal },
	}
	torii(parts, 0, 0, -10, 1.2, C(220, 50, 40))
	tree(parts, -34, -2, -12, 1.8, C(90, 60, 50), C(255, 170, 200), M.SmoothPlastic)
	tree(parts, 36, -2, -14, 2, C(90, 60, 50), C(255, 185, 210), M.SmoothPlastic)
	tree(parts, -55, -10, -35, 2.6, C(90, 60, 50), C(250, 160, 195), M.SmoothPlastic)
	lantern(parts, -22, 0, -5, C(255, 170, 80), 4)
	lantern(parts, 22, 0, -5, C(255, 170, 80), 4)
	Maps[#Maps + 1] = {
		name = "Temple Sakura",
		bg = "sakura",
		desc = "Pétales de cerisier et torii",
		icon = C(255, 150, 190),
		blast = { x = 96, top = 85, bottom = 60 },
		camRangeX = 36,
		theme = { clock = 16.5, ambient = C(190, 150, 160), backdrop = C(255, 200, 215), fog = C(255, 215, 225) },
		spawns = { V(-22, 4, 0), V(22, 4, 0), V(-8, 4, 0), V(8, 4, 0), V(-17, 15, 0), V(17, 15, 0) },
		respawn = V(0, 32, 0),
		parts = parts,
	}
end

----------------------------------------------------------------------
-- 12. Désert Antique
----------------------------------------------------------------------
do
	local parts = {
		{ kind = "solid", size = V(66, 6, 16), pos = V(0, -3, 0), color = C(220, 185, 120), material = M.Sandstone },
		{ size = V(56, 10, 13), pos = V(0, -11, 0), color = C(200, 165, 105), material = M.Sandstone },
		{ size = V(10, 3, 0.4), pos = V(0, -9, 6.7), color = C(80, 200, 220), material = M.Neon, light = { color = C(80, 200, 220), range = 12 } },
		{ kind = "platform", size = V(14, 1, 10), pos = V(-22, 10, 0), color = C(235, 200, 140), material = M.Sandstone },
		{ kind = "platform", size = V(14, 1, 10), pos = V(22, 10, 0), color = C(235, 200, 140), material = M.Sandstone },
		{ kind = "platform", size = V(12, 1, 10), pos = V(0, 18, 0), color = C(230, 180, 60), material = M.Metal,
			move = { offset = V(12, 0, 0), period = 7 } },
		-- obélisques
		{ size = V(3, 18, 3), pos = V(-28, 9, -6), color = C(210, 175, 110), material = M.Sandstone },
		{ size = V(3, 18, 3), pos = V(28, 9, -6), color = C(210, 175, 110), material = M.Sandstone },
		{ shape = "Ball", size = V(2, 2, 2), pos = V(-28, 19, -6), color = C(255, 210, 60), material = M.Neon, light = { color = C(255, 200, 80), range = 12 } },
		{ shape = "Ball", size = V(2, 2, 2), pos = V(28, 19, -6), color = C(255, 210, 60), material = M.Neon, light = { color = C(255, 200, 80), range = 12 } },
		-- cactus
		{ shape = "Cylinder", size = V(6, 1.6, 1.6), pos = V(-12, 3, -6), rot = V(0, 0, 90), color = C(70, 150, 70), material = M.Grass },
		{ shape = "Cylinder", size = V(3, 1, 1), pos = V(-10.8, 4, -6), rot = V(0, 0, 90), color = C(70, 150, 70), material = M.Grass },
	}
	pyramid(parts, -45, -40, -55, 45, C(225, 190, 125))
	pyramid(parts, 25, -40, -70, 60, C(215, 180, 115))
	pyramid(parts, 75, -40, -50, 30, C(225, 190, 125))
	palm(parts, 40, -2, -12, 1.4)
	Maps[#Maps + 1] = {
		name = "Désert Antique",
		bg = "desert",
		desc = "Pyramides, obélisques et tempête de sable",
		icon = C(230, 180, 90),
		blast = { x = 100, top = 85, bottom = 60 },
		camRangeX = 40,
		theme = { clock = 12, ambient = C(200, 170, 130), backdrop = C(250, 200, 140), fog = C(240, 210, 160) },
		spawns = { V(-26, 4, 0), V(26, 4, 0), V(-10, 4, 0), V(10, 4, 0), V(-22, 14, 0), V(22, 14, 0) },
		respawn = V(0, 30, 0),
		parts = parts,
	}
end

return Maps
