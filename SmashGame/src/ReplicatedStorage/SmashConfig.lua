-- SmashConfig (ModuleScript dans ReplicatedStorage)
-- Tous les réglages du jeu sont ici.

local Config = {}

-- Arène
Config.ARENA_ORIGIN = Vector3.new(0, 1000, 0) -- dessus de la scène (loin de la map existante)
-- Les arènes et leurs zones de KO sont dans le module SmashMaps

-- Partie
Config.STOCKS = 3
Config.ROUND_TIME = 180    -- secondes par manche (0 = illimité)
Config.VOTE_TIME = 15      -- secondes pour voter la map
Config.INTERMISSION = 6    -- secondes d'écran de résultats

-- Bots CPU : un bot par ligne (supprime des lignes pour en avoir moins)
-- think = délai de réaction (s), aggro = chance d'attaquer, smash = chance de smash, aim = précision
Config.BOTS = {
	{ name = "CPU Moyen",     think = 0.18, aggro = 0.70, smash = 0.25, special = 0.15, aim = 0.80, dodge = 0.15, ledge = true },
	{ name = "CPU Difficile", think = 0.09, aggro = 0.90, smash = 0.30, special = 0.20, aim = 0.95, dodge = 0.35, ledge = true },
	{ name = "CPU Expert",    think = 0.05, aggro = 1.00, smash = 0.35, special = 0.20, aim = 1.00, dodge = 0.60, ledge = true, finisher = true },
	{ name = "CPU Facile",    think = 0.30, aggro = 0.45, smash = 0.15, special = 0.08, aim = 0.60, dodge = 0.00, ledge = false },
}
Config.BOT_COUNT = 3 -- combien de bots de la liste ci-dessus sont utilisés (dans l'ordre)
-- dodge = chance d'esquiver/bloquer une attaque proche • finisher = cherche le smash quand tu es à haut %
Config.FILL_WITH_BOTS = true -- false = pas de bots quand il y a 2 vrais joueurs ou plus
Config.RESPAWN_INVINCIBILITY = 2
Config.GRAVITY = 140
Config.TRAINING_BAG_NAME = "Sac de frappe"

-- Caméra
Config.CAMERA_FOLLOW = true   -- false = caméra totalement fixe sur l'arène
Config.CAMERA_MIN_DIST = 17
Config.CAMERA_MAX_DIST = 48
Config.CAMERA_FIXED_DIST = 38

-- Déplacement
Config.WALK_SPEED = 26
Config.JUMP_POWER = 55
Config.AIR_JUMPS = 1
Config.AIR_JUMP_VELOCITY = 55
Config.FAST_FALL_SPEED = 90
Config.RECOVERY_VELOCITY = 80 -- E + haut en l'air : super saut (1 fois par saut)

-- Bouclier
Config.SHIELD_MAX = 100
Config.SHIELD_DRAIN = 18      -- par seconde
Config.SHIELD_REGEN = 10      -- par seconde
Config.SHIELD_BREAK_STUN = 2

-- Attaques : dmg (%), base / growth (recul), angle (degrés), hitbox
Config.ATTACKS = {
	JabSide   = { dmg = 4,  base = 14, growth = 0.18, angle = 35,  offset = Vector2.new(3.5, 0),  size = Vector3.new(5, 5, 6), cooldown = 0.28 },
	JabUp     = { dmg = 5,  base = 18, growth = 0.20, angle = 85,  offset = Vector2.new(0.5, 4),  size = Vector3.new(5, 5, 6), cooldown = 0.32 },
	JabDown   = { dmg = 5,  base = 14, growth = 0.16, angle = 20,  offset = Vector2.new(3, -2),   size = Vector3.new(6, 3, 6), cooldown = 0.30 },
	AirDown   = { dmg = 7,  base = 20, growth = 0.30, angle = -70, offset = Vector2.new(0, -3.5), size = Vector3.new(5, 4, 6), cooldown = 0.45 },
	SmashSide = { dmg = 13, base = 30, growth = 1.00, angle = 38,  offset = Vector2.new(4, 0),    size = Vector3.new(6, 5, 6), cooldown = 0.70, startup = 0.12 },
	SmashUp   = { dmg = 14, base = 30, growth = 0.95, angle = 88,  offset = Vector2.new(0, 4.5),  size = Vector3.new(6, 6, 6), cooldown = 0.70, startup = 0.12 },
	SmashDown = { dmg = 12, base = 28, growth = 0.90, angle = 25,  offset = Vector2.new(0, -1.5), size = Vector3.new(11, 3, 6), cooldown = 0.75, startup = 0.12, bothSides = true },
	SpecialUp = { dmg = 6,  base = 22, growth = 0.25, angle = 80,  offset = Vector2.new(0, 2),    size = Vector3.new(6, 7, 6), cooldown = 0.5 },
	Special   = { dmg = 6,  base = 12, growth = 0.12, angle = 20,  speed = 75, lifetime = 1.2, cooldown = 0.8 },
}
Config.SMASH_CHARGE_MAX = 1.0      -- secondes
Config.SMASH_CHARGE_BONUS = 0.6    -- +60% dégâts/recul à pleine charge
Config.HITSTUN_FACTOR = 0.007
Config.HITSTUN_MAX = 1.5

return Config
