--> Variables
local _L = _G._L

local TableUtility
local Maid

--> Constants
	
------------->
local Tracker = {}
Tracker.__index = Tracker

function Tracker.Subscribe(trackers, subscribingFunc)
	local unlisteners = {}

	for _, tracker in pairs(trackers) do
		table.insert(unlisteners, tracker:Bind(function(value)
			subscribingFunc(tracker)
		end))
	end

	return function()
		for _, unlistener in pairs(unlisteners) do
			unlistener()
		end
	end
end

function Tracker.new(value, props)
	local self = setmetatable({}, Tracker)
	
	self._value = value
	self._last_value = nil
	self._props = props
	
	self._listeners = {}
	
	return self
end

function Tracker:Bind(listenerFunc, props)
	props = {}
	
	props = {
		fire_first = props.fire_first or true,
		fire_any_change = props.fire_any_change or false
	}
	
	table.insert(self._listeners, {listenerFunc, props})
	
	if props.fire_first then
		task.spawn(function()
			listenerFunc(self._value)
		end)
	end
	
	return function()
		local i, v = TableUtility.match(self._listeners, function(i, v)
			return v[1] == listenerFunc
		end)
		
		if i then
			table.remove(self._listeners, i)
		end
	end
end

function Tracker:Set(value, props)
	local areTables = typeof(value) == "table" and typeof(self._value) == "table"
	
	local lastValue = self._value

	self._last_value = lastValue
	self._props = if props then props.props else nil
	
	if areTables then
		value = TableUtility.deep.copy(value)
		self._value = TableUtility.deep.copy(self._value)
		
		if not TableUtility.deep.compare(value, self._value) then
			self._value = TableUtility.deep.copy(value)
			self:Fire()
		end
	elseif value ~= self._value then
		self._value = value
		self:Fire()
	end
end

function Tracker:Get()
	return TableUtility.deep.clone(self._value)
end

function Tracker:Fire()
	for _, listenerFunc in pairs(self._listeners) do
		task.spawn(function()
			listenerFunc[1](self._value, self._props)
		end)
	end
end

function Tracker:GetLast()
	return self._last_value
end

function Tracker:GetProps()
	return self._props
end

function Tracker:GiveTask(...)
	if not self._maid then
		self._maid = Maid.new()

		self._maid:GiveTask(...)
	end
end

function Tracker:Destroy()
	if self._maid then
		self._maid:Destroy()
	end
end

function Tracker._init()
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"}
end

return Tracker