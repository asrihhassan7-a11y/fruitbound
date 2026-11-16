-- Session-locked DataStore persistence. Never hands out a blank profile when a real load fails:
-- the player is kicked instead, so progress can't be overwritten.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Util = require(Shared.Util)
local Foods = require(Shared.Config.Foods)

local DataService = {}

DataService.MOCK = false -- keep false outside testing (true = in-memory only, nothing saved)
local STORE_NAME = "TFFD_PlayerData_v1"
local LOCK_STALE = 180 -- seconds; autosave refreshes the lock every AUTOSAVE seconds
local AUTOSAVE = 60
local VERSION = 1

local TEMPLATE = {
	Version = VERSION,
	Coins = 0,
	TotalCoins = 0,
	XP = 0,
	Level = 1,
	MaxZone = 1,
	Foods = { [Foods.Default] = true },
	EquippedFood = Foods.Default,
	Upgrades = { range = 0, speed = 0, bonus = 0, crit = 0, multi = 0 },
	Dragons = {}, -- [dragonId] = times fed
	Stats = { Feeds = 0, Throws = 0, RareFeeds = 0, MythicFeeds = 0, Hatches = 0 },
	Pets = {}, -- [uid] = petId
	Equipped = {}, -- { uid }
	NextUid = 1,
	Daily = { Streak = 0, Last = 0 },
	Quests = { Day = 0, List = {} },
	Achievements = {}, -- [id] = true when claimed
	Boosts = {}, -- [name] = expiry unix time
	Settings = { Music = 0.5, Sfx = 0.8, LowGfx = false, ShowOthers = true },
	AutoThrow = false,
	Receipts = {}, -- [purchaseId] = true
	ReceiptOrder = {},
}

local store: DataStore? = nil
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local listeners: { (Player, any) -> () } = {}

local function migrate(data)
	data.Version = VERSION
	Util.reconcile(data, TEMPLATE)
	if not Foods.ById[data.EquippedFood] or not data.Foods[data.EquippedFood] then
		data.EquippedFood = Foods.Default
	end
	return data
end

local function key(userId: number): string
	return "P_" .. userId
end

local function initStore()
	if DataService.MOCK then
		return
	end
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = res
	elseif RunService:IsStudio() then
		warn("[TFFD] DataStore unavailable in Studio (enable API access to test saving). Using session-only data:", res)
		DataService.MOCK = true
	else
		error(res)
	end
end

-- Returns data, or nil + reason.
local function loadAsync(player: Player)
	if DataService.MOCK then
		return Util.deepCopy(TEMPLATE)
	end
	local k = key(player.UserId)
	for attempt = 1, 8 do
		local result, lockedBy = nil, nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(k, function(old)
				old = old or Util.deepCopy(TEMPLATE)
				local lock = old.Lock
				if lock and lock.Job ~= game.JobId and os.time() - (lock.Time or 0) < LOCK_STALE then
					lockedBy = lock.Job
					return nil -- abort write, keep their lock
				end
				old.Lock = { Job = game.JobId, Time = os.time() }
				result = old
				return old
			end)
		end)
		if not player.Parent then
			return nil, "left"
		end
		if ok and result then
			return result
		end
		if not ok then
			warn("[TFFD] Load attempt", attempt, "failed:", err)
		end
		task.wait(math.min(2 ^ attempt, 10))
	end
	return nil, "locked"
end

local function saveAsync(player: Player, release: boolean): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	if DataService.MOCK then
		dirty[player] = nil
		return true
	end
	local snapshot = Util.deepCopy(data)
	for attempt = 1, 4 do
		local stolen = false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key(player.UserId), function(old)
				if old and old.Lock and old.Lock.Job ~= game.JobId then
					stolen = true
					return nil -- another server owns this profile now; never overwrite it
				end
				snapshot.Lock = (not release) and { Job = game.JobId, Time = os.time() } or nil
				return snapshot
			end)
		end)
		if ok then
			if stolen then
				warn("[TFFD] Session lock lost for", player.UserId, "- save skipped")
				return false
			end
			dirty[player] = nil
			return true
		end
		warn("[TFFD] Save attempt", attempt, "failed:", err)
		task.wait(attempt * 1.5)
	end
	return false
end

function DataService.get(player: Player)
	return profiles[player]
end

-- Waits (up to timeout) for the profile to finish loading.
function DataService.wait(player: Player, timeout: number?)
	local t0 = os.clock()
	while player.Parent and not profiles[player] and os.clock() - t0 < (timeout or 15) do
		task.wait(0.2)
	end
	return profiles[player]
end

function DataService.markDirty(player: Player)
	dirty[player] = true
end

function DataService.saveNow(player: Player): boolean
	return saveAsync(player, false)
end

function DataService.onLoaded(fn: (Player, any) -> ())
	table.insert(listeners, fn)
	for p, d in profiles do
		task.spawn(fn, p, d)
	end
end

local function onPlayerAdded(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true
	local data, reason = loadAsync(player)
	loading[player] = nil
	if not player.Parent then
		return
	end
	if not data then
		player:Kick(reason == "locked" and "Your data is still saving on another server. Please rejoin in a minute." or "Could not load your data safely. Please rejoin.")
		return
	end
	profiles[player] = migrate(data)
	for _, fn in listeners do
		task.spawn(fn, player, profiles[player])
	end
end

local function onPlayerRemoving(player: Player)
	-- wait for an in-flight load so we don't drop the lock or save nothing
	while loading[player] do
		task.wait(0.2)
	end
	if profiles[player] then
		saveAsync(player, true)
		profiles[player] = nil
	end
	dirty[player] = nil
end

function DataService.start()
	initStore()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for p in profiles do
				task.spawn(saveAsync, p, false) -- always refresh the lock
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for p in profiles do
			pending += 1
			task.spawn(function()
				saveAsync(p, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

DataService.Template = TEMPLATE
return DataService
