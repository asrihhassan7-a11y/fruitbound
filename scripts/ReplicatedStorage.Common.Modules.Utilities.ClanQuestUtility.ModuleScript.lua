--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local ClanQuests
local AttributeUtility
local Constants

--> Constants

---------->
local ClanQuestUtility

ClanQuestUtility = {
	getInfo = function(clanQuestId)
		local _, clanQuestInfo = TableUtility.match(ClanQuests, function(i, v)
			return typeof(v) == "table" and v.id == clanQuestId
		end)

		return clanQuestInfo
	end,
	
	canClaimServer = function(clanQuestId, clan, client)
		warn("a")
		local clanQuestInfo = ClanQuestUtility.getInfo(clanQuestId)

		if not clanQuestInfo then
			return false
		end
		
		warn("b")
		local _, clanPlayerData = TableUtility.match(clan._data:Get("players"), function(i, v)
			return v[1] == client.player.UserId
		end)

		if clanPlayerData and clanPlayerData[2] then
			warn("C")
			local success = clanQuestInfo.server_predicate(clan, client)
			
			if success and not client.data:Get({"clan_quests", clanQuestInfo.id}) then
				warn("e")
				local _, clanQuestData = TableUtility.match(clan._data:Get("quests"), function(i, v)
					return v[1] == clanQuestId
				end)

				if clanQuestData and clanQuestData[2] >= clanPlayerData[2] then
					return true
				end
			end
		end
		
		return false
	end,
	
	canClaimClient = function(clanQuestId, clanData, playerData)
		local clanQuestInfo = ClanQuestUtility.getInfo(clanQuestId)

		if not clanQuestInfo then
			return false
		end
		
		local _, clanPlayerData = TableUtility.match(clanData:Get("players"), function(i, v)
			return v[1] == _L.Player.UserId
		end)
		
		if clanPlayerData and clanPlayerData[2] then
			local success = clanQuestInfo.client_predicate(clanData, playerData)

			if success then
				if not playerData:Get({"clan_quests", clanQuestInfo.id}) then
					local _, clanQuestData = TableUtility.match(clanData:Get("quests"), function(i, v)
						return v[1] == clanQuestId
					end)

					if clanQuestData and clanQuestData[2] >= clanPlayerData[2] then
						return true
					end
				else
					return false, "already"
				end
			end
		end

		return false
	end,
	
	_init = function()
		ClanQuests = _L.Get {"Common", "Modules", "Databases", "ClanQuests"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return ClanQuestUtility