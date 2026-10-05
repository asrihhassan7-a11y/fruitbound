--> Variables
local _L = _G._L

local TableUtility
local Services
local Promise
local Signal
local Network

--> Constants
	
------------->
local Data = {_objects = {}}
Data.__index = Data

function Data.Await(player, dontYield)
	player = player or _L.Player
	
	local data = Data._objects[player]
	
	if data then
		return data
	elseif not dontYield then
		local newTrove = Trove.new()
		
		return Promise.new(function(resolve, reject)
			local data = Data._objects[player]
			
			if data then
				resolve(data)
				return
			end
			
			newTrove:Connect(Data.Added, function(addedData)
				if addedData._player == player then
					resolve(addedData)
				end
			end)

			newTrove:Connect(Services.Players.PlayerRemoving, function(removedPlayer)
				if removedPlayer == player then
					reject()
				end
			end)
		end):finally(function()
			newTrove:Destroy()
		end):catch(warn):expect()
	end
end

function Data.Add(player, value)
	local data = Data._objects[player]
	
	if not data then
		local newData = Data.new(player, value)
		data = newData
	end
	
	return data
end

function Data.Remove(player)
	local data = Data._objects[player]

	if data then
		Data._objects[player] = nil
		data:Destroy()
	end
end

function Data.new(player, value)
	local self = setmetatable({}, Data)
	
	self._player = player
	
	self._cache = {}
	
	self._trove = Trove.new()
	
	self._tracker = self._trove:Add(TableTracker.new(value))
	
	self:_construct()
	
	return self
end

function Data:_construct()
	Data._objects[self._player] = self
	
	Data.Added:Fire(self)
end

function Data:Get(path)
	return self._tracker:Get(path)
end

function Data:Bind(path, func)
	return self._tracker:Bind(path, func)
end

function Data:Track(path)
	return self._tracker:Track(path)
end

function Data:_update(path, value, updateTime)
	local encodedPath = Services.HttpService:JSONEncode(path)
	
	if self._cache[encodedPath] and self._cache[encodedPath] > updateTime then
		return
	end 
	
	self._cache[encodedPath] = updateTime
	
	return self._tracker:Set(path, value)
end

function Data:Destroy()
	self._trove:Destroy()
end

function Data._init()
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Services = _L.Get {"Common", "Library", "Services"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	TableTracker = _L.Get {"Common", "Library", "Classes", "Tracker", "TableTracker"}
	Network = _L.Get {"Common", "Library", "Network"}
	
	Data.Added = Signal.new()
end

function Data._start()
	Services.Players.PlayerRemoving:Connect(function(player)
		Data.Remove(player)
	end)
	
	Network.Remote.Fired("C_Data_Update", function(player, path, value, updateTime)
		local data = Data.Add(player, value, updateTime)
		data:_update(path, value, updateTime)
	end)
	
	local values = Network.Remote.Invoke("S_Data_Request") or {}
	
	for _, value in pairs(values) do
		task.spawn(function()
			Data.Add(value[1], value[2])
		end)
	end
end

return Data