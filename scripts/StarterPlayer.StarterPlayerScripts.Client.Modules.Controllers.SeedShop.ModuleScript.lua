---> SeedShop (client)
-- Opens when the server fires C_SeedShop_Open (Seed Shop NPC proximity prompt).
-- Shows seed packs for purchase with Coins and your owned seeds (EQUIP one, then tap your farm soil).
-- All purchases are validated server-side. The client never decides rewards.

local _L = _G._L

local Network
local Audio
local NumberUtility
local UIAnimationController
local Data
local UI
local SeedPacks
local playerData

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeedShop = {}

-- SEED_EMOJI by plant style (matches PlantBuilder styles)
local SEED_EMOJI = {
    Clover = "\u{1F340}", Leaf = "\u{1F33F}", Veggie = "\u{1F955}",
    Flower = "\u{1F33B}", Mushroom = "\u{1F344}",
}

local SEED_NAME_EMOJI = {
    clover = "\u{1F340}", mint = "\u{1F33F}", carrot = "\u{1F955}",
    sunflower = "\u{1F33B}", glow_mushroom = "\u{1F344}",
}

-- Error messages for server return codes
local ERRORS = {
    invalid = "Invalid request. Try again!",
    distance = "Too far away! Get closer to the shop!",
    afford = "Not enough Coins! Sell some crops first!",
    ownership = "You don't own that seed!",
}

-- State
local gui
local window
local packContainer
local seedContainer
local coinsLabel
local buying = false
local revealing = false
local isOpen = false

-------- UI helpers (same pattern as Backpack controller) --------

local function short(n)
    local ok, s = pcall(NumberUtility.short, n)
    return if ok then s else tostring(math.floor(n))
end

local function notify(text, color)
    pcall(function()
        local UI = _L.Get {"Client", "Modules", "UI"}
        UI.Get("Notifications"):add({text = text, color = color or Color3.fromRGB(120, 230, 120), duration = 3})
    end)
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, border)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(180, 180, 180)
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function pad(parent, all)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, all)
    p.PaddingBottom = UDim.new(0, all)
    p.PaddingLeft = UDim.new(0, all)
    p.PaddingRight = UDim.new(0, all)
    p.Parent = parent
    return p
end

local function makeLabel(parent, text, props)
    local l = Instance.new("TextLabel")
    l.Text = text or ""
    l.Font = props.font or Enum.Font.FredokaOne
    l.TextScaled = props.scaled ~= false
    l.TextColor3 = props.color or Color3.fromRGB(60, 60, 60)
    l.BackgroundTransparency = 1
    l.Size = props.size or UDim2.new(1, 0, 0, 20)
    l.Position = props.pos or UDim2.new(0, 0, 0, 0)
    l.AnchorPoint = props.anchor or Vector2.new(0, 0)
    l.TextXAlignment = props.xAlign or Enum.TextXAlignment.Center
    l.TextYAlignment = props.yAlign or Enum.TextYAlignment.Center
    l.Parent = parent
    return l
end

local function makeButton(parent, text, bgColor, textColor)
    local b = Instance.new("TextButton")
    b.Text = text or ""
    b.Font = Enum.Font.FredokaOne
    b.TextScaled = true
    b.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
    b.BackgroundColor3 = bgColor or Color3.fromRGB(80, 180, 80)
    b.AutoButtonColor = true
    b.Size = UDim2.new(0, 100, 0, 36)
    b.Parent = parent
    corner(b, 8)
    stroke(b, Color3.fromRGB(0, 0, 0), 0, true)
    return b
end

local function addSeedPreview(parent, visualName, x, y, w, h)
    local seedsFolder = ReplicatedStorage.Assets.Models:FindFirstChild("Seeds")
    local template = seedsFolder and seedsFolder:FindFirstChild(visualName)
    if not template then return end

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "SeedPreview"
    viewport.Position = UDim2.fromOffset(x or 6, y or 6)
    viewport.Size = UDim2.fromOffset(w or 56, h or 56)
    viewport.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
    viewport.BackgroundTransparency = 0.25
    viewport.Ambient = Color3.fromRGB(190, 190, 190)
    viewport.LightColor = Color3.fromRGB(255, 255, 255)
    viewport.LightDirection = Vector3.new(-1, -1, -1)
    viewport.Parent = parent
    corner(viewport, 8)
    stroke(viewport, Color3.fromRGB(150, 110, 75), 2, true)

    local world = Instance.new("WorldModel")
    world.Parent = viewport
    local visual = template:Clone()
    visual.Parent = world
    visual:PivotTo(CFrame.new())
    for _, descendant in ipairs(visual:GetDescendants()) do
        if descendant:IsA("BasePart") then descendant.Anchored = true end
    end
    local boxCFrame, boxSize = visual:GetBoundingBox()
    local radius = math.max(boxSize.X, boxSize.Y, boxSize.Z)
    local direction = Vector3.new(1, 0.45, 1).Unit
    local camera = Instance.new("Camera")
    camera.CFrame = CFrame.lookAt(boxCFrame.Position + direction * radius * 3, boxCFrame.Position)
    camera.FieldOfView = 35
    camera.Parent = viewport
    viewport.CurrentCamera = camera
end

-------- Core logic --------

-- Hides / shows the Roblox Backpack hotbar (where the seed Tools live) for the pack reveal.
-- Goes through ReplicatedFirst.BackpackVisibility, so it never fights the loading screen:
-- the hotbar only comes back when no other hide reason remains.
local BackpackVisibility = require(game:GetService("ReplicatedFirst"):WaitForChild("BackpackVisibility"))
function SeedShop._setHotbarHidden(hidden)
    if hidden then
        BackpackVisibility.hide("SeedPackReveal")
    else
        BackpackVisibility.show("SeedPackReveal")
    end
end

local function closeShop()
    if not isOpen then return end
    isOpen = false
    if gui then
        gui.Enabled = false
        local reveal = gui:FindFirstChild("PackReveal")
        if reveal then
            reveal:Destroy()
        end
    end
    revealing = false
end

local function openShop()
    if isOpen then return end
    local backpack = Players.LocalPlayer.PlayerGui:FindFirstChild("Backpack")
    if backpack and backpack:FindFirstChild("Window") then
        backpack.Window.Visible = false
    end
    if UI._current:Get() then
        UI.Close({name = UI._current:Get()})
    end
    isOpen = true
    if gui then
        gui.Enabled = true
    end
    -- Refresh state from server
    task.spawn(function()
        local ok, state = pcall(Network.Remote.Invoke, "S_Seeds_Get")
        if ok and state then
            SeedShop._render(state)
        end
    end)
end

-- Render the pack list and seed inventory from server state
function SeedShop._render(state)
    if not gui then return end

    -- Update coins
    local coins = 0
    local data = _G.Data
    if data then
        coins = data:Get({"stats", "Strength"}) or 0
    end
    if coinsLabel then
        coinsLabel.Text = "\u{1F4B0} " .. short(coins) .. " Coins"
    end

    -- Clear old pack cards (destroy only GuiObjects so the UIListLayout survives)
    for _, child in ipairs(packContainer:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    -- Render pack cards
    if state.packs then
        local packs = table.clone(state.packs)
        table.sort(packs, function(a, b)
            return a.price < b.price
        end)
        for _, preview in ipairs(SeedPacks.PreviewPacks or {}) do
            table.insert(packs, preview)
        end
        -- Garden-theme tint per pack tier
        local PACK_COLORS = {
            starter = Color3.fromRGB(255, 245, 220),
            garden = Color3.fromRGB(224, 244, 212),
            flower = Color3.fromRGB(252, 233, 240),
            woodland = Color3.fromRGB(219, 237, 226),
            golden_grove = Color3.fromRGB(250, 236, 190),
            enchanted_garden = Color3.fromRGB(228, 220, 250),
        }

        -- Fruit-inspired tier badge colors (FruitBound identity)
        local TIER_COLORS = {
            starter = Color3.fromRGB(160, 220, 70),
            garden = Color3.fromRGB(92, 175, 84),
            flower = Color3.fromRGB(255, 150, 160),
            woodland = Color3.fromRGB(70, 130, 60),
            golden_grove = Color3.fromRGB(255, 205, 66),
            enchanted_garden = Color3.fromRGB(170, 100, 220),
        }

        for packIndex, pack in ipairs(packs) do
            local card = Instance.new("Frame")
            card.Name = "Pack_" .. pack.id
            card.Size = UDim2.new(1, 0, 0, 132)
            card.LayoutOrder = packIndex
            card.BackgroundColor3 = if pack.preview then Color3.fromRGB(219, 237, 226) else PACK_COLORS[pack.id] or Color3.fromRGB(255, 245, 220)
            card.Parent = packContainer
            corner(card, 10)
            stroke(card, Color3.fromRGB(150, 110, 75), 1.5, true)
            addSeedPreview(card, pack.visual or "starter_pack")

            -- Fruit tier badge (seed-packet label under the name)
            local tierName = (SeedPacks.getPack(pack.id) or {}).tier or "Garden"
            local badge = Instance.new("TextLabel")
            badge.Name = "TierBadge"
            badge.Size = UDim2.new(0, 86, 0, 20)
            badge.Position = UDim2.new(0, 70, 0, 58)
            badge.BackgroundColor3 = TIER_COLORS[pack.id] or Color3.fromRGB(92, 175, 84)
            badge.Font = Enum.Font.FredokaOne
            badge.TextScaled = true
            badge.Text = string.upper(tierName)
            badge.TextColor3 = Color3.fromRGB(255, 252, 240)
            badge.BorderSizePixel = 0
            badge.Parent = card
            corner(badge, 8)
            stroke(badge, Color3.fromRGB(105, 66, 32), 1.5, true)

            -- Pack name
            makeLabel(card, pack.display_name or "Seed Pack", {
                size = UDim2.new(0.55, 0, 0, 28),
                pos = UDim2.new(0, 70, 0, 6),
                color = Color3.fromRGB(70, 50, 30),
                xAlign = Enum.TextXAlignment.Left,
            })

            -- Rolls label (tier comes from the local pack definition)
            local packTier = (SeedPacks.getPack(pack.id) or {}).tier or "Garden"
            makeLabel(card, if pack.preview then (pack.tier or "New") .. " tier · Coming later" else tostring(pack.rolls) .. " seeds · " .. packTier .. " tier", {
                size = UDim2.new(0.55, 0, 0, 18),
                pos = UDim2.new(0, 70, 0, 38),
                color = Color3.fromRGB(150, 140, 120),
                font = Enum.Font.GothamMedium,
                xAlign = Enum.TextXAlignment.Left,
            })

            -- Price + Buy button
            local canAfford = not pack.preview and coins >= pack.price
            local buyBtn = makeButton(card,
                "\u{1F4B0} " .. short(pack.price),
                canAfford and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(160, 160, 160),
                Color3.fromRGB(255, 255, 255))
            buyBtn.Size = UDim2.new(0, 110, 0, 44)
            buyBtn.AnchorPoint = Vector2.new(1, 0.5)
            buyBtn.Position = UDim2.new(1, -8, 0, 32)
            buyBtn.Name = "Buy"
            buyBtn:SetAttribute("PackPrice", pack.price)
            buyBtn.Active = not pack.preview
            buyBtn.AutoButtonColor = not pack.preview
            local contents = {}
            local definition = SeedPacks.getPack(pack.id)
            for _, entry in ipairs(definition and definition.entries or {}) do
                local seed = SeedPacks.getSeed(entry.seed_id)
                table.insert(contents, seed.display_name .. " " .. entry.chance .. "%")
            end
            local contentLabel = makeLabel(card, if pack.preview then "Price and contents not set. Not available for purchase." else "Possible seeds: " .. table.concat(contents, " · "), {
                size = UDim2.new(1, -20, 0, 52),
                pos = UDim2.fromOffset(10, 74),
                color = Color3.fromRGB(95, 75, 50),
                xAlign = Enum.TextXAlignment.Left,
                font = Enum.Font.GothamMedium,
            })
            contentLabel.TextWrapped = true
            buyBtn.Text = "\u{1F4B0} " .. short(pack.price)

            buyBtn.MouseButton1Click:Connect(function()
                if buying or pack.preview then return end
                buying = true
                buyBtn.Text = "..."
                buyBtn.BackgroundColor3 = Color3.fromRGB(120, 160, 120)

                local ok, success, results = pcall(Network.Remote.Invoke, "S_SeedPack_Buy", pack.id)
                buying = false

                if not ok then
                    notify("Connection error. Try again!", Color3.fromRGB(255, 120, 60))
                    SeedShop._render(state)
                    return
                end

                -- Refresh state after purchase
                local function refresh()
                    task.spawn(function()
                        local ok2, state2 = pcall(Network.Remote.Invoke, "S_Seeds_Get")
                        if ok2 and state2 then
                            SeedShop._render(state2)
                        end
                    end)
                end

                if success and typeof(results) == "table" then
                    -- Animated reveal of what seeds were rolled (server decides, not client).
                    -- The seeds are already saved; the shop list and the hotbar Tools only
                    -- update once the reveal is over, so they don't spoil it.
                    SeedShop._showPackReveal(pack, results, refresh)
                else
                    local errCode = typeof(results) == "string" and results or "invalid"
                    notify(ERRORS[errCode] or "Something went wrong!", Color3.fromRGB(255, 120, 60))
                    refresh()
                end
            end)
        end
    end

    -- Clear old seed items (destroy only GuiObjects so the UIListLayout survives)
    for _, child in ipairs(seedContainer:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end

    -- Render seed inventory
    local hasSeeds = false
    if state.inventory and typeof(state.inventory) == "table" then
        -- Sort seeds alphabetically for consistent order
        local seedIds = {}
        for seedId, count in pairs(state.inventory) do
            if typeof(count) == "number" and count > 0 then
                table.insert(seedIds, seedId)
            end
        end
        table.sort(seedIds)

        for _, seedId in ipairs(seedIds) do
            hasSeeds = true
            local count = state.inventory[seedId]
            local displayName = seedId:gsub("_", " "):gsub("^%l", string.upper)
            local emoji = SEED_NAME_EMOJI[seedId] or "\u{1F331}"

            local card = Instance.new("Frame")
            card.Name = "Seed_" .. seedId
            card.Size = UDim2.new(1, 0, 0, 64)
            card.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
            card.Parent = seedContainer
            corner(card, 10)
            stroke(card, Color3.fromRGB(150, 110, 75), 1.5, true)
            addSeedPreview(card, seedId)

            -- Count badge shaped like a little fruit dot
            local countBadge = Instance.new("TextLabel")
            countBadge.Name = "CountBadge"
            countBadge.Size = UDim2.new(0, 44, 0, 20)
            countBadge.Position = UDim2.new(0, 70, 0, 56)
            countBadge.BackgroundColor3 = Color3.fromRGB(92, 175, 84)
            countBadge.Font = Enum.Font.FredokaOne
            countBadge.TextScaled = true
            countBadge.Text = "x" .. tostring(count)
            countBadge.TextColor3 = Color3.fromRGB(255, 252, 240)
            countBadge.BorderSizePixel = 0
            countBadge.Parent = card
            corner(countBadge, 8)
            stroke(countBadge, Color3.fromRGB(105, 66, 32), 1.5, true)

            -- Seed name
            makeLabel(card, emoji .. " " .. displayName, {
                size = UDim2.new(0.55, 0, 0, 28),
                pos = UDim2.new(0, 70, 0, 6),
                color = Color3.fromRGB(50, 100, 50),
                xAlign = Enum.TextXAlignment.Left,
            })

            -- Count
            makeLabel(card, "x" .. tostring(count), {
                size = UDim2.new(0.55, 0, 0, 18),
                pos = UDim2.new(0, 70, 0, 34),
                color = Color3.fromRGB(120, 140, 120),
                font = Enum.Font.GothamMedium,
                xAlign = Enum.TextXAlignment.Left,
            })

            -- Equip button: planting is physical now (Seed Tool -> tap your farm soil)
            local plantBtn = makeButton(card, "\u{1F331} EQUIP",
                Color3.fromRGB(100, 160, 60), Color3.fromRGB(255, 255, 255))
            plantBtn.Size = UDim2.new(0, 100, 0, 40)
            plantBtn.AnchorPoint = Vector2.new(1, 0.5)
            plantBtn.Position = UDim2.new(1, -8, 0.5, 0)

            plantBtn.MouseButton1Click:Connect(function()
                SeedShop._equipSeed(seedId)
            end)
        end
    end

    if not hasSeeds then
        makeLabel(seedContainer, "\u{1F331} No seeds yet! Buy a pack above to get started.", {
            size = UDim2.new(1, 0, 0, 40),
            pos = UDim2.new(0, 0, 0, 8),
            color = Color3.fromRGB(160, 160, 160),
            font = Enum.Font.GothamMedium,
        })
    end
end

-- Equip that Seed's Tool and go plant it: the shop closes and the player taps their farm soil
function SeedShop._equipSeed(seedId)
    local player = Players.LocalPlayer
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = player:FindFirstChildOfClass("Backpack")
    local tool
    for _, container in ipairs({character, backpack}) do
        for _, child in ipairs(container and container:GetChildren() or {}) do
            if child:IsA("Tool") and child:GetAttribute("SeedId") == seedId then
                tool = child
            end
        end
    end
    closeShop()
    if tool and humanoid and tool.Parent ~= character then
        humanoid:EquipTool(tool)
    end
    notify("\u{1F331} Go to your farm and tap the soil to plant!", Color3.fromRGB(150, 230, 150))
end

-------- Pack opening animation --------

local function tween(inst, props, time, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- Card border tint from the pack's roll chance (lower chance = rarer feel)
local function rarityColor(chance)
    if typeof(chance) ~= "number" then return Color3.fromRGB(180, 220, 180) end
    if chance >= 50 then return Color3.fromRGB(180, 220, 180) end
    if chance >= 20 then return Color3.fromRGB(120, 185, 250) end
    if chance >= 5 then return Color3.fromRGB(195, 145, 250) end
    return Color3.fromRGB(255, 210, 90)
end

--[[
Shows an animated "tap to open" reveal for a purchased pack:
closed pack -> shake -> burst -> one card per seed (rarest last),
then a Nice! button. Works with mouse and touch.
@param pack table -- Local pack definition (id, visual, display_name).
@param results table -- Seed ids rolled by the server.
]]
function SeedShop._showPackReveal(pack, results, onRevealed)
    -- The seeds and their Tools already exist (the server saves and mirrors them at once).
    -- Only the Roblox hotbar is hidden on this client while the reveal is on screen, so it
    -- can't spoil the result. finishReveal() is the one way back: last card shown, reveal
    -- closed early, shop closed / walked away, or the overlay destroyed any other way.
    local finished = false
    local function finishReveal()
        if finished then return end
        finished = true
        SeedShop._setHotbarHidden(false)
        task.spawn(function()
            -- one normal rebuild from the saved seed_inventory, then refresh the shop list
            pcall(Network.Remote.Invoke, "S_SeedTools_Refresh")
            if onRevealed then
                onRevealed()
            end
        end)
    end
    local release = finishReveal
    if not gui or revealing then
        release()
        return
    end
    SeedShop._setHotbarHidden(true)
    revealing = true

    -- group duplicates and reveal rarest last
    local counts = {}
    local order = {}
    for _, seedId in ipairs(results) do
        if counts[seedId] == nil then
            counts[seedId] = 0
            table.insert(order, seedId)
        end
        counts[seedId] += 1
    end
    local packDef = SeedPacks.getPack(pack.id)
    local chanceOf = {}
    for _, entry in ipairs(packDef and packDef.entries or {}) do
        chanceOf[entry.seed_id] = entry.chance
    end
    table.sort(order, function(a, b)
        return (chanceOf[a] or 0) > (chanceOf[b] or 0)
    end)

    -- modal overlay (drawn above the window because it is a later sibling)
    local overlay = Instance.new("TextButton")
    overlay.Name = "PackReveal"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.35
    overlay.Text = ""
    overlay.AutoButtonColor = false
    overlay.Parent = gui
    overlay.Destroying:Connect(release)
    overlay.AncestryChanged:Connect(function()
        if not overlay:IsDescendantOf(game) then
            release()
        end
    end)

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 420, 0, 380)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.BackgroundColor3 = Color3.fromRGB(250, 245, 235)
    panel.Parent = overlay
    corner(panel, 16)
    stroke(panel, Color3.fromRGB(125, 85, 55), 3, true)

    makeLabel(panel, "\u{1F381} " .. (pack.display_name or "Seed Pack"), {
        size = UDim2.new(1, 0, 0, 34),
        pos = UDim2.new(0, 0, 0, 10),
        color = Color3.fromRGB(70, 50, 30),
    })

    -- closed pack stage: tap to open
    local packStage = Instance.new("TextButton")
    packStage.Name = "PackStage"
    packStage.Size = UDim2.new(0, 160, 0, 210)
    packStage.Position = UDim2.new(0.5, 0, 0.5, 16)
    packStage.AnchorPoint = Vector2.new(0.5, 0.5)
    packStage.BackgroundColor3 = Color3.fromRGB(255, 245, 220)
    packStage.Text = ""
    packStage.AutoButtonColor = true
    packStage.Parent = panel
    corner(packStage, 12)
    stroke(packStage, Color3.fromRGB(200, 195, 180), 2, true)
    addSeedPreview(packStage, pack.visual or "starter_pack", 52, 46, 56, 56)
    makeLabel(packStage, "\u{1F446} Tap to open!", {
        size = UDim2.new(1, 0, 0, 26),
        pos = UDim2.new(0, 0, 1, -32),
        color = Color3.fromRGB(95, 65, 40),
    })
    local stageScale = Instance.new("UIScale")
    stageScale.Parent = packStage

    local function finish()
        if overlay.Parent then
            overlay:Destroy()
        end
        revealing = false
    end

    packStage.MouseButton1Click:Connect(function()
        if not packStage.Active then return end
        packStage.Active = false
        pcall(function() Audio.Play({name = "UI_Open"}) end)
        task.spawn(function()
            -- shake the pack
            for i = 1, 3 do
                if not panel.Parent then return end
                tween(packStage, {Rotation = 8}, 0.06)
                task.wait(0.07)
                tween(packStage, {Rotation = -8}, 0.06)
                task.wait(0.07)
                pcall(function() Audio.Play({name = "Plop1", speed = 0.8 + i * 0.15}) end)
            end
            if not panel.Parent then return end
            packStage.Rotation = 0
            -- burst: implode the pack
            tween(stageScale, {Scale = 0.01}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            task.wait(0.2)
            if not panel.Parent then return end
            packStage.Visible = false

            -- seed cards, rarest last
            local cards = Instance.new("Frame")
            cards.Name = "Cards"
            cards.Size = UDim2.new(1, -24, 1, -116)
            cards.Position = UDim2.new(0, 12, 0, 100)
            cards.BackgroundTransparency = 1
            cards.Parent = panel
            local grid = Instance.new("UIGridLayout")
            grid.CellSize = UDim2.new(0, 104, 0, 128)
            grid.CellPadding = UDim2.new(0, 10, 0, 10)
            grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
            grid.VerticalAlignment = Enum.VerticalAlignment.Center
            grid.Parent = cards

            for i, seedId in ipairs(order) do
                if not panel.Parent then return end
                local seed = SeedPacks.getSeed(seedId)
                local displayName = (seed and seed.display_name) or seedId:gsub("_", " "):gsub("^%l", string.upper)
                local chance = chanceOf[seedId]

                local card = Instance.new("Frame")
                card.Name = "Card_" .. seedId
                card.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
                card.Parent = cards
                corner(card, 12)
                stroke(card, rarityColor(chance), 3, true)
                local scale = Instance.new("UIScale")
                scale.Scale = 0
                scale.Parent = card

                addSeedPreview(card, (seed and seed.visual) or seedId, 24, 8, 56, 56)
                makeLabel(card, displayName, {
                    size = UDim2.new(1, 0, 0, 22),
                    pos = UDim2.new(0, 0, 0, 68),
                    color = Color3.fromRGB(50, 100, 50),
                })
                if counts[seedId] > 1 then
                    makeLabel(card, "x" .. counts[seedId], {
                        size = UDim2.new(1, 0, 0, 18),
                        pos = UDim2.new(0, 0, 0, 92),
                        color = Color3.fromRGB(120, 140, 120),
                        font = Enum.Font.GothamMedium,
                    })
                end
                if typeof(chance) == "number" and chance < 5 then
                    makeLabel(card, "\u{2B50}", {
                        size = UDim2.new(1, 0, 0, 16),
                        pos = UDim2.new(0, 0, 1, -18),
                        color = Color3.fromRGB(255, 200, 60),
                    })
                end

                tween(scale, {Scale = 1}, 0.35, Enum.EasingStyle.Back)
                pcall(function() Audio.Play({name = "Plop1", speed = 0.9 + i * 0.12}) end)
                task.wait(0.35)
            end
            if not panel.Parent then return end

            -- every seed is on screen now: the new Tools and counts can appear
            release()

            -- done: let the player admire their seeds
            pcall(function() Audio.Play({name = "Reward1"}) end)
            local doneBtn = makeButton(panel, "\u{1F389} Nice!", Color3.fromRGB(80, 180, 80), Color3.fromRGB(255, 255, 255))
            doneBtn.Size = UDim2.new(0, 140, 0, 42)
            doneBtn.AnchorPoint = Vector2.new(0.5, 1)
            doneBtn.Position = UDim2.new(0.5, 0, 1, -12)
            doneBtn.MouseButton1Click:Connect(finish)
            overlay.MouseButton1Click:Connect(finish)
        end)
    end)
end

-- Check distance to Seed Shop NPC (auto-close if too far)
local function isNearSeedShop()
    local map = workspace:FindFirstChild("__MAP")
    local village = map and map:FindFirstChild("Village")
    local shops = village and village:FindFirstChild("Shops")
    local shop = shops and shops:FindFirstChild("Seed Shop")
    local npc = shop and shop:FindFirstChild("Gardener_Seed")
    local npcPart = (npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc:FindFirstChildWhichIsA("BasePart"))) or (shop and shop:FindFirstChildWhichIsA("BasePart", true))
    if not npcPart then return false end
    local player = Players.LocalPlayer
    local char = player and player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return (root.Position - npcPart.Position).Magnitude <= 16
end

-- Build the entire UI
local function buildUI()
    if gui then return end

    gui = Instance.new("ScreenGui")
    gui.Name = "SeedShop"
    gui.DisplayOrder = 8
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Enabled = false
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

    -- Backdrop (dim background, click to close)
    local backdrop = Instance.new("TextButton")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.4
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.Parent = gui

    backdrop.MouseButton1Click:Connect(closeShop)

    -- Window
    window = Instance.new("Frame")
    window.Name = "Window"
    window.Size = UDim2.new(0, 460, 0, 540)
    window.Position = UDim2.new(0.5, 0, 0.5, 0)
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.BackgroundColor3 = Color3.fromRGB(250, 245, 235)
    window.Parent = gui
    corner(window, 16)
    stroke(window, Color3.fromRGB(125, 85, 55), 3, true)

    -- UIScale for mobile responsiveness
    local scale = Instance.new("UIScale")
    scale.Scale = 1
    scale.Parent = window

    local function updateScale()
        local viewport = workspace.CurrentCamera.ViewportSize
        window.Size = UDim2.fromOffset(math.min(560, viewport.X - 32), math.min(580, viewport.Y - 24))
        scale.Scale = 1
    end
    updateScale()
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

    -- Header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 56)
    header.BackgroundColor3 = Color3.fromRGB(150, 105, 65)
    header.Parent = window
    corner(header, 16)

    -- Mask bottom corners of header
    local headerMask = Instance.new("Frame")
    headerMask.Size = UDim2.new(1, 0, 0, 20)
    headerMask.Position = UDim2.new(0, 0, 1, -10)
    headerMask.BackgroundColor3 = Color3.fromRGB(150, 105, 65)
    headerMask.BorderSizePixel = 0
    headerMask.Parent = header

    -- Wooden plank seams across the header (hand-made sign feel)
    for i = 1, 3 do
        local seam = Instance.new("Frame")
        seam.Name = "PlankSeam" .. i
        seam.Size = UDim2.new(1, 0, 0, 2)
        seam.Position = UDim2.new(0, 0, 0, 12 + i * 12)
        seam.BackgroundColor3 = Color3.fromRGB(125, 88, 52)
        seam.BorderSizePixel = 0
        seam.BackgroundTransparency = 0.35
        seam.Parent = header
    end

    -- Sprouting leaf accents on the window's top corners (FruitBound signature)
    for _, xDir in ipairs({-1, 1}) do
        local leaf = Instance.new("Frame")
        leaf.Name = "WindowLeaf" .. (xDir < 0 and "L" or "R")
        leaf.Size = UDim2.new(0, 18, 0, 18)
        leaf.AnchorPoint = Vector2.new(0.5, 0.5)
        leaf.Position = UDim2.new(if xDir < 0 then 0 else 1, xDir * 14, 0, -4)
        leaf.BackgroundColor3 = Color3.fromRGB(120, 200, 100)
        leaf.Rotation = 45 + (xDir < 0 and -8 or 8)
        leaf.BorderSizePixel = 0
        leaf.Parent = window
        corner(leaf, 5)
        stroke(leaf, Color3.fromRGB(80, 150, 70), 2, true)
    end

    local title = makeLabel(header, "\u{1F331} Seed Shop", {
        size = UDim2.new(1, -204, 1, 0),
        pos = UDim2.new(0, 16, 0, 0),
        color = Color3.fromRGB(255, 246, 220),
        xAlign = Enum.TextXAlignment.Left,
    })

    -- Coins display
    local coinFrame = Instance.new("Frame")
    coinFrame.Size = UDim2.new(0, 130, 0, 34)
    coinFrame.AnchorPoint = Vector2.new(1, 0.5)
    coinFrame.Position = UDim2.new(1, -60, 0.5, 0)
    coinFrame.BackgroundColor3 = Color3.fromRGB(255, 240, 200)
    coinFrame.Parent = header
    corner(coinFrame, 8)
    stroke(coinFrame, Color3.fromRGB(200, 170, 80), 2, true)

    coinsLabel = Instance.new("TextLabel")
    coinsLabel.Name = "CoinsLabel"
    coinsLabel.Font = Enum.Font.FredokaOne
    coinsLabel.TextScaled = true
    coinsLabel.TextColor3 = Color3.fromRGB(120, 90, 30)
    coinsLabel.BackgroundTransparency = 1
    coinsLabel.Size = UDim2.new(1, -8, 1, -4)
    coinsLabel.Position = UDim2.new(0, 4, 0, 2)
    coinsLabel.Text = "\u{1F4B0} 0 Coins"
    coinsLabel.Parent = coinFrame
    pad(coinFrame, 4)

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "Close"
    closeBtn.Size = UDim2.new(0, 44, 0, 44)
    closeBtn.AnchorPoint = Vector2.new(1, 0.5)
    closeBtn.Position = UDim2.new(1, -8, 0.5, 0)
    closeBtn.Font = Enum.Font.FredokaOne
    closeBtn.TextScaled = true
    closeBtn.Text = "\u{2716}"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 60)
    closeBtn.AutoButtonColor = true
    closeBtn.Parent = header
    corner(closeBtn, 8)

    closeBtn.MouseButton1Click:Connect(closeShop)

    -- Content area (scrolling)
    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 1, -64)
    content.Position = UDim2.new(0, 8, 0, 60)
    content.BackgroundColor3 = Color3.fromRGB(250, 245, 235)
    content.ScrollBarThickness = 6
    content.ScrollBarImageColor3 = Color3.fromRGB(180, 170, 140)
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Parent = window

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content
    pad(content, 8)

    -- Section: Seed Packs
    local packHeader = makeLabel(content, "\u{1F4E6} Seed Packets", {
        size = UDim2.new(1, 0, 0, 24),
        color = Color3.fromRGB(125, 85, 55),
        xAlign = Enum.TextXAlignment.Left,
    })

    packContainer = Instance.new("Frame")
    packHeader.LayoutOrder = 1
    packContainer.LayoutOrder = 2
    packContainer.Name = "PackContainer"
    packContainer.Size = UDim2.new(1, 0, 0, 0)
    packContainer.AutomaticSize = Enum.AutomaticSize.Y
    packContainer.BackgroundTransparency = 1
    packContainer.Parent = content

    local packLayout = Instance.new("UIListLayout")
    packLayout.Padding = UDim.new(0, 6)
    packLayout.SortOrder = Enum.SortOrder.LayoutOrder
    packLayout.Parent = packContainer

    -- Section: My Seeds
    local seedHeader = makeLabel(content, "\u{1F33E} My Seeds", {
        size = UDim2.new(1, 0, 0, 24),
        color = Color3.fromRGB(125, 85, 55),
        xAlign = Enum.TextXAlignment.Left,
    })

    seedContainer = Instance.new("Frame")
    seedHeader.LayoutOrder = 3
    seedContainer.LayoutOrder = 4
    seedContainer.Name = "SeedContainer"
    seedContainer.Size = UDim2.new(1, 0, 0, 0)
    seedContainer.AutomaticSize = Enum.AutomaticSize.Y
    seedContainer.BackgroundTransparency = 1
    seedContainer.Parent = content

    local seedLayout = Instance.new("UIListLayout")
    seedLayout.Padding = UDim.new(0, 6)
    seedLayout.Parent = seedContainer

end

-------- Module lifecycle --------

function SeedShop._init()
    Network = _L.Get {"Common", "Library", "Network"}
    Audio = _L.Get {"Common", "Library", "Audio"}
    NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
    Data = _L.Get {"Client", "Library", "Classes", "Data"}
    UI = _L.Get {"Client", "Modules", "UI"}
    SeedPacks = _L.Get {"Common", "Modules", "Databases", "SeedPacks"}
end

function SeedShop._start()
    buildUI()

    -- never leave the hotbar hidden after a respawn (reset during a pack reveal)
    Players.LocalPlayer.CharacterAdded:Connect(function()
        SeedShop._setHotbarHidden(false)
    end)

    -- Open shop when server fires C_SeedShop_Open
    Network.Remote.Fired("C_SeedShop_Open", function()
        openShop()
    end)

    -- Update coins when balance changes
    playerData = Data.Await()
    if playerData then
        playerData:Bind({"stats", "Strength"}, function(coins)
            if coinsLabel then
                coinsLabel.Text = "\u{1F4B0} " .. short(coins) .. " Coins"
            end
            for _, card in ipairs(packContainer:GetChildren()) do
                local buy = card:FindFirstChild("Buy")
                local price = buy and buy:GetAttribute("PackPrice")
                if price then
                    buy.BackgroundColor3 = if coins >= price then Color3.fromRGB(80, 180, 80) else Color3.fromRGB(160, 160, 160)
                end
            end
        end)
    end

    -- Close when another UI opens
    if UI and UI._current then
        UI._current:Bind(function()
            if isOpen then
                closeShop()
            end
        end)
    end

    -- Auto-close loop: check distance every 0.5s while open
    task.spawn(function()
        while task.wait(0.5) do
            if isOpen and not isNearSeedShop() then
                closeShop()
            end
        end
    end)
end

SeedShop.Open = openShop
SeedShop.Close = closeShop

return SeedShop