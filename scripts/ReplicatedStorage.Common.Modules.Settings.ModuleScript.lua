--> Variables
local _L = _G._L

--> Constants

---------->
return {
	data = {
		mock = false,
		key = "Player_Data_002",
		template = {
			gamepasses = {},
			
			clan = nil,
			
			used_codes = {},
			owned_powers = {},
			
			upgrades = {
				["1"] = 1,
				["2"] = 1,
				["3"] = 1,
				["4"] = 1,
			},
			
			-- Upgrade Tree levels: tree[nodeId] = level
			tree = {},
			
			-- new players choose ONE starter fruit (Strawberry or Apple) in the starter menu
			received_starter_fruit = false,
			starter_fruit = "", -- which one they picked ("" = not chosen yet)
			
			-- Achievements: achievements[id] = true once claimed
			achievements = {},
			-- Gardens the player has visited (garden ids), for exploring achievements
			discovered_gardens = {},
			
			-- Tycoon farm: upgrades[id] = true once bought, storage = coins waiting in the crate
			farm = {upgrades = {}, storage = 0, decor = {}}, -- decor = placed decorations {u, i, x, z, r}
			
			titles = {{id = 3}},
			
			lucky_passes = {
				false,
				false,
				false,
			},
			
			auto_delete = {},
			
			stats = {
				Strength = 0,
				Gems = 0,
				Kills = 0, -- LEGACY harvest counter (old 6-item harvests), frozen: never written by harvests any more
				Crops_Harvested = 0, -- real crops harvested (1 per finished plant): quests, achievements, ranks
				Rebirths = 0,
				Crowns = 5,
				Wheel_Spin = 2,
				Pet_Storage_Space = 35,
				Pet_Equip_Space = 3,
				Fruit_Storage_Space = 35,
				Fruit_Equip_Space = 3,
				Deaths = 0,
				Huge_Event_Kills = 0,
				Hacker_Event_Kills = 0,
				Event_Eggs_1_Opened = 0,
				Total_Strength = 0,
				Total_Time = 0,
				Fruits_Collected = 0, -- every fruit ever received (eggs, rewards, starter)
				Food_Collected = 0, -- every food item harvested from plants
				Best_Fruit_Stage = 0 -- highest evolution stage reached (0 Normal .. 5 Divine)
			},
			
			settings = {
				Music = true,
				Other_Pets = true,
				Your_Pets = true,
				Other_Fruits = true,
				Your_Fruits = true,
				SFX = true,
				Trades = true,
				Trades_Friends_Only = false, -- V1.1: only friends can send trade requests
				Auto_Rebirth = false,
				Popups = true,
				Notifications = true,
				Auto_Collect_Zone = true,
				MusicVolume = 0.7, -- 0..1 volume sliders (Settings menu)
				SFXVolume = 0.8,
				AmbientVolume = 0.6
			},
			
			boosts = {
				["x2_Strength"] = {time_left = 0, quantity = 0},
				["Lucky_Potion"] = {time_left = 0, quantity = 0},
				["Protection_Potion"] = {time_left = 0, quantity = 0},
				["x2_Damage"] = {time_left = 0, quantity = 0},
				["Growth_Speed"] = {time_left = 0, quantity = 0},
			},
			processed_receipts = {},
			
			pets = {},
			fruits = {},
			mounts = {owned = {}}, -- Mounts: owned[mountId] = true, equipped = mountId (Databases.Mounts)
			gears = {owned = {}}, -- Gears: owned[gearId] = true, equipped = gearId
			discovered_fruits = {}, -- Fruit Book: [fruitName] = true once ever obtained (kept after selling / deleting / trading)
			plants = {},
			plant_values = {},
			seed_inventory = {},
			seed_crops = {},
			seed_planted_count = 0,
			-- heaviest crop this player ever HARVESTED: the "Heaviest Crop" leaderboard
			heaviest_crop = {weight = 0},
			-- crop progression migration (ProgressUtility.migrateCropProgress): 0 = old save not migrated yet
			crop_progression_version = 0,
			-- written once by that migration: {rank = rank index from the old Kills thresholds (a rank never
			-- drops below it), achievements = {[id] = true} harvest achievements already completed with old Kills}
			crop_legacy = {},
			daycare = {slots = {}}, -- RETIRED V1 Daycare (kept as-is for old saves, never read for V1.1)
			-- V1.1 Daycare (Fruit Pen): entries[fruitUid] = {fruit_uid, fruit_id, deposited_at, last_collected_at}
			-- The Fruit record itself stays in `fruits` (same UID / level / stage / tier) with daycare = true.
			fruit_daycare = {entries = {}},
			-- V1.1 expansion (all additive, filled by Reconcile):
			-- restricted_hatch[eggName] = how many guaranteed hatches this account has done on that Egg
			-- (PolicyService accounts with paid random items restricted get a fixed, shown-in-advance order)
			restricted_hatch = {},
			-- Second Garden Floor: bought with Coins, crops on it live in seed_crops under the "F2:" key prefix
			garden_floor2 = false,
			fishing = {casts = 0, catches = 0}, -- lifetime Fishing stats
			wild_captures = 0, -- lifetime Wild Fruit captures
			trade_history = {}, -- last 20 completed Fruit trades {t, with (UserId), gave, got} (debug / exploit checks)
			farm_mutations = {}, -- [crop path in your farm plot] = mutation id (World events)
			claimed_free_pet_pack = false,
			claimed_huge_event_reward = false,
			claimed_hacker_event_reward = false,

			time_reward_chests = {},
			tutorial_marker = 1, -- saved onboarding step (1-7 active, 8 complete)
			tutorial_version = 3, -- new profiles use the server-confirmed FruitBound flow
			auto_collect = false,
			tutorial_sold = false, -- compatibility flag for profiles from the earlier guide
			
			last_daily_gift = {i = nil, t = 0},
			last_daily_case = 0,
			last_premium_case = 0,
			rank_reward = 0,
			
			robux_multiplier = nil,
			
			seasons = {
				{owns_premium = false, free = {}, premium = {}, total_strength_gained = 0, skipped = {}}
			},
			
			clan_quests = {},
			quests = {
				daily = {t = nil, v = {}},
				weekly = {t = nil, v = {}},
				tutorial = {v = {}}
			},
			
			invite_rewards = {},
			friends_invited = {},

			-- Mastery: powers[componentName] = xp, fruits[fruitName] = xp, player = totalXp
			mastery = {powers = {}, fruits = {}, player = 0}
		}
	}
}