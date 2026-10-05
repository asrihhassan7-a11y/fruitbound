--> FishingUtility (shared) - pure helpers for the V1.1 Fishing system.
-- normalize() turns any saved data.fishing value into the full shape (never removes anything),
-- so old saves ({casts, catches, rod, treasures}) keep working. The reel simulation is
-- deterministic: the server and the client run the SAME steps from the same seed and inputs,
-- and only the server's result counts.
local _L = _G._L

local Fishing -- database

local FishingUtility = {}

FishingUtility.DT = 0.05 -- reel simulation step (seconds)
FishingUtility.REEL_TIMEOUT = 25 -- seconds before the fish gets away no matter what
-- reel feel (tuned with simulated players reacting 0.2 s late; see the V1.1 Fishing report)
FishingUtility.TUNE = {
	gravity = 1.7, liftScale = 0.72, damping = 0.93,
	fishBase = 0.7, fishPerDifficulty = 0.28, retargetBase = 0.8, retargetPerDifficulty = 0.08,
	gainBase = 4.2, gainPerDifficulty = 0.9, lossBase = 0.06, lossPerDifficulty = 0.032,
	perfectSlack = 0.4,
}

local function num(v, default)
	if typeof(v) ~= "number" or v ~= v or math.abs(v) == math.huge then
		return default
	end
	return v
end

local function dict(v)
	local out = {}
	if typeof(v) == "table" then
		for k, x in pairs(v) do
			out[k] = x
		end
	end
	return out
end

-- full fishing save shape (a fresh copy; the caller saves it back with data:Set("fishing", ...))
function FishingUtility.normalize(value)
	local f = dict(value)
	f.casts = math.floor(num(f.casts, 0))
	f.catches = math.floor(num(f.catches, 0))
	f.treasures = math.floor(num(f.treasures, 0))
	f.xp = math.max(0, math.floor(num(f.xp, 0)))
	f.level = (FishingUtility.levelFromXp(f.xp)) -- level always follows XP (never trusted on its own)
	f.rods = dict(f.rods)
	if f.rod == true then
		f.rods.starter = true -- pre-overhaul saves: the free rod was already claimed
	end
	if typeof(f.rod_id) ~= "string" or not Fishing.rod(f.rod_id) or not f.rods[f.rod_id] then
		f.rod_id = if f.rods.starter then "starter" else nil
	end
	f.bait = dict(f.bait)
	for k, v in pairs(f.bait) do
		f.bait[k] = math.max(0, math.floor(num(v, 0)))
	end
	if typeof(f.selected_bait) ~= "string" or not Fishing.bait(f.selected_bait) then
		f.selected_bait = "none"
	end
	f.materials = dict(f.materials)
	f.bag = if typeof(f.bag) == "table" then table.clone(f.bag) else {}
	f.journal = dict(f.journal)
	f.claimed = dict(f.claimed)
	f.cosmetics = dict(f.cosmetics)
	f.cosmetics.owned = dict(f.cosmetics.owned)
	f.cosmetics.owned.classic_bobber = true
	f.cosmetics.owned.default_skin = true
	if not f.cosmetics.bobber or not f.cosmetics.owned[f.cosmetics.bobber] then
		f.cosmetics.bobber = "classic_bobber"
	end
	if not f.cosmetics.skin or not f.cosmetics.owned[f.cosmetics.skin] then
		f.cosmetics.skin = "default_skin"
	end
	f.quests = dict(f.quests)
	return f
end

function FishingUtility.getRod(f)
	return f and f.rod_id and Fishing.rod(f.rod_id) or nil
end

function FishingUtility.rodRank(f)
	local rod = FishingUtility.getRod(f)
	return rod and rod.rank or 0
end

function FishingUtility.bagCapacity(f)
	return if (f.level or 1) >= 12 then Fishing.BAG_SIZE_BIG else Fishing.BAG_SIZE
end

-- level from total XP (returns level, xp into this level, xp needed for next)
function FishingUtility.levelFromXp(xp)
	local level = 1
	xp = math.max(0, xp or 0)
	while level < Fishing.MAX_LEVEL and xp >= Fishing.xpForLevel(level) do
		xp -= Fishing.xpForLevel(level)
		level += 1
	end
	return level, xp, if level < Fishing.MAX_LEVEL then Fishing.xpForLevel(level) else 0
end

-- weight tier label from where the weight sits in the species range
function FishingUtility.weightTier(fishInfo, weight)
	local t = (weight - fishInfo.w[1]) / math.max(fishInfo.w[2] - fishInfo.w[1], 0.01)
	if t >= 0.95 then
		return "Record"
	elseif t >= 0.8 then
		return "Huge"
	elseif t >= 0.55 then
		return "Large"
	elseif t >= 0.2 then
		return "Normal"
	end
	return "Small"
end

-- sell value of one catch (Perfect Catch = +10%, never doubled)
function FishingUtility.value(fishInfo, weight, perfect)
	local t = math.clamp((weight - fishInfo.w[1]) / math.max(fishInfo.w[2] - fishInfo.w[1], 0.01), 0, 1)
	local v = fishInfo.value * (0.7 + 0.6 * t)
	if perfect then
		v *= 1.1
	end
	return math.max(1, math.floor(v + 0.5))
end

function FishingUtility.likeMultiplier(fishInfo, baitId)
	local like = fishInfo.likes and fishInfo.likes[baitId] or "neutral"
	return Fishing.LIKE[like] or 1
end

-- ids of every species in a zone / of a rarity / all (journal + collections)
function FishingUtility.speciesWhere(filter)
	local list = {}
	for _, fish in ipairs(Fishing.FISH) do
		local ok = true
		if filter.zone then
			ok = table.find(fish.zones, filter.zone) ~= nil
		end
		if filter.rarity then
			ok = ok and fish.rarity == filter.rarity
		end
		if ok then
			table.insert(list, fish.id)
		end
	end
	return list
end

function FishingUtility.discoveredCount(f)
	local n = 0
	for _, fish in ipairs(Fishing.FISH) do
		if f.journal[fish.id] and (f.journal[fish.id].n or 0) > 0 then
			n += 1
		end
	end
	return n
end

-- is a collection complete for this save?
function FishingUtility.collectionDone(f, col)
	if col.need == "species" then
		return FishingUtility.discoveredCount(f) >= col.count
	end
	local ids = FishingUtility.speciesWhere({zone = col.zone, rarity = col.rarity})
	if #ids == 0 then
		return false
	end
	for _, id in ipairs(ids) do
		if not (f.journal[id] and (f.journal[id].n or 0) > 0) then
			return false
		end
	end
	return true
end

-- today's 3 quests (deterministic per player per UTC day)
function FishingUtility.questDay(now)
	return math.floor((now or os.time()) / 86400)
end
function FishingUtility.pickQuests(userId, day)
	local rng = Random.new(day * 7919 + (userId % 100003))
	local pool = {}
	for _, q in ipairs(Fishing.QUESTS) do
		table.insert(pool, q.id)
	end
	local picked = {}
	for _ = 1, 3 do
		local i = rng:NextInteger(1, #pool)
		table.insert(picked, table.remove(pool, i))
	end
	return picked
end

-- ------------------------------------------------------------ reel simulation
-- params = {seed, difficulty (1..6), zone, lift, stability}
function FishingUtility.newReel(params)
	local d = params.difficulty
	return {
		rng = Random.new(params.seed),
		difficulty = d,
		zone = params.zone,
		lift = params.lift * FishingUtility.TUNE.liftScale,
		stability = params.stability,
		zonePos = 0.5,
		zoneVel = 0,
		fishPos = 0.5,
		fishTarget = 0.5,
		fishTimer = 0.6,
		fishSpeed = FishingUtility.TUNE.fishBase + FishingUtility.TUNE.fishPerDifficulty * d,
		gain = 1 / (FishingUtility.TUNE.gainBase + FishingUtility.TUNE.gainPerDifficulty * d), -- 1/gain = seconds of control needed (fish stamina)
		loss = (FishingUtility.TUNE.lossBase + FishingUtility.TUNE.lossPerDifficulty * d) / params.stability,
		progress = 0.3,
		step = 0,
		outside = 0,
		done = nil, -- "caught" | "escaped"
	}
end

function FishingUtility.stepReel(s, holding)
	if s.done then
		return s
	end
	local DT = FishingUtility.DT
	s.step += 1
	-- player's catch zone: hold = pull up, release = sink
	local accel = if holding then s.lift else -FishingUtility.TUNE.gravity
	s.zoneVel = (s.zoneVel + accel * DT) * FishingUtility.TUNE.damping
	s.zonePos += s.zoneVel * DT
	local half = s.zone / 2
	if s.zonePos < half then
		s.zonePos = half
		s.zoneVel = math.max(0, s.zoneVel)
	elseif s.zonePos > 1 - half then
		s.zonePos = 1 - half
		s.zoneVel = math.min(0, s.zoneVel)
	end
	-- fish: picks new spots, harder fish move faster and dart more
	s.fishTimer -= DT
	if s.fishTimer <= 0 then
		s.fishTarget = s.rng:NextNumber(0.08, 0.92)
		s.fishTimer = s.rng:NextNumber(0.7, 1.7) / (FishingUtility.TUNE.retargetBase + FishingUtility.TUNE.retargetPerDifficulty * s.difficulty)
	end
	s.fishPos += (s.fishTarget - s.fishPos) * math.clamp(s.fishSpeed * DT, 0, 1)
	-- control
	if math.abs(s.fishPos - s.zonePos) <= half then
		s.progress += s.gain * DT
	else
		s.progress -= s.loss * DT
		if s.step * DT > 1 then
			s.outside += DT
		end
	end
	if s.progress >= 1 then
		s.done = "caught"
	elseif s.progress <= 0 or s.step * DT >= FishingUtility.REEL_TIMEOUT then
		s.done = "escaped"
	end
	return s
end

function FishingUtility.isPerfect(s)
	return s.done == "caught" and s.outside <= FishingUtility.TUNE.perfectSlack
end

function FishingUtility._init()
	Fishing = _L.Get {"Common", "Modules", "Databases", "Fishing"}
end

return FishingUtility
