--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local TrainingAreas
local AttributeUtility
local Constants
local Services
local NumberUtility
local Network

--> Constants

---------->
local LuckPassUtility

LuckPassUtility = {
	getInfo = function(luckPassId)
		local _, luckPassInfo = TableUtility.match(LuckPasses, function(i, v)
			return typeof(v) == "table" and v.id == luckPassId
		end)

		return luckPassInfo
	end,
	
	getBestInfo = function(data)
		local i, v = TableUtility.max(TableUtility.filter(data:Get("lucky_passes"), function(i, v)
			return v
		end), function(i, v)
			return i
		end)
		
		return LuckPassUtility.getInfo(i)
	end,
	
	getNextInfo = function(luckPassId)
		local luckPassInfo = LuckPassUtility.getInfo(luckPassId)
		local nextLuckPassInfo = LuckPassUtility.getInfo(luckPassInfo.id + 1)
		return nextLuckPassInfo
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
		Network = _L.Get {"Common", "Library", "Network"}
		LuckPasses = _L.Get {"Common", "Modules", "Databases", "LuckPasses"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end,
	
	_start = function()
	end,
}

return LuckPassUtility