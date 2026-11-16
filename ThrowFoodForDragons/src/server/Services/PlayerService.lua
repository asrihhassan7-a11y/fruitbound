-- Per-player runtime: game pass ownership, derived stats, currency/xp, leaderstats and state sync.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Util = require(Shared.Util)
local Net = require(Shared.Net)
local Formulas = require(Shared.Formulas)
local Products = require(Shared.Config.Products)
local Dragons = require(Shared.Config.Dragons)
local Rarities = require(Shared.Config.Rarities)
local DataService = require(script.Parent.DataService)

local StateRemote = Net.get("State")
local NotifyRemote = Net.get("Notify")

local PlayerService = {}
local passes: { [Player]: { [string]: boolean } } = {}
local syncQueued: { [Player]: boolean } = {}
local hooks = { coins = {}, levelUp = {} }

function PlayerService.on(event: string, fn)
	table.insert(hooks[event], fn)
end

function PlayerService.passes(player: Player)
	return passes[player] or {}
end

function PlayerService.hasPass(player: Player, name: string): boolean
	return (passes[player] or {})[name] == true
end

function PlayerService.stats(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	return Formulas.compute(profile, PlayerService.passes(player), os.time())
end

function PlayerService.notify(player: Player, text: string, kind: string?)
	NotifyRemote:FireClient(player, text, kind or "info")
end

local function updateLeaderstats(player: Player, profile)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	(ls :: any).Coins.Value = Util.fmt(profile.Coins)
	local n = 0
	for id in profile.Dragons do
		if Dragons.ById[id] then
			n += 1
		end
	end
	(ls :: any).Dragons.Value = n
end

local function buildView(player: Player, profile)
	local view = {}
	for k, v in profile do
		if k ~= "Receipts" and k ~= "ReceiptOrder" and k ~= "Lock" then
			view[k] = v
		end
	end
	view.Passes = PlayerService.passes(player)
	view.Computed = Formulas.compute(profile, view.Passes, os.time())
	view.ServerTime = os.time()
	return view
end

-- Throttled full-state push (profiles are small; this keeps client UI trivially consistent).
function PlayerService.sync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.delay(0.15, function()
		syncQueued[player] = nil
		local profile = DataService.get(player)
		if profile and player.Parent then
			updateLeaderstats(player, profile)
			StateRemote:FireClient(player, buildView(player, profile))
		end
	end)
end

function PlayerService.addCoins(player: Player, amount: number, source: string?)
	local profile = DataService.get(player)
	if not profile or not Util.finite(amount) or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	profile.Coins += amount
	profile.TotalCoins += amount
	for _, fn in hooks.coins do
		fn(player, amount, source)
	end
	PlayerService.sync(player)
end

function PlayerService.spend(player: Player, amount: number): boolean
	local profile = DataService.get(player)
	if not profile or not Util.finite(amount) or amount < 0 or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	PlayerService.sync(player)
	return true
end

function PlayerService.addXP(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.XP += amount
	local leveled = false
	while profile.XP >= Formulas.xpForLevel(profile.Level) and profile.Level < 500 do
		profile.XP -= Formulas.xpForLevel(profile.Level)
		profile.Level += 1
		leveled = true
	end
	if leveled then
		PlayerService.notify(player, "⭐ Level " .. profile.Level .. "! +2% coins per level", "level")
		for _, fn in hooks.levelUp do
			fn(player, profile.Level)
		end
	end
	PlayerService.sync(player)
end

function PlayerService.addBoost(player: Player, name: string, seconds: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local now = os.time()
	profile.Boosts[name] = math.max(profile.Boosts[name] or 0, now) + seconds
	PlayerService.sync(player)
end

function PlayerService.refreshCompanions(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local ids = {}
	for _, uid in profile.Equipped do
		if profile.Pets[uid] then
			table.insert(ids, profile.Pets[uid])
		end
	end
	player:SetAttribute("Companions", table.concat(ids, ","))
end

-- Backpack: one Tool per dragon species, named with the count. Equip it and click your farm to place it.
function PlayerService.refreshInventory(player: Player)
	local profile = DataService.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not profile or not backpack then
		return
	end
	local existing = {}
	for _, holder in { backpack, player.Character } do
		if holder then
			for _, t in holder:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("DefId") then
					existing[t:GetAttribute("DefId")] = t
				end
			end
		end
	end
	for defId, count in profile.Inventory do
		local def = Dragons.ById[defId]
		if def and count > 0 then
			local tool = existing[defId]
			if not tool then
				tool = Instance.new("Tool")
				tool.RequiresHandle = false
				tool.CanBeDropped = false
				tool:SetAttribute("DefId", defId)
				tool.Parent = backpack
			end
			tool.Name = def.name .. " x" .. count
			tool.ToolTip = def.rarity .. " • click your farm to place"
			tool:SetAttribute("Count", count)
			tool:SetAttribute("Rarity", def.rarity)
			existing[defId] = nil
		end
	end
	for _, t in existing do
		t:Destroy()
	end
end

function PlayerService.refreshFarm(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local parts = {}
	for _, e in profile.Farm do
		table.insert(parts, string.format("%s:%.1f:%.1f", e.d, e.x, e.z))
	end
	player:SetAttribute("Farm", table.concat(parts, ";"))
end

function PlayerService.inventoryCount(profile): number
	local n = 0
	for _, c in profile.Inventory do
		n += c
	end
	return n
end

local function checkPasses(player: Player)
	local owned = passes[player] or {}
	passes[player] = owned
	for name, p in Products.Passes do
		if p.id and p.id > 0 and not owned[name] then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.id)
			if ok and has then
				owned[name] = true
			end
		end
	end
	player:SetAttribute("VIP", owned.VIP == true)
end

function PlayerService.grantPass(player: Player, name: string)
	passes[player] = passes[player] or {}
	passes[player][name] = true
	player:SetAttribute("VIP", passes[player].VIP == true)
	PlayerService.refreshCompanions(player)
	PlayerService.sync(player)
end

function PlayerService.start()
	local function added(player: Player)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local coins = Instance.new("StringValue")
		coins.Name = "Coins"
		coins.Value = "0"
		coins.Parent = ls
		local dr = Instance.new("IntValue")
		dr.Name = "Dragons"
		dr.Parent = ls
		ls.Parent = player
		task.spawn(checkPasses, player)
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		task.spawn(added, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			passes[player] = nil
			syncQueued[player] = nil
		end)
	end)
	DataService.onLoaded(function(player, profile)
		-- wait briefly for pass checks so the first state is correct
		local t0 = os.clock()
		while not passes[player] and os.clock() - t0 < 5 do
			task.wait(0.1)
		end
		if not PlayerService.hasPass(player, "AutoThrow") then
			profile.AutoThrow = false
		end
		PlayerService.refreshCompanions(player)
		PlayerService.refreshFarm(player)
		PlayerService.refreshInventory(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			PlayerService.refreshInventory(player)
		end)
		-- offline farm earnings (25% for up to 3 hours)
		local stats = PlayerService.stats(player)
		if profile.LastOnline > 0 and stats then
			local secs = math.clamp(os.time() - profile.LastOnline, 0, 3 * 3600)
			local earned = math.floor(stats.income * secs * 0.25)
			if earned > 0 and secs > 60 then
				PlayerService.addCoins(player, earned, "offline")
				PlayerService.notify(player, "🏡 Your dragons earned " .. Util.fmt(earned) .. " coins while you were away!", "success")
			end
		end
		PlayerService.sync(player)
		player:SetAttribute("Loaded", true)
	end)
	-- farm income tick
	local acc: { [Player]: number } = {}
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local stats = PlayerService.stats(player)
				if stats and stats.income > 0 then
					acc[player] = (acc[player] or 0) + stats.income
					local whole = math.floor(acc[player])
					if whole >= 1 then
						acc[player] -= whole
						PlayerService.addCoins(player, whole, "farm")
					end
				end
			end
			for p in acc do
				if not p.Parent then
					acc[p] = nil
				end
			end
		end
	end)
end

return PlayerService
