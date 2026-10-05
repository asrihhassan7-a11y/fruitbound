-- // VARIABLES // --
local _L = _G._L

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GearUtility
local Network

local TOOL_ATTRIBUTE = "FruitBoundGear"
local ACTIVATE_RANGE = 18
local GearTools = {}
local states = {}
local IMPORTED_OFFSETS = {
	garden_shears = CFrame.new(0, 0.35, -0.2) * CFrame.Angles(0, math.rad(90), math.rad(10)),
	harvest_basket = CFrame.new(0, -0.65, 0) * CFrame.Angles(0, math.rad(90), 0),
	growth_spray = CFrame.new(0, 0.05, -0.15) * CFrame.Angles(0, math.rad(90), math.rad(-10)),
	watering_can = CFrame.new(0, -0.5, -0.05) * CFrame.Angles(0, math.rad(90), math.rad(-10)),
	golden_watering_can = CFrame.new(0, -0.45, -0.05) * CFrame.Angles(0, math.rad(90), math.rad(-10)),
}

-- // FUNCTIONS // --

--[[
Builds a recognizable physical tool from the existing Gear definition.
@param info table -- Gear configuration.
@return Tool -- Backpack tool.
]]
local function buildTool(info)
	local tool = Instance.new("Tool")
	tool.Name = info.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(TOOL_ATTRIBUTE, info.id)

	local importedFolder = ReplicatedStorage.Assets.Models:FindFirstChild("Gears")
	local importedTemplate = importedFolder and importedFolder:FindFirstChild(info.id)
	if importedTemplate and IMPORTED_OFFSETS[info.id] then
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.3, 1, 0.3)
		handle.Transparency = 1
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
		handle.Parent = tool

		local visual = importedTemplate:Clone()
		visual.Name = "ImportedVisual"
		visual:PivotTo(handle.CFrame * IMPORTED_OFFSETS[info.id])
		visual.Parent = tool
		for _, descendant in ipairs(visual:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
		tool.Grip = CFrame.new(0, -0.25, 0) * CFrame.Angles(math.rad(-20), 0, 0)
		return tool
	end

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.28, 1.15, 0.28)
	handle.Color = info.color or Color3.fromRGB(120, 180, 120)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "ToolHead"
	head.Size = if info.type == "shears" then Vector3.new(0.8, 0.16, 1.2) elseif info.type == "basket" then Vector3.new(1.3, 0.75, 1.1) else Vector3.new(0.85, 0.75, 0.85)
	head.Color = if info.type == "shears" then Color3.fromRGB(215, 220, 230) elseif info.type == "basket" then Color3.fromRGB(205, 150, 85) else (info.color or Color3.fromRGB(120, 180, 120))
	head.Material = if info.type == "shears" then Enum.Material.Metal elseif info.type == "basket" then Enum.Material.Wood else Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 0.8, -0.35)
	head.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head

	tool.Grip = CFrame.new(0, -0.25, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	return tool
end

--[[
Removes generated Gear tools from one container.
@param container Instance? -- Character or Backpack.
]]
local function clearTools(container)
	if not container then
		return
	end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute(TOOL_ATTRIBUTE) then
			child:Destroy()
		end
	end
end

--[[
Returns the existing server player controller.
@param player Player -- Tool owner.
@return table? -- Player controller.
]]
local function getController(player)
	local ok, client = pcall(Network.Bindable.Invoke, "S_Client_Get", player)
	return if ok and client then client.player_controller else nil
end

--[[
Connects a generated tool to the existing secure farming path.
@param player Player -- Tool owner.
@param tool Tool -- Generated tool.
@param gearId string -- Existing Gear identifier.
@param data table -- Existing profile data wrapper.
]]
local function connectTool(player, tool, gearId, data)
	tool.Equipped:Connect(function()
		if GearUtility.owns(data, gearId) then
			GearUtility.equip(data, gearId)
			task.defer(function()
				local character = player.Character
				local visual = character and character:FindFirstChild("GearVisual")
				if visual then
					visual:Destroy()
				end
			end)
		end
	end)
	tool.Unequipped:Connect(function()
		if GearUtility.getEquipped(data) == gearId then
			GearUtility.unequip(data)
		end
	end)
	tool.Activated:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if tool.Parent ~= character or not humanoid or humanoid.Health <= 0 or not GearUtility.owns(data, gearId) then
			return
		end
		local controller = getController(player)
		if controller then
			GearUtility.equip(data, gearId)
			controller:_power_click(nil, ACTIVATE_RANGE)
		end
	end)
end

--[[
Returns a stable key for the set of owned Gears.
@param data table -- Existing profile data wrapper.
@return string -- Sorted ownership key.
]]
local function ownershipKey(data)
	local ids = {}
	for _, info in ipairs(GearUtility.getOwned(data)) do
		table.insert(ids, info.id)
	end
	table.sort(ids)
	return table.concat(ids, "|")
end

--[[
Synchronizes saved Gear ownership into the Roblox Backpack.
@param player Player -- Tool owner.
@param data table -- Existing profile data wrapper.
]]
local function sync(player, data)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	clearTools(backpack)
	clearTools(player.Character)
	for _, info in ipairs(GearUtility.getOwned(data)) do
		local tool = buildTool(info)
		connectTool(player, tool, info.id, data)
		tool.Parent = backpack
	end
end

--[[
Begins Backpack synchronization for a player profile.
@param player Player -- Joining player.
]]
local function watch(player)
	task.spawn(function()
		local client
		for _ = 1, 60 do
			local ok, result = pcall(Network.Bindable.Invoke, "S_Client_Get", player)
			if ok and result and result.data then
				client = result
				break
			end
			task.wait(1)
		end
		if not client or not player.Parent then
			return
		end
		local lastOwnership
		local function syncOwnership()
			local currentOwnership = ownershipKey(client.data)
			if currentOwnership == lastOwnership then
				return
			end
			lastOwnership = currentOwnership
			sync(player, client.data)
		end
		states[player] = client.data:Bind("gears", syncOwnership)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			sync(player, client.data)
		end)
		syncOwnership()
	end)
end

--[[
Loads dependencies for Gear Tool synchronization.
]]
function GearTools._init()
	Network = _L.Get {"Common", "Library", "Network"}
	GearUtility = _L.Get {"Common", "Modules", "Utilities", "GearUtility"}
end

--[[
Starts server-side Gear Tool lifecycle management.
]]
function GearTools._start()
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

-- // INITIALIZATION // --
return GearTools
