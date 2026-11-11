-- SmashMaps (ModuleScript dans ReplicatedStorage)
-- Liste des arènes. Coordonnées relatives à Config.ARENA_ORIGIN (Y = 0 = dessus de la scène principale).
-- kind = "solid" (sol), "platform" (traversable par-dessous), "deco" (sans collision)

local V = Vector3.new
local C = Color3.fromRGB
local M = Enum.Material

local Maps = {}

Maps[1] = {
	name = "Temple du Ciel",
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
		{ kind = "platform", size = V(14, 1, 10), pos = V(0, 23, 0), color = C(255, 220, 120), material = M.SmoothPlastic },
		{ kind = "deco", size = V(3, 30, 3), pos = V(-40, -10, -30), color = C(240, 240, 250), material = M.Marble },
		{ kind = "deco", size = V(3, 30, 3), pos = V(40, -10, -30), color = C(240, 240, 250), material = M.Marble },
	},
}

Maps[2] = {
	name = "Plateau Final",
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
		{ kind = "platform", size = V(14, 1, 10), pos = V(0, 10, 0), color = C(160, 110, 70), material = M.Wood },
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
}

Maps[5] = {
	name = "Glacier",
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
}

return Maps
