--> Variables
local _L = _G._L

--> Constants

---------->
local TableUtility

TableUtility = {	
	all = function(t, f)
		local tt = true
		for a, b in pairs(t) do
			if f(a, b) == false then
				tt = false
			end
		end
		return tt
	end,
	
	once = function(t, f)
		for a, b in pairs(t) do
			return f(a, b)
		end
	end,
	
	filter = function(t, predicate)
		local new = {}
		for k, v in pairs(t) do
			if predicate(k, v) then
				new[k] = v
			end
		end
		return new
	end,
	
	max = function(t, mapper)
		local bk, bv, bn
		
		for k, v in pairs(t) do
			local n = mapper(k, v)
			
			if not bv or n >= bn then
				bk, bv, bn = k, v, n
			end
		end
		
		return bk, bv, bn
	end,
	
	min = function(t, mapper)
		local bk, bv, bn

		for k, v in pairs(t) do
			local n = mapper(k, v)

			if not bv or n <= bn then
				bk, bv, bn = k, v, n
			end
		end

		return bk, bv, bn
	end,
	
	entries = function(d)
		local new = {}
		for k, v in pairs(d) do
			table.insert(new, {k,v})
		end
		return new
	end,

	match = function(t, predicate)
		for k, v in pairs(t) do
			if predicate(k, v) then
				return k, v
			end
		end
	end,
	
	length = function(t)
		local n = 0
		for k, v in pairs(t) do
			n += 1
		end
		return n
	end,
	
	map = function(d, mapper)
		local new = {}
		for k, v in pairs(d) do
			local mk, mv = mapper(k, v)
			new[mk or k] = mv
		end
		return new
	end,
	
	sort = function(t, f)
		table.sort(t, f)
		return t
	end,
	
	deep = {
		set = function(t, p, v)
			if #p == 0 then
				t = v
				return
			end

			local n = 0

			for i = 1, TableUtility.length(p) do
				if i == TableUtility.length(p) then 
					t[p[i]] = v
				end
				t = t[p[i]] 
			end
		end,

		get = function(t, p)
			local n = 0

			if TableUtility.length(p) == 0 then
				return t
			end

			for i = 1, TableUtility.length(p) do
				if i == TableUtility.length(p) then 
					return t[p[i]]
				end

				if t[p[i]] and typeof(t[p[i]]) == "table" then
					t = t[p[i]] 
				else
					break
				end
			end
		end,

		compare = function(t1, t2)
			local function compare(t1, t2)
				local ty1 = type(t1)
				local ty2 = type(t2)

				if ty1 ~= ty2 then return false end
				if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end

				for k1, v1 in pairs(t1) do
					local v2 = t2[k1]
					if v2 == nil or not compare(v1, v2) then return false end
				end

				for k2, v2 in pairs(t2) do
					local v1 = t1[k2]
					if v1 == nil or not compare(v1, v2) then return false end
				end

				return true
			end

			return compare(t1, t2)
		end,

		copy = function(target, _context)
			_context = _context or  {}
			if _context[target] then
				return _context[target]
			end

			if type(target) == "table" then
				local new = {}
				_context[target] = new
				for index, value in pairs(target) do
					new[TableUtility.deep.copy(index, _context)] = TableUtility.deep.copy(value, _context)
				end
				return setmetatable(new, TableUtility.deep.copy(getmetatable(target), _context))
			else
				return target
			end
		end,
	},
	
	copy = table.clone,
}

TableUtility.clone = TableUtility.copy
TableUtility.deep.clone = TableUtility.deep.copy

return TableUtility