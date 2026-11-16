-- Every dragon species. Columns:
-- id, name, zone, rarity, body hex, accent hex, eye hex, move ("walk"|"hop"|"fly"), idle ("bob"|"sway"|"flap"|"spin"),
-- speed (studs/s), fx (nil|"leaf"|"fire"|"frost"|"sparkle"|"storm"|"sand"|"shadow"|"star"|"cosmic"|"rainbow"), personality
-- Mythic/Secret dragons are event spawns (zone 0 = any unlocked zone).
local rows = {
	-- 1 Dragon Valley
	{ "sproutling", "Sproutling", 1, "Common", "7ED957", "F7E26B", "1B1B1B", "walk", "bob", 14, nil, "A cheerful hatchling that sneezes petals." },
	{ "pebblewing", "Pebblewing", 1, "Uncommon", "A8A29E", "F2B880", "2B2B2B", "hop", "bob", 16, nil, "Hops everywhere, collects shiny pebbles." },
	{ "meadowdrake", "Meadow Drake", 1, "Rare", "5CC8FF", "FFF3B0", "102030", "walk", "sway", 15, "leaf", "Naps in flower fields after every snack." },
	{ "bloomhorn", "Bloomhorn", 1, "Epic", "FF8FC7", "FFE066", "3A0F2A", "fly", "flap", 18, "sparkle", "Its horns blossom when it is happy." },
	{ "valleywarden", "Valley Warden", 1, "Legendary", "2E9E5B", "FFD447", "FFE58A", "walk", "sway", 17, "sparkle", "Ancient guardian of the first valley." },
	-- 2 Forest Kingdom
	{ "mossback", "Mossback", 2, "Common", "4E8F3A", "9BD06A", "1A1A1A", "walk", "bob", 12, nil, "Slow, sleepy and covered in moss." },
	{ "acornwhelp", "Acorn Whelp", 2, "Uncommon", "B5793E", "F1C27D", "201510", "hop", "bob", 17, nil, "Buries snacks and forgets where." },
	{ "thornscale", "Thornscale", 2, "Rare", "2F6B3A", "C0392B", "FFEB3B", "walk", "sway", 16, "leaf", "Prickly outside, softie inside." },
	{ "canopyglider", "Canopy Glider", 2, "Epic", "7CDB8A", "3AA6B9", "0D2B1F", "fly", "flap", 20, "leaf", "Glides between the tallest trees." },
	{ "elderoak", "Elder Oakwyrm", 2, "Legendary", "6B4F2A", "8EE04E", "B6FF6A", "walk", "sway", 14, "leaf", "Older than the forest itself." },
	-- 3 Volcano Island
	{ "cinderpup", "Cinder Pup", 3, "Common", "D9534F", "FFB347", "1A0A00", "hop", "bob", 16, nil, "Leaves tiny scorch marks when it hops." },
	{ "embersnout", "Ember Snout", 3, "Uncommon", "FF7043", "FFD54F", "1A0A00", "walk", "bob", 15, "fire", "Snorts little fireballs when excited." },
	{ "magmacrawler", "Magma Crawler", 3, "Rare", "3E2723", "FF5722", "FF9800", "walk", "sway", 13, "fire", "Swims through lava like water." },
	{ "blazewyvern", "Blaze Wyvern", 3, "Epic", "FF3D00", "FFEA00", "FFFFFF", "fly", "flap", 21, "fire", "Its wings are made of living flame." },
	{ "infernoking", "Inferno King", 3, "Legendary", "B71C1C", "FFC107", "FFEB3B", "walk", "sway", 16, "fire", "Rules the volcano from its crater throne." },
	-- 4 Frozen Peaks
	{ "snowpuff", "Snowpuff", 4, "Common", "F5FBFF", "9AD0F5", "26425A", "hop", "bob", 15, nil, "A fluffy ball of frost and giggles." },
	{ "frostnip", "Frostnip", 4, "Uncommon", "9AD0F5", "FFFFFF", "0B3954", "walk", "bob", 16, "frost", "Nibbles icicles like candy." },
	{ "glacierdrake", "Glacier Drake", 4, "Rare", "4FC3F7", "E1F5FE", "01579B", "walk", "sway", 14, "frost", "Its scales are clear as glacier ice." },
	{ "blizzardwyvern", "Blizzard Wyvern", 4, "Epic", "B3E5FC", "5C6BC0", "1A237E", "fly", "flap", 21, "frost", "Every flap brings a snowstorm." },
	{ "aurorasovereign", "Aurora Sovereign", 4, "Legendary", "26C6DA", "B388FF", "E0F7FA", "fly", "flap", 19, "sparkle", "Paints the night sky with auroras." },
	-- 5 Crystal Caverns
	{ "shardling", "Shardling", 5, "Common", "9575CD", "E1BEE7", "1A0033", "hop", "bob", 16, nil, "Chimes like a bell when it walks." },
	{ "geodebiter", "Geode Biter", 5, "Uncommon", "5E35B1", "80DEEA", "000000", "walk", "bob", 15, "sparkle", "Cracks geodes open with its teeth." },
	{ "prismdrake", "Prism Drake", 5, "Rare", "80DEEA", "F48FB1", "FFFFFF", "walk", "sway", 16, "sparkle", "Splits light into tiny rainbows." },
	{ "amethystwyrm", "Amethyst Wyrm", 5, "Epic", "7B1FA2", "CE93D8", "F3E5F5", "fly", "flap", 20, "sparkle", "Hoards crystals deep in the caverns." },
	{ "diamondmonarch", "Diamond Monarch", 5, "Legendary", "E0F7FA", "4DD0E1", "00BCD4", "walk", "sway", 16, "sparkle", "Its hide is harder than diamond." },
	-- 6 Sky Kingdom
	{ "cloudhopper", "Cloudhopper", 6, "Common", "FFFFFF", "90CAF9", "1E3A5F", "hop", "bob", 17, nil, "Bounces from cloud to cloud." },
	{ "breezewing", "Breezewing", 6, "Uncommon", "B2EBF2", "FFF59D", "004D61", "fly", "flap", 20, nil, "Rides the warm winds all day." },
	{ "stormdrake", "Storm Drake", 6, "Rare", "546E7A", "FFEB3B", "FFF176", "fly", "flap", 22, "storm", "Crackles with static when it eats." },
	{ "thunderwyvern", "Thunder Wyvern", 6, "Epic", "283593", "FFEE58", "FFFF8D", "fly", "flap", 24, "storm", "Its roar is the thunder you hear." },
	{ "tempestemperor", "Tempest Emperor", 6, "Legendary", "1A237E", "80D8FF", "FFFFFF", "fly", "flap", 22, "storm", "Commands every storm in the sky." },
	-- 7 Ancient Dragon Lands
	{ "fossilpup", "Fossil Pup", 7, "Common", "D7CCC8", "8D6E63", "3E2723", "walk", "bob", 14, nil, "Loves digging up its own ancestors." },
	{ "runewhelp", "Rune Whelp", 7, "Uncommon", "A1887F", "4DB6AC", "80CBC4", "hop", "bob", 16, "sand", "Glowing runes appear when it naps." },
	{ "relicdrake", "Relic Drake", 7, "Rare", "C8A165", "26A69A", "1DE9B6", "walk", "sway", 15, "sand", "Guards relics nobody remembers." },
	{ "sandstonetitan", "Sandstone Titan", 7, "Epic", "D4A373", "6D4C41", "FFCA28", "walk", "sway", 12, "sand", "As big and patient as a pyramid." },
	{ "pharaohwyrm", "Pharaoh Wyrm", 7, "Legendary", "FFD54F", "00897B", "00E5FF", "fly", "flap", 18, "sparkle", "Crowned ruler of the ancient sands." },
	-- 8 Shadow Realm
	{ "gloomling", "Gloomling", 8, "Common", "4A148C", "7C4DFF", "E040FB", "hop", "bob", 16, nil, "Shy, but very hungry." },
	{ "duskfang", "Duskfang", 8, "Uncommon", "311B92", "B388FF", "FF4081", "walk", "bob", 18, "shadow", "Only comes out at dusk." },
	{ "voidstalker", "Void Stalker", 8, "Rare", "1A1A2E", "6A1B9A", "FF1744", "walk", "sway", 19, "shadow", "Moves without making a sound." },
	{ "nightmarewyvern", "Nightmare Wyvern", 8, "Epic", "12005E", "D500F9", "FF1744", "fly", "flap", 22, "shadow", "Feeds on bad dreams (and plums)." },
	{ "shadowtyrant", "Shadow Tyrant", 8, "Legendary", "0D0D0D", "AA00FF", "FF0055", "walk", "sway", 17, "shadow", "The darkness bows to it." },
	-- 9 Celestial Islands
	{ "starlingdrake", "Starling Drake", 9, "Common", "FFF8E1", "FFD54F", "5D4037", "hop", "bob", 17, nil, "Twinkles softly at night." },
	{ "moonwhisker", "Moonwhisker", 9, "Uncommon", "CFD8DC", "B3E5FC", "263238", "walk", "bob", 16, "star", "Its whiskers glow like moonbeams." },
	{ "solardrake", "Solar Drake", 9, "Rare", "FFB300", "FFF176", "FFFFFF", "fly", "flap", 21, "star", "Warm as a summer sunrise." },
	{ "halowyvern", "Halo Wyvern", 9, "Epic", "FFFDE7", "FFD740", "FFAB00", "fly", "flap", 22, "star", "Wears a golden halo of light." },
	{ "seraphdragon", "Seraph Dragon", 9, "Legendary", "FFFFFF", "FFC400", "FFE57F", "fly", "flap", 20, "star", "Six wings, endless kindness." },
	-- 10 Cosmic Dimension
	{ "nebulapup", "Nebula Pup", 10, "Common", "7E57C2", "F06292", "FFFFFF", "hop", "bob", 18, "cosmic", "Made of baby stardust." },
	{ "comettail", "Comet Tail", 10, "Uncommon", "29B6F6", "E1F5FE", "FFFFFF", "fly", "flap", 23, "cosmic", "Leaves a sparkling trail behind it." },
	{ "galaxydrake", "Galaxy Drake", 10, "Rare", "311B92", "18FFFF", "FF80AB", "fly", "flap", 22, "cosmic", "A whole galaxy swirls in its belly." },
	{ "quasarwyrm", "Quasar Wyrm", 10, "Epic", "1A0033", "FF00FF", "00E5FF", "fly", "flap", 24, "cosmic", "Shines brighter than a thousand stars." },
	{ "supernovalord", "Supernova Lord", 10, "Legendary", "FF6D00", "FFFF00", "FFFFFF", "fly", "flap", 22, "cosmic", "Born from an exploding star." },
	-- Mythic event spawns
	{ "verdantcolossus", "Verdant Colossus", 2, "Mythic", "1B5E20", "FFD600", "FFFF00", "walk", "sway", 14, "leaf", "A walking forest. Appears once in a blue moon." },
	{ "phoenixwyrm", "Phoenix Wyrm", 3, "Mythic", "FF1744", "FFEA00", "FFFFFF", "fly", "flap", 22, "fire", "Reborn from its own embers." },
	{ "frostfirehydra", "Frostfire Hydra", 4, "Mythic", "00B0FF", "FF3D00", "FFFFFF", "walk", "sway", 15, "frost", "Half ice, half fire, all hungry." },
	{ "stormphoenix", "Storm Phoenix", 6, "Mythic", "304FFE", "FFFF00", "FFFFFF", "fly", "flap", 24, "storm", "Lightning follows wherever it flies." },
	{ "eclipsedragon", "Eclipse Dragon", 8, "Mythic", "000000", "FF6D00", "FFAB40", "fly", "flap", 22, "shadow", "Blots out the sun when it yawns." },
	{ "cosmicleviathan", "Cosmic Leviathan", 10, "Mythic", "0D0033", "00E5FF", "FF00FF", "fly", "flap", 20, "cosmic", "The universe's oldest dragon." },
	-- Secret event spawns
	{ "forgottenone", "The Forgotten One", 7, "Secret", "37474F", "00E676", "00E676", "walk", "sway", 13, "sand", "Nobody remembers it... except you now." },
	{ "prismaticanomaly", "Prismatic Anomaly", 0, "Secret", "FF0000", "FFFFFF", "FFFFFF", "fly", "spin", 24, "rainbow", "A glitch in reality. Shimmers every color." },
}

local list, byId, byZone, events = {}, {}, {}, {}
for i, r in rows do
	local d = {
		order = i,
		id = r[1],
		name = r[2],
		zone = r[3],
		rarity = r[4],
		body = Color3.fromHex(r[5]),
		accent = Color3.fromHex(r[6]),
		eye = Color3.fromHex(r[7]),
		move = r[8],
		idle = r[9],
		speed = r[10],
		fx = r[11],
		desc = r[12],
	}
	table.insert(list, d)
	byId[d.id] = d
	if d.rarity == "Mythic" or d.rarity == "Secret" then
		table.insert(events, d)
	else
		byZone[d.zone] = byZone[d.zone] or {}
		table.insert(byZone[d.zone], d)
	end
end

return { List = list, ById = byId, ByZone = byZone, Events = events }
