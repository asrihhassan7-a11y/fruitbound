-- // VARIABLES // --
local _L = _G._L

local Network

local Daycare = {}
local panel
local availableFrame
local slotsFrame

-- // FUNCTIONS // --

--[[
Creates a rounded interface element.
@param className string -- Roblox UI class.
@param parent Instance -- Parent interface object.
@return GuiObject -- Created interface object.
]]
local function create(className, parent)
    local object = Instance.new(className)
    object.Parent = parent
    if object:IsA("GuiObject") and className ~= "TextLabel" then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 14)
        corner.Parent = object
    end
    return object
end

--[[
Creates a readable Daycare action button.
@param parent Instance -- Parent interface object.
@param text string -- Button label.
@return TextButton -- Created button.
]]
local function button(parent, text)
    local object = create("TextButton", parent)
    object.BackgroundColor3 = Color3.fromRGB(232, 137, 165)
    object.Font = Enum.Font.FredokaOne
    object.Text = text
    object.TextColor3 = Color3.new(1, 1, 1)
    object.TextScaled = true
    return object
end

--[[
Clears generated interface rows.
@param parent Instance -- Container to clear.
]]
local function clear(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

--[[
Shows a short local Daycare message.
@param text string -- Message text.
]]
local function notify(text)
    local Notifications = _L.Get {"Client", "Modules", "UI", "Notifications"}
    if Notifications then
        Notifications:add({text = text, color = Color3.fromRGB(245, 155, 185)})
    end
end

--[[
Refreshes available Fruits and occupied Daycare slots.
]]
local function refresh()
    local state = Network.Remote.Invoke("S_Daycare_Get")
    if not state then
        return
    end
    clear(availableFrame)
    clear(slotsFrame)
    for _, fruit in ipairs(state.available or {}) do
        local add = button(availableFrame, fruit.name .. "\nAdd to Daycare")
        add.Size = UDim2.new(1, -8, 0, 56)
        add.Activated:Connect(function()
            local success, reason = Network.Remote.Invoke("S_Daycare_Put", fruit.uid)
            if success then
                notify(fruit.name .. " joined Daycare!")
                refresh()
            elseif reason == "full" then
                notify("All Daycare slots are full.")
            else
                notify("That Fruit is not available.")
            end
        end)
    end
    if #(state.available or {}) == 0 then
        local empty = create("TextLabel", availableFrame)
        empty.Size = UDim2.new(1, -8, 0, 56)
        empty.BackgroundTransparency = 1
        empty.Font = Enum.Font.FredokaOne
        empty.Text = "Unequip a Fruit to add it."
        empty.TextColor3 = Color3.fromRGB(95, 70, 80)
        empty.TextScaled = true
    end
    for slotIndex = 1, state.max_slots do
        local slot = state.slots[tostring(slotIndex)]
        local card = create("Frame", slotsFrame)
        card.Size = UDim2.new(1, -8, 0, 82)
        card.BackgroundColor3 = Color3.fromRGB(250, 216, 225)
        local label = create("TextLabel", card)
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(8, 4)
        label.Size = UDim2.new(0.55, -8, 1, -8)
        label.Font = Enum.Font.FredokaOne
        label.TextColor3 = Color3.fromRGB(95, 60, 75)
        label.TextScaled = true
        label.TextWrapped = true
        label.Text = slot and (slot.fruit_name .. "\n" .. slot.reward .. " Coins ready") or ("Slot " .. slotIndex .. "\nEmpty")
        if slot then
            local claim = button(card, "Claim")
            claim.Position = UDim2.new(0.57, 0, 0, 7)
            claim.Size = UDim2.new(0.2, -4, 1, -14)
            claim.BackgroundColor3 = Color3.fromRGB(90, 180, 100)
            claim.Activated:Connect(function()
                local success, result = Network.Remote.Invoke("S_Daycare_Claim", slotIndex)
                if success then
                    notify("Claimed " .. result .. " Coins!")
                elseif result == "wait" then
                    notify("Your Fruit is still playing.")
                end
                refresh()
            end)
            local remove = button(card, "Remove")
            remove.Position = UDim2.new(0.78, 0, 0, 7)
            remove.Size = UDim2.new(0.21, -7, 1, -14)
            remove.BackgroundColor3 = Color3.fromRGB(135, 120, 155)
            remove.Activated:Connect(function()
                local success = Network.Remote.Invoke("S_Daycare_Remove", slotIndex)
                if success then
                    notify("Fruit returned to your inventory.")
                    refresh()
                end
            end)
        end
    end
end

--[[
Shows the Daycare interface.
]]
local function open()
    panel.Visible = true
    panel.Parent.Open.Visible = false
    local seeds = _L.PlayerGui:FindFirstChild("SeedGarden")
    if seeds and seeds:FindFirstChild("Open") then
        seeds.Open.Visible = false
    end
    refresh()
end

--[[
Builds the responsive Daycare interface.
]]
local function build()
    local gui = Instance.new("ScreenGui")
    gui.Name = "Daycare"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 23
    gui.Parent = _L.PlayerGui

    local openButton = button(gui, "Daycare")
    openButton.Name = "Open"
    openButton.AnchorPoint = Vector2.new(0, 1)
    openButton.Position = UDim2.new(0, 120, 1, -84)
    openButton.Size = UDim2.fromOffset(104, 52)
    openButton.Activated:Connect(open)

    panel = create("Frame", gui)
    panel.Name = "Panel"
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0.86, 0, 0.76, 0)
    panel.BackgroundColor3 = Color3.fromRGB(255, 242, 226)
    panel.Visible = false
    local constraint = Instance.new("UISizeConstraint")
    constraint.MaxSize = Vector2.new(680, 450)
    constraint.MinSize = Vector2.new(330, 235)
    constraint.Parent = panel

    local title = create("TextLabel", panel)
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(18, 8)
    title.Size = UDim2.new(1, -76, 0, 42)
    title.Font = Enum.Font.FredokaOne
    title.Text = "Fruit Daycare"
    title.TextColor3 = Color3.fromRGB(180, 86, 120)
    title.TextScaled = true

    local close = button(panel, "X")
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.new(1, -10, 0, 10)
    close.Size = UDim2.fromOffset(46, 46)
    close.BackgroundColor3 = Color3.fromRGB(238, 93, 105)
    close.Activated:Connect(function()
        panel.Visible = false
        gui.Open.Visible = true
        local seeds = _L.PlayerGui:FindFirstChild("SeedGarden")
        if seeds and seeds:FindFirstChild("Open") then
            seeds.Open.Visible = true
        end
    end)

    availableFrame = create("ScrollingFrame", panel)
    availableFrame.Position = UDim2.new(0, 14, 0, 58)
    availableFrame.Size = UDim2.new(0.42, -20, 1, -72)
    availableFrame.BackgroundColor3 = Color3.fromRGB(238, 220, 195)
    availableFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    availableFrame.CanvasSize = UDim2.new()
    availableFrame.ScrollBarThickness = 8
    local availableLayout = Instance.new("UIListLayout")
    availableLayout.Padding = UDim.new(0, 8)
    availableLayout.Parent = availableFrame

    slotsFrame = create("ScrollingFrame", panel)
    slotsFrame.Position = UDim2.new(0.42, 4, 0, 58)
    slotsFrame.Size = UDim2.new(0.58, -18, 1, -72)
    slotsFrame.BackgroundColor3 = Color3.fromRGB(245, 226, 232)
    slotsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    slotsFrame.CanvasSize = UDim2.new()
    slotsFrame.ScrollBarThickness = 8
    local slotsLayout = Instance.new("UIListLayout")
    slotsLayout.Padding = UDim.new(0, 8)
    slotsLayout.Parent = slotsFrame
end

--[[
Loads Daycare interface dependencies.
]]
function Daycare._init()
    Network = _L.Get {"Common", "Library", "Network"}
end

--[[
Starts Daycare UI interactions.
]]
function Daycare._start()
    build()
    Network.Remote.Fired("C_Daycare_Open", open)
    _L.Player.CharacterAdded:Connect(function()
        panel.Visible = false
        panel.Parent.Open.Visible = true
        local seeds = _L.PlayerGui:FindFirstChild("SeedGarden")
        if seeds and seeds:FindFirstChild("Open") then
            seeds.Open.Visible = true
        end
    end)
end

-- // INITIALIZATION // --
return Daycare
