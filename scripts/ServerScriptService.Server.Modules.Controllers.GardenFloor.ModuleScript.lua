-- // VARIABLES // --
-- V1.1 Second Garden Floor: a raised deck on the player's own farm plot, bought once with Coins.
-- Unlock = data.garden_floor2 (server only). The deck soil beds are tagged FarmSoil like the
-- ground beds, so planting, crop saving, growth, Fruit bonuses, exact-tap harvest and Auto Collect
-- all run through the existing FarmingV2 / Harvest code (FarmingV2.soilRects knows the beds).
-- The Garden Lift moves the owner between the ground and the deck (server teleport).
local _L = _G._L

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Farm
local GardenFloorInfo
local NumberUtility

local BUY_DISTANCE = 14
local LIFT_DISTANCE = 10
local REQUEST_COOLDOWN = 1
local MODEL_NAME = "GardenFloor2"
local SALE_NAME = "GardenFloor2Sale"

local WOOD = Color3.fromRGB(176, 124, 78)
local WOOD_DARK = Color3.fromRGB(128, 86, 52)
local STONE = Color3.fromRGB(158, 152, 140)
local TRIM = Color3.fromRGB(110, 74, 45)
local SOIL = Color3.fromRGB(135, 95, 60)

local GardenFloor = {}
local lastRequest = {}

-- // FUNCTIONS // --

local function passRateLimit(player)
    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
        return false
    end
    lastRequest[player] = now
    return true
end

local function notify(state, text, color)
    pcall(function()
        state.controller:_notify({text = text, color = color or Color3.fromRGB(255, 215, 80)})
    end)
end

local function owned(state)
    return state.data:Get("garden_floor2") == true
end

-- anchored part in plot space: centre (x, y, z) and size
local function part(parent, plotCf, name, center, size, color, material, collide, props)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = plotCf * CFrame.new(center)
    p.Color = color
    p.Material = material or Enum.Material.WoodPlanks
    p.Anchored = true
    p.CanCollide = collide == true
    p.CanTouch = false
    p.CanQuery = collide == true or (props and props.CanQuery) or false
    p.CastShadow = collide == true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(props or {}) do
        p[k] = v
    end
    p.Parent = parent
    return p
end

-- wooden railing from a to b (plot space, on the deck surface y): posts + two rails + a
-- see-through collision wall so nobody falls off
local function railing(parent, plotCf, a, b, y)
    local delta = b - a
    local length = delta.Magnitude
    if length < 0.5 then
        return
    end
    local mid = (a + b) / 2
    local alongX = math.abs(delta.X) > math.abs(delta.Z)
    local size = function(thick, height)
        return if alongX then Vector3.new(length, height, thick) else Vector3.new(thick, height, length)
    end
    part(parent, plotCf, "Rail", Vector3.new(mid.X, y + 3, mid.Z), size(0.45, 0.4), WOOD_DARK, Enum.Material.Wood, false)
    part(parent, plotCf, "Rail", Vector3.new(mid.X, y + 1.6, mid.Z), size(0.3, 0.3), WOOD_DARK, Enum.Material.Wood, false)
    part(parent, plotCf, "RailWall", Vector3.new(mid.X, y + 2, mid.Z), size(0.4, 4), WOOD, Enum.Material.SmoothPlastic, true, {Transparency = 1, CastShadow = false})
    local posts = math.max(1, math.floor(length / 5.5))
    for i = 0, posts do
        local p = a + delta * (i / posts)
        part(parent, plotCf, "RailPost", Vector3.new(p.X, y + 1.6, p.Z), Vector3.new(0.6, 3.2, 0.6), WOOD_DARK, Enum.Material.Wood, false)
    end
end

local function flowerPot(parent, plotCf, at, y, color)
    part(parent, plotCf, "Pot", Vector3.new(at.X, y + 0.7, at.Z), Vector3.new(2, 1.4, 2), Color3.fromRGB(190, 110, 70), Enum.Material.SmoothPlastic, true)
    local bush = part(parent, plotCf, "PotLeaves", Vector3.new(at.X, y + 2, at.Z), Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(95, 175, 80), Enum.Material.Grass, false, {Shape = Enum.PartType.Ball})
    bush.CastShadow = false
    for i = 1, 3 do
        local angle = i * 2.1
        part(parent, plotCf, "Flower", Vector3.new(at.X + math.cos(angle) * 0.8, y + 3, at.Z + math.sin(angle) * 0.8), Vector3.new(0.7, 0.7, 0.7), color, Enum.Material.SmoothPlastic, false, {Shape = Enum.PartType.Ball})
    end
end

local function signGui(board, title, subtitle)
    for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
        local gui = Instance.new("SurfaceGui")
        gui.Face = face
        gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        gui.PixelsPerStud = 40
        gui.LightInfluence = 0
        gui.Parent = board
        local label = Instance.new("TextLabel")
        label.Name = "Title"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, if subtitle then 0.55 else 1)
        label.Font = Enum.Font.FredokaOne
        label.TextScaled = true
        label.TextColor3 = Color3.fromRGB(255, 244, 214)
        label.Text = title
        label.Parent = gui
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 3
        stroke.Color = Color3.fromRGB(70, 45, 30)
        stroke.Parent = label
        if subtitle then
            local sub = label:Clone()
            sub.Name = "Subtitle"
            sub.Position = UDim2.fromScale(0, 0.55)
            sub.Size = UDim2.fromScale(1, 0.45)
            sub.TextColor3 = Color3.fromRGB(255, 210, 70)
            sub.Text = subtitle
            sub.Parent = gui
        end
    end
end

-- the Garden Lift tower; returns nothing (prompts are wired by the caller)
local function buildLift(model, plotCf, surface)
    local lift = GardenFloorInfo.lift
    local cx, cz = lift.at.X, lift.at.Z
    local hx, hz = lift.size.X / 2, lift.size.Z / 2
    local top = surface + 4
    for _, c in ipairs({{-hx, -hz}, {hx, -hz}, {-hx, hz}, {hx, hz}}) do
        part(model, plotCf, "LiftPost", Vector3.new(cx + c[1], (0.5 + top) / 2, cz + c[2]), Vector3.new(0.9, top - 0.5, 0.9), WOOD_DARK, Enum.Material.Wood, true)
    end
    -- roof beams + pulley wheel
    part(model, plotCf, "LiftBeam", Vector3.new(cx, top + 0.3, cz - hz), Vector3.new(lift.size.X + 0.9, 0.6, 0.6), WOOD_DARK, Enum.Material.Wood, false)
    part(model, plotCf, "LiftBeam", Vector3.new(cx, top + 0.3, cz + hz), Vector3.new(lift.size.X + 0.9, 0.6, 0.6), WOOD_DARK, Enum.Material.Wood, false)
    part(model, plotCf, "LiftBeam", Vector3.new(cx, top + 0.3, cz), Vector3.new(0.6, 0.6, lift.size.Z + 0.9), WOOD_DARK, Enum.Material.Wood, false)
    local wheel = part(model, plotCf, "LiftWheel", Vector3.new(cx, top - 0.6, cz), Vector3.new(0.5, 1.8, 1.8), Color3.fromRGB(90, 90, 95), Enum.Material.Metal, false, {Shape = Enum.PartType.Cylinder})
    wheel.CFrame = plotCf * CFrame.new(cx, top - 0.6, cz)
    part(model, plotCf, "LiftRope", Vector3.new(cx + 0.9, (1 + top) / 2, cz), Vector3.new(0.15, top - 1.2, 0.15), Color3.fromRGB(205, 180, 130), Enum.Material.Fabric, false)
    -- ground pad and top landing
    part(model, plotCf, "LiftPad", Vector3.new(cx, 0.7, cz), Vector3.new(lift.size.X, 0.4, lift.size.Z), WOOD, Enum.Material.WoodPlanks, true)
    part(model, plotCf, "LiftLanding", Vector3.new(cx, surface - 0.5, cz), Vector3.new(lift.size.X, 1, lift.size.Z), WOOD, Enum.Material.WoodPlanks, true)
    railing(model, plotCf, Vector3.new(cx - hx, 0, cz + hz), Vector3.new(cx + hx, 0, cz + hz), surface)
    railing(model, plotCf, Vector3.new(cx - hx, 0, cz - hz), Vector3.new(cx - hx, 0, cz + hz), surface)
    railing(model, plotCf, Vector3.new(cx + hx, 0, cz - hz), Vector3.new(cx + hx, 0, cz + hz), surface)
    local sign = part(model, plotCf, "LiftSign", Vector3.new(cx, 4.3, cz + hz + 0.5), Vector3.new(5, 1.6, 0.3), WOOD_DARK, Enum.Material.Wood, false)
    signGui(sign, "GARDEN LIFT")
end

local function prompt(parentPart, action, objectText, hold)
    local p = Instance.new("ProximityPrompt")
    p.ActionText = action
    p.ObjectText = objectText
    p.HoldDuration = hold or 0
    p.MaxActivationDistance = 8
    p.RequiresLineOfSight = false
    p.KeyboardKeyCode = Enum.KeyCode.E
    p.GamepadKeyCode = Enum.KeyCode.ButtonX
    p.Parent = parentPart
    return p
end

-- builds the whole deck on this player's plot (replaces an old one)
function GardenFloor.buildDeck(state)
    local built = state.plot.model:FindFirstChild("Built")
    if not built then
        return nil
    end
    local old = built:FindFirstChild(MODEL_NAME)
    if old then
        old:Destroy()
    end
    local sale = built:FindFirstChild(SALE_NAME)
    if sale then
        sale:Destroy()
    end
    local cf = state.plot.cf
    local userId = state.player.UserId
    local info = GardenFloorInfo
    local surface = info.HEIGHT + 1
    local model = Instance.new("Model")
    model.Name = MODEL_NAME
    model:SetAttribute("Owner", userId)

    local deckAt, deckSize = info.deck.at, info.deck.size
    local x0, x1 = deckAt.X - deckSize.X / 2, deckAt.X + deckSize.X / 2
    local z0, z1 = deckAt.Z - deckSize.Z / 2, deckAt.Z + deckSize.Z / 2
    local ox0, ox1 = info.opening.at.X - info.opening.size.X / 2, info.opening.at.X + info.opening.size.X / 2
    local oz0, oz1 = info.opening.at.Z - info.opening.size.Z / 2, info.opening.at.Z + info.opening.size.Z / 2
    local y = surface - 0.5
    -- planks: four strips around the skylight
    local function plank(ax, bx, az, bz)
        part(model, cf, "Deck", Vector3.new((ax + bx) / 2, y, (az + bz) / 2), Vector3.new(bx - ax, 1, bz - az), WOOD, Enum.Material.WoodPlanks, true)
    end
    plank(x0, x1, z0, oz0)
    plank(x0, x1, oz1, z1)
    plank(x0, ox0, oz0, oz1)
    plank(ox1, x1, oz0, oz1)
    -- trim under the deck edge
    part(model, cf, "DeckTrim", Vector3.new(deckAt.X, surface - 1.3, z0), Vector3.new(deckSize.X + 0.4, 0.8, 0.5), TRIM, Enum.Material.Wood, false)
    part(model, cf, "DeckTrim", Vector3.new(deckAt.X, surface - 1.3, z1), Vector3.new(deckSize.X + 0.4, 0.8, 0.5), TRIM, Enum.Material.Wood, false)
    part(model, cf, "DeckTrim", Vector3.new(x0, surface - 1.3, deckAt.Z), Vector3.new(0.5, 0.8, deckSize.Z + 0.4), TRIM, Enum.Material.Wood, false)
    part(model, cf, "DeckTrim", Vector3.new(x1, surface - 1.3, deckAt.Z), Vector3.new(0.5, 0.8, deckSize.Z + 0.4), TRIM, Enum.Material.Wood, false)

    -- stone pillars + wooden beams under the deck
    local pillarHeight = surface - 1 - 0.5
    for _, at in ipairs(info.pillars) do
        part(model, cf, "Pillar", Vector3.new(at.X, 0.5 + pillarHeight / 2, at.Z), Vector3.new(info.PILLAR_SIZE, pillarHeight, info.PILLAR_SIZE), STONE, Enum.Material.Cobblestone, true)
        part(model, cf, "PillarCap", Vector3.new(at.X, 1, at.Z), Vector3.new(info.PILLAR_SIZE + 0.6, 1, info.PILLAR_SIZE + 0.6), STONE, Enum.Material.Slate, true)
    end
    for _, px in ipairs({x0 + 0.5, x1 - 0.5}) do
        part(model, cf, "Beam", Vector3.new(px, surface - 1.5, deckAt.Z), Vector3.new(1, 1, deckSize.Z), WOOD_DARK, Enum.Material.Wood, false)
    end
    for _, pz in ipairs({z0 + 0.5, deckAt.Z, z1 - 0.5}) do
        part(model, cf, "Beam", Vector3.new(deckAt.X, surface - 1.5, pz), Vector3.new(deckSize.X, 1, 1), WOOD_DARK, Enum.Material.Wood, false)
    end

    -- soil beds (tagged FarmSoil exactly like FarmBuilder's beds; the server validates by GardenFloor.beds)
    for _, bed in ipairs(info.beds) do
        local soil = part(model, cf, "Soil", Vector3.new(bed.at.X, surface + 0.2, bed.at.Z), Vector3.new(bed.soil.X, 0.4, bed.soil.Z), SOIL, Enum.Material.Ground, false, {CanQuery = true})
        soil:SetAttribute("Owner", userId)
        soil:SetAttribute("UpgradeId", bed.id)
        CollectionService:AddTag(soil, "FarmSoil")
        local hx, hz = bed.soil.X / 2, bed.soil.Z / 2
        for _, e in ipairs({{0, hz, bed.soil.X + 0.6, 0.6}, {0, -hz, bed.soil.X + 0.6, 0.6}, {hx, 0, 0.6, bed.soil.Z}, {-hx, 0, 0.6, bed.soil.Z}}) do
            part(model, cf, "Edge", Vector3.new(bed.at.X + e[1], surface + 0.4, bed.at.Z + e[2]), Vector3.new(e[3], 0.8, e[4]), TRIM, Enum.Material.Wood, false)
        end
    end

    -- railings: outer edge (gap for the bridge at the front centre) and around the skylight
    local bridgeHalf = 2
    railing(model, cf, Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0), surface)
    railing(model, cf, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), surface)
    railing(model, cf, Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1), surface)
    railing(model, cf, Vector3.new(x0, 0, z1), Vector3.new(-bridgeHalf, 0, z1), surface)
    railing(model, cf, Vector3.new(bridgeHalf, 0, z1), Vector3.new(x1, 0, z1), surface)
    railing(model, cf, Vector3.new(ox0, 0, oz0), Vector3.new(ox1, 0, oz0), surface)
    railing(model, cf, Vector3.new(ox0, 0, oz1), Vector3.new(ox1, 0, oz1), surface)
    railing(model, cf, Vector3.new(ox0, 0, oz0), Vector3.new(ox0, 0, oz1), surface)
    railing(model, cf, Vector3.new(ox1, 0, oz0), Vector3.new(ox1, 0, oz1), surface)

    -- bridge from the deck to the lift landing
    local lift = info.lift
    local liftZ0 = lift.at.Z - lift.size.Z / 2
    part(model, cf, "Bridge", Vector3.new(lift.at.X, y, (z1 + liftZ0) / 2), Vector3.new(bridgeHalf * 2, 1, liftZ0 - z1 + 0.2), WOOD, Enum.Material.WoodPlanks, true)
    railing(model, cf, Vector3.new(-bridgeHalf, 0, z1), Vector3.new(-bridgeHalf, 0, liftZ0), surface)
    railing(model, cf, Vector3.new(bridgeHalf, 0, z1), Vector3.new(bridgeHalf, 0, liftZ0), surface)
    buildLift(model, cf, surface)

    -- a little life: flower pots in the deck corners
    flowerPot(model, cf, Vector3.new(x0 + 1.6, 0, z0 + 1.6), surface, Color3.fromRGB(255, 120, 160))
    flowerPot(model, cf, Vector3.new(x1 - 1.6, 0, z0 + 1.6), surface, Color3.fromRGB(255, 215, 90))
    flowerPot(model, cf, Vector3.new(x0 + 1.6, 0, z1 - 1.6), surface, Color3.fromRGB(170, 140, 255))
    flowerPot(model, cf, Vector3.new(x1 - 1.6, 0, z1 - 1.6), surface, Color3.fromRGB(255, 150, 90))

    -- lift prompts: invisible anchors at the ground pad and the top landing
    local bottom = part(model, cf, "LiftBottom", Vector3.new(lift.at.X, 3, lift.at.Z), Vector3.new(1, 1, 1), WOOD, nil, false, {Transparency = 1})
    local topAnchor = part(model, cf, "LiftTop", Vector3.new(lift.at.X, surface + 2.5, lift.at.Z), Vector3.new(1, 1, 1), WOOD, nil, false, {Transparency = 1})
    prompt(bottom, "Ride Up", "Garden Lift").Triggered:Connect(function(player)
        GardenFloor.ride(player, "up")
    end)
    prompt(topAnchor, "Ride Down", "Garden Lift").Triggered:Connect(function(player)
        GardenFloor.ride(player, "down")
    end)

    model.Parent = built
    return model
end

-- "for sale" sign where the lift will stand
function GardenFloor.buildSaleSign(state)
    local built = state.plot.model:FindFirstChild("Built")
    if not built or built:FindFirstChild(SALE_NAME) or built:FindFirstChild(MODEL_NAME) then
        return nil
    end
    local cf = state.plot.cf
    local info = GardenFloorInfo
    local at = info.lift.at
    local model = Instance.new("Model")
    model.Name = SALE_NAME
    model:SetAttribute("Owner", state.player.UserId)
    part(model, cf, "SignPost", Vector3.new(at.X - 2.2, 2.6, at.Z), Vector3.new(0.5, 4.2, 0.5), WOOD_DARK, Enum.Material.Wood, true)
    part(model, cf, "SignPost", Vector3.new(at.X + 2.2, 2.6, at.Z), Vector3.new(0.5, 4.2, 0.5), WOOD_DARK, Enum.Material.Wood, true)
    local board = part(model, cf, "Board", Vector3.new(at.X, 4, at.Z), Vector3.new(5.4, 2.6, 0.3), WOOD, Enum.Material.WoodPlanks, true)
    board.CFrame = cf * CFrame.new(at.X, 4, at.Z)
    signGui(board, info.icon .. " SECOND GARDEN FLOOR", "💰 " .. NumberUtility.short(info.COST) .. " Coins")
    -- readable from across the farm, so players know the upgrade exists
    local bb = Instance.new("BillboardGui")
    bb.Name = "FloorForSale"
    bb.Size = UDim2.fromScale(10, 3.2)
    bb.StudsOffset = Vector3.new(0, 4.5, 0)
    bb.MaxDistance = 160
    bb.LightInfluence = 0
    bb.AlwaysOnTop = false
    bb.Parent = board
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
    frame.Parent = bb
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0.25, 0)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 3
    stroke.Color = Color3.fromRGB(70, 50, 40)
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromScale(0.04, 0.06)
    title.Size = UDim2.fromScale(0.92, 0.5)
    title.Font = Enum.Font.FredokaOne
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(80, 55, 35)
    title.Text = info.icon .. " Second Garden Floor"
    title.Parent = frame
    local price = title:Clone()
    price.Position = UDim2.fromScale(0.04, 0.56)
    price.Size = UDim2.fromScale(0.92, 0.38)
    price.TextColor3 = Color3.fromRGB(230, 160, 30)
    price.Text = "💰 " .. NumberUtility.short(info.COST) .. " Coins - plant on a raised deck!"
    price.Parent = frame
    -- faint outline of where the deck will stand
    local d = info.deck
    for _, s in ipairs({{0, d.size.Z / 2, d.size.X, 0.5}, {0, -d.size.Z / 2, d.size.X, 0.5}, {d.size.X / 2, 0, 0.5, d.size.Z}, {-d.size.X / 2, 0, 0.5, d.size.Z}}) do
        part(model, cf, "PlanOutline", Vector3.new(d.at.X + s[1], 0.58, d.at.Z + s[2]), Vector3.new(s[3], 0.15, s[4]), Color3.fromRGB(150, 240, 130), Enum.Material.Neon, false, {Transparency = 0.5})
    end
    prompt(board, "Buy (" .. NumberUtility.short(info.COST) .. " Coins)", info.name, 0.6).Triggered:Connect(function(player)
        GardenFloor.buy(player)
    end)
    model.Parent = built
    return model
end

function GardenFloor.buy(player)
    local state = Farm._farms[player]
    if not state or not passRateLimit(player) then
        return false, "busy"
    end
    if state.plot.owner ~= player then
        return false, "ownership"
    end
    if owned(state) then
        return false, "owned"
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local signPos = state.plot.cf * (GardenFloorInfo.lift.at + Vector3.new(0, 3, 0))
    if not humanoid or humanoid.Health <= 0 or not root or (root.Position - signPos).Magnitude > BUY_DISTANCE then
        return false, "distance"
    end
    if state.buying then
        return false, "busy"
    end
    local coins = state.data:Get({"stats", "Strength"})
    if typeof(coins) ~= "number" or coins ~= coins or coins < GardenFloorInfo.COST then
        notify(state, "❌ You need " .. NumberUtility.short(GardenFloorInfo.COST - (tonumber(coins) or 0)) .. " more Coins for the " .. GardenFloorInfo.name .. "!", Color3.fromRGB(255, 90, 90))
        return false, "afford"
    end
    state.buying = true
    state.data:Set({"stats", "Strength"}, coins - GardenFloorInfo.COST)
    state.data:Set("garden_floor2", true)
    -- decorations standing where the pillars / lift go are refunded
    local areas = {{at = GardenFloorInfo.lift.at, size = GardenFloorInfo.lift.size + Vector3.new(1, 0, 1)}}
    for _, at in ipairs(GardenFloorInfo.pillars) do
        table.insert(areas, {at = at, size = Vector3.new(GardenFloorInfo.PILLAR_SIZE + 0.6, 0, GardenFloorInfo.PILLAR_SIZE + 0.6)})
    end
    pcall(Farm._clearDecorFor, state, {id = GardenFloorInfo.id, areas = areas})
    local ok, err = pcall(GardenFloor.buildDeck, state)
    if not ok then
        warn("[GardenFloor] build failed:", err)
    end
    state.buying = false
    player:SetAttribute("GardenFloor2", true)
    notify(state, "🎉 " .. GardenFloorInfo.icon .. " " .. GardenFloorInfo.name .. " unlocked! Take the Garden Lift up and plant!")
    return true
end

-- Garden Lift: the farm owner only, standing at the matching end, alive
function GardenFloor.ride(player, direction)
    local state = Farm._farms[player]
    if not state or state.plot.owner ~= player or not owned(state) or not passRateLimit(player) then
        return false
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then
        return false
    end
    local info = GardenFloorInfo
    local surface = info.HEIGHT + 1
    local lift = info.lift.at
    local from = if direction == "up" then Vector3.new(lift.X, 3, lift.Z) elseif direction == "down" then Vector3.new(lift.X, surface + 2.5, lift.Z) else nil
    if not from or (root.Position - state.plot.cf * from).Magnitude > LIFT_DISTANCE then
        return false
    end
    local target, lookAt
    if direction == "up" then
        target = Vector3.new(lift.X, surface + 3, info.deck.at.Z + info.deck.size.Z / 2 - 3)
        lookAt = Vector3.new(lift.X, surface + 3, info.deck.at.Z)
    else
        target = Vector3.new(lift.X + info.lift.size.X / 2 + 3.5, 4, lift.Z)
        lookAt = Vector3.new(lift.X + 10, 4, lift.Z)
    end
    local worldTarget = state.plot.cf * target
    local worldLook = state.plot.cf * lookAt
    character:PivotTo(CFrame.lookAt(worldTarget, Vector3.new(worldLook.X, worldTarget.Y, worldLook.Z)))
    return true
end

local function syncPlayer(player)
    for _ = 1, 120 do
        local state = Farm._farms[player]
        if state and state.plot and state.plot.model:FindFirstChild("Built") then
            break
        end
        task.wait(0.5)
        if not player.Parent then
            return
        end
    end
    local state = Farm._farms[player]
    if not state then
        return
    end
    task.wait(0.5) -- let Farm finish rebuilding the plot first
    if not player.Parent or Farm._farms[player] ~= state then
        return
    end
    if owned(state) then
        player:SetAttribute("GardenFloor2", true)
        local ok, err = pcall(GardenFloor.buildDeck, state)
        if not ok then
            warn("[GardenFloor] build failed:", err)
        end
    else
        pcall(GardenFloor.buildSaleSign, state)
    end
end

function GardenFloor._init()
    Farm = _L.Get {"Server", "Modules", "Controllers", "Farm"}
    GardenFloorInfo = _L.Get {"Common", "Modules", "Databases", "GardenFloor"}
    NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
end

function GardenFloor._start()
    Players.PlayerAdded:Connect(function(player)
        task.spawn(syncPlayer, player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(syncPlayer, player)
    end
    Players.PlayerRemoving:Connect(function(player)
        lastRequest[player] = nil
    end)
end

return GardenFloor
