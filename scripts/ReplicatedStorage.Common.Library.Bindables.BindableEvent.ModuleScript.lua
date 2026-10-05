--> Variables
local _L = _G._L

--> Constants

---------->
local BindableEvent = {}
BindableEvent.__index = BindableEvent

function BindableEvent.new()
	local self = setmetatable({}, BindableEvent)
	
	self._listeners = {}
	
	return self
end

function BindableEvent:Connect(callback)
	table.insert(self._listeners, callback)
	return {
		Disconnect = function()
			for i, listener in ipairs(self._listeners) do
				if listener == callback then
					table.remove(self._listeners, i)
					break
				end
			end
		end
	}
end

function BindableEvent:Fire(...)
	local args = {...}
	for _, listener in ipairs(self._listeners) do
		task.spawn(function()
			listener(unpack(args))
		end)
	end
end

return BindableEvent