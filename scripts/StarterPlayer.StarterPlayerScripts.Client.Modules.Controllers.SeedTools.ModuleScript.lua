---> SeedTools (client)
-- The server mirrors owned seeds into Backpack Tools. Equip one and click (mouse) or tap
-- (touch) the soil on YOUR farm to plant it exactly there. While a Seed Tool is equipped a
-- small disc previews the spot: green = it can be planted, red = it can't (not your soil,
-- locked land, too close to another crop, too far away).
-- The preview is only a hint: the server (FarmingV2 S_Seed_Plant) checks everything again
-- before a Seed is spent.

local _L = _G._L

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Network
local Audio
local FarmUpgrades

-- must match FarmingV2 (server)
local PLANT_DISTANCE = 30 -- studs from your character
local MIN_SPACING = 4.5 -- studs between crops
local EDGE_MARGIN = 2 -- studs inside the soil bed edges
local AIM_RANGE = 120 -- ray length from the camera

local VALID = Color3.fromRGB(110, 230, 110)
local INVALID = Color3.fromRGB(240, 80, 70)

local ERRORS = {
	invalid = "Invalid request. Try again!",
	distance = "Get closer to that spot to plant!",
	ownership = "You don't have that seed anymore!",
	occupied = "Too close to another crop!",
	soil = "Plant on the soil of your own farm!",
	locked = "That land is locked! Unlock it on your farm first.",
	full = "Your farm is full of crops! Harvest some first.",
}

local SeedTools = {}

local connections = {} -- [Tool] = {Activated, Equipped, Unequipped}
local equipHintShown = {} -- [seedId] = true
local lastUse = 0
local lastTouch = nil -- {position = Vector2, t = os.clock()} for touch planting
local preview -- the green / red disc (local only)
local previewConnection -- RenderStepped, only while a Seed Tool is equipped
local equippedTool

local function notify(text, color)
	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		UI.Get("Notifications"):add({text = text, color = color or Color3.fromRGB(120, 230, 120), duration = 3})
	end)
end

local function playSound(name)
	pcall(function()
		Audio.Play({name = name})
	end)
end

-- the mature crop (HarvestBush) a part belongs to, if any
local function cropOf(instance)
	local node = instance
	while node and node ~= workspace do
		if node:IsA("Model") and CollectionService:HasTag(node, "HarvestBush") then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- What the pointer / tap is aiming at: RaycastResult or nil
local function aim(screenPosition)
	local camera = workspace.CurrentCamera
	if not camera or not screenPosition then
		return nil
	end
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	local ignore = {camera}
	if _L.Player.Character then
		table.insert(ignore, _L.Player.Character)
	end
	local debris = workspace:FindFirstChild("__DEBRIS")
	if debris then
		table.insert(ignore, debris)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	return workspace:Raycast(ray.Origin, ray.Direction * AIM_RANGE, params)
end

-- Same rules as the server. Returns ok, errorCode
local function check(result)
	if not result then
		return false, "soil"
	end
	local part = result.Instance
	if cropOf(part) then
		return false, "crop"
	end
	if not CollectionService:HasTag(part, "FarmSoil") then
		return false, "soil"
	end
	if part:GetAttribute("Owner") ~= _L.Player.UserId then
		return false, "soil"
	end
	-- keep away from the bed edges (soil beds are axis aligned with their plot); the plantable
	-- size is FarmUpgrades.soil, exactly what the server checks (a Greenhouse floor is bigger)
	local plantable = part.Size
	for _, info in ipairs(FarmUpgrades) do
		if info.id == part:GetAttribute("UpgradeId") and info.soil then
			plantable = info.soil
		end
	end
	local localPoint = part.CFrame:PointToObjectSpace(result.Position)
	if math.abs(localPoint.X) > plantable.X / 2 - EDGE_MARGIN or math.abs(localPoint.Z) > plantable.Z / 2 - EDGE_MARGIN then
		return false, "soil"
	end
	local root = _L.Player.Character and _L.Player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "invalid"
	end
	local flat = Vector3.new(root.Position.X - result.Position.X, 0, root.Position.Z - result.Position.Z).Magnitude
	if flat > PLANT_DISTANCE then
		return false, "distance"
	end
	for _, crop in ipairs(CollectionService:GetTagged("SeedCrop")) do
		if crop:GetAttribute("Owner") == _L.Player.UserId and crop:IsA("Model") then
			local p = crop:GetPivot().Position
			if Vector3.new(p.X - result.Position.X, 0, p.Z - result.Position.Z).Magnitude < MIN_SPACING then
				return false, "occupied"
			end
		end
	end
	return true
end

local function getPreview()
	if preview and preview.Parent then
		return preview
	end
	preview = Instance.new("Part")
	preview.Name = "SeedPlantPreview"
	preview.Shape = Enum.PartType.Cylinder
	preview.Size = Vector3.new(0.12, MIN_SPACING, MIN_SPACING)
	preview.Anchored = true
	preview.CanCollide = false
	preview.CanQuery = false
	preview.CanTouch = false
	preview.CastShadow = false
	preview.Material = Enum.Material.Neon
	preview.Transparency = 0.55
	preview.Parent = workspace.CurrentCamera
	return preview
end

local function hidePreview()
	if preview then
		preview.Transparency = 1
	end
end

-- where the player is pointing right now, in screen coordinates (same as the harvest click):
-- mouse; the last tap on touch; the screen centre on gamepad
local function pointerPosition()
	local last = UserInputService:GetLastInputType()
	local inset = game:GetService("GuiService"):GetGuiInset()
	if last == Enum.UserInputType.Touch then
		return lastTouch and lastTouch.position or nil
	end
	if last.Name:match("^Gamepad") then
		local size = workspace.CurrentCamera.ViewportSize
		return Vector2.new(size.X / 2, size.Y / 2) - inset
	end
	return UserInputService:GetMouseLocation() - inset
end

local function updatePreview()
	local result = aim(pointerPosition())
	if not result or not CollectionService:HasTag(result.Instance, "FarmSoil") then
		hidePreview()
		return
	end
	local ok = check(result)
	local disc = getPreview()
	disc.Color = if ok then VALID else INVALID
	disc.Transparency = 0.55
	disc.CFrame = CFrame.new(result.Position + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

local function stopPreview()
	if previewConnection then
		previewConnection:Disconnect()
		previewConnection = nil
	end
	hidePreview()
end

local function startPreview()
	stopPreview()
	previewConnection = RunService.RenderStepped:Connect(updatePreview)
end

-- Plants the equipped tool's seed where the player clicked / tapped.
local function plant(tool)
	local seedId = tool:GetAttribute("SeedId")
	if not seedId then
		return
	end

	-- client-side debounce; the server rate-limits independently
	local now = os.clock()
	if now - lastUse < 0.3 then
		return
	end
	lastUse = now

	local result = aim(pointerPosition())
	local ok, code = check(result)
	if code == "crop" then
		return -- tapping a mature crop harvests it (handled by the harvest click), never plants
	end
	if not ok then
		notify("\u{1F331} " .. (ERRORS[code] or "Can't plant there!"), Color3.fromRGB(255, 160, 60))
		playSound("Fail1")
		return
	end

	local callOk, success, errCode = pcall(Network.Remote.Invoke, "S_Seed_Plant", seedId, result.Position)
	if not callOk then
		notify("Connection error. Try again!", Color3.fromRGB(255, 120, 60))
		return
	end
	if success then
		playSound("Plop1")
	else
		local errorCode = typeof(errCode) == "string" and errCode or "invalid"
		notify("\u{1F331} " .. (ERRORS[errorCode] or "Could not plant there!"), Color3.fromRGB(255, 120, 60))
		playSound("Fail1")
	end
end

local function release(tool)
	local set = connections[tool]
	if set then
		for _, connection in pairs(set) do
			connection:Disconnect()
		end
		connections[tool] = nil
	end
	if equippedTool == tool then
		equippedTool = nil
		stopPreview()
	end
end

-- Wires one server-made seed Tool (mirrored from seed_inventory).
local function watchTool(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("SeedId") then
		return
	end
	if connections[tool] then
		return
	end
	connections[tool] = {
		Activated = tool.Activated:Connect(function()
			plant(tool)
		end),
		Equipped = tool.Equipped:Connect(function()
			equippedTool = tool
			startPreview()
			local seedId = tool:GetAttribute("SeedId")
			if not equipHintShown[seedId] then
				equipHintShown[seedId] = true
				notify("\u{1F331} Tap the soil on your farm to plant!", Color3.fromRGB(150, 230, 150))
			end
		end),
		Unequipped = tool.Unequipped:Connect(function()
			if equippedTool == tool then
				equippedTool = nil
				stopPreview()
			end
		end),
	}
	tool.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			release(tool)
		end
	end)
	tool.Destroying:Connect(function()
		release(tool)
	end)
end

local function watchContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		watchTool(child)
	end
	container.ChildAdded:Connect(watchTool)
end

-- true while the local player holds a Seed Tool (the harvest click leaves plain soil taps to planting)
function SeedTools.isHoldingSeed()
	local character = _L.Player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("SeedId") ~= nil
end

function SeedTools._init()
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	FarmUpgrades = _L.Get {"Common", "Modules", "Databases", "FarmUpgrades"}
end

function SeedTools._start()
	local player = _L.Player

	-- touch: remember where the finger went down (Tool.Activated has no position)
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = {position = Vector2.new(input.Position.X, input.Position.Y), t = os.clock()}
		end
	end)

	-- tools are equipped into the Character...
	player.CharacterAdded:Connect(watchContainer)
	if player.Character then
		watchContainer(player.Character)
	end

	-- ...and rest in the Backpack, which is recreated on every respawn
	local function onPlayerChild(child)
		if child:IsA("Backpack") then
			watchContainer(child)
		end
	end
	player.ChildAdded:Connect(onPlayerChild)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchContainer(backpack)
	end
end

return SeedTools
