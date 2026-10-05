--> Variables
local _L = _G._L

local NumberUtility
local DictionaryUtility
local ArrayUtility
local Network
local TableUtility
local Powers
local PowerUtility

--> Constants

---------->
local Shared

Shared = {
	_init = function()
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
		DictionaryUtility = _L.Get {"Common", "Library", "Utilities", "DictionaryUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		Network = _L.Get {"Common", "Library", "Network"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Powers = _L.Get {"Common", "Modules", "Databases", "Powers", "Powers"}
		PowerUtility = _L.Get {"Common", "Modules", "Utilities", "PowerUtility"}
	end,
	
	GetBestPowerInfo = function(client)
		local currentPowerInfo = Shared.GetCurrentPowerInfoFromStrength(client.player_controller._data:Get({"stats", "Strength"}))
		local result, a = currentPowerInfo.strength, currentPowerInfo
		
		for _, ownedPowerName in pairs(client.player_controller._data:Get({"owned_powers"})) do
			local ownedPowerInfo = PowerUtility.getInfo(ownedPowerName)
			if ownedPowerInfo.strength >= result then
				result, a = ownedPowerInfo.strength, ownedPowerInfo
			end
		end

		return a
	end,
	
	GetCurrentPowerInfoFromStrength = function(x)
		local new = ArrayUtility.filter(Powers, function(i, v)
			if typeof(v) == "table" and v.required then
				return v.required <= x
			end
		end)

		table.sort(new, function(a, b)
			return a.required < b.required
		end)

		return new[#new]
	end,

	GetNextPowerInfoFromStrength = function(x)
		local new = ArrayUtility.filter(Powers, function(i, v)
			if  typeof(v) == "table" and v.required then
				return v.required > x
			end
		end)

		table.sort(new, function(a, b)
			return a.required < b.required
		end)

		return new[1]
	end,

	GetStrengthRequiredForRebirth = function(x)
		-- Rebalanced: rebirth 1 = 25,000 Coins, then x2.2 per rebirth (5th = 585K, 10th = 34M, 20th = 81B, 30th = 196T)
		-- so rebirths follow the garden unlock pace instead of being spammable at the start.
		-- (never cheaper than the old formula)
		local old = 100*x^math.clamp(math.ceil(x / 25), 2, 7)
		return math.max(old, math.floor(25000 * 2.2^(math.max(x, 1) - 1)))
		--if x == 0 then
		--	return 0
		--end
		--local m = x%3+1
		--local z = 2+math.floor(x/3)
		--local ar = {0.5, 1, 2.5}
		--return ar[m]*10^z
	end,
	
	GetGemsGivenForRebirth = function(x)
		--return math.round(math.sqrt(x) * 100)
		return 100*x
	end,
}

return Shared