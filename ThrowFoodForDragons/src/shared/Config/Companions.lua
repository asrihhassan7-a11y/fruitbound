-- Companion dragons hatched from eggs. Each companion reuses a wild dragon's look (mini size).
-- Bonus keys: coins (+x reward mult), xp (+x xp mult), power (+x throw power %), crit (+x crit chance).
local Rarities = require(script.Parent.Rarities)

local eggs = {
	{ id = "valley", name = "Valley Egg", icon = "🥚", zone = 1, cost = 800, color = Color3.fromRGB(150, 230, 120), looks = { "sproutling", "pebblewing", "meadowdrake", "bloomhorn", "valleywarden" } },
	{ id = "ember", name = "Ember Egg", icon = "🔥", zone = 3, cost = 40000, color = Color3.fromRGB(255, 110, 50), looks = { "cinderpup", "embersnout", "magmacrawler", "blazewyvern", "infernoking" } },
	{ id = "crystal", name = "Crystal Egg", icon = "💎", zone = 5, cost = 1500000, color = Color3.fromRGB(150, 120, 255), looks = { "shardling", "geodebiter", "prismdrake", "amethystwyrm", "diamondmonarch" } },
	{ id = "shadow", name = "Shadow Egg", icon = "🌑", zone = 8, cost = 200000000, color = Color3.fromRGB(110, 40, 170), looks = { "gloomling", "duskfang", "voidstalker", "nightmarewyvern", "shadowtyrant" } },
	{ id = "cosmic", name = "Cosmic Egg", icon = "🌌", zone = 10, cost = 5000000000, color = Color3.fromRGB(255, 90, 220), looks = { "nebulapup", "comettail", "galaxydrake", "quasarwyrm", "supernovalord" } },
}
local RARITY_SLOTS = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local WEIGHTS = { 55, 28, 12, 4.5, 0.5 }
local BASE = { 0.06, 0.12, 0.25, 0.5, 1.1 }
local SECOND = { "xp", "xp", "power", "crit", "power" }
local SECOND_AMT = { 0.05, 0.1, 0.06, 0.02, 0.15 }

local pets, eggById = {}, {}
for t, egg in eggs do
	egg.pets = {}
	eggById[egg.id] = egg
	local tierMul = 1 + (t - 1) * 0.8
	for i, look in egg.looks do
		local id = "pet_" .. look
		local p = {
			id = id,
			look = look,
			egg = egg.id,
			rarity = RARITY_SLOTS[i],
			weight = WEIGHTS[i],
			bonus = { coins = BASE[i] * tierMul },
		}
		local key = SECOND[i]
		p.bonus[key] = (p.bonus[key] or 0) + SECOND_AMT[i] * (key == "crit" and 1 or tierMul)
		p.score = p.bonus.coins + (p.bonus.xp or 0) * 0.3 + (p.bonus.power or 0) * 0.5 + (p.bonus.crit or 0) * 2
		pets[id] = p
		table.insert(egg.pets, p)
	end
end

local Companions = {
	Eggs = eggs,
	EggById = eggById,
	Pets = pets,
	BaseEquip = 3,
	BaseStorage = 30,
	LuckyRareMult = 2.5, -- weight multiplier for Epic/Legendary while Lucky boost is active
}

function Companions.rarityColor(petId: string): Color3
	local p = pets[petId]
	return p and Rarities.Info[p.rarity].color or Color3.new(1, 1, 1)
end

return Companions
