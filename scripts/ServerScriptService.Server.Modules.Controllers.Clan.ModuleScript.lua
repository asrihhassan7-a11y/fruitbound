--> Variables
local _L = _G._L

local Services
local Maid
local Network
local Audio
local TableUtility
local Create
local ArrayUtility
local Timer
local Tracker
local ClanQuests
local Compress

--> Constants
local CLANS_DATA_STORE
local MESSAGES_SORTED_MAP
local JOIN_CODES_DATA_STORE

------------->
local Clan = {_objects = {}}
Clan.__index = Clan

function Clan._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"} 
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"} 
	TableTracker = _L.Get {"Common", "Library", "Classes", "Tracker", "TableTracker"} 
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	ClanQuests = _L.Get {"Common", "Modules", "Databases", "ClanQuests"}
	Compress = _L.Get {"Common", "Library", "Functions", "Compress"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"} 
end

function Clan:_message()
	local messageId = Services.HttpService:GenerateGUID(false)
	
	local success, result = pcall(function()
		local packet = {self._uid, self._incremented, game.JobId, {
			name = self._data:Get("name"),
			emblem = self._data:Get("emblem"),
			_type = self._data:Get("_type"),
			max_players = self._data:Get("max_players"),
			quests = self._data:Get("quests"),
			deleted = self._data:Get("deleted"),
		--	description = self._data:Get("description")
		}, self._enter, self._leave}

		return MESSAGES_SORTED_MAP:SetAsync(messageId, packet, 60)
	end)
	
	if success then
		local success, result = pcall(function()
			return Services.MessagingService:PublishAsync(self._uid, {messageId, game.JobId})
		end)
		
		if success then
			table.clear(self._incremented)
			table.clear(self._enter)
			table.clear(self._leave)
		else
			warn(result)
		end
	else
		warn(result)
	end
end

function Clan:_receive(value)
	local messageId = value.Data[1]
	local jobId = value.Data[2]
	
	local data = MESSAGES_SORTED_MAP:GetAsync(messageId)
	
	if data then
		if jobId == game.JobId then
			return
		end

		local clanIncremented = data[2]

		for k, v in pairs(clanIncremented) do
			self:increment(k, v, true)
		end

		local otherClanData = data[4]
		
		if otherClanData.name and otherClanData.name[1] and otherClanData.name[1] >= tick() then
			self._data:Set("name", otherClanData.name)
		end
		
		if otherClanData.emblem and otherClanData.emblem[1] and otherClanData.emblem[1] >= tick() then
			self._data:Set("emblem", otherClanData.emblem)
		end
		
		if otherClanData._type and otherClanData._type[1] and otherClanData._type[1] >= tick() then
			self._data:Set("_type", otherClanData._type)
		end
		
		--if otherClanData.description and otherClanData.description[1] and otherClanData.description[1] >= tick() then
		--	self._data:Set("description", otherClanData.description)
		--end
		
		self._data:Set("max_players", otherClanData.max_players)
		self._data:Set("quests", otherClanData.quests)
		self._data:Set("deleted", otherClanData.deleted)
		
		local clanEnter = data[5]

		for _, playerPacket in pairs(clanEnter) do
			self:_join(playerPacket[1], false, "Member", true, playerPacket[2])
		end

		local clanLeave = data[6]

		for _, userId in pairs(clanLeave) do
			self:_kick(userId, false, true)
		end
	end
end

function Clan._start()
	task.spawn(function()
		if not _G.CLANS_DATA_STORE then
			repeat task.wait() until _G.CLANS_DATA_STORE
		end
		
		CLANS_DATA_STORE = _G.CLANS_DATA_STORE
	end)
	
	task.spawn(function()
		if not _G.JOIN_CODES_DATA_STORE then
			repeat task.wait() until _G.JOIN_CODES_DATA_STORE
		end

		JOIN_CODES_DATA_STORE = _G.JOIN_CODES_DATA_STORE
	end)
	
	task.spawn(function()
		if not _G.MESSAGES_SORTED_MAP then
			repeat task.wait() until _G.MESSAGES_SORTED_MAP
		end

		MESSAGES_SORTED_MAP = _G.MESSAGES_SORTED_MAP
	end)
	
	if not Services.RunService:IsStudio() then
		game:BindToClose(function()
			local i = 0
			for _, clan in pairs(Clan._objects) do
				task.spawn(function()
					clan:_destroy()
					i += 1
				end)
			end
			repeat task.wait() until TableUtility.length(Clan._objects) == i
		end)
	end
end

function Clan.new(props)
	local self = setmetatable({}, Clan)
	
	self._uid = props.uid
	
	self._incremented = {}
	self._leave = {}
	self._enter = {}
	
	self._data = nil
	
	self._trove = Trove.new()
	
	self:_construct()

	return self
end

function Clan:_construct()
	Clan._objects[self._uid] = self

	self._trove:Add(function()
		Clan._objects[self._uid] = nil
	end)
	
	self._trove:AddPromise(Promise.new(function(resolve, reject)
		self:_connect()
		
		local store = self:_store()
		local fetched = self:_fetch()
		
		self._data = self._trove:Add(TableTracker.new({
			uid = fetched.uid,
			name = fetched.name,
			emblem = fetched.emblem,
			_type = fetched._type or {"Public", tick()},
			players = fetched.players,
			max_players = fetched.max_players or 10,
			kills = fetched.kills or 0, -- LEGACY clan harvest counter (old 6-item harvests), frozen
			-- real crops harvested by members (clan quest "1"). One-time migration for clans saved before
			-- it existed: floor(kills / 6), marked by crop_progression_version (kills itself is kept)
			crops_harvested = if fetched.crop_progression_version == 1 and typeof(fetched.crops_harvested) == "number"
				then fetched.crops_harvested
				else math.max(0, math.floor(tonumber(fetched.crops_harvested) or 0)) + math.max(0, math.floor((tonumber(fetched.kills) or 0) / 6)),
			crop_progression_version = 1,
			deaths = fetched.deaths or 0,
			eggs_opened = fetched.eggs_opened or 0,
			strength = fetched.strength or 0,
			rebirths = fetched.rebirths or 0,
			kings = fetched.kings or 0,
			quests = fetched.quests or {},
			join_code = fetched.join_code or nil,
			deleted = fetched.deleted or false,
			--description = fetched.description or {"", tick()},
		}))
		
		self._data:Set("quests", self:get_quests())

		self._holder = self._trove:Add(self:_create_holder())

		self._data:Bind({}, function()
			self:_update()
		end)

		self._trove:Add(Services.Players.PlayerRemoving:Connect(function(player)
			local newPlayers = self._data:Get("players")
			local t = nil
			local newUserIdIndex, _ = TableUtility.match(newPlayers, function(i, v)
				return v[1] == player.UserId
			end)
			if newUserIdIndex then
				local success, result = self:_write()
				if success then
					t = true
				end
			end
			self:_should_destroy(t)
		end))
		
		for _, client in pairs(Network.Bindable.Invoke("S_Client_GetAll")) do
			if client.data:Get("clan") == self._uid then
				local _, playerPacket = TableUtility.match(self._data:Get("players"), function(i, v)
					return v[1] == client.player.UserId
				end)
				
				if not playerPacket or self._data:Get("deleted") then
					client.data:Set("clan", nil)
				end
			end
			
			for _, playerPacket in pairs(self._data:Get("players")) do
				task.spawn(function()
					local userId = playerPacket[1]
					if (userId == client.player.UserId and client.data:Get("clan") ~= self._uid) or self._data:Get("deleted") then
						self:_kick(userId)
					end
				end)
			end
		end
		
		local owner = self:get_owner()
		
		if not self._data:Get("join_code") and owner then
			self._trove:Add(task.spawn(function()
				local store = self:_store("JoinCodes")
				
				if owner then
					local joinCode = owner[1]
					
					local success, err = pcall(function()
						return store:SetAsync(joinCode, self._uid)
					end)
					
					if success then
						self._data:Set("join_code", joinCode)
						self:_message()
					else
						warn(err)
					end
				end
			end))
		end
		
		resolve()
	end)):await()
	
	self._trove:Add(Timer.Simple(60, function()
		self:_message()
	end))
end

function Clan:_connect()
	local success, result = pcall(function()
		return Services.MessagingService:SubscribeAsync(self._uid, function(value)
			self:_receive(value)
		end)
	end)
	
	if success then
		if result then
			self._trove:Add(result)
		end
	else
		task.wait(1)
		self:_connect()
	end
end

function Clan:_should_destroy(t)
	if self._data then
		local players = self._data:Get("players")
		local shouldDestroy = true

		for _, playerPacket in pairs(players) do
			local userId = playerPacket[1]
			local player = Services.Players:GetPlayerByUserId(userId)
			if player then
				shouldDestroy = false
			end
		end

		if shouldDestroy then
			self:_destroy(t)
		end
	end
end

function Clan:_destroy(t)
	if self._destroyed then
		return
	end
	self._destroyed = true
	if not t then
		self:_write(true)
	end
	self:_message()
	self:Destroy()
end

function Clan:_create_holder()
	return Create("Folder", {
		Name = self._uid,
		Parent = _L.Debris.Clans
	})
end

function Clan:_kick(userIds, shouldWrite, ignoreCache)
	if not self._data then
		return false
	end
	if userIds then
		userIds = if typeof(userIds) == "table" then userIds else {userIds}
		local newPlayers = TableUtility.deep.clone(self._data:Get("players"))
		for _, userId in pairs(userIds) do
			local newUserIdIndex, _ = TableUtility.match(newPlayers, function(i, v)
				return v[1] == userId
			end)

			if newUserIdIndex then
				local player = Services.Players:GetPlayerByUserId(userId)

				if player then
					local client = Network.Bindable.Invoke("S_Client_Get", player)

					if client then
						client.data:Set("clan", nil)
					end
				end

				if not ignoreCache then
					local a, b = TableUtility.match(self._leave, function(i, v)
						return v == userId
					end)
					if not b then
						table.insert(self._leave, userId)
					end
				end
				table.remove(newPlayers, newUserIdIndex)
			end
		end
		if shouldWrite then
			local success, result = self:_write()
			if not success then
				self:_join(userIds, false)
				return false
			end
			self:_message()
		end
		self._data:Set("players", newPlayers)
		self:_should_destroy()
		return true
	end
	return false
end

function Clan:_join(userIds, shouldWrite, rank, ignoreCache, t)
	if not self._data then
		return false
	end
	if self._data:Get("deleted") then
		return false
	end
	t = t or tick()
	rank = rank or "Member"
	local maxPlayers = self._data:Get("max_players")
	if userIds then
		userIds = if typeof(userIds) == "table" then userIds else {userIds}
		local newPlayers = TableUtility.deep.clone(self._data:Get("players"))
		for _, userId in pairs(userIds) do
			if #newPlayers + 1 <= maxPlayers then
				local newUserIdIndex, _ = TableUtility.match(newPlayers, function(i, v)
					return v[1] == userId
				end)
				if not newUserIdIndex then
					local player = Services.Players:GetPlayerByUserId(userId)

					if player then
						local client = Network.Bindable.Invoke("S_Client_Get", player)

						if client then
							client.data:Set("clan", self._uid)
						end
					end

					if not ignoreCache then
						local a, b = TableUtility.match(self._enter, function(i, v)
							return v[1] == userId
						end)
						if not b then
							table.insert(self._enter, {userId, t})
						end
					end
					table.insert(newPlayers, {userId, t, rank})
				end
			end
		end
		self._data:Set("players", newPlayers)
		if shouldWrite then
			local success, result = self:_write()
			if not success then
				self:_kick(userIds, false)
				return false
			end
			self:_message()
		end
		self:_should_destroy()
		return true
	end
	return false, "full"
end

function Clan:_store(name)
	name = name or "Clans"
	
	if name == "Clans" then
		if not CLANS_DATA_STORE then
			repeat task.wait() until CLANS_DATA_STORE
		end
		return CLANS_DATA_STORE
	elseif name == "JoinCodes" then
		if not JOIN_CODES_DATA_STORE then
			repeat task.wait() until JOIN_CODES_DATA_STORE
		end
		return JOIN_CODES_DATA_STORE
	end
end

function Clan:_write()
	return pcall(function()
		local store = self:_store()
		return store:UpdateAsync(self._uid, function(oldData)
			oldData = oldData or {}
			
			local newPlayers = self._data:Get("players")
			
			return {
				uid = self._data:Get("uid"),
				name = self._data:Get("name"),
				emblem = self._data:Get("emblem"),
				_type = self._data:Get("_type"),
				players = newPlayers,
				max_players = self._data:Get("max_players"),
				kills = self._data:Get("kills"),
				crops_harvested = self._data:Get("crops_harvested"),
				crop_progression_version = self._data:Get("crop_progression_version"),
				deaths = self._data:Get("deaths"),
				eggs_opened = self._data:Get("eggs_opened"),
				strength = self._data:Get("strength"),
				rebirths = self._data:Get("rebirths"),
				kings = self._data:Get("kings"),
				quests = self:get_quests(),
				join_code = self._data:Get("join_code"),
				deleted = self._data:Get("deleted"),
				--description = self._data:Get("description"),
			}
		end)
	end)
end

function Clan:_fetch()
	local store = self:_store()
	return store:GetAsync(self._uid)
end

function Clan:get_owner()
	local _, v = TableUtility.match(TableUtility.deep.clone(self._data:Get("players")), function(i, v)
		return v[3] == "Owner"
	end)
	return v
end

function Clan:get_quests()
	return ArrayUtility.map(TableUtility.filter(ClanQuests, function(i, v) return typeof(v) == "table" end), function(i, v)
		local ii, vv = TableUtility.match(self._data:Get("quests") or {}, function(iii, vvv)
			return v.id == vvv[1]
		end)
		
		if vv then
			return vv
		else
			local success = v.server_predicate(self)
			
			if success then
				return {v.id, tick()}
			else
				return nil
			end
		end
	end)
end

function Clan:increment(name, value, ignoreCache)
	if self._data then
		if not ignoreCache then
			self._incremented[name] = (self._incremented[name] or 0) + value
		end
		-- (or 0): a counter another server version does not know yet starts at 0 instead of erroring
		self._data:Set(name, (self._data:Get(name) or 0) + value)
	end
end

function Clan:_update()
	local newQuests = self:get_quests()
	
	self._data:Set("quests", newQuests)
	
	AttributeUtility.set(self._holder, "data", {
		uid = self._data:Get("uid"),
		name = self._data:Get("name"),
		emblem = self._data:Get("emblem"),
		_type = self._data:Get("_type"),
		players = self._data:Get("players"),
		max_players = self._data:Get("max_players"),
		kills = self._data:Get("kills"),
		crops_harvested = self._data:Get("crops_harvested"),
		deaths = self._data:Get("deaths"),
		eggs_opened = self._data:Get("eggs_opened"),
		strength = self._data:Get("strength"),
		rebirths = self._data:Get("rebirths"),
		kings = self._data:Get("kings"),
		quests = newQuests,
		join_code = self._data:Get("join_code"),
		deleted = self._data:Get("deleted"),
		--description = self._data:Get("description"),
	})
end

function Clan:Destroy()
	self._trove:Destroy()
end

return Clan