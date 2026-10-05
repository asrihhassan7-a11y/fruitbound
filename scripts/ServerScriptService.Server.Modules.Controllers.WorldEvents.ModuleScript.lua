--> WorldEvents (server)
-- * Day/night: the server only publishes when the day started (workspace attribute "DayStart");
--   every client computes the clock from it and animates the lighting smoothly.
-- * Events: every 8-15 min a random event (Databases.WorldEvents) may start. While it runs,
--   workspace attributes "Event" / "EventEnds" are set (all players see the banner),
--   and every ROLL_EVERY seconds each crop GROWING in a player's farm garden rolls for mutations.
-- * All mutation / value logic is here and in Harvest (server side). Mutations are saved in data.
-- Admin chat:  !event Rain   !event Storm   !event Sunny   !event Moonlight   !event Rainbow   !event stop

local _L = _G._L

local Players = game:GetService("Players")

local Network
local DB
local Harvest
local MutationUtility
local AdminUtility

local WorldEvents = {
	_active = nil, -- {info, ends}
}

local START_HOUR = 7

local function now()
	return workspace:GetServerTimeNow()
end

function WorldEvents.getClock()
	local start = workspace:GetAttribute("DayStart") or now()
	return (START_HOUR + (now() - start) / DB.DAY_LENGTH * 24) % 24
end

function WorldEvents.isNight()
	local c = WorldEvents.getClock()
	return c >= 20.5 or c < 5
end

local function getClient(player)
	local ok, client = pcall(Network.Bindable.Invoke, "S_Client_Get", player)
	return ok and client or nil
end

local function notify(player, text, color)
	Network.Remote.Fire("C_Notifications_Add", player, {text = text, color = color})
end

local function pickEvent()
	local night = WorldEvents.isNight()
	local pool, total = {}, 0
	for _, e in ipairs(DB.Events) do
		if e.when == "any" or (e.when == "night") == night then
			table.insert(pool, e)
			total += e.weight
		end
	end
	local r = math.random() * total
	for _, e in ipairs(pool) do
		r -= e.weight
		if r <= 0 then
			return e
		end
	end
	return pool[1]
end

local function findEvent(id)
	for _, e in ipairs(DB.Events) do
		if string.lower(e.id) == string.lower(id) then
			return e
		end
	end
	return nil
end

function WorldEvents.stop()
	WorldEvents._active = nil
	workspace:SetAttribute("Event", nil)
	workspace:SetAttribute("EventEnds", nil)
	Harvest.setEventGrowth(1)
end

function WorldEvents.start(info, duration)
	duration = duration or math.random(info.duration[1], info.duration[2])
	WorldEvents._active = {info = info, ends = now() + duration}
	workspace:SetAttribute("Event", info.id)
	workspace:SetAttribute("EventEnds", now() + duration)
	Harvest.setEventGrowth(info.growth or 1)
end

-- one mutation roll for every growing crop of every player
local function rollMutations(info)
	if not info.mutations then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local client = getClient(player)
		local data = client and client.data
		if data then
			local changed = {}
			for _, bush in ipairs(Harvest.getOwnedBushes(player)) do
				if Harvest.isGrowing(player, bush) then
					local current = bush.model:GetAttribute("Mutation")
					-- try the rarest mutation first
					local best
					for mutationId, chance in pairs(info.mutations) do
						if math.random() < chance and MutationUtility.isUpgrade(current, mutationId) then
							if not best or MutationUtility.getInfo(mutationId).tier > MutationUtility.getInfo(best).tier then
								best = mutationId
							end
						end
					end
					if best then
						Harvest.setMutation(player, data, bush, best)
						changed[best] = (changed[best] or 0) + 1
					end
				end
			end
			for mutationId, n in pairs(changed) do
				local m = MutationUtility.getInfo(mutationId)
				notify(player, "✨ " .. n .. " of your crops became " .. m.name .. "! (x" .. m.value .. " value)", m.color)
			end
		end
	end
end

local function onChatted(player, message)
	local arg = string.match(message, "^!event%s+(%S+)")
	if not arg or not AdminUtility.isAdmin(player) then
		return
	end
	if string.lower(arg) == "stop" then
		WorldEvents.stop()
		return
	end
	local info = findEvent(arg)
	if info then
		WorldEvents.start(info)
	else
		notify(player, "Unknown event: " .. arg, Color3.fromRGB(255, 80, 80))
	end
end

function WorldEvents._init()
	Network = _L.Get {"Common", "Library", "Network"}
	DB = _L.Get {"Common", "Modules", "Databases", "WorldEvents"}
	Harvest = _L.Get {"Server", "Modules", "Controllers", "Harvest"}
	MutationUtility = _L.Get {"Common", "Modules", "Utilities", "MutationUtility"}
	AdminUtility = _L.Get {"Common", "Modules", "Utilities", "AdminUtility"}
end

function WorldEvents._start()
	workspace:SetAttribute("DayStart", now())
	workspace:SetAttribute("DayLength", DB.DAY_LENGTH)

	local function setup(player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		setup(p)
	end
	Players.PlayerAdded:Connect(setup)

	-- event scheduler
	task.spawn(function()
		local nextAt = now() + math.random(DB.FIRST_EVENT_DELAY[1], DB.FIRST_EVENT_DELAY[2])
		workspace:SetAttribute("NextEvent", nextAt) -- shown on the village Event Board
		local lastRoll = 0
		local lastSync = 0
		while true do
			task.wait(1)
			local t = now()
			local active = WorldEvents._active

			if active then
				if t >= active.ends then
					WorldEvents.stop()
					nextAt = t + math.random(DB.TIME_BETWEEN[1], DB.TIME_BETWEEN[2])
					workspace:SetAttribute("NextEvent", nextAt)
				elseif t - lastRoll >= DB.ROLL_EVERY then
					lastRoll = t
					local ok, err = pcall(rollMutations, active.info)
					if not ok then
						warn("[WorldEvents] roll failed:", err)
					end
				end
			elseif t >= nextAt then
				WorldEvents.start(pickEvent())
				lastRoll = t
			end

			-- keep saved mutations visible on everyone's farm (after joining / farm rebuilt)
			if t - lastSync >= 5 then
				lastSync = t
				for _, player in ipairs(Players:GetPlayers()) do
					local client = getClient(player)
					if client and client.data then
						pcall(Harvest.syncMutations, player, client.data)
					end
				end
			end
		end
	end)
end

return WorldEvents
