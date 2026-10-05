--> Variables
local _L = _G._L

local PlayerRewardUtility

--> Constants

---------->
return {
	{
		value = "release",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Strength",
				value = 500
			}}}, true)
		end,
	},

	{
		value = "100v",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Gems",
				value = 100
			}}}, true)
		end,
	},


	{
		value = "OKbutwhat",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Gems",
				value = 100
			}}}, true)
		end,
	},

	{
		value = "overpowered",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Pet", props = {
				name = "Toxic Hydra",
				value = 1
			}}}, true)
		end,
	},

	{
		value = "secret",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Boost", props = {
				name = "x2_Strength",
				value = 1
			}}}, true)
		end,
	},

	{
		value = "protection",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Boost", props = {
				name = "Lucky_Potion",
				value = 1
			}}}, true)
		end,
	},


	{
		value = "lucky",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Boost", props = {
				name = "Lucky_Potion",
				value = 1
			}}}, true)
		end,
	},

	{
		value = "visits?",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Gems",
				value = 250
			}},{name = "Boost", props = {
				name = "x2_Strength",
				value = 1
			}},{name = "Boost", props = {
				name = "Lucky_Potion",
				value = 1
			}}}, true)
		end,
	},

	{
		value = "pro",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Boost", props = {
				name = "x2_Strength",
				value = 1
			}}}, true)
		end,
	},

	{
		value = "plsss",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Gems",
				value = 500
			}},{name = "Boost", props = {
				name = "x2_Strength",
				value = 2
			}},{name = "Boost", props = {
				name = "Lucky_Potion",
				value = 2
			}}}, true)
		end,
	},

	{
		value = "likespls",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Gems",
				value = 750
			}},{name = "Boost", props = {
				name = "x2_Strength",
				value = 3
			}}}, true)
		end,
	},
	
	{
		value = "pleaselikes",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Gems",
				value = 1000
			}},{name = "Boost", props = {
				name = "x2_Strength",
				value = 1
			}},{name = "Boost", props = {
				name = "Lucky_Potion",
				value = 1
			}}}, true)
		end,
	},
	
	{
		value = "uwu",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Gems",
				value = 1250
			}},{name = "Boost", props = {
				name = "x2_Strength",
				value = 1
			}},{name = "Boost", props = {
				name = "Lucky_Potion",
				value = 1
			}}}, true)
		end,
	},
	
	{
		value = "biguwu",

		callback = function(client)
			return PlayerRewardUtility.give(client, {{name = "Stat", props = {
				name = "Gems",
				value = 1500
			}},{name = "Boost", props = {
				name = "x2_Strength",
				value = 1
			}},{name = "Boost", props = {
				name = "Lucky_Potion",
				value = 1
			}}}, true)
		end,
	},
	
	-- 🦌 mount code: gives the Forest Deer once (Databases.Mounts). Owners get "already own" instead of a duplicate.
	{
		value = "forestdeer",

		callback = function(client)
			local MountUtility = _L.Get {"Common", "Modules", "Utilities", "MountUtility"}
			local ok, err = MountUtility.give(client, {id = "forest_deer"})
			if ok then
				return true, "mount"
			end
			return false, if err == "owned" then "mount_owned" else "invalid"
		end,
	},

	_init = function()
		PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	end
}



