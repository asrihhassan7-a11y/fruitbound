--> Farm (server) - tycoon farms on Farm Island
-- Every player gets a plot on join. Their bought upgrades (data.farm.upgrades) are rebuilt,
-- and a glowing pad shows the next upgrade. Step on it with enough Coins to buy it:
-- the section is built right there (clients animate it popping in).
-- Helpers earn Coins into the storage crate; step on the yellow pad to collect.
-- Farms are kept through rebirth.

local _L = _G._L

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Network
local FarmUpgrades
local NumberUtility
local PowerUtility
local TitleUtility
local TableUtility
local FarmBuilder
local FarmDecor

local HttpService = game:GetService("HttpService")

-- player decorations (Decor Bench at the farm entrance)
local PLOT_HALF = 70 -- plots are 140 x 140
local BENCH_AT = Vector3.new(-18, 0, 64)
local PLAN_COUNT = 3 -- "coming soon" markers shown for the next upgrades
-- upgrades that build nothing visible (effect only, V1.1) get no "coming soon" stakes either
local NO_PLAN = {path = true, sprinklers = true, helper = true, market = true, pond = true, barn = true, windmill = true, fountain = true, gate = true}

--> Constants
local HELPER_TICK = 2 -- seconds between helper payouts
local HELPER_COINS = 1 -- Coins one helper earns per tick (30/min), before helper / farm bonuses
-- Farm plant grow time: worth more = grows slower (value 1 = 14s, value 8 = 25s, value 35 = 43s)
-- The Sprinklers upgrade (effect.regrow) makes everything grow faster (max -80%).
local function plantGrowTime(value)
	return 8 + 6 * math.sqrt(math.max(value or 1, 0.1))
end

---------->
local Farm = {
	_plots = {}, -- [plotId] = {model, cf, owner}
	_farms = {}, -- [player] = state
}

local function getClient(player)
	return Network.Bindable.Invoke("S_Client_Get", player)
end

local function notify(state, text, color)
	if state.controller and state.controller._notify then
		state.controller:_notify({text = text, color = color or Color3.fromRGB(120, 230, 120)})
	end
end

local function owns(state, id)
	local ups = state.data:Get({"farm", "upgrades"}) or {}
	return ups[id] == true
end

local function getInfo(id)
	for i, u in ipairs(FarmUpgrades) do
		if u.id == id then
			return u, i
		end
	end
end

-- Sum of all bought upgrade effects
function Farm.getEffects(state)
	local e = {farm_value = 0, regrow = 0, helpers = 0, helper_speed = 0, storage = 0}
	for _, u in ipairs(FarmUpgrades) do
		if owns(state, u.id) and u.effect then
			for k, v in pairs(u.effect) do
				if k == "storage" then
					e.storage = math.max(e.storage, v)
				elseif typeof(v) == "number" then
					e[k] = (e[k] or 0) + v
				end
			end
		end
	end
	return e
end

-- Helpers earn a FIXED amount (they no longer copy the Coins-based harvest power, which made
-- passive income grow with income): HELPER_COINS per tick each, x helper speed, x farm bonuses.
local function helperIncomePerTick(state)
	local e = Farm.getEffects(state)
	if e.helpers <= 0 then
		return 0
	end
	return HELPER_COINS * e.helpers * (1 + e.helper_speed) * (1 + e.farm_value)
end

local function storageCapacity(state)
	local e = Farm.getEffects(state)
	return helperIncomePerTick(state) * (60 / HELPER_TICK) * math.max(e.storage, 1)
end

-- Refresh plant multipliers / regrow and the storage label after anything changes
local function applyEffects(state)
	local e = Farm.getEffects(state)
	for _, section in ipairs(state.plot.model.Built:GetChildren()) do
		for _, m in ipairs(section:GetDescendants()) do
			if m:IsA("Model") and CollectionService:HasTag(m, "HarvestBush") then
				m:SetAttribute("CoinMultiplier", (m:GetAttribute("Value") or 1) * (1 + e.farm_value))
				m:SetAttribute("Regrow", plantGrowTime(m:GetAttribute("Value")) * (1 - math.clamp(e.regrow, 0, 0.8)))
			end
		end
	end
	state.plot.model:SetAttribute("Helpers", e.helpers)

	-- helpers: make sure the right number exist
	local helpersFolder = state.plot.model.Built:FindFirstChild("Helpers")
	if not helpersFolder then
		helpersFolder = Instance.new("Folder")
		helpersFolder.Name = "Helpers"
		helpersFolder.Parent = state.plot.model.Built
	end
	for i = #helpersFolder:GetChildren() + 1, e.helpers do
		local h = FarmBuilder.helper()
		h:SetAttribute("PlotId", state.plot.id)
		h:SetAttribute("Index", i)
		h:PivotTo(state.plot.cf * CFrame.new(30 + i * 3, 2.2, 52))
		h.Parent = helpersFolder
	end

	Farm._updateStorageLabel(state)
end

function Farm._updateStorageLabel(state)
	local hut = state.plot.model.Built:FindFirstChild("helper_hut")
	local storage = hut and hut:FindFirstChild("Storage")
	local crate = storage and storage:FindFirstChild("Crate")
	local label = crate and crate:FindFirstChild("StorageGui") and crate.StorageGui:FindFirstChild("Amount")
	if label then
		local stored = state.data:Get({"farm", "storage"}) or 0
		local cap = storageCapacity(state)
		label.Text = "💰 " .. NumberUtility.short(math.floor(stored)) .. " / " .. NumberUtility.short(math.floor(cap))
		label.TextColor3 = if stored >= cap and cap > 0 then Color3.fromRGB(255, 120, 90) else Color3.fromRGB(255, 205, 60)
	end
end

local function connectCollectPad(state, section)
	local pad = section:FindFirstChild("CollectPad", true)
	if not pad then
		return
	end
	local debounce = false
	state.plot.conns = state.plot.conns or {}
	table.insert(state.plot.conns, pad.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player ~= state.player or debounce then
			return
		end
		local stored = math.floor(state.data:Get({"farm", "storage"}) or 0)
		if stored <= 0 then
			return
		end
		debounce = true
		state.data:Set({"farm", "storage"}, 0)
		state.controller:_add_coins(stored)
		notify(state, "💰 Collected " .. NumberUtility.short(stored) .. " Coins from your helpers!", Color3.fromRGB(255, 210, 70))
		Network.Remote.Fire("C_Farm_Collected", state.player, pad.Position, stored)
		Farm._updateStorageLabel(state)
		task.delay(1, function()
			debounce = false
		end)
	end))
end

-- Build one upgrade on the plot. animate = players see it grow in.
local function buildSection(state, info, animate)
	local old = state.plot.model.Built:FindFirstChild(info.id)
	if old then
		old:Destroy()
	end
	local section = FarmBuilder.build(info, state.plot.cf, state.player.UserId)
	section:SetAttribute("BuiltAt", if animate then workspace:GetServerTimeNow() else 0)
	local fp = FarmBuilder.footprint(info)
	if fp then
		section:SetAttribute("FootCenter", info.at)
		section:SetAttribute("FootSize", fp)
	end
	section.Parent = state.plot.model.Built
	if info.kind == "helper_hut" then
		connectCollectPad(state, section)
	end
	return section
end

-- Show the pad for the next upgrade (they are bought in order)
local function refreshPads(state)
	state.plot.model.Pads:ClearAllChildren()
	-- "coming soon" stakes + signs for the upgrades after the next one, so empty land shows what it will become
	local nextFound, plans = false, 0
	for _, info in ipairs(FarmUpgrades) do
		if not owns(state, info.id) then
			if nextFound and plans < PLAN_COUNT and not NO_PLAN[info.kind] then
				plans += 1
				local plan = FarmBuilder.plan(info, state.plot.cf, "💰 " .. NumberUtility.short(info.cost))
				plan.Parent = state.plot.model.Pads
			end
			nextFound = true
		end
	end
	for _, info in ipairs(FarmUpgrades) do
		if not owns(state, info.id) then
			local padModel = FarmBuilder.pad(info, state.plot.cf, state.player.UserId, NumberUtility.short(info.cost))
			local fp = FarmBuilder.footprint(info)
			padModel:SetAttribute("FootCenter", info.at)
			padModel:SetAttribute("FootSize", fp or Vector3.new(10, 0, 10))
			padModel.Parent = state.plot.model.Pads
			local pad = padModel:FindFirstChild("Pad")
			local lastFail = 0
			pad.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player ~= state.player then
					return
				end
				local ok, reason = Farm.buy(state, info.id)
				if not ok and reason == "afford" and os.clock() - lastFail > 2.5 then
					lastFail = os.clock()
					local coins = state.data:Get({"stats", "Strength"}) or 0
					notify(state, "❌ You need " .. NumberUtility.short(info.cost - coins) .. " more Coins for " .. info.name .. "!", Color3.fromRGB(255, 90, 90))
				end
			end)
			break -- only the next one
		end
	end
end

function Farm.buy(state, id)
	if state.buying then
		return false, "busy"
	end
	local info, index = getInfo(id)
	if not info or owns(state, id) then
		return false, "invalid"
	end
	-- must be bought in order
	if index > 1 and not owns(state, FarmUpgrades[index - 1].id) then
		return false, "locked"
	end
	local coins = state.data:Get({"stats", "Strength"}) or 0
	if coins < info.cost then
		return false, "afford"
	end

	state.buying = true
	state.data:Set({"stats", "Strength"}, coins - info.cost)
	local ups = TableUtility.deep.clone(state.data:Get({"farm", "upgrades"}) or {})
	ups[id] = true
	state.data:Set({"farm", "upgrades"}, ups)

	buildSection(state, info, true)
	Farm._clearDecorFor(state, info)
	if info.effect and info.effect.title then
		TitleUtility.give(state.client, {id = info.effect.title})
	end
	applyEffects(state)
	refreshPads(state)

	notify(state, "🎉 " .. info.icon .. " " .. info.name .. " unlocked! Your farm is growing!", Color3.fromRGB(255, 215, 80))
	Network.Remote.Fire("C_Farm_Upgraded", state.player, id)
	state.buying = false
	return true
end

local function setSign(plot, text)
	local sign = plot.model:FindFirstChild("Sign")
	if sign then
		for _, sg in ipairs(sign:GetChildren()) do
			if sg:IsA("SurfaceGui") and sg:FindFirstChild("Text") then
				sg.Text.Text = text
			end
		end
	end
end

local function assign(player)
	local client
	for _ = 1, 120 do
		client = getClient(player)
		if client and client.player_controller and client.data then
			break
		end
		task.wait(0.5)
		if not player.Parent then
			return
		end
	end
	if not client or not client.player_controller then
		return
	end

	-- free plot
	local plot
	for id = 1, #Farm._plots do
		if not Farm._plots[id].owner then
			plot = Farm._plots[id]
			break
		end
	end
	if not plot then
		warn("[Farm] no free plot for", player.Name)
		return
	end
	plot.owner = player
	plot.model:SetAttribute("Owner", player.UserId)
	player:SetAttribute("FarmPlot", plot.id)
	plot.model.Base.Color = Color3.fromRGB(105, 190, 75) -- owned land is a richer green
	setSign(plot, "🌱 " .. player.DisplayName .. "'s Farm")

	local state = {player = player, client = client, controller = client.player_controller, data = client.data, plot = plot}
	Farm._farms[player] = state

	-- the starter farm is free
	if not owns(state, "starter") then
		local ups = TableUtility.deep.clone(state.data:Get({"farm", "upgrades"}) or {})
		ups.starter = true
		state.data:Set({"farm", "upgrades"}, ups)
	end

	-- rebuild everything they already own (no animation)
	for _, info in ipairs(FarmUpgrades) do
		if owns(state, info.id) then
			buildSection(state, info, false)
		end
	end
	-- decor bench + the player's own decorations
	local bench = FarmBuilder.workbench(plot.cf * CFrame.new(BENCH_AT + Vector3.new(0, FarmBuilder.GROUND, 0)))
	bench:SetAttribute("Owner", player.UserId)
	bench.Parent = plot.model.Built
	Farm._rebuildDecor(state)
	applyEffects(state)
	refreshPads(state)

	-- Teleport player to their farm on initial spawn and respawns
	local firstSpawn = true
	local function onCharacterAdded(character)
		if firstSpawn then
			firstSpawn = false
			-- Initial spawn: wait for loading screen to finish (min 4s + fade 1.15s)
			local spawnedAt = os.clock()
			task.spawn(function()
				task.wait(6)
				-- skip if the player already travelled somewhere themselves (no double teleport)
				if player.Parent and Farm._farms[player] and (Farm._travelledAt[player] or 0) < spawnedAt then
					Farm.teleport(player, "MyFarm")
				end
			end)
		else
			-- Respawn: teleport quickly after character loads
			task.spawn(function()
				for _ = 1, 30 do
					if character:FindFirstChild("HumanoidRootPart") then break end
					task.wait(0.2)
					if not player.Parent then return end
				end
				task.wait(0.5)
				if player.Parent and Farm._farms[player] then
					Farm.teleport(player, "MyFarm")
				end
			end)
		end
	end

	-- Handle existing character (for players already in game when script starts)
	if player.Character then
		onCharacterAdded(player.Character)
	end
	-- Handle future characters (initial spawn if not yet present, and all respawns)
	player.CharacterAdded:Connect(onCharacterAdded)
end

local function release(player)
	local state = Farm._farms[player]
	Farm._farms[player] = nil
	for _, plot in ipairs(Farm._plots) do
		if plot.owner == player then
			plot.owner = nil
			plot.model:SetAttribute("Owner", nil)
			plot.model:SetAttribute("Helpers", 0)
			plot.model.Base.Color = Color3.fromRGB(140, 220, 100)
			for _, c in ipairs(plot.conns or {}) do
				c:Disconnect()
			end
			plot.conns = {}
			plot.model.Built:ClearAllChildren()
			plot.model.Pads:ClearAllChildren()
			setSign(plot, "🌱 Free Plot")
		end
	end
end

---------------------------------------------------------------- decorations
local function decorList(state)
	return state.data:Get({"farm", "decor"}) or {}
end

local function decorFolder(state)
	local f = state.plot.model.Built:FindFirstChild("Decor")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Decor"
		f.Parent = state.plot.model.Built
	end
	return f
end

-- axis aligned rectangles in plot space: {cx, cz, hx, hz}
local function rect(center, size)
	return {center.X, center.Z, size.X / 2, size.Z / 2}
end
local function hit(a, b, margin)
	margin = margin or 0
	return math.abs(a[1] - b[1]) < a[3] + b[3] + margin and math.abs(a[2] - b[2]) < a[4] + b[4] + margin
end

local function decorRect(entry)
	local item = FarmDecor.ById[entry.i]
	if not item then
		return nil
	end
	return rect(Vector3.new(entry.x, 0, entry.z), FarmDecor.footprint(item, entry.r))
end

local function buildDecor(state, entry)
	local item = FarmDecor.ById[entry.i]
	if not item then
		return
	end
	local cf = state.plot.cf * CFrame.new(entry.x, FarmBuilder.GROUND, entry.z) * CFrame.Angles(0, math.rad(entry.r or 0), 0)
	local model = FarmBuilder.decor(item, cf, state.player.UserId)
	model:SetAttribute("DecorUid", entry.u)
	model:SetAttribute("DecorId", entry.i)
	model:SetAttribute("Owner", state.player.UserId)
	model:SetAttribute("FootCenter", Vector3.new(entry.x, 0, entry.z))
	model:SetAttribute("FootSize", FarmDecor.footprint(item, entry.r))
	model:SetAttribute("BuiltAt", workspace:GetServerTimeNow())
	model.Parent = decorFolder(state)
	return model
end

function Farm._rebuildDecor(state)
	decorFolder(state):ClearAllChildren()
	for _, entry in ipairs(decorList(state)) do
		buildDecor(state, entry)
	end
end

-- everything decorations may not overlap: built sections, the next pad, spawn and the bench
local function blockedRects(state)
	local list = {
		rect(Vector3.new(0, 0, 64), Vector3.new(8, 0, 8)), -- spawn
		rect(BENCH_AT, Vector3.new(7, 0, 5)), -- decor bench
		rect(Vector3.new(0, 0, 70), Vector3.new(26, 0, 3)), -- entrance sign
	}
	for _, info in ipairs(FarmUpgrades) do
		local fp = FarmBuilder.footprint(info)
		if fp and owns(state, info.id) then
			table.insert(list, rect(info.at, fp))
		end
	end
	-- Second Garden Floor: the Garden Lift (its sale sign stands there before buying) + deck pillars
	local GardenFloor = _L.Get {"Common", "Modules", "Databases", "GardenFloor"}
	table.insert(list, rect(GardenFloor.lift.at, GardenFloor.lift.size + Vector3.new(1, 0, 1)))
	if state.data:Get("garden_floor2") == true then
		for _, at in ipairs(GardenFloor.pillars) do
			table.insert(list, rect(at, Vector3.new(GardenFloor.PILLAR_SIZE + 0.6, 0, GardenFloor.PILLAR_SIZE + 0.6)))
		end
	end
	for _, info in ipairs(FarmUpgrades) do
		if not owns(state, info.id) then
			table.insert(list, rect(info.at, FarmBuilder.footprint(info) or Vector3.new(10, 0, 10)))
			break
		end
	end
	return list
end

function Farm.placeDecor(state, id, x, z, r)
	local item = FarmDecor.ById[id]
	if not item or typeof(x) ~= "number" or typeof(z) ~= "number" or typeof(r) ~= "number" then
		return false, "invalid"
	end
	if x ~= x or z ~= z or r ~= r then
		return false, "invalid"
	end
	x = math.floor(x * 2 + 0.5) / 2
	z = math.floor(z * 2 + 0.5) / 2
	r = (math.floor(r / 90 + 0.5) % 4) * 90
	local list = decorList(state)
	if #list >= FarmDecor.MAX_TOTAL then
		return false, "full"
	end
	if item.max then
		local n = 0
		for _, e in ipairs(list) do
			if e.i == id then
				n += 1
			end
		end
		if n >= item.max then
			return false, "max"
		end
	end
	local me = rect(Vector3.new(x, 0, z), FarmDecor.footprint(item, r))
	if math.abs(x) + me[3] > PLOT_HALF - 1.5 or math.abs(z) + me[4] > PLOT_HALF - 1.5 then
		return false, "outside"
	end
	for _, b in ipairs(blockedRects(state)) do
		if hit(me, b) then
			return false, "blocked"
		end
	end
	for _, e in ipairs(list) do
		local other = decorRect(e)
		if other and hit(me, other, 0.2) then
			return false, "blocked"
		end
	end
	local coins = state.data:Get({"stats", "Strength"}) or 0
	if coins < item.cost then
		return false, "afford"
	end

	state.data:Set({"stats", "Strength"}, coins - item.cost)
	local entry = {u = HttpService:GenerateGUID(false):sub(1, 8), i = id, x = x, z = z, r = r}
	local newList = TableUtility.deep.clone(list)
	table.insert(newList, entry)
	state.data:Set({"farm", "decor"}, newList)
	buildDecor(state, entry)
	if item.crop then
		applyEffects(state)
	end
	return true
end

function Farm.removeDecor(state, uid, refund)
	local list = decorList(state)
	for i, e in ipairs(list) do
		if e.u == uid then
			local newList = TableUtility.deep.clone(list)
			table.remove(newList, i)
			state.data:Set({"farm", "decor"}, newList)
			for _, m in ipairs(decorFolder(state):GetChildren()) do
				if m:GetAttribute("DecorUid") == uid then
					m:Destroy()
				end
			end
			local item = FarmDecor.ById[e.i]
			if refund ~= false and item then
				state.controller:_add_coins(item.cost)
			end
			return true, item
		end
	end
	return false
end

-- a new upgrade was built: decorations standing in its way go back to the player (full refund)
-- info.areas (optional): several {at, size} rects instead of one footprint (Second Garden Floor)
function Farm._clearDecorFor(state, info)
	local areas = {}
	if info.areas then
		for _, a in ipairs(info.areas) do
			table.insert(areas, rect(a.at, a.size))
		end
	else
		local fp = FarmBuilder.footprint(info)
		if not fp then
			return
		end
		table.insert(areas, rect(info.at, fp))
	end
	local moved = 0
	for _, e in ipairs(TableUtility.deep.clone(decorList(state))) do
		local r = decorRect(e)
		local inWay = false
		for _, area in ipairs(areas) do
			if r and hit(area, r) then
				inWay = true
				break
			end
		end
		if inWay then
			if Farm.removeDecor(state, e.u, true) then
				moved += 1
			end
		end
	end
	if moved > 0 then
		notify(state, "📦 " .. moved .. " decoration(s) were in the way - refunded!", Color3.fromRGB(255, 210, 90))
	end
end

-- Teleport spots in the village: stand in front of each shop, facing it
local SHOPS = {
	crop_market = {"Village", "CropSeller"},
	fruit_shop = {"Village", "Shops", "Fruit Shop"},
	garden_shop = {"Village", "Shops", "Garden Shop"},
	rewards = {"Village", "Rewards"},
	fruit_pen = {"Village", "FruitPen"},
}
local PLAZA = Vector3.new(1540, -297, 200)
function Farm.shopSpot(where)
	local path = typeof(where) == "string" and SHOPS[where]
	if not path then
		return nil
	end
	local node = workspace:FindFirstChild("__MAP")
	for _, name in ipairs(path) do
		node = node and node:FindFirstChild(name)
	end
	if not node then
		return nil
	end
	local cf, size = node:GetBoundingBox()
	local center = cf.Position
	-- the Crop Market: stand right in front of the seller NPC (inside sell range, outside the stall)
	if where == "crop_market" then
		local seller = if node.Name == "CropSeller" then node else node:FindFirstChild("Gardener_Seed")
		local torso = seller and (seller:FindFirstChild("HumanoidRootPart") or seller:FindFirstChild("Torso"))
		if torso then
			local toPlaza = Vector3.new(PLAZA.X - torso.Position.X, 0, PLAZA.Z - torso.Position.Z)
			toPlaza = if toPlaza.Magnitude > 0.1 then toPlaza.Unit else Vector3.new(0, 0, 1)
			-- first spot in front of the seller with nothing solid in it (crates, counter, walls)
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = {seller}
			local best
			for _, dist in ipairs({10, 12, 14, 8, 16}) do
				for _, deg in ipairs({0, 20, -20, 40, -40}) do
					local dir = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(toPlaza)
					local p = torso.Position + dir * dist
					local spot = Vector3.new(p.X, PLAZA.Y + 3, p.Z)
					local blocked = false
					for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(spot), Vector3.new(3, 5, 3), params)) do
						if part.CanCollide or part.Name == "Crate" or part.Name == "Item" then
							blocked = true
							break
						end
					end
					if not blocked then
						best = spot
						break
					end
				end
				if best then
					break
				end
			end
			local stand = best or (torso.Position + toPlaza * 16)
			return CFrame.lookAt(Vector3.new(stand.X, PLAZA.Y + 3, stand.Z), Vector3.new(torso.Position.X, PLAZA.Y + 3, torso.Position.Z))
		end
	end
	-- step from the shop toward the plaza, just outside its footprint
	local dir = Vector3.new(PLAZA.X - center.X, 0, PLAZA.Z - center.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	local stand = center + dir * (math.max(size.X, size.Z) / 2 + 6)
	return CFrame.lookAt(Vector3.new(stand.X, PLAZA.Y + 3, stand.Z), Vector3.new(center.X, PLAZA.Y + 3, center.Z))
end

Farm._travelledAt = {}

-- Teleport a player to a destination resolved here on the server:
--   "MyFarm"  -> this player's own farm entrance
--   "Village" -> the Workspace.TravelPoints.Village marker
--   "spawn"   -> the island arrival plaza ("Back to Spawn" pad)
--   any other id -> a village shop spot from SHOPS (e.g. "crop_market")
-- An unknown id or a missing destination is rejected: it never falls back to another place.
Farm._travelArea = {MyFarm = "MyFarm", spawn = "MyFarm"} -- area shown on the Travel button; shop spots are in the Village
function Farm.teleport(player, where)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or not character:IsDescendantOf(workspace) then
		return false, "character"
	end
	local target
	if where == "MyFarm" then
		local state = Farm._farms[player]
		local spawnPart = state and state.plot.model:FindFirstChild("Spawn")
		target = spawnPart and (spawnPart.CFrame * CFrame.Angles(0, math.pi, 0) + Vector3.new(0, 3, 0))
	elseif where == "Village" then
		local points = workspace:FindFirstChild("TravelPoints")
		local marker = points and points:FindFirstChild("Village")
		target = marker and marker:IsA("BasePart") and (marker.CFrame + Vector3.new(0, 3, 0)) or nil
	elseif where == "spawn" then
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
		target = spawn and (spawn.CFrame + Vector3.new(0, 4, 0))
		if not target then
			-- no SpawnLocation any more: the island plaza (Arrival) is the spawn
			local island = workspace:FindFirstChild("__MAP") and workspace.__MAP:FindFirstChild("FarmIsland")
			local arrival = island and island:FindFirstChild("Arrival")
			target = arrival and (arrival.CFrame + Vector3.new(0, 4, 0))
		end
	else
		target = Farm.shopSpot(where)
	end
	if not target then
		warn(string.format("[Farm] travel rejected: no destination for %q (player %s)", tostring(where), player.Name))
		return false, "missing"
	end
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 5)
	end)
	if character.Parent == nil or humanoid.Health <= 0 then
		return false, "character"
	end
	character:PivotTo(target)
	player:SetAttribute("TravelArea", Farm._travelArea[where] or "Village")
	return true
end

function Farm._init()
	Network = _L.Get {"Common", "Library", "Network"}
	FarmUpgrades = _L.Get {"Common", "Modules", "Databases", "FarmUpgrades"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	PowerUtility = _L.Get {"Common", "Modules", "Utilities", "PowerUtility"}
	TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	FarmBuilder = require(game:GetService("ServerStorage"):WaitForChild("FarmBuilder"))
	FarmDecor = _L.Get {"Common", "Modules", "Databases", "FarmDecor"}
end

function Farm._start()
	local island = workspace:WaitForChild("__MAP"):WaitForChild("FarmIsland", 30)
	if not island then
		warn("[Farm] FarmIsland not found")
		return
	end
	for _, model in ipairs(island.Plots:GetChildren()) do
		local id = model:GetAttribute("PlotId") or tonumber(model.Name)
		Farm._plots[id] = {id = id, model = model, cf = model.Base.CFrame}
	end

	Players.PlayerAdded:Connect(function(p) task.spawn(assign, p) end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(assign, p)
	end
	Players.PlayerRemoving:Connect(release)

	-- client teleports: only these destination ids (never a position), with a short cooldown.
	-- farm + village are the Travel menu; crop_market is the backpack SELL shortcut.
	local TRAVEL_IDS = {MyFarm = true, Village = true, crop_market = true}
	local TRAVEL_COOLDOWN = 3
	local TRAVEL_LEAF_DELAY = 0.3 -- departure leaves play this long before the move
	local lastTravel = {}
	Players.PlayerRemoving:Connect(function(p)
		lastTravel[p] = nil
		Farm._travelledAt[p] = nil
	end)
	Network.Remote.Invoked("S_Farm_Teleport", function(player, where)
		if typeof(where) ~= "string" or not TRAVEL_IDS[where] then
			warn(string.format("[Farm] travel rejected: invalid destination %s from %s", typeof(where) == "string" and string.format("%q", where:sub(1, 40)) or typeof(where), player.Name))
			return false, "invalid"
		end
		local now = os.clock()
		if lastTravel[player] and now - lastTravel[player] < TRAVEL_COOLDOWN then
			return false, "cooldown"
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root then
			return false, "dead"
		end
		-- the cooldown starts now, so taps during the short leaf burst below are refused
		lastTravel[player] = now
		-- leaf burst where the player stands (visual only: clients get a position, never a destination)
		Network.Remote.FireAll("C_Travel_Leaves", root.Position, "depart", player)
		task.wait(TRAVEL_LEAF_DELAY)
		local ok, why = Farm.teleport(player, where)
		if ok then
			Farm._travelledAt[player] = os.clock()
			local arrived = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if arrived then
				Network.Remote.FireAll("C_Travel_Leaves", arrived.Position, "arrive", player)
			end
		end
		return ok, why
	end)

	-- decorations: place / pick up (validated here, the client only previews)
	local lastDecor = {}
	local function decorGate(player)
		local state = Farm._farms[player]
		if not state or state.buying then
			return nil
		end
		local t = os.clock()
		if lastDecor[player] and t - lastDecor[player] < 0.2 then
			return nil
		end
		lastDecor[player] = t
		-- must be on (or right next to) their own plot
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return nil
		end
		local p = state.plot.cf:PointToObjectSpace(root.Position)
		if math.abs(p.X) > PLOT_HALF + 25 or math.abs(p.Z) > PLOT_HALF + 25 then
			return nil, "far"
		end
		return state
	end
	Network.Remote.Invoked("S_Decor_Place", function(player, id, x, z, r)
		local state, why = decorGate(player)
		if not state then
			return false, why or "busy"
		end
		state.buying = true
		local ok, result, reason = pcall(Farm.placeDecor, state, id, x, z, r)
		state.buying = false
		if not ok then
			warn("[Farm] decor place failed:", result)
			return false, "error"
		end
		return result, reason
	end)
	Network.Remote.Invoked("S_Decor_Remove", function(player, uid)
		local state, why = decorGate(player)
		if not state or typeof(uid) ~= "string" then
			return false, why or "busy"
		end
		state.buying = true
		local ok, result = pcall(Farm.removeDecor, state, uid, true)
		state.buying = false
		return ok and result or false
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastDecor[p] = nil
	end)

	-- Teleport player to their farm after loading screen finishes
	Network.Remote.Invoked("S_Spawn_At_Farm", function(player)
		local askedAt = os.clock()
		-- Wait for farm to be assigned (up to 30 seconds)
		for _ = 1, 60 do
			if Farm._farms[player] then
				break
			end
			task.wait(0.5)
			if not player.Parent then
				return false
			end
		end
		if (Farm._travelledAt[player] or 0) >= askedAt then
			return false, "travelled" -- the player already picked a destination
		end
		return Farm.teleport(player, "MyFarm")
	end)

	-- "Back to Spawn" pad on the island
	local back = island:FindFirstChild("BackToSpawn")
	if back then
		back.CanTouch = true
		local recent = {}
		back.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and not recent[player] then
				recent[player] = true
				Farm.teleport(player, "spawn")
				task.delay(2, function() recent[player] = nil end)
			end
		end)
	end

	-- helpers fill the storage crate
	task.spawn(function()
		while true do
			task.wait(HELPER_TICK)
			for player, state in pairs(Farm._farms) do
				if player.Parent then
					local income = helperIncomePerTick(state)
					if income > 0 then
						local cap = storageCapacity(state)
						local stored = state.data:Get({"farm", "storage"}) or 0
						if stored < cap then
							state.data:Set({"farm", "storage"}, math.min(cap, stored + income))
						end
						Farm._updateStorageLabel(state)
					end
				end
			end
		end
	end)
end

return Farm
