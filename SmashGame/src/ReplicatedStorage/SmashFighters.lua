-- SmashFighters (ModuleScript dans ReplicatedStorage)
-- Personnages jouables, poses d'attaque, objets et sons.

local C = Color3.fromRGB
local F = {}

----------------------------------------------------------------------
-- Personnages
-- speed/jump : déplacement • airJumps : sauts en l'air
-- weight : multiplicateur de recul SUBI (plus petit = plus lourd)
-- power : multiplicateur de dégâts INFLIGÉS • scale : taille du perso
-- projSpeed / projPower / specialCooldown : réglages du projectile (E)
----------------------------------------------------------------------
F.Characters = {
	{ id = "Brawler", name = "Bagarreur", desc = "Équilibré, bon partout", color = C(255, 80, 80),
		speed = 26, jump = 55, airJumps = 1, weight = 1.0, power = 1.0, scale = 1.0,
		projSpeed = 75, projPower = 1.0, specialCooldown = 0.8 },
	{ id = "Flash", name = "Éclair", desc = "Très rapide, 2 sauts en l'air, mais léger", color = C(255, 220, 60),
		speed = 35, jump = 62, airJumps = 2, weight = 1.2, power = 0.85, scale = 0.85,
		projSpeed = 90, projPower = 0.8, specialCooldown = 0.7 },
	{ id = "Titan", name = "Titan", desc = "Lent mais frappe fort et dur à éjecter", color = C(120, 140, 160),
		speed = 20, jump = 50, airJumps = 1, weight = 0.75, power = 1.3, scale = 1.25,
		projSpeed = 60, projPower = 1.2, specialCooldown = 1.1 },
	{ id = "Mage", name = "Mage", desc = "Projectiles rapides et puissants", color = C(170, 100, 255),
		speed = 24, jump = 56, airJumps = 1, weight = 1.05, power = 0.9, scale = 1.0,
		projSpeed = 110, projPower = 1.6, specialCooldown = 0.45 },
}

function F.get(id)
	for _, c in ipairs(F.Characters) do
		if c.id == id then return c end
	end
	return F.Characters[1]
end

----------------------------------------------------------------------
-- Poses d'attaque (angles en degrés, vers l'avant = positif)
-- RightArm / LeftArm / RightLeg / LeftLeg : bascule avant-arrière • Waist : rotation du buste
-- windup = pose de préparation pendant le "startup" des smashs
----------------------------------------------------------------------
F.Poses = {
	JabSide   = { strike = { RightArm = 95, Waist = -25 } },
	JabUp     = { strike = { RightArm = 175, LeftArm = 40 } },
	JabDown   = { strike = { RightLeg = 70, LeftArm = 40 } },
	AirDown   = { strike = { RightLeg = -10, LeftLeg = -10, RightArm = 150, LeftArm = 150 } },
	SmashSide = { windup = { RightArm = -70, LeftArm = 30, Waist = 35 }, strike = { RightArm = 100, LeftArm = 100, Waist = -35 } },
	SmashUp   = { windup = { RightArm = -40, LeftArm = -40 }, strike = { RightArm = 180, LeftArm = 180 } },
	SmashDown = { windup = { RightLeg = 30 }, strike = { RightLeg = 80, LeftLeg = -50, RightArm = 60, LeftArm = 60 } },
	Special   = { strike = { RightArm = 90, LeftArm = 90 } },
	SpecialUp = { strike = { RightArm = 180, LeftArm = 180, RightLeg = 20 } },
	Shield    = { strike = { RightArm = 70, LeftArm = 70 }, hold = true },
	Ledge     = { strike = { RightArm = 170, LeftArm = 170 }, hold = true },
}

----------------------------------------------------------------------
-- Objets qui tombent sur la scène
----------------------------------------------------------------------
F.ITEM_INTERVAL = 12       -- secondes entre deux objets
F.ITEM_LIFETIME = 15
F.Items = {
	{ id = "Heal",   name = "Soin",     color = C(90, 255, 120), weight = 3, desc = "-35 %" },
	{ id = "Hammer", name = "Marteau",  color = C(255, 170, 40), weight = 2, desc = "Coups x1.6 pendant 10 s", duration = 10, mult = 1.6 },
	{ id = "Boots",  name = "Bottes",   color = C(80, 200, 255), weight = 2, desc = "Vitesse x1.4 pendant 8 s", duration = 8, mult = 1.4 },
	{ id = "Bomb",   name = "Bombe",    color = C(40, 40, 40),   weight = 2, desc = "Explose quand on la touche !",
		dmg = 16, base = 40, growth = 0.9, angle = 55, radius = 10 },
}

----------------------------------------------------------------------
-- Sons (fichiers intégrés à Roblox). Remplace par des "rbxassetid://..." si tu veux.
----------------------------------------------------------------------
F.Sounds = {
	Hit = "rbxasset://sounds/swordslash.wav",
	Smash = "rbxasset://sounds/swordlunge.wav",
	Jump = "rbxasset://sounds/action_jump.mp3",
	Beep = "rbxasset://sounds/electronicpingshort.wav",
	KO = "rbxasset://sounds/Rocket shot.wav",
	Pickup = "rbxasset://sounds/electronicpingshort.wav",
}

-- Musique : mets l'ID d'une musique de la boutique Créateur (ex : "rbxassetid://1234567").
-- Une musique par map possible avec le champ `music` dans SmashMaps.
F.MenuMusic = ""
F.FightMusic = ""
F.MusicVolume = 0.4

return F
