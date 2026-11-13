-- ModuleScript "AuraConfig" -> ReplicatedStorage
return {
	MaxAura = 100,
	ChargeRate = 25,      -- aura par seconde en chargeant (C maintenu)
	RegenRate = 3,        -- regen passive par seconde
	MaxHealth = 150,

	Punch = { Damage = 8,  Range = 6,  Cooldown = 0.45, AuraGain = 5 },
	Blast = { Damage = 25, Speed = 90, Cost = 30, Cooldown = 1.2, Radius = 3, Lifetime = 2 },
	Burst = { Damage = 40, Radius = 14, Cost = 70, Cooldown = 6, Knockback = 70 },

	-- Paliers d'aura : couleur + multiplicateur de dégâts
	Tiers = {
		{ Min = 0,  Color = Color3.fromRGB(120, 180, 255), Mult = 1.0, Name = "Calme" },
		{ Min = 40, Color = Color3.fromRGB(255, 200, 60),  Mult = 1.25, Name = "Éveillé" },
		{ Min = 80, Color = Color3.fromRGB(255, 60, 60),   Mult = 1.6, Name = "Déchaîné" },
	},
}
