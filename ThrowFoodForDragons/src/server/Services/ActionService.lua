-- Single RemoteFunction router for every UI action. Each handler validates its own input.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Net = require(Shared.Net)
local Util = require(Shared.Util)
local Foods = require(Shared.Config.Foods)
local Zones = require(Shared.Config.Zones)
local Upgrades = require(Shared.Config.Upgrades)
local Companions = require(Shared.Config.Companions)
local Rarities = require(Shared.Config.Rarities)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local QuestService = require(script.Parent.QuestService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)
local Formulas = require(Shared.Formulas)
local DragonDefs = require(Shared.Config.Dragons)

local ActionRemote = Net.get("Action")

local ActionService = {}
local handlers = {}
local budget: { [Player]: { t: number, n: number } } = {}
local rng = Random.new()

local function ok(msg: string?, data: any?)
	return { ok = true, msg = msg, data = data }
end
local function fail(msg: string)
	return { ok = false, msg = msg }
end

-- Upgrades / food ---------------------------------------------------------------
function handlers.BuyUpgrade(player, profile, key)
	if type(key) ~= "string" or not Upgrades.Defs[key] then
		return fail("Unknown upgrade")
	end
	local level = profile.Upgrades[key] or 0
	local cost = Upgrades.cost(key, level)
	if not cost then
		return fail("Already maxed!")
	end
	if not PlayerService.spend(player, cost) then
		return fail("Not enough coins")
	end
	profile.Upgrades[key] = level + 1
	return ok(Upgrades.Defs[key].name .. " → Lv " .. (level + 1))
end

function handlers.BuyFood(player, profile, id)
	local f = type(id) == "string" and Foods.ById[id]
	if not f then
		return fail("Unknown food")
	end
	if profile.Foods[id] then
		return fail("Already owned")
	end
	if profile.MaxZone < f.zone then
		return fail("Unlock " .. Zones.List[f.zone].name .. " first")
	end
	if not PlayerService.spend(player, f.cost) then
		return fail("Not enough coins")
	end
	profile.Foods[id] = true
	profile.EquippedFood = id
	return ok(f.icon .. " " .. f.name .. " unlocked & equipped!")
end

function handlers.EquipFood(player, profile, id)
	if type(id) ~= "string" or not Foods.ById[id] or not profile.Foods[id] then
		return fail("You don't own that food")
	end
	profile.EquippedFood = id
	return ok()
end

-- Zones -----------------------------------------------------------------------
function handlers.UnlockZone(player, profile, index)
	if type(index) ~= "number" or index ~= profile.MaxZone + 1 or not Zones.List[index] then
		return fail(type(index) == "number" and index <= profile.MaxZone and "Already unlocked" or "Unlock the previous zone first")
	end
	local z = Zones.List[index]
	if not PlayerService.spend(player, z.cost) then
		return fail("Need " .. Util.fmt(z.cost) .. " coins")
	end
	profile.MaxZone = index
	PlayerService.notify(player, z.icon .. " " .. z.name .. " unlocked!", "unlock")
	return ok(nil, { unlocked = index })
end

-- Farm ---------------------------------------------------------------------------
-- arg = { d = dragonId, x = offsetX?, z = offsetZ? } (offsets relative to plot centre; random spot if omitted)
function handlers.PlaceDragon(player, profile, arg)
	if type(arg) ~= "table" or type(arg.d) ~= "string" or not DragonDefs.ById[arg.d] then
		return fail("Invalid dragon")
	end
	if (profile.Inventory[arg.d] or 0) <= 0 then
		return fail("You don't have that dragon")
	end
	local stats = PlayerService.stats(player)
	if #profile.Farm >= stats.farmCap then
		return fail("Farm full (" .. stats.farmCap .. ")! Upgrade Farm Size in the Shop")
	end
	local x, z = arg.x, arg.z
	if not (Util.finite(x) and Util.finite(z) and PlotService.validFarmOffset(x, z)) then
		x = rng:NextNumber(PlotService.FARM_MIN.X + 2, PlotService.FARM_MAX.X - 2)
		z = rng:NextNumber(PlotService.FARM_MIN.Y + 2, PlotService.FARM_MAX.Y - 2)
	end
	profile.Inventory[arg.d] -= 1
	if profile.Inventory[arg.d] <= 0 then
		profile.Inventory[arg.d] = nil
	end
	table.insert(profile.Farm, { d = arg.d, x = x, z = z })
	PlayerService.refreshInventory(player)
	PlayerService.refreshFarm(player)
	local def = DragonDefs.ById[arg.d]
	return ok("🏡 " .. def.name .. " placed! +" .. Util.fmt(Formulas.dragonIncome(arg.d) * stats.coinMult) .. "/s")
end

function handlers.PickupDragon(player, profile, index)
	if type(index) ~= "number" or not profile.Farm[index] then
		return fail("Invalid")
	end
	local stats = PlayerService.stats(player)
	if PlayerService.inventoryCount(profile) >= stats.backpack then
		return fail("Backpack full")
	end
	local e = table.remove(profile.Farm, index)
	profile.Inventory[e.d] = (profile.Inventory[e.d] or 0) + 1
	PlayerService.refreshInventory(player)
	PlayerService.refreshFarm(player)
	return ok()
end

-- Sell one backpack dragon for 2 minutes of its farm income.
function handlers.SellDragon(player, profile, defId)
	if type(defId) ~= "string" or (profile.Inventory[defId] or 0) <= 0 then
		return fail("You don't have that dragon")
	end
	profile.Inventory[defId] -= 1
	if profile.Inventory[defId] <= 0 then
		profile.Inventory[defId] = nil
	end
	local coins = math.max(1, math.floor(Formulas.dragonIncome(defId) * 120))
	PlayerService.addCoins(player, coins, "sell")
	PlayerService.refreshInventory(player)
	return ok("Sold for " .. Util.fmt(coins) .. " coins")
end

-- Companions --------------------------------------------------------------------
local function petCount(profile): number
	return Util.count(profile.Pets)
end

local function rollPet(egg, lucky: boolean)
	return Util.weightedPick(egg.pets, function(p)
		local w = p.weight
		if lucky and Rarities.Info[p.rarity].rank >= 4 then
			w *= Companions.LuckyRareMult
		end
		return w
	end, rng)
end

function handlers.HatchEgg(player, profile, arg)
	if type(arg) ~= "table" then
		return fail("Invalid")
	end
	local egg = type(arg.egg) == "string" and Companions.EggById[arg.egg]
	local count = arg.count == 3 and 3 or 1
	if not egg then
		return fail("Unknown egg")
	end
	if profile.MaxZone < egg.zone then
		return fail("Unlock " .. Zones.List[egg.zone].name .. " first")
	end
	local stats = PlayerService.stats(player)
	if petCount(profile) + count > stats.storage then
		return fail("Companion storage full (" .. stats.storage .. ")")
	end
	if not PlayerService.spend(player, egg.cost * count) then
		return fail("Not enough coins")
	end
	local results = {}
	for _ = 1, count do
		local pet = rollPet(egg, stats.lucky)
		local uid = tostring(profile.NextUid)
		profile.NextUid += 1
		profile.Pets[uid] = pet.id
		if #profile.Equipped < stats.equipSlots then
			table.insert(profile.Equipped, uid)
		end
		table.insert(results, pet.id)
	end
	profile.Stats.Hatches += count
	QuestService.track(player, "hatch", count)
	PlayerService.refreshCompanions(player)
	return ok(nil, results)
end

function handlers.EquipPet(player, profile, uid)
	if type(uid) ~= "string" or not profile.Pets[uid] then
		return fail("Unknown companion")
	end
	if table.find(profile.Equipped, uid) then
		return fail("Already equipped")
	end
	if #profile.Equipped >= PlayerService.stats(player).equipSlots then
		return fail("All companion slots are full")
	end
	table.insert(profile.Equipped, uid)
	PlayerService.refreshCompanions(player)
	return ok()
end

function handlers.UnequipPet(player, profile, uid)
	local i = type(uid) == "string" and table.find(profile.Equipped, uid)
	if not i then
		return fail("Not equipped")
	end
	table.remove(profile.Equipped, i)
	PlayerService.refreshCompanions(player)
	return ok()
end

function handlers.EquipBest(player, profile)
	local list = {}
	for uid, petId in profile.Pets do
		local p = Companions.Pets[petId]
		if p then
			table.insert(list, { uid = uid, score = p.score })
		end
	end
	table.sort(list, function(a, b)
		return a.score > b.score
	end)
	table.clear(profile.Equipped)
	for i = 1, math.min(#list, PlayerService.stats(player).equipSlots) do
		table.insert(profile.Equipped, list[i].uid)
	end
	PlayerService.refreshCompanions(player)
	return ok("Equipped your best companions!")
end

function handlers.DeletePet(player, profile, uid)
	if type(uid) ~= "string" or not profile.Pets[uid] then
		return fail("Unknown companion")
	end
	local i = table.find(profile.Equipped, uid)
	if i then
		table.remove(profile.Equipped, i)
	end
	profile.Pets[uid] = nil
	PlayerService.refreshCompanions(player)
	return ok("Companion released")
end

-- Rewards -----------------------------------------------------------------------
function handlers.ClaimDaily(player)
	local success, msg = QuestService.claimDaily(player)
	return success and ok(msg) or fail(msg)
end
function handlers.DailyPreview(player)
	return ok(nil, QuestService.dailyPreview(player))
end
function handlers.ClaimQuest(player, _, index)
	local success, msg = QuestService.claimQuest(player, index)
	return success and ok(msg) or fail(msg)
end
function handlers.ClaimAchievement(player, _, id)
	local success, msg = QuestService.claimAchievement(player, id)
	return success and ok(msg) or fail(msg)
end

-- Settings / passes -------------------------------------------------------------
local SETTINGS = { Music = "number", Sfx = "number", LowGfx = "boolean", ShowOthers = "boolean" }
function handlers.SetSetting(player, profile, arg)
	if type(arg) ~= "table" or type(arg.key) ~= "string" or SETTINGS[arg.key] == nil or type(arg.value) ~= SETTINGS[arg.key] then
		return fail("Invalid setting")
	end
	local v = arg.value
	if type(v) == "number" then
		if not Util.finite(v) then
			return fail("Invalid setting")
		end
		v = math.clamp(v, 0, 1)
	end
	profile.Settings[arg.key] = v
	return ok()
end

function handlers.SetAutoThrow(player, profile, on)
	if type(on) ~= "boolean" then
		return fail("Invalid")
	end
	if on and not PlayerService.hasPass(player, "AutoThrow") then
		MonetizationService.prompt(player, "pass", "AutoThrow")
		return fail("Auto Throw needs the Auto Throw pass")
	end
	profile.AutoThrow = on
	return ok(on and "🤖 Auto Throw ON" or "Auto Throw OFF")
end

function handlers.Prompt(player, _, arg)
	if type(arg) ~= "table" then
		return fail("Invalid")
	end
	local success, msg = MonetizationService.prompt(player, arg.kind, arg.key)
	return success and ok() or fail(msg or "Unavailable")
end

-------------------------------------------------------------------------------------
function ActionService.start()
	ActionRemote.OnServerInvoke = function(player, name, arg)
		-- rate limit: 12 actions per second
		local now = os.clock()
		local b = budget[player]
		if not b or now - b.t > 1 then
			b = { t = now, n = 0 }
			budget[player] = b
		end
		b.n += 1
		if b.n > 12 then
			return fail("Slow down!")
		end
		local handler = type(name) == "string" and handlers[name]
		local profile = DataService.get(player)
		if not handler or not profile then
			return fail(profile and "Unknown action" or "Still loading...")
		end
		local success, result = pcall(handler, player, profile, arg)
		if not success then
			warn("[TFFD] Action", name, "error:", result)
			return fail("Something went wrong")
		end
		PlayerService.sync(player)
		return result
	end
	Players.PlayerRemoving:Connect(function(p)
		budget[p] = nil
	end)
end

ActionService.handlers = handlers
return ActionService
