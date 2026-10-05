--> FruitPen (client)
-- Fruits wander around their pen like little farm animals (visual only, nothing here changes data).
--  * Pens = models tagged "FruitPen" with a part named "Meadow" (the walk area).
--      - the Village Fruit Pen: its FruitFriend models + YOUR Daycare fruits (if you have no pen on your farm)
--      - a Fruit Pen placed on a farm (Decor Bench): that farm owner's Daycare fruits (seen by everyone)
--  * V1.1: a pen shows exactly the Fruits that are IN DAYCARE (fruit.daycare = true), one model per
--    Daycare entry. Withdraw it and it leaves the pen; equipped / resting Fruits are not shown here.
--  * each fruit: pick a nearby spot -> hop there -> pause, bob and look around -> repeat
--  * your own Daycare fruits have a "Daycare" prompt that opens the Daycare menu
--  * the pen sign shows how many Daycare Gems are ready for you
-- One Heartbeat loop moves every fruit near the camera; far away pens are skipped.

local _L = _G._L

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local FruitUtility
local FruitStageUtility
local FruitAnimator
local AnimationPack
local Data

local MAX_PER_PEN = 10 -- resting fruits shown per pen (performance)
local ACTIVE_RANGE = 170 -- only animate pens this close to the camera
local EDGE = 2.2 -- keep this far from the fence
local WALK_SPEED = {3.2, 5}
local IDLE_TIME = {1.8, 4.5}
local HOP_HEIGHT = 0.45
local HOP_SPEED = 11

local FruitPen = {}

local pens = {} -- [penModel] = {residents = {[key] = roamer}}
local petted = setmetatable({}, {__mode = "k"}) -- [model] = true: its prompt was just used (Fruit_Interact)
local container

local function dataOf(player)
	local ok, d = pcall(Data.Await, player, true)
	return ok and d or nil
end

------------------------------------------------------------ helpers
local function rand(range)
	return range[1] + math.random() * (range[2] - range[1])
end

local function meadowOf(pen)
	local m = pen:FindFirstChild("Meadow")
	if m and m:IsA("BasePart") then
		return m
	end
end

-- pick a spot inside the meadow (local x, z), near `from` when given
local function pickSpot(meadow, from, margin)
	margin = EDGE + (margin or 0) -- bigger fruits stay further from the fence
	local hx = math.max(meadow.Size.X / 2 - margin, 0.5)
	local hz = math.max(meadow.Size.Z / 2 - margin, 0.5)
	local x, z
	if from then
		local a = math.random() * math.pi * 2
		local r = 3 + math.random() * 9
		x, z = from.X + math.cos(a) * r, from.Y + math.sin(a) * r
	else
		x, z = (math.random() * 2 - 1) * hx, (math.random() * 2 - 1) * hz
	end
	return Vector2.new(math.clamp(x, -hx, hx), math.clamp(z, -hz, hz))
end

local function prepModel(model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.PivotOffset = CFrame.new() -- pivot = centre of the part (same as followers)
		end
	end
	if model:IsA("BasePart") then
		model.Anchored = true
		model.CanCollide = false
		model.CanTouch = false
	end
end

local function sizeOf(model)
	if model:IsA("BasePart") then
		return model.Size
	end
	if model.PrimaryPart then
		return model.PrimaryPart.Size
	end
	return model:GetExtentsSize()
end

local function newRoamer(model, meadow, halfHeight, owned, radius, rest)
	local start = pickSpot(meadow, nil, radius)
	return {
		model = model,
		half = halfHeight,
		radius = radius or 0,
		rest = rest or CFrame.identity, -- the model's own resting rotation (keeps placed models upright)
		pos = start,
		target = nil,
		state = "idle",
		timer = rand({0.3, 2.5}),
		yaw = math.random() * math.pi * 2,
		lookYaw = 0,
		lookTarget = 0,
		speed = rand(WALK_SPEED),
		phase = math.random() * 10,
		hop = 0,
		owned = owned,
		anim = FruitAnimator.attach(model), -- blinking + little happy hops
	}
end

local function destroyRoamer(r)
	if r.owned and r.model then
		r.model:Destroy()
	end
end

------------------------------------------------------------ building resident fruits
local function tagText(fruitData, isMine)
	local info = FruitUtility.getInfo(fruitData.name)
	local text = FruitStageUtility.getDisplayName(info and (info.display_name or info.name) or fruitData.name, fruitData.stage)
	if isMine then
		local ok, summary = pcall(FruitUtility.getSummary, dataOf(Players.LocalPlayer), fruitData.uid)
		if ok and summary then
			text ..= "  Lv " .. summary.level
		end
	end
	return text
end

local function buildFruit(fruitData, isMine)
	local info = FruitUtility.getInfo(fruitData.name)
	local modelName = info and info.model or fruitData.name
	local source = _L.Assets.Models.Fruits:FindFirstChild(modelName)
	if not source then
		return nil
	end
	local model = source:Clone()
	pcall(FruitStageUtility.applyVisuals, model, fruitData.stage or 0)
	prepModel(model)
	model.Name = "PenFruit_" .. fruitData.uid
	local size = sizeOf(model)
	local anchor = if model:IsA("BasePart") then model else (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
	local l

	-- small name tag (only up close)
	if anchor then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Tag"
		bb.Size = UDim2.fromOffset(150, 26)
		bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.1, 0)
		bb.MaxDistance = 28
		bb.LightInfluence = 0
		bb.Parent = anchor
		l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(255, 250, 235)
		l.Text = tagText(fruitData, isMine)
		l.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Color = Color3.fromRGB(70, 45, 25)
		st.Parent = l

		if isMine then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PenFruitPrompt"
			prompt.ActionText = "Daycare"
			prompt.ObjectText = l.Text
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("FruitUid", fruitData.uid)
			prompt.Parent = anchor
			prompt.Triggered:Connect(function()
				petted[model] = true -- turns to you and does a happy wiggle
				pcall(function()
					local UI = _L.Get {"Client", "Modules", "UI"}
					UI.Open({name = "Daycare"})
				end)
			end)
		end
	end
	return model, size, l
end

-- which player's resting fruits live in this pen (nil = none)
local function penOwner(pen, hasFarmPen)
	local ownerId = pen:GetAttribute("Owner")
	if ownerId then
		return Players:GetPlayerByUserId(ownerId)
	end
	-- the village pen hosts YOUR fruits when you have no pen on your farm
	if not hasFarmPen[Players.LocalPlayer.UserId] then
		return Players.LocalPlayer
	end
end

-- the Fruits this pen shows: the owner's Daycare Fruits (V1.1)
local function restingFruits(data)
	local list = {}
	for _, f in ipairs(data:Get("fruits") or {}) do
		if f.daycare == true then
			table.insert(list, f)
		end
	end
	-- best (highest stage) first, so the cap keeps the nicest ones
	table.sort(list, function(a, b)
		return (a.stage or 0) > (b.stage or 0)
	end)
	return list
end

------------------------------------------------------------ reconcile (1x per second, not per frame)
local function reconcilePen(pen, hasFarmPen)
	local meadow = meadowOf(pen)
	local state = pens[pen]
	if not meadow then
		-- streamed out / not built yet: clean up our fruits, keep nothing running
		if state then
			for key, r in pairs(state.residents) do
				destroyRoamer(r)
				state.residents[key] = nil
			end
		end
		return
	end
	if not state then
		state = {residents = {}}
		pens[pen] = state
	end
	state.meadow = meadow

	local wanted = {}
	-- decorative friends already in the pen (Village)
	for _, m in ipairs(pen:GetChildren()) do
		if m.Name == "FruitFriend" and m:IsA("Model") then
			local key = m
			wanted[key] = true
			if not state.residents[key] then
				prepModel(m) -- pivot = part centre from here on
				local floorTop = meadow.Position.Y + meadow.Size.Y / 2
				local half = math.max(m:GetPivot().Position.Y - floorTop, 0.5)
				local rest = (meadow.CFrame:ToObjectSpace(m:GetPivot())).Rotation
				local ext = m:GetExtentsSize()
				local r = newRoamer(m, meadow, half, false, math.max(ext.X, ext.Z) / 2, rest)
				local lp = meadow.CFrame:PointToObjectSpace(m:GetPivot().Position)
				local hx = math.max(meadow.Size.X / 2 - EDGE - r.radius, 0.5)
				local hz = math.max(meadow.Size.Z / 2 - EDGE - r.radius, 0.5)
				r.pos = Vector2.new(math.clamp(lp.X, -hx, hx), math.clamp(lp.Z, -hz, hz))
				state.residents[key] = r
			end
		end
	end

	-- a player's resting fruits
	local owner = penOwner(pen, hasFarmPen)
	local data = owner and dataOf(owner)
	if data then
		local isMine = owner == Players.LocalPlayer
		for i, f in ipairs(restingFruits(data)) do
			if i > MAX_PER_PEN then
				break
			end
			local key = f.uid .. "#" .. (f.stage or 0)
			wanted[key] = true
			local existing = state.residents[key]
			if not existing then
				local model, size, label = buildFruit(f, isMine)
				if model then
					local r = newRoamer(model, meadow, size.Y / 2, true, math.max(size.X, size.Z) / 2)
					r.label = label
					state.residents[key] = r
					model.Parent = container
				end
			elseif isMine and existing.label then
				existing.label.Text = tagText(f, true) -- level changes after feeding
			end
		end
	end

	for key, r in pairs(state.residents) do
		if not wanted[key] or (r.model and not r.model.Parent) then
			destroyRoamer(r)
			state.residents[key] = nil
		end
	end
end

-- "💎 25 Gems ready" over the pen sign (your own Daycare, display only; the server computes the real amount)
local gemsTag
local function updateGemsTag()
	local pen
	for _, p in ipairs(CollectionService:GetTagged("FruitPen")) do
		if not p:GetAttribute("Owner") and p:IsDescendantOf(workspace) then
			pen = p
			break
		end
	end
	local sign = pen and pen:FindFirstChild("Sign")
	local board = sign and sign:FindFirstChild("Board")
	local data = dataOf(Players.LocalPlayer)
	if not board or not data then
		return
	end
	local FruitFarmUtility = _L.Get {"Common", "Modules", "Utilities", "FruitFarmUtility"}
	local entries = (data:Get("fruit_daycare") or {}).entries or {}
	local now = workspace:GetServerTimeNow()
	local total, count = 0, 0
	for uid, entry in pairs(entries) do
		local fruit = FruitUtility.getData(data, uid)
		if fruit then
			count += 1
			total += (FruitFarmUtility.getPending(entry, fruit, now))
		end
	end
	if not gemsTag or not gemsTag.Parent then
		gemsTag = Instance.new("BillboardGui")
		gemsTag.Name = "DaycareGems"
		gemsTag.Size = UDim2.fromOffset(190, 34)
		gemsTag.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
		gemsTag.MaxDistance = 60
		gemsTag.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(40, 120, 170)
		label.Parent = gemsTag
		Instance.new("UICorner", label).CornerRadius = UDim.new(1, 0)
		local pad = Instance.new("UIPadding", label)
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2.5
		stroke.Color = Color3.fromRGB(90, 60, 30)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = label
		gemsTag.Parent = board
	end
	gemsTag.Enabled = count > 0
	gemsTag.Text.Text = if total > 0 then ("💎 " .. total .. " Gems ready!") else ("💎 Daycare: " .. count .. "/" .. FruitFarmUtility.DAYCARE_CAPACITY)
end

local function reconcileAll()
	pcall(updateGemsTag)
	local list = CollectionService:GetTagged("FruitPen")
	local hasFarmPen = {}
	for _, pen in ipairs(list) do
		local id = pen:GetAttribute("Owner")
		if id then
			hasFarmPen[id] = true
		end
	end
	local alive = {}
	for _, pen in ipairs(list) do
		if pen:IsDescendantOf(workspace) then
			alive[pen] = true
			reconcilePen(pen, hasFarmPen)
		end
	end
	-- pens that were removed (picked up / owner left)
	for pen, state in pairs(pens) do
		if not alive[pen] then
			for _, r in pairs(state.residents) do
				destroyRoamer(r)
			end
			pens[pen] = nil
		end
	end
end

------------------------------------------------------------ movement (one loop for everything)
local function step(r, meadow, dt, t)
	if petted[r.model] then
		-- "Feed / Stats" used: stop, face the player, happy wiggle while the menu opens
		petted[r.model] = nil
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local rel = meadow.CFrame:PointToObjectSpace(root.Position)
			local dx, dz = rel.X - r.pos.X, rel.Z - r.pos.Y
			if dx * dx + dz * dz > 0.01 then
				r.turnTo = math.atan2(-dx, -dz)
			end
		end
		r.state = "idle"
		r.timer = math.max(r.timer or 0, 1.6)
		r.lookTarget = 0
		AnimationPack.play(r.anim, "Fruit_Interact", 0.1)
	end
	if r.state == "walk" then
		local delta = r.target - r.pos
		local dist = delta.Magnitude
		if dist < 0.25 then
			r.state = "idle"
			r.timer = rand(IDLE_TIME)
			r.lookTarget = (math.random() - 0.5) * 1.6
		else
			local dir = delta / dist
			r.pos += dir * math.min(dist, r.speed * dt)
			-- turn smoothly toward where it walks (models face -Z)
			local want = math.atan2(-dir.X, -dir.Y)
			local diff = (want - r.yaw + math.pi) % (math.pi * 2) - math.pi
			r.yaw += diff * math.clamp(dt * 8, 0, 1)
			r.hop += dt * HOP_SPEED
		end
		r.lookYaw += (0 - r.lookYaw) * math.clamp(dt * 6, 0, 1)
	else
		r.timer -= dt
		-- look around: glance to a side, sometimes switch
		if math.random() < dt * 0.6 then
			r.lookTarget = (math.random() - 0.5) * 1.6
		end
		r.lookYaw += (r.lookTarget - r.lookYaw) * math.clamp(dt * 3, 0, 1)
		if r.turnTo then
			local turn = (r.turnTo - r.yaw + math.pi) % (math.pi * 2) - math.pi
			r.yaw += turn * math.clamp(dt * 10, 0, 1)
		end
		if not AnimationPack.playing(r.anim) then
			r.turnTo = nil
			FruitAnimator.maybeIdleHop(r.anim, dt, 0.03) -- now and then a happy little hop
		end
		-- finish the current hop so it lands softly
		local frac = (r.hop / math.pi) % 1
		if frac > 0.02 then
			r.hop += dt * HOP_SPEED
		end
		if r.timer <= 0 then
			r.state = "walk"
			r.target = pickSpot(meadow, r.pos, r.radius)
			r.speed = rand(WALK_SPEED)
		end
	end

	local walking = r.state == "walk"
	local hopY = math.abs(math.sin(r.hop)) * HOP_HEIGHT
	local breathe = if walking then 0 else (math.sin(t * 2.2 + r.phase) * 0.5 + 0.5) * 0.12
	local tilt = if walking then math.sin(r.hop) * math.rad(9) else math.sin(t * 1.3 + r.phase) * math.rad(3)
	local lean = if walking then -math.abs(math.sin(r.hop)) * math.rad(6) else 0

	local floorTop = meadow.Size.Y / 2
	local cf = meadow.CFrame
		* CFrame.new(r.pos.X, floorTop + r.half + hopY + breathe, r.pos.Y)
		* CFrame.Angles(0, r.yaw + r.lookYaw, 0)
		* CFrame.Angles(lean, 0, tilt)
		* AnimationPack.shot(r.anim, dt, CFrame.identity, r.half)
		* FruitAnimator.step(r.anim, dt)
		* r.rest
	if r.model:IsA("Model") then
		r.model:PivotTo(cf)
	else
		r.model.CFrame = cf
	end
	FruitAnimator.afterPivot(r.anim)
end

local function onHeartbeat(dt)
	dt = math.min(dt, 0.1)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	for _, state in pairs(pens) do
		local meadow = state.meadow
		if meadow and meadow.Parent and (meadow.Position - camPos).Magnitude < ACTIVE_RANGE then
			for _, r in pairs(state.residents) do
				if r.model and r.model.Parent then
					step(r, meadow, dt, t)
				end
			end
		end
	end
end

------------------------------------------------------------
function FruitPen._init()
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	FruitAnimator = _L.Get {"Client", "Modules", "Classes", "FruitAnimator"}
	AnimationPack = _L.Get {"Client", "Modules", "Classes", "AnimationPack"}
end

function FruitPen._start()
	container = Instance.new("Folder")
	container.Name = "PenFruits"
	container.Parent = workspace

	RunService.Heartbeat:Connect(onHeartbeat)
	task.spawn(function()
		while true do
			local ok, err = pcall(reconcileAll)
			if not ok then
				warn("[FruitPen]", err)
			end
			task.wait(1)
		end
	end)
end

return FruitPen
