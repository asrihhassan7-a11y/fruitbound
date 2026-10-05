--> Variables
local _L = _G._L

local Network
local PlayerRewardUtility
local Constants
local SeasonUtility
--> Constants

---------->
return {
	{
		id = 3712547088,
		name = "x2_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 1)

			return true
		end,
	},
	
	{
		id = 3712547109,
		name = "x5_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 2)

			return true
		end,
	},
	
	{
		id = 3712547269,
		name = "x10_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 3)

			return true
		end,
	},
	
	{
		id = 3712547706,
		name = "x50_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 4)

			return true
		end,
	},
	
	{
		id = 3712547742,
		name = "x100_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 5)

			return true
		end,
	},
	
	{
		id = 3712547776,
		name = "x250_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 6)

			return true
		end,
	},
	
	{
		id = 3712548587,
		name = "x500_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 7)

			return true
		end,
	},
	
	{
		id = 3712548524,
		name = "x1,000_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 8)

			return true
		end,
	},
	
	{
		id = 3712548843,
		name = "x2,500_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 9)

			return true
		end,
	},
	
	{
		id = 3712548873,
		name = "x5,000_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 10)

			return true
		end,
	},
	
	{
		id = 3712549077,
		name = "x10,000_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 11)

			return true
		end,
	},
	
	{
		id = 3712549129,
		name = "x25,000_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 12)

			return true
		end,
	},
	
	{
		id = 3712549160,
		name = "x50,000_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 13)

			return true
		end,
	},
	
	{
		id = 3712549194,
		name = "x100,000_Strength_Multiplier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.data:Set("robux_multiplier", 14)

			return true
		end,
	},
	
	{
		id = 3712546720,
		name = "1_Wheel_Spin",
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Wheel_Spin",
					value = 1
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546824,
		name = "Skip_Tier",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end
			
			local currentSeasonId = Constants.CURRENT_SEASON_ID
			local currentSeasonInfo = SeasonUtility.getCurrentInfo()
			local currentStrength = client.data:Get({"seasons", currentSeasonId, "total_strength_gained"})

			local newSkipped = client.data:Get({"seasons", currentSeasonId, "skipped"})
			
			local _, highestTier = TableUtility.max(ArrayUtility.filter(currentSeasonInfo.tiers, function(i, v) return v.required <= currentStrength or table.find(newSkipped, v.id) end), function(i, v)
				return v.required
			end)
			
			local nextTierId = (if highestTier then highestTier.id else 0) + 1
			
			if not table.find(newSkipped, nextTierId) then
				table.insert(newSkipped, nextTierId)
			end
			
			client.data:Set({"seasons", currentSeasonId, "skipped"}, newSkipped)

			return true
		end,
	},
	
	{
		id = 3712546764,
		name = "10_Wheel_Spins",
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)
			
			if not client then
				return false
			end
			
			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Wheel_Spin",
					value = 10
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546850,
		name = "Season_Premium",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end
			
			local currentSeasonId = Constants.CURRENT_SEASON_ID
			
			client.data:Set({"seasons", currentSeasonId, "owns_premium"}, true)

			return true
		end,
	},
	
	{
		id = 3712546883,
		name = "Season_Unlock_All_Tiers",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			local currentSeasonId = Constants.CURRENT_SEASON_ID
			local currentSeasonInfo = SeasonUtility.getCurrentInfo()
			
			local newSkipped = client.data:Get({"seasons", currentSeasonId, "skipped"})
			
			for _, currentTierInfo in pairs(currentSeasonInfo.tiers) do
				if not table.find(newSkipped, currentTierInfo.id) then
					table.insert(newSkipped, currentTierInfo.id)
				end
			end
			
			client.data:Set({"seasons", currentSeasonId, "skipped"}, newSkipped)
			
			return true
		end,
	},
	
	{
		id = 3712546805,
		name = "100_Wheel_Spins",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Wheel_Spin",
					value = 100
				}
			}}, true)

			return true
		end,
	},
		
	{
		id = 3712546918,
		name = "25_Pet_Storage",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Pet_Storage_Space",
					value = 25
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546949,
		name = "100_Pet_Storage",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Pet_Storage_Space",
					value = 100
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545865,
		name = "1_Galaxy_Egg",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Galaxy_Egg",
					value = 1
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545931,
		name = "3_Galaxy_Eggs",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Galaxy_Egg",
					value = 3
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545965,
		name = "10_Galaxy_Eggs",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Galaxy_Egg",
					value = 10
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546046,
		name = "1_Midnight_Egg",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Midnight_Egg",
					value = 1
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712546086,
		name = "3_Midnight_Eggs",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Midnight_Egg",
					value = 3
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712546133,
		name = "10_Midnight_Eggs",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Midnight_Egg",
					value = 10
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546170,
		name = "1_Dragon_Egg",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Dragon_Egg",
					value = 1
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712546192,
		name = "3_Dragon_Eggs",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Dragon_Egg",
					value = 3
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546236,
		name = "10_Dragon_Eggs",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Egg",
				props = {
					name = "Dragon_Egg",
					value = 10
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546492,
		name = "5_Lucky_Potions",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Boost",
				props = {
					name = "Lucky_Potion",
					value = 5
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 1817317299,
		name = "Huge_Cthulhu",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end
			
			client.player_controller:_huge_event_reward_claim(true)

			return true
		end,
	},
	
	{
		id = 1817317298,
		name = "Hacker_Dominus",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			client.player_controller:_hacker_event_reward_claim(true)

			return true
		end,
	},	
	{
		id = 3712546532,
		name = "5_Protection_Potions",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Boost",
				props = {
					name = "Protection_Potion",
					value = 5
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546555,
		name = "5_Double_Damage_Potions",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Boost",
				props = {
					name = "x2_Damage",
					value = 5
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546568,
		name = "5_Double_Strength_Potions",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Boost",
				props = {
					name = "x2_Strength",
					value = 5
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712546694,
		name = "Ultra_Potion_Pack",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Boost",
				props = {
					name = "x2_Strength",
					value = 500
				}
			},{
				name = "Boost",
				props = {
					name = "x2_Damage",
					value = 500
				}
			},{
				name = "Boost",
				props = {
					name = "Lucky_Potion",
					value = 500
				}
			},{
				name = "Boost",
				props = {
					name = "Protection_Potion",
					value = 500
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712544874,
		name = "Skip_Rebirth",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client or not client.player_controller then
				return false
			end

			client.player_controller:_rebirth(true)

			return true
		end,
	},
	
	{
		id = 3712546318,
		name = "Lucky_1",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client or not client.player_controller then
				return false
			end

			local new = TableUtility.deep.clone(client.data:Get("lucky_passes"))
			
			new[1] = true
			
			client.data:Set("lucky_passes", new)
			
			return true
		end,
	},
	
	{
		id = 3712546350,
		name = "Lucky_2",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client or not client.player_controller then
				return false
			end

			local new = TableUtility.deep.clone(client.data:Get("lucky_passes"))

			new[2] = true

			client.data:Set("lucky_passes", new)

			return true
		end,
	},
	
	{
		id = 3712546417,
		name = "Lucky_3",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client or not client.player_controller then
				return false
			end

			local new = TableUtility.deep.clone(client.data:Get("lucky_passes"))
			
			new[3] = true

			client.data:Set("lucky_passes", new)
			
			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 50000
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545202,
		name = "Strength_1",
		tag = "Strength",
		value = 500,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Strength",
					value = 500
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545311,
		name = "Strength_2",
		tag = "Strength",
		value = 1000,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Strength",
					value = 1000
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545341,
		name = "Strength_3",
		tag = "Strength",
		value = 2000,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Strength",
					value = 2000
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545373,
		name = "Strength_4",
		tag = "Strength",
		value = 50000,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Strength",
					value = 50000
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545413,
		name = "Strength_5",
		tag = "Strength",
		value = 1000000,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Strength",
					value = 1000000
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545487,
		name = "Strength_6",
		tag = "Strength",
		value = 100000000,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Strength",
					value = 100000000
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545513,
		name = "Strength_7",
		tag = "Strength",
		value = 2500000000,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Strength",
					value = 2500000000
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712545550,
		name = "Gems_1",
		tag = "Gems",
		value = 250,

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 250
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712545584,
		name = "Gems_2",
		tag = "Gems",
		value = 500,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 500
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712545669,
		name = "Gems_3",
		tag = "Gems",
		value = 1000,

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 1000
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712545717,
		name = "Gems_4",
		tag = "Gems",
		value = 2000,

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 2000
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712545745,
		name = "Gems_5",
		tag = "Gems",
		value = 50000,
		
		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 50000
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712545772,
		name = "Gems_6",
		tag = "Gems",
		value = 1000000,

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 1000000
				}
			}}, true)

			return true
		end,
	},

	{
		id = 3712545799,
		name = "Gems_7",
		tag = "Gems",
		value = 25000000,

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 25000000
				}
			}}, true)

			return true
		end,
	},
	
	{
		id = 3712547006,
		name = "Electro_Pack",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Stat",
				props = {
					name = "Gems",
					value = 50000
				}
			}, {
				name = "Stat",
				props = {
					name = "Strength",
					value = 100000000
				}
			}, {
				name = "Power",
				props = {name = "Electro Power"}
			}, {
				name = "Pet",
				props = {name = "Electrolyte", value = 1}
			}}, true)

			return true
		end,
	},	
	
	{
		id = 3712546992,
		name = "Dark_Matter_Pack",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {
			{
				name = "Stat",
				props = {
					name = "Gems",
					value = 5000000
				}
			}, {
				name = "Stat",
				props = {
					name = "Strength",
					value = 999999999999
				}
			}, {
				name = "Power",
				props = {name = "Dark Matter Power"}
			}, {
				name = "Pet",
				props = {name = "Dark Dominus", value = 1}
			}}, true)

			return true
		end,
	},	
	
	{
		id = 3712547024,
		name = "Electrolyte",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Pet",
				props = {name = "Electrolyte", value = 1}
			}}, true)

			return true
		end,
	},	
	
	{
		id = 3712547053,
		name = "Electro_Spirit",

		callback = function(user)
			local client = Network.Bindable.Invoke("S_Client_Get", user._player)

			if not client then
				return false
			end

			PlayerRewardUtility.give(client, {{
				name = "Pet",
				props = {name = "Electro Spirit", value = 1}
			}}, true)

			return true
		end,
	},
	
	_init = function()
		Network = _L.Get {"Common", "Library", "Network"}
		PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
		SeasonUtility = _L.Get {"Common", "Modules", "Utilities", "SeasonUtility"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	end,
}