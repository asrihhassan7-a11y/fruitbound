--> GearShop (server, V1.1)
-- Village Gear Shop: rotating stock (Databases.Gears), Coins purchases, permanent Gear ownership
-- (data gears.owned[gear_id] = true) and exactly ONE Tool per owned Gear (Backpack + StarterGear).
-- Watering Can use: S_Gear_Water(cropKey) -> FarmingV2.waterCrop does every crop rule.
local _L = _G._L

local Players = game:GetService("Players")

local Network
local Gears
local FarmingV2
local TableUtility

local SHOP_DISTANCE = 18 -- studs from the Gear Shop counter to buy
local BUY_COOLDOWN = 1
local WATER_COOLDOWN = 0.5 -- per player request spam guard (each crop also has its own 3m cooldown)
local TOOL_ATTRIBUTE = "FruitBoundGear"

local GearShop = {}

local stockCycle = nil
local stockLeft = {} -- [gear_id] = amount left in this server for the current cycle
local lastBuy = {}
local lastWater = {}

local function getController(player)
	local client = Network.Bindable.Invoke("S_Client_Get", player)
	return client and client.player_controller or nil
end

local function shopCounter()
	local map = workspace:FindFirstChild("__MAP")
	local village = map and map:FindFirstChild("Village")
	local shops = village and village:FindFirstChild("Shops")
	local shop = shops and shops:FindFirstChild("Gear Shop")
	return shop and (shop:FindFirstChild("Counter") or shop:FindFirstChildWhichIsA("BasePart", true)) or nil
end

local function isNear(player, point, maximum)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil and (root.Position - point).Magnitude <= maximum
end

-- current cycle stock (rolled once per cycle, shared by everyone in this server)
local function currentStock()
	local cycle = Gears.cycle(os.time())
	if cycle ~= stockCycle then
		stockCycle = cycle
		stockLeft = Gears.rollStock(cycle)
	end
	return stockLeft
end

-- ============================================================
-- TOOLS
-- ============================================================

-- Watering Can tool (built from parts: no imported asset needed). Replace by putting a Tool named
-- "Watering Can" (with a Handle) in ReplicatedStorage.Assets.Gears.
local function buildWateringCan(info)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Gears")
	local authored = folder and folder:FindFirstChild(info.tool_name)
	if authored and authored:IsA("Tool") and authored:FindFirstChild("Handle") then
		return authored:Clone()
	end
	local tool = Instance.new("Tool")
	tool.Name = info.tool_name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Tap your growing crop to water it"
	tool.Grip = CFrame.new(0, -0.35, 0.1)

	local function part(name, size, color, cf, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = name == "Handle"
		p.Massless = true
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		return p, cf
	end
	local CAN = Color3.fromRGB(70, 165, 205)
	local DARK = Color3.fromRGB(45, 115, 150)
	local handle = part("Handle", Vector3.new(0.35, 1.1, 0.35), DARK)
	handle.Parent = tool
	local pieces = {
		{part("Body", Vector3.new(1.4, 1.2, 1.2), CAN, CFrame.new(0, -0.15, -0.95) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)},
		{part("Rim", Vector3.new(0.12, 1.25, 1.25), DARK, CFrame.new(0, 0.55, -0.95) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)},
		{part("Spout", Vector3.new(0.22, 0.22, 1.5), CAN, CFrame.new(0, 0.05, -2.05) * CFrame.Angles(math.rad(35), 0, 0))},
		{part("Rose", Vector3.new(0.18, 0.42, 0.42), DARK, CFrame.new(0, 0.5, -2.7) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, 0), Enum.PartType.Cylinder)},
	}
	for _, entry in ipairs(pieces) do
		local p, offset = entry[1], entry[2]
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Parent = tool
	end
	-- water stream point for the client visual
	local nozzle = Instance.new("Attachment")
	nozzle.Name = "Nozzle"
	nozzle.Parent = tool:FindFirstChild("Rose")
	return tool
end

local BUILDERS = {
	watering_can = buildWateringCan,
}

local function removeGearTools(container, gearId)
	if not container then
		return
	end
	for _, item in ipairs(container:GetChildren()) do
		if item:IsA("Tool") and item:GetAttribute(TOOL_ATTRIBUTE) == gearId then
			item:Destroy()
		end
	end
end

local function countGearTools(player, gearId)
	local n = 0
	for _, container in ipairs({player:FindFirstChild("Backpack"), player.Character}) do
		for _, item in ipairs(container and container:GetChildren() or {}) do
			if item:IsA("Tool") and item:GetAttribute(TOOL_ATTRIBUTE) == gearId then
				n += 1
			end
		end
	end
	return n
end

-- exactly one Tool per owned Gear: one in the Backpack (or held), one in StarterGear for respawns
local function syncTools(player)
	local controller = getController(player)
	if not controller then
		return
	end
	for _, info in ipairs(Gears.list) do
		local builder = BUILDERS[info.gear_id]
		if builder and Gears.owns(controller._data, info.gear_id) then
			local starterGear = player:FindFirstChild("StarterGear")
			if starterGear then
				removeGearTools(starterGear, info.gear_id)
				local spare = builder(info)
				spare:SetAttribute(TOOL_ATTRIBUTE, info.gear_id)
				spare.Parent = starterGear
			end
			local have = countGearTools(player, info.gear_id)
			if have ~= 1 then
				removeGearTools(player:FindFirstChild("Backpack"), info.gear_id)
				removeGearTools(player.Character, info.gear_id)
				local tool = builder(info)
				tool:SetAttribute(TOOL_ATTRIBUTE, info.gear_id)
				tool.Parent = player:FindFirstChild("Backpack")
			end
		end
	end
end

-- ============================================================
-- REMOTES
-- ============================================================

local function getState(player)
	local controller = getController(player)
	local stock = currentStock()
	local list = {}
	for _, info in ipairs(Gears.list) do
		table.insert(list, {
			gear_id = info.gear_id,
			name = info.name,
			rarity = info.rarity,
			price = info.price,
			icon = info.icon,
			description = info.description,
			stock = stock[info.gear_id] or 0,
			owned = controller ~= nil and Gears.owns(controller._data, info.gear_id),
		})
	end
	local now = os.time()
	return {gears = list, now = now, next_restock = Gears.nextRestock(now)}
end

local function buy(player, gearId)
	if typeof(gearId) ~= "string" or #gearId > 40 then
		return false, "invalid"
	end
	local now = os.clock()
	if lastBuy[player] and now - lastBuy[player] < BUY_COOLDOWN then
		return false, "cooldown"
	end
	lastBuy[player] = now
	local info = Gears.get(gearId)
	local controller = getController(player)
	if not info or not controller then
		return false, "invalid"
	end
	local counter = shopCounter()
	if not counter or not isNear(player, counter.Position, SHOP_DISTANCE) then
		return false, "distance"
	end
	local data = controller._data
	if Gears.owns(data, gearId) then
		return false, "owned"
	end
	local stock = currentStock()
	if (stock[gearId] or 0) <= 0 then
		return false, "stock"
	end
	local balance = data:Get({"stats", "Strength"})
	if typeof(balance) ~= "number" or balance ~= balance or math.abs(balance) == math.huge or balance < info.price then
		return false, "afford"
	end
	-- ownership first (whole table so older saves without "gears" work), then the price, then stock
	local saved = data:Get("gears")
	local gears = if typeof(saved) == "table" then TableUtility.deep.clone(saved) else {}
	gears.owned = if typeof(gears.owned) == "table" then gears.owned else {}
	gears.owned[gearId] = true
	data:Set("gears", gears)
	if not Gears.owns(data, gearId) then
		return false, "error"
	end
	data:Set({"stats", "Strength"}, balance - info.price)
	stock[gearId] -= 1
	syncTools(player)
	return true
end

local function water(player, cropKey)
	if typeof(cropKey) ~= "string" or #cropKey > 40 then
		return false, "invalid"
	end
	local now = os.clock()
	if lastWater[player] and now - lastWater[player] < WATER_COOLDOWN then
		return false, "spam"
	end
	lastWater[player] = now
	local controller = getController(player)
	if not controller or not Gears.owns(controller._data, "watering_can") then
		return false, "ownership"
	end
	-- the can must be in the player's hand
	local character = player.Character
	local held = character and character:FindFirstChildOfClass("Tool")
	if not held or held:GetAttribute(TOOL_ATTRIBUTE) ~= "watering_can" then
		return false, "equip"
	end
	return FarmingV2.waterCrop(player, cropKey)
end

function GearShop._init()
	Network = _L.Get {"Common", "Library", "Network"}
	Gears = _L.Get {"Common", "Modules", "Databases", "Gears"}
	FarmingV2 = _L.Get {"Server", "Modules", "Controllers", "FarmingV2"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
end

function GearShop._start()
	Network.Remote.Invoked("S_GearShop_Get", getState)
	Network.Remote.Invoked("S_GearShop_Buy", buy)
	Network.Remote.Invoked("S_Gear_Water", water)

	local counter = shopCounter()
	if counter then
		local prompt = counter:FindFirstChild("GearShopPrompt") or Instance.new("ProximityPrompt")
		prompt.Name = "GearShopPrompt"
		prompt.ActionText = "Open Gear Shop"
		prompt.ObjectText = "Gear Shop"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = counter
		prompt.Triggered:Connect(function(player)
			Network.Remote.Fire("C_GearShop_Open", player)
		end)
	else
		warn("[GearShop] Village.Shops['Gear Shop'] not found")
	end

	local function onPlayer(player)
		task.spawn(function()
			for _ = 1, 60 do
				if getController(player) then
					break
				end
				task.wait(0.5)
				if not player.Parent then
					return
				end
			end
			syncTools(player)
		end)
		player.CharacterAdded:Connect(function()
			-- StarterGear already copies the spare into the Backpack; only repair a missing / doubled tool
			task.delay(1, function()
				if player.Parent then
					syncTools(player)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastBuy[player] = nil
		lastWater[player] = nil
	end)
end

return GearShop
