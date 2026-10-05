--> Variables
local _L = _G._L

local TableUtility
local Services
local Promise
local Signal
local User
local ProfileService
local ProfileStore
local Network
local DictionaryUtility
local ArrayUtility

--> Constants
	
-- Fields of a player's save that OTHER clients may see (everything else only goes to the owner):
--   fruits / pets     -> their followers are drawn on every client, trade window
--   titles, boosts, stats -> character overhead / leaderboard-style info
--   gamepasses        -> per-player perks shown on the character
local PUBLIC_FIELDS = {
	fruits = true, pets = true, titles = true, boosts = true, stats = true, gamepasses = true,
	crop_legacy = true, -- rank shown above other players (RankUtility reads crop_legacy.rank)
}

local function publicView(value)
	local view = {}
	if typeof(value) == "table" then
		for k in pairs(PUBLIC_FIELDS) do
			view[k] = value[k]
		end
	end
	return view
end

------------->
local Data = {_objects = {}}
Data.__index = Data

function Data.Await(player, dontYield)
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

			newTrove:Connect(User.Removed, function(removedUser)
				if removedUser._player == player then
					reject()
				end
			end)
		end):finally(function()
			newTrove:Destroy()
		end):catch(warn):expect()
	end
end

function Data.Add(user)
	local player = user._player
	local data = Data._objects[player]
	
	if not data then
		local newData = Data.new(user)
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

function Data.new(user)
	local self = setmetatable({}, Data)
	
	self._user = user
	self._player = self._user._player
	
	self._profile = nil
	self._tracker = nil
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function Data:_construct()
	self._trove:Add(function()
		if self._profile then
			self._profile:Release()
		else
			self._player:Kick()
		end
	end)
	
	local profileStore = ProfileStore:expect()
	local profile = (if Settings.data.mock and Services.RunService:IsStudio() then profileStore.Mock else profileStore):LoadProfileAsync("Player_" .. self._player.UserId, "ForceLoad")
	
	self._profile = profile
	
	if profile then
		profile:Reconcile()
		-- crop progression migration (old 6-item Kills -> Crops_Harvested; once, plus old-server catch-up), before any reader
		local okMigrate, migrateErr = pcall(function()
			local ProgressUtility = _L.Get {"Common", "Modules", "Utilities", "ProgressUtility"}
			ProgressUtility.migrateCropProgress(profile.Data, _L.Get {"Common", "Modules", "Databases", "Ranks"}, _L.Get {"Common", "Modules", "Databases", "Achievements"}, _L.Get {"Common", "Modules", "Databases", "Quests"})
		end)
		if not okMigrate then
			warn("[Data] crop progression migration failed (will retry next join):", migrateErr)
		end
		profile:ListenToRelease(function()
			self._player:Kick()
		end)

		if self._player:IsDescendantOf(Services.Players) and self._player then
			self._tracker = TableTracker.new(self._profile.Data)
			
			self._trove:Add(self._tracker:Bind({}, function(value, path)
				local now = tick()
				local changed = if path then TableUtility.deep.get(value, path) else value
				-- the owner gets every change; other players only get the public fields (see PUBLIC_FIELDS)
				local top = if typeof(path) == "table" then path[1] else path
				for _, other in ipairs(Services.Players:GetPlayers()) do
					if other == self._player then
						Network.Remote.Fire("C_Data_Update", other, self._player, path, changed, now)
					elseif top == nil then
						Network.Remote.Fire("C_Data_Update", other, self._player, nil, publicView(value), now)
					elseif PUBLIC_FIELDS[top] then
						Network.Remote.Fire("C_Data_Update", other, self._player, path, changed, now)
					end
				end
				self._profile.Data = value
			end))
			
			Data._objects[self._player] = self
			Data.Added:Fire(self)
		else
			-- player left while loading: release the profile right away (Data.Remove can't, it isn't registered yet)
			self:Destroy()
		end
	else
		-- load failed: kick instead of letting the player play unsaved (nothing is ever written over their save)
		self:Destroy()
	end
end

function Data:Get(path)
	return self._tracker:Get(path)
end

function Data:Set(path, value)
	return self._tracker:Set(path, value, path)
end

function Data:Bind(path, func)
	return self._tracker:Bind(path, func)
end

function Data:Track(path)
	return self._tracker:Track(path)
end

function Data:Destroy()
	self._trove:Destroy()
end

function Data._init()
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	DictionaryUtility = _L.Get {"Common", "Library", "Utilities", "DictionaryUtility"}
	Services = _L.Get {"Common", "Library", "Services"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	User = _L.Get {"Server", "Modules", "Classes", "User"}
	ProfileService = _L.Get {"Server", "Library", "ProfileService"}
	Settings = _L.Get {"Common", "Modules", "Settings"}
	TableTracker = _L.Get {"Common", "Library", "Classes", "Tracker", "TableTracker"}
	Network = _L.Get {"Common", "Library", "Network"}
	
	Data.Added = Signal.new()
end

function Data._start()
	-- Returns {player, data} pairs: the requester's own full save, and only the PUBLIC_FIELDS of everyone else.
	-- Arguments from the client are ignored. Throttled so it can't be spammed for big payloads.
	local lastRequest = {}
	Services.Players.PlayerRemoving:Connect(function(p)
		lastRequest[p] = nil
	end)
	Network.Remote.Invoked("S_Data_Request", function(player)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < 2 then
			return {}
		end
		lastRequest[player] = now
		local out = {}
		for owner, v in pairs(Data._objects) do
			if v._tracker ~= nil then
				local value = v._tracker:Get()
				table.insert(out, {owner, if owner == player then value else publicView(value)})
			end
		end
		return out
	end)
	
	ProfileStore = Promise.new(function(resolve, reject)
		resolve(ProfileService.GetProfileStore(Settings.data.key, Settings.data.template))
	end)
end

return Data