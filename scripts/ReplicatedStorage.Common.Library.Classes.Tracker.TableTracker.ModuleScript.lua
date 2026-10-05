--> Variables
local _L = _G._L

local Services
local TableUtility
local TablePathUtility
local Tracker

--> Constants
	
------------->
local TableTracker = {}
TableTracker.__index = TableTracker

function TableTracker.new(value)
	local self = setmetatable({}, TableTracker)
	
	self._value = {
		value = value or {}
	}
	
	self._listeners = {}
	
	return self
end

function TableTracker:Bind(path, listenerFunc)
	path = TablePathUtility.format(path)
	
	local encodedPath = Services.HttpService:JSONEncode(path)
	
	local _, pack = TableUtility.match(self._listeners, function(k, v)
		return v[1] == encodedPath
	end)
	
	local trackerListener = self:Track(path)
	
	return trackerListener:Bind(listenerFunc)
end

function TableTracker:Get(path)
	path = TablePathUtility.format(path)
	return TableUtility.deep.get(self._value, {"value", unpack(path)})
end

function TableTracker:Set(path, value, ...)
	path = TablePathUtility.format(path)
	
	local encodedPath = Services.HttpService:JSONEncode(path)
	
	local new = TableUtility.deep.clone(self._value)
	
	TableUtility.deep.set(new, {"value", unpack(path)}, TableUtility.deep.copy(value))
	
	self._value = new
	
	local _, pack = TableUtility.match(self._listeners, function(k, v)
		return v[1] == encodedPath
	end)

	if not pack then
		pack = {encodedPath, Tracker.new(TableUtility.deep.clone(TableUtility.deep.get(self._value, {"value", unpack(path)})))}
		table.insert(self._listeners, pack)
	end
	
	self:_update(...)
end

function TableTracker:Track(path)
	path = TablePathUtility.format(path)
	
	local encodedPath = Services.HttpService:JSONEncode(path)

	local _, pack = TableUtility.match(self._listeners, function(k, v)
		return v[1] == encodedPath
	end)

	local trackerListener

	if not pack then
		trackerListener = Tracker.new(TableUtility.deep.get(self._value, {"value", unpack(path)}))

		pack = {encodedPath, trackerListener}

		table.insert(self._listeners, pack)
	else
		trackerListener = pack[2]
	end

	return trackerListener
end

function TableTracker:_update(...)
	for _, pack in pairs(self._listeners) do
		local encodedPath = pack[1]
		local trackerListener = pack[2]
		
		local listenerPath = TablePathUtility.format(Services.HttpService:JSONDecode(encodedPath))
		trackerListener:Set(TableUtility.deep.clone(TableUtility.deep.get(self._value, {"value", unpack(listenerPath)})), ...)
	end
end

function TableTracker:Destroy()
	table.clear(self._listeners)
end

function TableTracker._init()
	Services = _L.Get {"Common", "Library", "Services"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	TablePathUtility = _L.Get {"Common", "Library", "Utilities", "TablePathUtility"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
end

return TableTracker