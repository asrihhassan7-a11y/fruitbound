--> Variables
local _L = _G._L

local TableUtility

--> Constants

---------->
local DictionaryUtility

DictionaryUtility = {
	values = function(d)
		local new = {}
		for k, v in pairs(d) do
			table.insert(new, v)
		end
		return new
	end,

	keys = function(d)
		local new = {}
		for k, v in pairs(d) do
			table.insert(new, k)
		end
		return new
	end,
	
	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		
		DictionaryUtility.length = TableUtility.length
		DictionaryUtility.entries = TableUtility.entries
		DictionaryUtility.map = TableUtility.map
		DictionaryUtility.match = TableUtility.match
		DictionaryUtility.copy = TableUtility.copy
		DictionaryUtility.filter = TableUtility.filter
	end,
}

DictionaryUtility.toArray = DictionaryUtility.values

return DictionaryUtility