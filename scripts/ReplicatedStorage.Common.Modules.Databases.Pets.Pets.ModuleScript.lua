--> Variables
local _L = _G._L

--> Constants

---------->
local Pets

Pets = {
	{
		name = "Krill",
		rarity = "Common",
		image = "rbxassetid://18925321319",
		boost = 1.5
		
	},
	
	{
		name = "Gohan",
		rarity = "Common",
		image = "rbxassetid://18925322622",
		boost = 2
	},
	
	{
		name = "Trunks",
		rarity = "Rare",
		image = "rbxassetid://18925323874",
		boost = 2.5
	},
	
	{
		name = "Josuke",
		rarity = "Epic",
		image = "rbxassetid://18925324924",
		boost = 3.5
	},

	{
		name = "Kura",
		rarity = "Legendary",
		image = "rbxassetid://18931651024",
		boost = 6
	},

	{
		name = "Kurapika",
		rarity = "Secret",
		image = "rbxassetid://18931651024",
		boost = 1200
	},
	
	{
		name = "Ranuto",
		rarity = "Secret",
		image = "rbxassetid://18925305142",
		boost = 300
	},
	
	{
		name = "Galaxy Beast",
		rarity = "Huge",
		image = "rbxassetid://13833686277",
		boost = 400
	},
	
	{
		name = "Galaxy Dragon",
		rarity = "Epic",
		image = "rbxassetid://13838825213",
		boost = 35
	},
	
	{
		name = "Galaxy Cat",
		rarity = "Rare",
		image = "rbxassetid://13838863825",
		boost = 20
	},
	
	{
		name = "Cosmic Cyborg",
		rarity = "Huge",
		image = "rbxassetid://13840639620",
		boost = 150
	},
	
	{
		name = "Galactic Alien",
		rarity = "Epic",
		image = "rbxassetid://13840656570",
		boost = 75
	},
	
	{
		name = "Renito",
		rarity = "Common",
		image = "rbxassetid://18934162667",
		boost = 10
		
	},
	
	{
		name = "Black Beard",
		rarity = "Huge",
		image = "rbxassetid://18934149674",
		boost = 80
	},
	
	{
		name = "Renato",
		rarity = "Epic",
		image = "rbxassetid://18934155290",
		boost = 60
	},
	
	{
		name = "Muzan",
		rarity = "Epic",
		image = "rbxassetid://18934168756",
		boost = 25
	},
	
	{
		name = "Aries",
		rarity = "Huge",
		image = "rbxassetid://18934142757",
		boost = 300
	},
	
	{
		name = "Toxic Hydra",
		rarity = "Huge",
		image = "rbxassetid://13850136166",
		boost = 6.5
	},
	
	{
		name = "Gruh",
		rarity = "Common",
		image = "rbxassetid://18925341487",
		boost = 30
	},

	{
		name = "Hisoka+",
		rarity = "Secret",
		image = "rbxassetid://18931798822",
		boost = 2000
	},

	{
		name = "Hisoka",
		rarity = "Legendary",
		image = "rbxassetid://18931800720",
		boost = 50
	},


	{
		name = "Buhin",
		rarity = "Common",
		image = "rbxassetid://18925342562",
		boost = 120
	},

	{
		name = "Hawks",
		rarity = "Legendary",
		image = "rbxassetid://18931978328",
		boost = 350
	},

	{
		name = "Buhan",
		rarity = "Epic",
		image = "rbxassetid://18925343575",
		boost = 220
	},
	{
		name = "Gon",
		rarity = "Huge",
		image = "rbxassetid://18925344674",
		boost = 550
	},
	{
		name = "Gon+",
		rarity = "Secret",
		image = "rbxassetid://18925345980",
		boost = 5500
	},
	{
		name = "Emerald Dominus",
		rarity = "Huge",
		image = "rbxassetid://14291808749",
		boost = 70
	},
	{
		name = "Ruby Dominus",
		rarity = "Huge",
		image = "rbxassetid://14291808566",
		boost = 90
	},
	{
		name = "Blue Angel",
		rarity = "Legendary",
		image = "rbxassetid://13873993606",
		boost = 20
	},
	{
		name = "Pink Angel",
		rarity = "Legendary",
		image = "rbxassetid://13873993775",
		boost = 20
	},
	{
		name = "Green Angel",
		rarity = "Legendary",
		image = "rbxassetid://13873993416",
		boost = 20
	},
	{
		name = "Roger",
		rarity = "Common",
		image = "rbxassetid://18925326924",
		boost = 2
	},
	{
		name = "Ronie",
		rarity = "Common",
		image = "rbxassetid://18925329115",
		boost = 2.5
	},
	{
		name = "Tanji",
		rarity = "Rare",
		image = "rbxassetid://18925330463",
		boost = 3
	},
	{
		name = "Tanji+",
		rarity = "Epic",
		image = "rbxassetid://18925331635",
		boost = 5
	},
	{
		name = "Ginx",
		rarity = "Common",
		image = "rbxassetid://18925333429",
		boost = 2.9
	},
	{
		name = "Ginx+",
		rarity = "Common",
		image = "rbxassetid://18925335308",
		boost = 4
	},
	{
		name = "Killa",
		rarity = "Rare",
		image = "rbxassetid://18925336724",
		boost = 4.7
	},
	{
		name = "Killa+",
		rarity = "Epic",
		image = "rbxassetid://18925338127",
		boost = 7
	},
	{
		name = "Rengage",
		rarity = "Secret",
		image = "rbxassetid://18925339234",
		boost = 5000
	},
	{
		name = "Huge Cthulhu",
		rarity = "Huge",
		image = "rbxassetid://14263491853",
		boost = 80
	},
	{
		name = "Hacker Dominus",
		rarity = "Huge",
		image = "rbxassetid://14378065165",
		boost = 80
	},
	{
		name = "Electrolyte",
		rarity = "Huge",
		image = "rbxassetid://14265821276",
		boost = 300
	},
	{
		name = "Forest Wyvern",
		rarity = "Huge",
		image = "rbxassetid://14295292648",
		boost = 120
	},
	{
		name = "Mega Kraken",
		rarity = "Huge",
		image = "rbxassetid://14295292484",
		boost = 120
	},
	{
		name = "250k Dragon",
		rarity = "Rare",
		image = "rbxassetid://14306010667",
		boost = 15
	},
	{
		name = "Dark Spirit",
		rarity = "Rare",
		image = "rbxassetid://14306061312",
		boost = 20
	},
	{
		name = "Wisp Dragon",
		rarity = "Epic",
		image = "rbxassetid://14306065861",
		boost = 35
	},
	{
		name = "Raged Beast",
		rarity = "Legendary",
		image = "rbxassetid://14306115633",
		boost = 85
	},
	{
		name = "Holy Dominus",
		rarity = "Huge",
		image = "rbxassetid://14306117200",
		boost = 150
	},
	{
		name = "500k Bull",
		rarity = "Rare",
		image = "rbxassetid://14351833989",
		boost = 15
	},
	{
		name = "Hell Wisp",
		rarity = "Epic",
		image = "rbxassetid://14351549491",
		boost = 20
	},
	{
		name = "Deadly Dominus",
		rarity = "Legendary",
		image = "rbxassetid://14351799131",
		boost = 90
	},
	{
		name = "Holy Kraken",
		rarity = "Huge",
		image = "rbxassetid://14351757094",
		boost = 115
	},
	{
		name = "Dark Dominus",
		rarity = "Huge",
		image = "rbxassetid://14352328410",
		boost = 165
	},
	{
		name = "Golden Dominus",
		rarity = "Clan S1",
		image = "rbxassetid://14356658227",
		boost = 450
	},
	{
		name = "S1 Clan Trophy",
		rarity = "Clan S1",
		image = "rbxassetid://14356688963",
		boost = 250
	},
	{
		name = "1M Lion",
		rarity = "Rare",
		image = "rbxassetid://14389174142",
		boost = 25
	},
	{
		name = "Lava Angel",
		rarity = "Epic",
		image = "rbxassetid://14389173980",
		boost = 35
	},
	{
		name = "Lava Dragon",
		rarity = "Legendary",
		image = "rbxassetid://14389173756",
		boost = 120
	},
	{
		name = "Storm Wyvern",
		rarity = "Huge",
		image = "rbxassetid://14389173342",
		boost = 170
	},
	{
		name = "Storm Dragon",
		rarity = "Huge",
		image = "rbxassetid://14389173541",
		boost = 275
	},
	{
		name = "Candy Dragon",
		rarity = "Huge",
		image = "rbxassetid://14461328680",
		boost = 375
	},
	{
		name = "Community Beast",
		rarity = "Huge",
		image = "rbxassetid://14391299698",
		boost = 15
	},
	{
		name = "Radioactive Cat",
		rarity = "Epic",
		image = "rbxassetid://14398830465",
		boost = 100
	},
	{
		name = "Toxic Cactus Boi",
		rarity = "Epic",
		image = "rbxassetid://14398830179",
		boost = 150
	},
	{
		name = "Toxic Dragon",
		rarity = "Legendary",
		image = "rbxassetid://14398829912",
		boost = 300
	},
	{
		name = "Toxic Phoenix",
		rarity = "Huge",
		image = "rbxassetid://14397530387",
		boost = 400
	},
	{
		name = "Fiery Phoenix",
		rarity = "Huge",
		image = "rbxassetid://14461285648",
		boost = 550
	},
	{
		name = "Developer Monkey",
		rarity = "Developer",
		image = "rbxassetid://14398379269",
		boost = 100000000000000
	},
	{
		name = "Emerald Monkey",
		rarity = "Secret",
		image = "rbxassetid://14487279631",
		boost = 3000
	},
	{
		name = "Toxic Alien",
		rarity = "Secret",
		image = "rbxassetid://14399503907",
		boost = 1250
	},
	{
		name = "SLIME BOY",
		rarity = "Secret",
		image = "rbxassetid://14397449610",
		boost = 2200
	},
	{
		name = "Gift",
		rarity = "Epic",
		image = "rbxassetid://14456861569",
		boost = 340
	},
	{
		name = "Bat",
		rarity = "Epic",
		image = "rbxassetid://14415354182",
		boost = 780
	},
	{
		name = "Bee",
		rarity = "Legendary",
		image = "rbxassetid://14456861919",
		boost = 1000
	},
	{
		name = "Ice Scorpion",
		rarity = "Legendary",
		image = "rbxassetid://14456861275",
		boost = 1235
	},
	{
		name = "Evil Spirit",
		rarity = "Secret",
		image = "rbxassetid://14415353960",
		boost = 1950
	},
	{
		name = "Electro Spirit",
		rarity = "Legendary",
		image = "rbxassetid://18932388989",
		boost = 4500
	},
	{
		name = "2M Serpent",
		rarity = "Secret",
		image = "rbxassetid://14415353239",
		boost = 5200
	},
	{
		name = "Golden Spirit",
		rarity = "Clan S1",
		image = "rbxassetid://14458034360",
		boost = 1365
	},
	{
		name = "Magic Wyvern",
		rarity = "Huge",
		image = "rbxassetid://14460059729",
		boost = 900
	},	
	{
		name = "Snowy Wyvern",
		rarity = "Huge",
		image = "rbxassetid://14460059917",
		boost = 1235
	},	
	{
		name = "Molten Creature",
		rarity = "Epic",
		image = "rbxassetid://14460479141",
		boost = 550
	},
	{
		name = "Molten Scorpion",
		rarity = "Epic",
		image = "rbxassetid://14460478824",
		boost = 750
	},
	{
		name = "Molten Wyvern",
		rarity = "Legendary",
		image = "rbxassetid://14460478122",
		boost = 1100
	},
	{
		name = "Molten Wisp",
		rarity = "Legendary",
		image = "rbxassetid://14460478462",
		boost = 1755
	},
	{
		name = "Molten Alien",
		rarity = "Secret",
		image = "rbxassetid://14460344431",
		boost = 5720
	},
	{
		name = "Soldier",
		rarity = "Epic",
		image = "rbxassetid://18932400865",
		boost = 1000
	},
	{
		name = "Super Ares",
		rarity = "Legendary",
		image = "rbxassetid://18932398396",
		boost = 1500
	},
	{
		name = "Smite",
		rarity = "Huge",
		image = "rbxassetid://18932394258",
		boost = 2000
	},
	{
		name = "Big",
		rarity = "Secret",
		image = "rbxassetid://18932392080",
		boost = 3000
	},
	{
		name = "Big Sun",
		rarity = "Secret",
		image = "rbxassetid://18932388989",
		boost = 5700
	},

	
}

return Pets