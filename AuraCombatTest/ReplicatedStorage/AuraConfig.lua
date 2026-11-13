-- ModuleScript "AuraConfig" -> ReplicatedStorage
-- Chaque aura = un "gant" : puissance de recul, cooldown, capacité spéciale (E)
return {
	HitRange = 7,
	RagdollTime = 1.2,
	VoidY = -30, -- en dessous = éliminé

	Auras = {
		{ Name = "Normale", Color = Color3.fromRGB(200, 200, 255), Power = 60,  Cooldown = 0.8, Ability = "None",     AbilityCd = 0,  Desc = "Aura de base." },
		{ Name = "Feu",     Color = Color3.fromRGB(255, 90, 30),   Power = 75,  Cooldown = 1.0, Ability = "Dash",     AbilityCd = 5,  Desc = "E : ruée enflammée vers l'avant." },
		{ Name = "Glace",   Color = Color3.fromRGB(120, 220, 255), Power = 55,  Cooldown = 0.9, Ability = "Freeze",   AbilityCd = 8,  Desc = "E : gèle les ennemis proches 2s." },
		{ Name = "Foudre",  Color = Color3.fromRGB(255, 240, 60),  Power = 50,  Cooldown = 0.5, Ability = "Speed",    AbilityCd = 10, Desc = "Frappe rapide. E : vitesse x2 pendant 4s." },
		{ Name = "Vent",    Color = Color3.fromRGB(180, 255, 180), Power = 65,  Cooldown = 1.0, Ability = "Gust",     AbilityCd = 7,  Desc = "E : bourrasque qui repousse tout autour." },
		{ Name = "Ombre",   Color = Color3.fromRGB(110, 40, 160),  Power = 70,  Cooldown = 1.1, Ability = "Teleport", AbilityCd = 9,  Desc = "E : se téléporte derrière l'ennemi le plus proche." },
		{ Name = "Titan",   Color = Color3.fromRGB(255, 40, 80),   Power = 140, Cooldown = 3.0, Ability = "None",     AbilityCd = 0,  Desc = "Énorme recul, très lent." },
	},
}
