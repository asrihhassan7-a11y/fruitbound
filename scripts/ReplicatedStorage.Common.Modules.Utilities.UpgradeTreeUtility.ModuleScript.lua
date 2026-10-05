--> Variables
local _L = _G._L

local UpgradeTree

---------->
-- Shared helpers for the Upgrade Tree (used by both server and client).
-- Player data stores levels in data.tree[nodeId] = level
local UpgradeTreeUtility

UpgradeTreeUtility = {
	getAll = function()
		return UpgradeTree
	end,

	getInfo = function(nodeId)
		for _, node in ipairs(UpgradeTree) do
			if node.id == nodeId then
				return node
			end
		end
		return nil
	end,

	getLevel = function(data, nodeId)
		local tree = data:Get("tree")
		return (tree and tree[nodeId]) or 0
	end,

	-- Cost to go from `level` to `level + 1`
	getCost = function(nodeId, level)
		local node = UpgradeTreeUtility.getInfo(nodeId)
		if not node then
			return math.huge
		end
		return math.floor(node.base_cost * node.growth ^ level)
	end,

	isUnlocked = function(data, nodeId)
		local node = UpgradeTreeUtility.getInfo(nodeId)
		if not node then
			return false
		end
		if not node.requires then
			return true
		end
		return UpgradeTreeUtility.getLevel(data, node.requires.node) >= node.requires.level
	end,

	isMaxed = function(data, nodeId)
		local node = UpgradeTreeUtility.getInfo(nodeId)
		return node ~= nil and UpgradeTreeUtility.getLevel(data, nodeId) >= node.max_level
	end,

	-- Total bonus of an effect type across all nodes (sum of level * per_level)
	getBonus = function(data, effect)
		local total = 0
		local tree = data:Get("tree") or {}
		for _, node in ipairs(UpgradeTree) do
			if node.effect == effect then
				total += (tree[node.id] or 0) * node.per_level
			end
		end
		return total
	end,

	-- Ready-to-use multipliers
	getCoinMultiplier = function(data)
		return 1 + UpgradeTreeUtility.getBonus(data, "coins")
	end,

	getLuckMultiplier = function(data)
		return 1 + UpgradeTreeUtility.getBonus(data, "luck")
	end,

	getRebirthPowerMultiplier = function(data)
		return 1 + UpgradeTreeUtility.getBonus(data, "rebirth_power")
	end,

	getRebirthCostMultiplier = function(data)
		return math.max(0.1, 1 - UpgradeTreeUtility.getBonus(data, "rebirth_discount"))
	end,

	getRebirthGemsMultiplier = function(data)
		return 1 + UpgradeTreeUtility.getBonus(data, "rebirth_gems")
	end,

	_init = function()
		UpgradeTree = _L.Get {"Common", "Modules", "Databases", "UpgradeTree"}
	end,
}

return UpgradeTreeUtility
