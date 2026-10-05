--> Mount (server)
-- Ride one of your Fruits. Only Fruits with CanMount = true (Databases.Fruits.Fruits) can be mounted.
--  * S_Fruits_Mount(uid)  -> mount that fruit (or unmount if it is already your mount)
--  * S_Fruits_Unmount()   -> get off
-- Everything is checked here on the server: you must own the fruit, it must be CanMount,
-- ADMIN ONLY fruits need an admin (AdminUtility). One mount at a time.
-- The mount is welded under the character, so it follows every movement, and it is
-- removed automatically on death / respawn (it lives inside the character).
-- Dedicated MOUNTS (Databases.Mounts, owned via codes etc., data "mounts"):
--  * S_Mount_Equip(id)  -> equip (must own it) + ride it     * S_Mount_Unequip() -> unequip + get off
--  * S_Mount_Ride()     -> ride / get off your equipped mount (G key, DPad Up, 🐎 button)
-- Riders get the attribute "RidingMount" = id; the model has "MountId" so every client can animate its legs.
-- Admin chat commands:  !givemount  (get the Admin Test Mount)   !mount   !unmount

local _L = _G._L

local Network
local FruitUtility
local AdminUtility

local Players = game:GetService("Players")

local ADMIN_FRUIT = "Admin Test Mount"
local DEFAULT_HEIGHT = 6
local DEFAULT_SPEED = 8
local SIT_ANIM = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://2506281703",
	[Enum.HumanoidRigType.R6] = "rbxassetid://178130996",
}

---------->
local Mount = {
	_active = {}, -- [player] = {uid, model, hip, speed, track, humanoid, died}
}

local function getClient(player)
	local ok, client = pcall(Network.Bindable.Invoke, "S_Client_Get", player)
	return ok and client or nil
end

local function notify(player, text, color)
	Network.Remote.Fire("C_Notifications_Add", player, {text = text, color = color or Color3.fromRGB(120, 230, 120)})
end

-- Build the ridable model: the fruit's own model (Assets.Models.Fruits) scaled up,
-- or a simple round fruit if it has no model yet.
local function buildModel(info)
	local source = _L.Assets.Models.Fruits:FindFirstChild(info.model or info.name)
	local model
	if source then
		local copy = source:Clone()
		if copy:IsA("BasePart") then
			model = Instance.new("Model")
			copy.Parent = model
			model.PrimaryPart = copy
		else
			model = copy
		end
	else
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(4, 4, 4)
		body.Color = Color3.fromRGB(235, 70, 80)
		body.Material = Enum.Material.SmoothPlastic
		body.Parent = model
		local leaf = Instance.new("Part")
		leaf.Name = "Leaf"
		leaf.Size = Vector3.new(1.2, 0.3, 0.8)
		leaf.Color = Color3.fromRGB(90, 200, 90)
		leaf.CFrame = body.CFrame * CFrame.new(0.5, 2.1, 0) * CFrame.Angles(0, 0, math.rad(-20))
		leaf.Parent = model
		model.PrimaryPart = body
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end

	local _, size = model:GetBoundingBox()
	local height = info.mount_scale or DEFAULT_HEIGHT
	pcall(function()
		model:ScaleTo(model:GetScale() * height / math.max(size.Y, 0.1))
	end)

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			if d ~= model.PrimaryPart then
				local w = Instance.new("WeldConstraint")
				w.Part0 = model.PrimaryPart
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	model.Name = "FruitMount"
	return model
end

function Mount.isMounted(player)
	return Mount._active[player] ~= nil
end

function Mount.unmount(player)
	local state = Mount._active[player]
	if not state then
		return false
	end
	Mount._active[player] = nil
	player:SetAttribute("MountedFruit", nil)
	player:SetAttribute("RidingMount", nil)

	if state.died then
		state.died:Disconnect()
	end
	if state.track then
		pcall(function()
			state.track:Stop(0.2)
		end)
	end
	if state.model then
		state.model:Destroy()
	end
	local humanoid = state.humanoid
	if humanoid and humanoid.Parent and humanoid.Health > 0 then
		humanoid.HipHeight = math.max(0, humanoid.HipHeight - state.hip)
		if humanoid.WalkSpeed >= state.speed + 8 then
			humanoid.WalkSpeed -= state.speed
		end
	end
	return true
end

-- returns true, uid  |  false, reason ("missing", "cannot", "admin", "dead")
function Mount.mount(player, fruitUid)
	if typeof(fruitUid) ~= "string" then
		return false, "missing"
	end
	local client = getClient(player)
	local data = client and client.data
	if not data then
		return false, "missing"
	end

	-- ownership + validity
	local fruitData = FruitUtility.getData(data, fruitUid)
	if not fruitData then
		return false, "missing"
	end
	if fruitData.daycare then
		return false, "daycare"
	end
	local info = FruitUtility.getInfo(fruitData.name)
	if not info or info.CanMount ~= true then
		return false, "cannot"
	end
	if info.admin_only and not AdminUtility.isAdmin(player) then
		return false, "admin"
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return false, "dead"
	end

	-- only one mount at a time
	Mount.unmount(player)

	local model = buildModel(info)
	local bbox, size = model:GetBoundingBox()
	local height = size.Y
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local hip = height * 0.8
	-- put the fruit on the ground under the player, then lift the player on top of it
	local centerY = -(root.Size.Y / 2 + legs + humanoid.HipHeight + hip) + height / 2
	local pivotFromCenter = bbox:ToObjectSpace(model:GetPivot())
	-- mount_yaw (degrees, Fruits database) turns the model so its face looks forward
	local yaw = CFrame.Angles(0, math.rad(info.mount_yaw or 0), 0)
	model:PivotTo(root.CFrame * CFrame.new(0, centerY, 0) * yaw * pivotFromCenter)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "MountWeld"
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	model.Parent = character

	local speed = info.mount_speed or DEFAULT_SPEED
	humanoid.HipHeight += hip
	humanoid.WalkSpeed += speed

	local track
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local anim = Instance.new("Animation")
		anim.AnimationId = SIT_ANIM[humanoid.RigType] or SIT_ANIM[Enum.HumanoidRigType.R15]
		track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
	end)

	local state = {uid = fruitUid, model = model, hip = hip, speed = speed, track = track, humanoid = humanoid}
	-- removed on death (and the model dies with the character on respawn)
	state.died = humanoid.Died:Connect(function()
		Mount.unmount(player)
	end)
	Mount._active[player] = state
	player:SetAttribute("MountedFruit", fruitUid)
	return true, fruitUid
end

function Mount.toggle(player, fruitUid)
	local state = Mount._active[player]
	if state and state.uid == fruitUid then
		Mount.unmount(player)
		return true, nil
	end
	return Mount.mount(player, fruitUid)
end

------------------------------------------------------------ dedicated mounts
local MountUtility

-- ridable copy of Assets.Models.Mounts[info.model]; legs/neck/tail keep their Motor6Ds (animated on the clients)
local function buildMountModel(info)
	local folder = _L.Assets.Models:FindFirstChild("Mounts")
	local source = folder and folder:FindFirstChild(info.model or info.name)
	if not source or not source:IsA("Model") then
		return nil
	end
	local model = source:Clone()
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	end
	local jointed = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("JointInstance") and d.Part1 then
			jointed[d.Part1] = true
		elseif d:IsA("WeldConstraint") and d.Part1 then
			jointed[d.Part1] = true
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			if d ~= model.PrimaryPart and not jointed[d] then
				local w = Instance.new("WeldConstraint")
				w.Part0 = model.PrimaryPart
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	model.Name = "RideMount"
	model:SetAttribute("MountId", info.id)
	return model
end

-- returns true, id | false, reason ("invalid", "not_owned", "dead", "model")
function Mount.ride(player, id)
	local client = getClient(player)
	local data = client and client.data
	if not data then
		return false, "invalid"
	end
	local info = MountUtility.getInfo(id)
	if not info then
		return false, "invalid"
	end
	if not MountUtility.owns(data, id) then
		return false, "not_owned"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then
		return false, "dead"
	end
	local model = buildMountModel(info)
	if not model then
		return false, "model"
	end

	-- only one mount at a time (fruit or dedicated)
	Mount.unmount(player)

	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local groundOffset = root.Size.Y / 2 + legs + humanoid.HipHeight -- root center -> feet
	local seat = info.seat_height or model:GetAttribute("SeatHeight") or 4
	-- the rider's hips rest on the saddle: raise the humanoid so its root sits on the seat
	local hip = math.max(0, seat + 0.35 - (legs + humanoid.HipHeight))
	-- model origin (y = 0) on the ground under the player, facing where the player faces
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	local basis = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	local groundCf = basis * CFrame.new(0, -groundOffset - hip, 0)
	-- the source model is built with its origin (0,0,0) on the ground, facing -Z,
	-- so moving the clone by groundCf keeps every part (and Motor6D) in place
	model:PivotTo(groundCf * model:GetPivot())

	humanoid.HipHeight += hip
	-- the model was placed relative to the root's FINAL height (ground - hip); the weld keeps that
	-- offset, and the humanoid lifts itself (and the mount) by `hip` on the next physics step

	local weld = Instance.new("Weld")
	weld.Name = "MountWeld"
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.C0 = root.CFrame:ToObjectSpace(model.PrimaryPart.CFrame)
	weld.Parent = model.PrimaryPart
	model.Parent = character

	local speed = math.max(0, info.speed or 0)
	humanoid.WalkSpeed += speed

	local track
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local anim = Instance.new("Animation")
		anim.AnimationId = SIT_ANIM[humanoid.RigType] or SIT_ANIM[Enum.HumanoidRigType.R15]
		track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
	end)

	local state = {uid = "mount:" .. id, mount_id = id, model = model, hip = hip, speed = speed, track = track, humanoid = humanoid}
	state.died = humanoid.Died:Connect(function()
		Mount.unmount(player)
	end)
	Mount._active[player] = state
	player:SetAttribute("RidingMount", id)
	return true, id
end

function Mount.equip(player, id)
	local client = getClient(player)
	local data = client and client.data
	if not data then
		return false, "invalid"
	end
	local ok, err = MountUtility.equip(data, id)
	if not ok then
		return false, err
	end
	local rode, rideErr = Mount.ride(player, id)
	return true, if rode then "riding" else rideErr
end

function Mount.unequip(player)
	local client = getClient(player)
	local data = client and client.data
	if not data then
		return false
	end
	local state = Mount._active[player]
	if state and state.mount_id then
		Mount.unmount(player)
	end
	return MountUtility.unequip(data)
end

-- ride / get off the equipped mount
function Mount.toggleRide(player)
	local state = Mount._active[player]
	if state and state.mount_id then
		Mount.unmount(player)
		return true, "off"
	end
	local client = getClient(player)
	local data = client and client.data
	local id = data and MountUtility.getEquipped(data)
	if not id then
		return false, "none"
	end
	return Mount.ride(player, id)
end

local function findAdminFruit(data)
	for _, f in ipairs(data:Get("fruits") or {}) do
		if f.name == ADMIN_FRUIT then
			return f
		end
	end
	return nil
end

local function onChatted(player, message)
	local cmd = string.lower(message)
	if cmd ~= "!givemount" and cmd ~= "!mount" and cmd ~= "!unmount" then
		return
	end
	if not AdminUtility.isAdmin(player) then
		return -- silently ignored for normal players
	end
	if cmd == "!unmount" then
		Mount.unmount(player)
		return
	end
	local client = getClient(player)
	if not client or not client.data then
		return
	end
	local fruit = findAdminFruit(client.data)
	if not fruit then
		FruitUtility.give(client, {name = ADMIN_FRUIT, value = 1})
		fruit = findAdminFruit(client.data)
		notify(player, "🛠️ Admin: you got the " .. ADMIN_FRUIT .. "! (Fruits menu > Mount)", Color3.fromRGB(255, 210, 80))
	elseif cmd == "!givemount" then
		notify(player, "🛠️ Admin: you already own the " .. ADMIN_FRUIT .. ".", Color3.fromRGB(255, 210, 80))
	end
	if cmd == "!mount" and fruit then
		Mount.mount(player, fruit.uid)
	end
end

function Mount._init()
	Network = _L.Get {"Common", "Library", "Network"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	AdminUtility = _L.Get {"Common", "Modules", "Utilities", "AdminUtility"}
	MountUtility = _L.Get {"Common", "Modules", "Utilities", "MountUtility"}
end

function Mount._start()
	Network.Remote.Invoked("S_Fruits_Mount", function(player, fruitUid)
		return Mount.toggle(player, fruitUid)
	end)
	Network.Remote.Invoked("S_Fruits_Unmount", function(player)
		return Mount.unmount(player)
	end)

	-- dedicated mounts (everything verified on the server; per-player cooldown against spam)
	local lastCall = {}
	local function throttled(player)
		local now = os.clock()
		if lastCall[player] and now - lastCall[player] < 0.4 then
			return true
		end
		lastCall[player] = now
		return false
	end
	Network.Remote.Invoked("S_Mount_Equip", function(player, id)
		if throttled(player) then return false, "wait" end
		if typeof(id) ~= "string" then return false, "invalid" end
		return Mount.equip(player, id)
	end)
	Network.Remote.Invoked("S_Mount_Unequip", function(player)
		if throttled(player) then return false, "wait" end
		return Mount.unequip(player)
	end)
	Network.Remote.Invoked("S_Mount_Ride", function(player)
		if throttled(player) then return false, "wait" end
		return Mount.toggleRide(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)

	local function setup(player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
		player.CharacterRemoving:Connect(function()
			Mount.unmount(player)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		Mount.unmount(player)
	end)

	-- if the mounted fruit is deleted / leaves the inventory, get off
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in pairs(Mount._active) do
				if state.mount_id then
					continue
				end
				local client = getClient(player)
				if not client or not client.data or not FruitUtility.getData(client.data, state.uid) then
					Mount.unmount(player)
				end
			end
		end
	end)
end

return Mount
