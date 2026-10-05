--> GearVisual (server)
-- Shows the equipped Gear (data "gears".equipped, Databases.Gears) as a small model in the player's
-- right hand. Purely visual: gear ownership / effects stay in GearUtility. Rebuilt on equip/unequip
-- and on respawn. Everything is welded to the hand, non-colliding and massless.

local _L = _G._L
local Players = game:GetService("Players")

local Network
local GearUtility

local GearVisual = {}

local rgb = Color3.fromRGB

local function part(model, name, size, cf, color, shape, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
	p.Anchored = true
	p.Parent = model
	return p
end

-- models are built around the grip point (0,0,0) = inside the fist; -Z = forward, +Y = up
local BUILDERS = {
	watering_can = function(m, info)
		local c = info.color or rgb(100, 180, 255)
		part(m, "Handle", Vector3.new(0.25, 0.25, 0.9), CFrame.new(0, 0, 0), c:Lerp(rgb(40, 40, 40), 0.3))
		part(m, "Body", Vector3.new(1, 0.9, 1), CFrame.new(0, -0.65, -0.1) * CFrame.Angles(0, 0, math.rad(90)), c, Enum.PartType.Cylinder)
		part(m, "Spout", Vector3.new(0.18, 0.18, 1), CFrame.new(0, -0.35, -0.85) * CFrame.Angles(math.rad(-35), 0, 0), c)
		part(m, "Rose", Vector3.new(0.22, 0.32, 0.32), CFrame.new(0, -0.08, -1.25) * CFrame.Angles(0, math.rad(90), math.rad(90)), c:Lerp(rgb(255, 255, 255), 0.3), Enum.PartType.Cylinder)
	end,
	shears = function(m, info)
		part(m, "Handle", Vector3.new(0.3, 0.3, 0.7), CFrame.new(0, 0, 0.1), rgb(90, 170, 90))
		part(m, "Handle2", Vector3.new(0.3, 0.3, 0.7), CFrame.new(0.28, 0, 0.1), rgb(90, 170, 90))
		part(m, "Blade", Vector3.new(0.08, 0.25, 1.1), CFrame.new(0.08, 0, -0.75) * CFrame.Angles(0, math.rad(6), 0), rgb(210, 215, 225), nil, Enum.Material.Metal)
		part(m, "Blade2", Vector3.new(0.08, 0.25, 1.1), CFrame.new(0.2, 0, -0.75) * CFrame.Angles(0, math.rad(-6), 0), rgb(210, 215, 225), nil, Enum.Material.Metal)
	end,
	basket = function(m, info)
		part(m, "Handle", Vector3.new(0.2, 0.9, 0.2), CFrame.new(0, 0.1, 0), rgb(150, 105, 60), nil, Enum.Material.Wood)
		part(m, "Body", Vector3.new(1.2, 0.7, 1.2), CFrame.new(0, -0.65, 0), rgb(200, 150, 90), nil, Enum.Material.Wood)
		part(m, "Rim", Vector3.new(1.3, 0.12, 1.3), CFrame.new(0, -0.3, 0), rgb(160, 110, 60), nil, Enum.Material.Wood)
		part(m, "Apple", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0.2, -0.2, 0.1), rgb(230, 60, 60), Enum.PartType.Ball)
		part(m, "Pear", Vector3.new(0.4, 0.4, 0.4), CFrame.new(-0.25, -0.22, -0.15), rgb(250, 200, 70), Enum.PartType.Ball)
	end,
	spray = function(m, info)
		part(m, "Handle", Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, 0, 0), rgb(240, 240, 240))
		part(m, "Bottle", Vector3.new(0.9, 0.55, 0.55), CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)), info.color or rgb(180, 255, 180), Enum.PartType.Cylinder)
		part(m, "Nozzle", Vector3.new(0.2, 0.2, 0.45), CFrame.new(0, 1.05, -0.2), rgb(90, 170, 90))
	end,
}

local function characterHand(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

function GearVisual.refresh(player, gearId)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("GearVisual")
	if old then
		old:Destroy()
	end
	local heldTool = character:FindFirstChildWhichIsA("Tool")
	if heldTool and heldTool:GetAttribute("FruitBoundGear") then
		return
	end
	local info = gearId and GearUtility.getInfo(gearId)
	local hand = characterHand(character)
	if not info or not hand then
		return
	end
	local build = BUILDERS[info.type] or BUILDERS.watering_can
	local model = Instance.new("Model")
	model.Name = "GearVisual"
	model:SetAttribute("GearId", gearId)
	build(model, info)
	local handle = model:FindFirstChild("Handle")
	model.PrimaryPart = handle
	-- grip: in the fist, pointing forward
	local grip = hand:FindFirstChild("RightGripAttachment")
	local gripCf = if grip then hand.CFrame * grip.CFrame else hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)
	model:PivotTo(gripCf * CFrame.Angles(math.rad(-90), 0, 0))
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local w = Instance.new("WeldConstraint")
			w.Part0 = hand
			w.Part1 = p
			w.Parent = p
			p.Anchored = false
		end
	end
	model.Parent = character
end

local function watch(player)
	task.spawn(function()
		local client
		for _ = 1, 60 do
			local ok, c = pcall(Network.Bindable.Invoke, "S_Client_Get", player)
			if ok and c and c.data then
				client = c
				break
			end
			task.wait(1)
		end
		if not client then
			return
		end
		local function current()
			return GearUtility.getEquipped(client.data)
		end
		client.data:Bind("gears", function()
			GearVisual.refresh(player, current())
		end)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			task.wait(0.5)
			GearVisual.refresh(player, current())
		end)
		GearVisual.refresh(player, current())
	end)
end

function GearVisual._init()
	Network = _L.Get {"Common", "Library", "Network"}
	GearUtility = _L.Get {"Common", "Modules", "Utilities", "GearUtility"}
end

function GearVisual._start()
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
end

return GearVisual
