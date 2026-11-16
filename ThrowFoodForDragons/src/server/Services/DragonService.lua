-- Server-authoritative dragon AI + food piles + feeding rewards.
-- Dragons exist only as data on the server; clients build and animate the models from batched events.
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

local PER_ZONE = 8
local DETECT = 100
local EAT_TIME = 0.9
local FULL_TIME = 1.1
local FOOD_LIFE = 10
local MAX_PILES = 12
local EVENT_INTERVAL = 75
local EVENT_LIFE = 180

local dragons: { [number]: any } = {}
local foods: { [number]: any } = {}
local zoneFoods: { [number]: { [number]: any } } = {}
local pilesByPlayer: { [Player]: { number } } = {}
local nextDragonId, nextFoodId = 1, 1
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

local function randomPointInZone(zone: number, near: Vector3?, radius: number?): Vector3
	local c = Zones.center(zone)
	for _ = 1, 8 do
		local base = near or c
		local r = radius or Zones.SPAWN_RADIUS
		local a = rng:NextNumber(0, math.pi * 2)
		local d = math.sqrt(rng:NextNumber()) * r
		local p = base + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		if (Vector3.new(p.X, 0, p.Z) - c).Magnitude <= Zones.SPAWN_RADIUS then
			return Vector3.new(p.X, 0, p.Z)
		end
	end
	return c
end

local function spawnDragon(def, zone: number, isEvent: boolean?)
	local id = nextDragonId
	nextDragonId += 1
	local d = {
		id = id,
		def = def,
		zone = zone,
		pos = randomPointInZone(zone),
		yaw = rng:NextNumber(0, math.pi * 2),
		state = "idle",
		untilT = os.clock() + rng:NextNumber(1, 4),
		event = isEvent,
		expires = isEvent and (os.clock() + EVENT_LIFE) or nil,
		scale = Rarities.Info[def.rarity].scale,
	}
	dragons[id] = d
	push({ "s", id, def.id, d.pos, d.yaw })
	return d
end

local function despawnDragon(d)
	if d.target and foods[d.target] then
		foods[d.target].claimed = nil
	end
	dragons[d.id] = nil
	push({ "x", d.id })
end

local function rollZoneDragon(zone: number)
	local pool = DragonDefs.ByZone[zone]
	return Util.weightedPick(pool, function(def)
		return Rarities.Info[def.rarity].weight
	end, rng)
end

local function moveTo(d, dest: Vector3, speedMul: number)
	local delta = dest - d.pos
	local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local dur = math.max(0.25, dist / (d.def.speed * speedMul))
	if dist > 0.5 then
		d.yaw = math.atan2(-delta.X, -delta.Z)
	end
	d.from = d.pos
	d.to = dest
	d.moveStart = os.clock()
	d.state = "move"
	d.untilT = os.clock() + dur
	push({ "m", d.id, dest, dur })
end

local function removeFood(food, eaten: boolean)
	foods[food.id] = nil
	if zoneFoods[food.zone] then
		zoneFoods[food.zone][food.id] = nil
	end
	local list = food.owner and pilesByPlayer[food.owner]
	if list then
		local i = table.find(list, food.id)
		if i then
			table.remove(list, i)
		end
	end
	if food.part then
		if eaten then
			local p = food.part
			task.delay(0.25, function()
				p:Destroy()
			end)
		else
			food.part:Destroy()
		end
	end
end

-- Picks the nearest free dragon in the zone and sends it to the food.
local function assign(food)
	local best, bestD = nil, DETECT
	for _, d in dragons do
		if d.zone == food.zone and not d.target and (d.state == "idle" or d.state == "move") then
			local dist = (Vector3.new(food.pos.X, 0, food.pos.Z) - d.pos).Magnitude
			if dist < bestD then
				best, bestD = d, dist
			end
		end
	end
	if not best then
		return
	end
	food.claimed = best.id
	best.target = food.id
	-- current position if it was mid-wander
	if best.state == "move" and best.from then
		local a = math.clamp((os.clock() - best.moveStart) / math.max(best.untilT - best.moveStart, 1e-3), 0, 1)
		best.pos = best.from:Lerp(best.to, a)
	end
	local flat = Vector3.new(food.pos.X, 0, food.pos.Z)
	local dir = flat - best.pos
	local reach = 3.9 * best.scale
	local dest = flat
	if dir.Magnitude > reach then
		dest = flat - dir.Unit * reach
	else
		dest = best.pos
	end
	moveTo(best, dest, 1)
	if dir.Magnitude > 0.5 then
		best.yaw = math.atan2(-dir.X, -dir.Z)
	end
end

local function feed(d, food)
	local owner = food.owner
	local def = d.def
	d.state = "eat"
	d.untilT = os.clock() + EAT_TIME
	push({ "e", d.id, d.yaw })
	removeFood(food, true)
	d.target = nil
	if not owner or not owner.Parent then
		return
	end
	local profile = DataService.get(owner)
	local stats = PlayerService.stats(owner)
	if not profile or not stats or profile.MaxZone < d.zone then
		return
	end
	local rarity = Rarities.Info[def.rarity]
	local crit = rng:NextNumber() < stats.crit
	local coins = food.def.value * rarity.mult * Zones.List[d.zone].mult * stats.coinMult * (crit and 3 or 1)
	coins = math.max(1, math.floor(coins))
	local xp = math.max(1, math.floor(food.def.xp * (1 + (rarity.rank - 1) * 0.5) * stats.xpMult))
	local first = profile.Dragons[def.id] == nil
	profile.Dragons[def.id] = (profile.Dragons[def.id] or 0) + 1
	profile.Stats.Feeds += 1
	if rarity.rank >= 3 then
		profile.Stats.RareFeeds += 1
	end
	if rarity.rank >= 6 then
		profile.Stats.MythicFeeds += 1
	end
	PlayerService.addCoins(owner, coins, "feed")
	PlayerService.addXP(owner, xp)
	FedRemote:FireAllClients(d.id, owner.UserId, coins, crit, food.def.id)
	if first then
		DiscoverRemote:FireClient(owner, def.id)
	end
	for _, fn in fedListeners do
		task.spawn(fn, owner, def, coins, first)
	end
end

-- Called by ThrowService when a throw lands. zone = island hit (nil = water/bridge).
function DragonService.landFood(player: Player, foodDef, pos: Vector3, zone: number?)
	if not zone or not player.Parent then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if profile.MaxZone < zone then
		PlayerService.notify(player, "🔒 Unlock " .. Zones.List[zone].name .. " to feed its dragons!", "error")
		return
	end
	local list = pilesByPlayer[player]
	if not list then
		list = {}
		pilesByPlayer[player] = list
	end
	if #list >= MAX_PILES then
		local oldest = foods[list[1]]
		if oldest then
			if oldest.claimed and dragons[oldest.claimed] then
				dragons[oldest.claimed].target = nil
			end
			removeFood(oldest, false)
		else
			table.remove(list, 1)
		end
	end
	local id = nextFoodId
	nextFoodId += 1
	local p = Instance.new("Part")
	p.Name = foodDef.id
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * foodDef.size
	p.Color = foodDef.color
	p.Material = foodDef.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Position = pos + Vector3.new(0, foodDef.size / 2, 0)
	p.Parent = foodFolder
	local food = { id = id, owner = player, def = foodDef, pos = pos, zone = zone, part = p, expires = os.clock() + FOOD_LIFE }
	foods[id] = food
	zoneFoods[zone] = zoneFoods[zone] or {}
	zoneFoods[zone][id] = food
	table.insert(list, id)
	assign(food)
end

-- Nearest dragon position to `pos` within the player's unlocked zones (used by Auto Throw).
function DragonService.nearestDragon(pos: Vector3, maxZone: number, range: number): Vector3?
	local best, bestD = nil, range
	for _, d in dragons do
		if d.zone <= maxZone then
			local dp = d.pos
			if d.state == "move" and d.from then
				local a = math.clamp((os.clock() - d.moveStart) / math.max(d.untilT - d.moveStart, 1e-3), 0, 1)
				dp = d.from:Lerp(d.to, a)
			end
			local dist = (Vector3.new(pos.X, 0, pos.Z) - dp).Magnitude
			if dist < bestD then
				best, bestD = dp, dist
			end
		end
	end
	return best
end

local function tick()
	local now = os.clock()
	for _, d in dragons do
		if d.expires and now > d.expires then
			despawnDragon(d)
			continue
		end
		if now < d.untilT then
			continue
		end
		if d.state == "move" then
			d.pos = d.to
			d.from = nil
			if d.target then
				local food = foods[d.target]
				if food and food.claimed == d.id then
					feed(d, food)
					continue
				end
				d.target = nil
			end
			d.state = "idle"
			d.untilT = now + rng:NextNumber(2, 6)
		elseif d.state == "eat" then
			d.state = "full"
			d.untilT = now + FULL_TIME
		elseif d.state == "full" then
			d.state = "idle"
			d.untilT = now + rng:NextNumber(0.2, 2)
		elseif d.state == "idle" then
			-- look for unclaimed food first
			local zf = zoneFoods[d.zone]
			local found = false
			if zf then
				for _, food in zf do
					if not food.claimed and (Vector3.new(food.pos.X, 0, food.pos.Z) - d.pos).Magnitude < DETECT then
						assign(food)
						found = d.target ~= nil
						break
					end
				end
			end
			if not found then
				moveTo(d, randomPointInZone(d.zone, d.pos, 28), 0.35)
			end
		end
	end
	for id, food in foods do
		if now > food.expires and not food.claimed then
			removeFood(food, false)
		elseif not food.claimed and foods[id] then
			assign(food)
		end
	end
end

local function zoneHasPlayers(zone: number): boolean
	for _, p in Players:GetPlayers() do
		local profile = DataService.get(p)
		if profile and profile.MaxZone >= zone then
			return true
		end
	end
	return false
end

local function rollEvents()
	for _, def in DragonDefs.Events do
		local chance = def.rarity == "Mythic" and 0.06 or 0.008
		if rng:NextNumber() < chance then
			local zone = def.zone
			if zone == 0 then
				zone = rng:NextInteger(1, #Zones.List)
			end
			if zoneHasPlayers(zone) then
				spawnDragon(def, zone, true)
				NotifyRemote:FireAllClients(("%s A %s %s appeared in %s!"):format(def.rarity == "Secret" and "❓" or "🌟", def.rarity:upper(), def.name, Zones.List[zone].name), def.rarity)
			end
		end
	end
	-- refresh variety: swap one non-event dragon per zone
	for zone = 1, #Zones.List do
		local candidates = {}
		for _, d in dragons do
			if d.zone == zone and not d.event and d.state == "idle" and not d.target then
				table.insert(candidates, d)
			end
		end
		if #candidates > 0 then
			despawnDragon(candidates[rng:NextInteger(1, #candidates)])
			local def = rollZoneDragon(zone)
			if def then
				spawnDragon(def, zone)
			end
		end
	end
end

function DragonService.snapshot()
	local now = os.clock()
	local list = {}
	for _, d in dragons do
		local entry = { d.id, d.def.id, d.pos, d.yaw }
		if d.state == "move" and d.from then
			entry[3] = d.from:Lerp(d.to, math.clamp((now - d.moveStart) / math.max(d.untilT - d.moveStart, 1e-3), 0, 1))
			entry[5] = d.to
			entry[6] = math.max(0, d.untilT - now)
		end
		table.insert(list, entry)
	end
	return list
end

-- Testing helper (Studio only, called from the command bar / test scripts).
function DragonService.debugSpawn(defId: string, zone: number)
	local def = DragonDefs.ById[defId]
	if def then
		return spawnDragon(def, zone, def.rarity == "Mythic" or def.rarity == "Secret")
	end
	return nil
end

function DragonService.start()
	foodFolder = Instance.new("Folder")
	foodFolder.Name = "TFFD_Food"
	foodFolder.Parent = workspace
	for zone = 1, #Zones.List do
		for _ = 1, PER_ZONE do
			local def = rollZoneDragon(zone)
			if def then
				spawnDragon(def, zone)
			end
		end
	end
	GetDragons.OnServerInvoke = function()
		return DragonService.snapshot()
	end
	Players.PlayerRemoving:Connect(function(player)
		local list = pilesByPlayer[player]
		if list then
			for _, id in table.clone(list) do
				local f = foods[id]
				if f then
					if f.claimed and dragons[f.claimed] then
						dragons[f.claimed].target = nil
					end
					removeFood(f, false)
				end
			end
		end
		pilesByPlayer[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(tick)
			if not ok then
				warn("[TFFD] Dragon tick error:", err)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			if #ops > 0 then
				local batch = ops
				ops = {}
				DragonsRemote:FireAllClients(batch)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(EVENT_INTERVAL)
			pcall(rollEvents)
		end
	end)
end

return DragonService
