-- Daily quests, achievements and the 7-day daily reward streak. All checks are server-side.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Util = require(Shared.Util)
local Formulas = require(Shared.Formulas)
local Quests = require(Shared.Config.Quests)
local Dragons = require(Shared.Config.Dragons)
local Rarities = require(Shared.Config.Rarities)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local QuestService = {}

local function today(): number
	return os.time() // 86400
end

local function incomeMinutes(profile, minutes: number): number
	return math.floor(Formulas.income(profile.MaxZone) * 60 * minutes)
end

function QuestService.ensure(player: Player, profile)
	local day = today()
	if profile.Quests.Day == day and #profile.Quests.List > 0 then
		return
	end
	local rng = Random.new(day * 7919 + player.UserId % 100000)
	local pool = table.clone(Quests.Templates)
	local list = {}
	for _ = 1, math.min(Quests.PerDay, #pool) do
		local t = table.remove(pool, rng:NextInteger(1, #pool))
		local goal
		if t.amount == "income8" then
			goal = incomeMinutes(profile, 8)
		else
			goal = t.amount(profile.MaxZone)
		end
		table.insert(list, {
			kind = t.kind,
			text = t.text:format(Util.fmt(goal)),
			goal = goal,
			progress = 0,
			coins = incomeMinutes(profile, t.minutes),
			xp = 25 * profile.MaxZone,
			claimed = false,
		})
	end
	profile.Quests.Day = day
	profile.Quests.List = list
end

function QuestService.track(player: Player, kind: string, amount: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	QuestService.ensure(player, profile)
	local changed = false
	for _, q in profile.Quests.List do
		if q.kind == kind and not q.claimed and q.progress < q.goal then
			q.progress = math.min(q.goal, q.progress + amount)
			changed = true
			if q.progress >= q.goal then
				PlayerService.notify(player, "📜 Quest complete: " .. q.text .. " — claim it!", "quest")
			end
		end
	end
	if changed then
		PlayerService.sync(player)
	end
end

function QuestService.claimQuest(player: Player, index: any)
	local profile = DataService.get(player)
	if not profile or type(index) ~= "number" then
		return false, "Invalid quest"
	end
	QuestService.ensure(player, profile)
	local q = profile.Quests.List[index]
	if not q or q.claimed or q.progress < q.goal then
		return false, "Quest not complete"
	end
	q.claimed = true
	local stats = PlayerService.stats(player)
	local mult = stats and stats.rewardMult or 1
	PlayerService.addCoins(player, q.coins * mult, "quest")
	PlayerService.addXP(player, q.xp * mult)
	return true, "+" .. Util.fmt(q.coins * mult) .. " coins"
end

function QuestService.statValue(profile, stat: string): number
	if stat == "Discovered" then
		local n = 0
		for id in profile.Dragons do
			if Dragons.ById[id] then
				n += 1
			end
		end
		return n
	elseif stat == "MaxZone" then
		return profile.MaxZone
	elseif stat == "Level" then
		return profile.Level
	end
	return profile.Stats[stat] or 0
end

function QuestService.claimAchievement(player: Player, id: any)
	local profile = DataService.get(player)
	if not profile or type(id) ~= "string" then
		return false, "Invalid"
	end
	for _, a in Quests.Achievements do
		if a.id == id then
			if profile.Achievements[id] then
				return false, "Already claimed"
			end
			if QuestService.statValue(profile, a.stat) < a.goal then
				return false, "Not finished yet"
			end
			profile.Achievements[id] = true
			local stats = PlayerService.stats(player)
			local coins = a.coins * (stats and stats.rewardMult or 1)
			PlayerService.addCoins(player, coins, "achievement")
			return true, "🏆 " .. a.name .. ": +" .. Util.fmt(coins) .. " coins"
		end
	end
	return false, "Unknown achievement"
end

function QuestService.claimDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return false, "Not loaded"
	end
	local now = os.time()
	local d = profile.Daily
	if now - d.Last < Quests.DailyCooldown then
		return false, "Come back in " .. Util.time(Quests.DailyCooldown - (now - d.Last))
	end
	if d.Last == 0 or now - d.Last > Quests.DailyResetAfter then
		d.Streak = 1
	else
		d.Streak = d.Streak % #Quests.Daily + 1
	end
	d.Last = now
	local reward = Quests.Daily[d.Streak]
	local stats = PlayerService.stats(player)
	local coins = incomeMinutes(profile, reward.minutes) * (stats and stats.rewardMult or 1)
	PlayerService.addCoins(player, coins, "daily")
	if reward.boost then
		PlayerService.addBoost(player, reward.boost[1], reward.boost[2])
	end
	return true, "🎁 Day " .. d.Streak .. ": +" .. Util.fmt(coins) .. " coins" .. (reward.boost and " + boost!" or "")
end

-- Preview values the client can't compute alone (coin amounts depend on server-side income).
function QuestService.dailyPreview(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return {}
	end
	local out = {}
	for i, r in Quests.Daily do
		out[i] = incomeMinutes(profile, r.minutes)
	end
	return out
end

function QuestService.start(DragonService, ThrowService)
	DataService.onLoaded(function(player, profile)
		QuestService.ensure(player, profile)
		PlayerService.sync(player)
	end)
	DragonService.onFed(function(player, def)
		QuestService.track(player, "feed", 1)
		if Rarities.Info[def.rarity].rank >= 3 then
			QuestService.track(player, "rarefeed", 1)
		end
	end)
	ThrowService.onThrow(function(player)
		QuestService.track(player, "throw", 1)
	end)
	PlayerService.on("coins", function(player, amount, source)
		if source == "feed" then
			QuestService.track(player, "coins", amount)
		end
	end)
end

return QuestService
