--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local Titles
local AttributeUtility
local Constants

--> Constants

---------->
local TitleUtility

TitleUtility = {
	getInfo = function(titleId)
		local _, rebirthTierInfo = TableUtility.match(Titles, function(i, v)
			return typeof(v) == "table" and v.id == titleId
		end)

		return rebirthTierInfo
	end,
	
	give = function(client, props)
		local titleId = props.id

		local clientData = client.data
		
		if clientData and titleId then
			local new = TableUtility.deep.clone(client.data:Get("titles") or {})
			
			local i, v = TableUtility.match(new, function(i, v)
				return v.id == titleId
			end)
			
			if not v then
				table.insert(new, {
					id = titleId,
					equipped = false
				})
			end
			
			client.data:Set("titles", new)
			
			return true
		end

		return false
	end,
	
	getAll = function()
		return Titles
	end,
	
	owns = function(data, titleId)
		for _, t in ipairs(data:Get("titles") or {}) do
			if t.id == titleId then
				return true
			end
		end
		return false
	end,
	
	-- The equipped title's info (or nil)
	getEquipped = function(data)
		for _, t in ipairs(data:Get("titles") or {}) do
			if t.equipped then
				return TitleUtility.getInfo(t.id)
			end
		end
		return nil
	end,
	
	-- Bonus from the equipped title for one boost type (0.05 = +5%). "all" is added to every type.
	getBoost = function(data, boostType)
		local info = data and TitleUtility.getEquipped(data)
		if not info or not info.boosts then
			return 0
		end
		return (info.boosts[boostType] or 0) + (info.boosts.all or 0)
	end,
	
	-- Multiplier version: 1 + bonus
	getMultiplier = function(data, boostType)
		return 1 + TitleUtility.getBoost(data, boostType)
	end,
	
	-- "+5% Luck", "+15% All Boosts" ... for the menu
	describeBoosts = function(titleInfo)
		local names = {luck = "Fruit Luck", walk_speed = "Walk Speed", harvest_speed = "Harvest Speed", coins = "Coins", all = "All Boosts"}
		local order = {"all", "luck", "coins", "harvest_speed", "walk_speed"}
		local lines = {}
		for _, key in ipairs(order) do
			local v = titleInfo.boosts and titleInfo.boosts[key]
			if v and v > 0 then
				table.insert(lines, "+" .. math.floor(v * 100 + 0.5) .. "% " .. names[key])
			end
		end
		return lines
	end,

	_init = function()
		Titles = _L.Get {"Common", "Modules", "Databases", "Titles"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return TitleUtility