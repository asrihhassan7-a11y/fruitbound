-- Server-authoritative dragon encounters. Zones start empty: every food that lands on an unlocked island
-- makes a dragon pop in (rolled by zone + rarity weights), run to the food, eat it, and get caught by the thrower.
-- Dragons exist only as data here; clients build and animate the models from batched events.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Net = require(Shared.Net)
local Util = require(Shared.Util)
local Zones = require(Shared.Config.Zones)
local DragonDefs = require(Shared.Config.Dragons)
local Rarities = require(Shared.Config.Rarities)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local DragonsRemote = Net.get("Dragons")
local FedRemote = Net.get("Fed")
local DiscoverRemote = Net.get("Discover")
local NotifyRemote = Net.get("Notify")
local GetDragons = Net.get("GetDragons")

local DragonService = {}

local POP_TIME = 0.45 -- spawn pop before running to the food
local EAT_TIME = 0.9
local MAX_ACTIVE_PER_PLAYER = 14
local MYTHIC_CHANCE = 1 / 350
local SECRET_CHANCE = 1 / 4000

local dragons: { [number]: any } = {}
local activeByPlayer: { [Player]: number } = {}
local nextDragonId = 1
local ops = {}
local fedListeners = {}
local rng = Random.new()
local foodFolder: Folder

function DragonService.onFed(fn)
	table.insert(fedListeners, fn)
end

local function push(op)
	table.insert(ops, op)
end

local function rollDragon(zone: number, lucky: boolean)
	local luck = lucky and 2 or 1
	-- rare event dragons
	for _, def in DragonDefs.Events do
		if def.zone == zone or def.zone == 0 then
			local chance = (def.rarity == "Secret" and SECRET_CHANCE or MYTHIC_CHANCE) * luck
			if rng:NextNumber() < chance then
				return def
			end
		end
	end
	return Util.weightedPick(DragonDefs.ByZone[zone], function(def)
		local w = Rarities.Info[def.rarity].weight
		if lucky and Rarities.Info[def.rarity].rank >= 3 then
			w *= 2
		end
		return w
	end, rng)
end

-- Spawn point: in the same zone band, 14-24 studs from the food, preferably on the far side from the thrower.
local function spawnPoint(zone: number, food: Vector3, from: Vector3): Vector3
	local z0, z1 = Zones.band(zone)
	local halfW = Zones.FIELD_W / 2 - 4
	local away = Vector3.new(food.X - from.X, 0, food.Z - from.Z)
	local baseAngle = away.Magnitude > 1 and math.atan2(away.Z, away.X) or rng:NextNumber(0, math.pi * 2)
	local a = baseAngle + rng:NextNumber(-1.3, 1.3)
	local d = rng:NextNumber(14, 24)
	return Vector3.new(math.clamp(food.X + math.cos(a) * d, -halfW, halfW), 0, math.clamp(food.Z + math.sin(a) * d, z0 + 2, z1 - 2))
end

local function finish(d)
	dragons[d.id] = nil
	if d.owner and activeByPlayer[d.owner] then
		activeByPlayer[d.owner] = math.max(0, activeByPlayer[d.owner] - 1)
	end
end

local function reward(d)
	local owner = d.owner
	if not owner or not owner.Parent then
		return
	end
	local profile = DataService.get(owner)
	local stats = PlayerService.stats(owner)
	if not profile or not stats or profile.MaxZone < d.zone then
		return
	end
	local def = d.def
	local rarity = Rarities.Info[def.rarity]
	local crit = rng:NextNumber() < stats.crit
	-- small instant reward; the real income comes from placing the dragon on your farm
	local coins = d.food.value * rarity.mult * Zones.List[d.zone].mult * stats.coinMult * (crit and 3 or 1) * 0.3
	coins = math.max(1, math.floor(coins))
	local xp = math.max(1, math.floor(d.food.xp * (1 + (rarity.rank - 1) * 0.5) * stats.xpMult))
	local first = profile.Dragons[def.id] == nil
	profile.Dragons[def.id] = (profile.Dragons[def.id] or 0) + 1
	profile.Stats.Feeds += 1
	if rarity.rank >= 3 then
		profile.Stats.RareFeeds += 1
	end
	if rarity.rank >= 6 then
		profile.Stats.MythicFeeds += 1
	end
	-- caught! into the backpack (if there's room)
	if PlayerService.inventoryCount(profile) < stats.backpack then
		profile.Inventory[def.id] = (profile.Inventory[def.id] or 0) + 1
		PlayerService.refreshInventory(owner)
	else
		PlayerService.notify(owner, "🎒 Backpack full! Place dragons on your farm.", "error")
	end
	PlayerService.addCoins(owner, coins, "feed")
	PlayerService.addXP(owner, xp)
	FedRemote:FireAllClients(d.id, owner.UserId, coins, crit, d.food.id)
	if first then
		DiscoverRemote:FireClient(owner, def.id)
	end
	for _, fn in fedListeners do
		task.spawn(fn, owner, def, coins, first)
	end
end

-- Called by ThrowService when a throw lands. zone = island hit (nil = water/bridge).
function DragonService.landFood(player: Player, foodDef, pos: Vector3, zone: number?, from: Vector3?)
	if not zone or not player.Parent then
		return
	end
	local profile = DataService.get(player)
	local stats = PlayerService.stats(player)
	if not profile or not stats then
		return
	end
	if profile.MaxZone < zone then
		PlayerService.notify(player, "🔒 Unlock " .. Zones.List[zone].name .. " to meet its dragons!", "error")
		return
	end
	if (activeByPlayer[player] or 0) >= MAX_ACTIVE_PER_PLAYER then
		return -- too many dragons already eating your food
	end
	local def = rollDragon(zone, stats.lucky)
	if not def then
		return
	end
	-- food pile (visible to everyone)
	local pile = Instance.new("Part")
	pile.Name = foodDef.id
	pile.Shape = Enum.PartType.Ball
	pile.Size = Vector3.one * foodDef.size
	pile.Color = foodDef.color
	pile.Material = foodDef.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	pile.Anchored = true
	pile.CanCollide = false
	pile.CanQuery = false
	pile.CanTouch = false
	pile.CastShadow = false
	pile.Position = pos + Vector3.new(0, foodDef.size / 2, 0)
	pile.Parent = foodFolder

	local id = nextDragonId
	nextDragonId += 1
	local flat = Vector3.new(pos.X, 0, pos.Z)
	local start = spawnPoint(zone, flat, from or flat)
	local scale = Rarities.Info[def.rarity].scale
	local dir = flat - start
	local yaw = dir.Magnitude > 0.5 and math.atan2(-dir.X, -dir.Z) or 0
	local reach = 3.9 * scale
	local dest = dir.Magnitude > reach and (flat - dir.Unit * reach) or start
	local runTime = math.max(0.35, (dest - start).Magnitude / (def.speed * 1.4))
	local d = { id = id, def = def, zone = zone, pos = start, yaw = yaw, owner = player, food = foodDef }
	dragons[id] = d
	activeByPlayer[player] = (activeByPlayer[player] or 0) + 1
	push({ "s", id, def.id, start, yaw })
	if Rarities.Info[def.rarity].rank >= 6 then
		NotifyRemote:FireAllClients(("%s %s found a %s %s in %s!"):format(def.rarity == "Secret" and "❓" or "🌟", player.DisplayName, def.rarity:upper(), def.name, Zones.List[zone].name), def.rarity)
	end
	task.delay(POP_TIME, function()
		d.pos = dest
		push({ "m", id, dest, runTime })
		task.delay(runTime, function()
			push({ "e", id, yaw })
			task.delay(0.25, function()
				pile:Destroy()
			end)
			reward(d)
			task.delay(EAT_TIME, function()
				push({ "c", id, player.UserId })
				finish(d)
			end)
		end)
	end)
end

function DragonService.snapshot()
	local list = {}
	for _, d in dragons do
		table.insert(list, { d.id, d.def.id, d.pos, d.yaw })
	end
	return list
end

-- Studio testing helper: forces a specific dragon to appear on the next landing in its zone.
function DragonService.debugSpawn(defId: string, zone: number)
	return DragonDefs.ById[defId] ~= nil and zone ~= nil
end

function DragonService.start()
	foodFolder = Instance.new("Folder")
	foodFolder.Name = "TFFD_Food"
	foodFolder.Parent = workspace
	GetDragons.OnServerInvoke = function()
		return DragonService.snapshot()
	end
	Players.PlayerRemoving:Connect(function(player)
		activeByPlayer[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.05)
			if #ops > 0 then
				local batch = ops
				ops = {}
				DragonsRemote:FireAllClients(batch)
			end
		end
	end)
end

return DragonService
