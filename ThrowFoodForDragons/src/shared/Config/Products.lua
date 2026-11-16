-- Monetization. Create the Game Passes / Developer Products on the Creator Dashboard and paste their ids here.
-- id = 0 means "not configured yet": the store shows it as unavailable and nothing can be bought.
local Products = {
	Passes = {
		VIP = { id = 0, name = "VIP", icon = "👑", desc = "x1.5 coins, +1 companion slot, golden name tag" },
		DoubleCoins = { id = 0, name = "2x Coins", icon = "💰", desc = "Double coins from every feed, forever" },
		DoubleRewards = { id = 0, name = "2x Rewards", icon = "🎁", desc = "Double XP, quest, daily & achievement rewards" },
		AutoThrow = { id = 0, name = "Auto Throw", icon = "🤖", desc = "Automatically feeds the nearest dragon" },
		ExtraInventory = { id = 0, name = "Extra Inventory", icon = "🎒", desc = "+50 companion storage, +1 equip slot" },
	},
	PassOrder = { "VIP", "DoubleCoins", "DoubleRewards", "AutoThrow", "ExtraInventory" },
	DevProducts = {
		Boost2x = { id = 0, name = "2x Coins (15 min)", icon = "⏱️", kind = "boost", boost = "Coins2x", seconds = 900 },
		Lucky = { id = 0, name = "Lucky Boost (15 min)", icon = "🍀", kind = "boost", boost = "Lucky", seconds = 900 },
		CoinsS = { id = 0, name = "Coin Pouch", icon = "👛", kind = "coins", minutes = 10 },
		CoinsM = { id = 0, name = "Coin Chest", icon = "🧰", kind = "coins", minutes = 60 },
		CoinsL = { id = 0, name = "Coin Vault", icon = "🏦", kind = "coins", minutes = 360 },
	},
	ProductOrder = { "Boost2x", "Lucky", "CoinsS", "CoinsM", "CoinsL" },
	Boosts = {
		Coins2x = { name = "2x Coins", icon = "💰" },
		Lucky = { name = "Lucky", icon = "🍀" },
	},
}
return Products
