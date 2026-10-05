--> Variables
local _L = _G._L

local TableUtility

--> Constants

---------->
local ArrayUtility

ArrayUtility = {
	remove = function(t, needle)
		local i = table.find(t, needle)
		if i then
			table.remove(t, i)
		end
		return t
	end,
	
	filter = function(t, predicate)
		if not t then return warn("T has no length") end
		local new = {}
		for k, v in pairs(t) do
			if predicate(k, v) then
				table.insert(new, v)
			end
		end
		return new
	end,
	
	reverse = function(t)
		local new = {}
		for i=#t, 1, -1 do
			table.insert(new, t[i])
		end
		return new
	end,
	
	shuffle = function(t, random)
		if random then
			for i = #t, 2, -1 do
				local j = random:NextInteger(1, i)
				t[i], t[j] = t[j], t[i]
			end
		else
			for i = #t, 2, -1 do
				local j = math.random(i)
				t[i], t[j] = t[j], t[i]
			end
		end
	end,
	
	random = function(t)
		local r = math.random(1, #t)
		return r, t[r]
	end,
	
	map = function(t, mapper)
		local new = {}
		for k, v in pairs(t) do
			local mv = mapper(k, v)
			table.insert(new, mv)
		end
		return new
	end,
	
	sort = function(t, ...)
		table.sort(t, ...)
		return t
	end,
	
	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		
		ArrayUtility.length = TableUtility.length
		ArrayUtility.entries = TableUtility.entries
		--ArrayUtility.map = TableUtility.map
		ArrayUtility.match = TableUtility.match
		ArrayUtility.copy = TableUtility.copy
	end,
}

return ArrayUtility