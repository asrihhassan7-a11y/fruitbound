--> Variables
local _L = _G._L

local TableUtility
local Services
local Promise
local Signal
local Data
local Purchases
local Network

--> Constants
	
------------->
local User = {_objects = {}}
User.__index = User

function User.Await(player, dontYield)
	local user = User._objects[player]
	
	if user then
		return user
	elseif not dontYield then
		local newTrove = Trove.new()
		
		return Promise.new(function(resolve, reject)
			newTrove:Connect(User.Added, function(addedUser)
				if addedUser._player == player then
					resolve(addedUser)
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

function User.Add(player)
	local user = User._objects[player]
	
	if not user then
		local newUser = User.new(player)
		
		User._objects[player] = newUser
		
		user = newUser
	end
	
	return user
end

function User.Remove(player)
	local user = User._objects[player]

	if user then
		User._objects[player] = nil
		user:Destroy()
	end
end

function User.new(player)
	local self = setmetatable({}, User)
	
	self._player = player
	
	self._data = nil
	self._purchases = nil
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function User:_construct()
	self._trove:Add(function()
		Data.Remove(self._player)
		Purchases.Remove(self._player)
	end)
	
	local thread = task.spawn(function()
		self._data = Data.Add(self)
		self._purchases = Purchases.Add(self)
		User.Added:Fire(self)
	end)
	
	self._trove:Add(function()
		self._trove:AddPromise(Promise.new(function(resolve, reject)
			Network.Bindable.Invoke("S_User_Removing")
			resolve()
		end):finally(function()
			pcall(function()
				task.cancel(thread)
			end)
		end))
	end)
end

function User:Destroy()
	self._trove:Destroy()
end

function User._init()
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Services = _L.Get {"Common", "Library", "Services"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Data = _L.Get {"Server", "Modules", "Classes", "Data"}
	Purchases = _L.Get {"Server", "Modules", "Classes", "Purchases"}
	Network = _L.Get {"Common", "Library", "Network"}
	
	User.Added = Signal.new()
end

function User._start()
	Services.Players.PlayerRemoving:Connect(function(player)
		User.Remove(player)
	end)

	for _, player in pairs(Services.Players:GetPlayers()) do
		task.spawn(function()
			User.Add(player)
		end)
	end
	
	Services.Players.PlayerAdded:Connect(function(player)
		User.Add(player)
	end)
end

return User