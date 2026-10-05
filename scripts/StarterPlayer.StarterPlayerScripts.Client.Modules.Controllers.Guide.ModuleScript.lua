--> Guide (client)
-- Calm tutorial arrows for new players:
--   1. harvest a plant    -> soft arrow over your nearest ready plant
--   2. sell them          -> arrow over the nearest Crop Seller (Gardener)
--   3. buy a seed pack    -> arrow over the Seed Shop NPC (Starter Seed Pack)
--   4. plant a seed       -> arrow over your nearest EMPTY garden slot
--   5. grow + harvest     -> arrow over your growing seed crop
--   6. hatch a fruit      -> arrow over the nearest approved egg stand
--   7. equip the fruit    -> screen arrow pointing at the Fruits menu button
-- After that it only comes back when your backpack is full (-> Gardener).
-- Visuals: a gently bobbing arrow above the target, a few faint chevrons on the ground
-- pointing the way, and a small hint pill at the top of the screen. Nothing flashes.

local _L = _G._L

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local BackpackUtility
local EggUtility

local PICKS_BEFORE_SELL = 10 -- show the Gardener once you carry this many plants

local CHEVRONS = 6
local CHEVRON_GAP = 4
local CHEVRON_SPEED = 3.5 -- studs per second the arrows glide toward the target
local SOFT = Color3.fromRGB(170, 245, 180)
local ARROW_COLOR = Color3.fromRGB(90, 225, 110)

local STEPS = {
	[1] = {key = "pick", title = "🍀 Harvest", text = "Harvest the mature crop.", label = "Harvest"},
	[2] = {key = "sell", title = "💰 Sell", text = "Sell your harvest.", label = "Sell"},
	[3] = {key = "get_seed", title = "🛒 Seeds", text = "Buy a Starter Seed Pack.", label = "Seeds"},
	[4] = {key = "plant", title = "🌱 Plant a Seed", text = "Equip a Seed, then tap the soil.", label = "Plant"},
	[5] = {key = "grow", title = "⏳ Grow", text = "Harvest your crop when it's ready.", label = "Grow"},
	[6] = {key = "hatch", title = "🥚 Hatch", text = "Hatch your first Fruit.", label = "Hatch"},
	[7] = {key = "equip", title = "🍓 Equip", text = "Equip your Fruit.", label = "Equip"},
}
local STEP_COUNT = 7

local FINAL_MESSAGE = "Fruits boost your farming. Find rarer Fruits and grow your farm!"

local Guide = {
	-- set by Settings > Skip Tutorial so skipping doesn't show the "well done" message
	skipping = false,
}

local function rootOf(inst)
	if not inst or not inst.Parent then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	return inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

local function nearest(list, from)
	local best, bestD
	for _, inst in ipairs(list) do
		local part = rootOf(inst)
		if part then
			local d = (part.Position - from).Magnitude
			if not bestD or d < bestD then
				best, bestD = inst, d
			end
		end
	end
	return best
end

local function hasBlooms(model)
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "Bloom" and d:IsA("BasePart") and d.LocalTransparencyModifier < 0.3 then
			return true
		end
	end
	return false
end

function Guide._step(data)
	local marker = data:Get("tutorial_marker")
	local info = typeof(marker) == "number" and STEPS[marker] or nil
	if not info then
		return nil
	end
	if marker == 6 and not EggUtility.isContentApproved() then
		return nil
	end
	return info.key, info
end

function Guide._cheapestEgg()
	if Guide._eggPrice then
		return Guide._eggPrice
	end
	local price = 100
	pcall(function()
		local Eggs = _L.Get {"Common", "Modules", "Databases", "Eggs"}
		local eggFolder = _L.Map:FindFirstChild("Eggs")
		local best
		for _, e in ipairs(Eggs) do
			if typeof(e) == "table" and e.price and eggFolder and eggFolder:FindFirstChild(e.name) and not e.is_exclusive then
				best = if best then math.min(best, e.price) else e.price
			end
		end
		price = best or price
	end)
	Guide._eggPrice = price
	return price
end

function Guide._target(step, from)
	if step == "pick" then
		local mine, any = {}, {}
		for _, m in ipairs(CollectionService:GetTagged("HarvestBush")) do
			if m:IsA("Model") and hasBlooms(m) then
				local owner = m:GetAttribute("Owner")
				if owner == _L.Player.UserId then
					table.insert(mine, m)
				elseif not owner then
					table.insert(any, m)
				end
			end
		end
		return nearest(if #mine > 0 then mine else any, from)
	elseif step == "sell" or step == "full" then
		return nearest(CollectionService:GetTagged("Gardener"), from)
	elseif step == "get_seed" then
		local village = _L.Map:FindFirstChild("Village")
		local shops = village and village:FindFirstChild("Shops")
		local seedShop = shops and shops:FindFirstChild("Seed Shop")
		return seedShop and (seedShop:FindFirstChild("Gardener_Seed") or seedShop)
	elseif step == "plant" then
		-- your own plantable soil (free planting: anywhere on it)
		local mine = {}
		for _, soil in ipairs(CollectionService:GetTagged("FarmSoil")) do
			if soil:GetAttribute("Owner") == _L.Player.UserId then
				table.insert(mine, soil)
			end
		end
		return nearest(mine, from)
	elseif step == "grow" then
		local mine = {}
		for _, crop in ipairs(CollectionService:GetTagged("SeedCrop")) do
			-- the crop the player planted, not the leftover starter Clover
			if crop:IsA("Model") and crop:GetAttribute("Owner") == _L.Player.UserId and not crop:GetAttribute("TutorialCrop") then
				table.insert(mine, crop)
			end
		end
		return nearest(mine, from)
	elseif step == "hatch" then
		local eggs = _L.Map:FindFirstChild("Eggs")
		local approved = {}
		for _, egg in ipairs(eggs and eggs:GetChildren() or {}) do
			if EggUtility.isContentApproved(egg.Name) then
				table.insert(approved, egg)
			end
		end
		return nearest(approved, from)
	end
	return nil
end

-- Server-published positions used while the real target is outside this client's
-- streaming radius (phones stream less of the map). The marker moves onto the real
-- object as soon as it streams in.
local FALLBACK = {
	pick = {player = "GuideFarm"},
	plant = {player = "GuideFarm"},
	grow = {player = "GuideFarm"},
	sell = {world = "GuideSell"},
	full = {world = "GuideSell"},
	get_seed = {world = "GuideSeedShop"},
	hatch = {world = "GuideEgg"},
}

function Guide._fallbackPosition(step)
	local info = FALLBACK[step]
	local value = info and (if info.player then _L.Player:GetAttribute(info.player) else workspace:GetAttribute(info.world))
	return if typeof(value) == "Vector3" then value else nil
end

function Guide._build()
	local Data = _L.Get {"Client", "Library", "Classes", "Data"}
	local data = Data.Await()
	local UI = _L.Get {"Client", "Modules", "UI"}
	local previousMarker = data:Get("tutorial_marker")
	data:Bind("tutorial_marker", function(value)
		if value == 8 and typeof(previousMarker) == "number" and previousMarker < 8 and not Guide.skipping then
			UI.Get("Notifications"):add({text = FINAL_MESSAGE, color = Color3.fromRGB(110, 220, 120), duration = 3})
		end
		if value == 8 then
			Guide.skipping = false
		end
		previousMarker = value
	end)

	-- compact tutorial card: bottom-centre, small, never blocks the middle of the screen (phones)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Guide"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.Parent = _L.PlayerGui
	local pill = Instance.new("Frame")
	pill.Name = "TutorialCard"
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.new(0.5, 0, 1, -92) -- above the seed / tool hotbar
	pill.Size = UDim2.new(0.78, 0, 0, 0)
	pill.AutomaticSize = Enum.AutomaticSize.Y
	pill.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
	pill.BackgroundTransparency = 0.04
	pill.Active = false
	pill.Visible = false
	pill.Parent = gui
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 14)
	local ps = Instance.new("UIStroke")
	ps.Color = Color3.fromRGB(110, 190, 90)
	ps.Thickness = 2.5
	ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ps.Parent = pill
	local pad = Instance.new("UIPadding", pill)
	pad.PaddingTop = UDim.new(0, 7)
	pad.PaddingBottom = UDim.new(0, 7)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	local limit = Instance.new("UISizeConstraint", pill)
	limit.MaxSize = Vector2.new(440, 120)
	limit.MinSize = Vector2.new(230, 0)
	local list = Instance.new("UIListLayout", pill)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)

	local function cardText(name, order, height, maxText, color)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.LayoutOrder = order
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, height)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = color
		local c = Instance.new("UITextSizeConstraint", t)
		c.MaxTextSize = maxText
		c.MinTextSize = 11
		t.Parent = pill
		return t
	end
	local header = cardText("Title", 1, 22, 20, Color3.fromRGB(70, 130, 55))
	local progress = Instance.new("TextLabel")
	progress.Name = "Progress"
	progress.AnchorPoint = Vector2.new(1, 0)
	progress.Position = UDim2.fromScale(1, 0)
	progress.Size = UDim2.new(0.3, 0, 1, 0)
	progress.BackgroundTransparency = 1
	progress.Font = Enum.Font.FredokaOne
	progress.TextScaled = true
	progress.TextXAlignment = Enum.TextXAlignment.Right
	progress.TextColor3 = Color3.fromRGB(150, 120, 90)
	Instance.new("UITextSizeConstraint", progress).MaxTextSize = 16
	progress.Parent = header
	local body = cardText("Hint", 2, 20, 17, Color3.fromRGB(95, 65, 40))

	-- SKIP: secondary, tap twice to confirm (same server skip as Settings > Skip Tutorial)
	local skipRow = Instance.new("Frame")
	skipRow.Name = "SkipRow"
	skipRow.LayoutOrder = 3
	skipRow.BackgroundTransparency = 1
	skipRow.Size = UDim2.new(1, 0, 0, 18)
	skipRow.Parent = pill
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.fromScale(1, 0)
	skip.Size = UDim2.new(0, 64, 1, 0)
	skip.BackgroundTransparency = 1
	skip.Font = Enum.Font.FredokaOne
	skip.Text = "SKIP"
	skip.TextScaled = true
	skip.TextXAlignment = Enum.TextXAlignment.Right
	skip.TextColor3 = Color3.fromRGB(170, 140, 110)
	Instance.new("UITextSizeConstraint", skip).MaxTextSize = 14
	skip.Parent = skipRow
	local skipArmedUntil = 0
	local skipPending = false
	skip.MouseButton1Click:Connect(function()
		if skipPending then
			return
		end
		if os.clock() > skipArmedUntil then
			skipArmedUntil = os.clock() + 3
			skip.Text = "SKIP?"
			skip.TextColor3 = Color3.fromRGB(215, 95, 70)
			task.delay(3, function()
				if os.clock() >= skipArmedUntil then
					skip.Text = "SKIP"
					skip.TextColor3 = Color3.fromRGB(170, 140, 110)
				end
			end)
			return
		end
		skipPending = true
		Guide.skipping = true
		local Network = _L.Get {"Common", "Library", "Network"}
		local ok, success = pcall(Network.Remote.Invoke, "S_Tutorial_Skip")
		skipPending = false
		skipArmedUntil = 0
		skip.Text = "SKIP"
		skip.TextColor3 = Color3.fromRGB(170, 140, 110)
		if not (ok and success) then
			Guide.skipping = false
		end
	end)

	-- marker above the target (bobbing arrow + small label)
	local marker = Instance.new("BillboardGui")
	marker.Name = "GuideMarker"
	marker.Size = UDim2.fromOffset(90, 90)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.MaxDistance = 2000 -- far fallback targets (not streamed in yet) still get an arrow
	marker.Enabled = false
	marker.ResetOnSpawn = false
	marker.Parent = _L.PlayerGui -- billboards don't render inside a ScreenGui
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 0.62)
	arrow.Position = UDim2.fromScale(0, 0.36)
	arrow.Font = Enum.Font.FredokaOne
	arrow.TextScaled = true
	arrow.Text = "▼"
	arrow.TextColor3 = SOFT
	arrow.Parent = marker
	local as = Instance.new("UIStroke", arrow)
	as.Color = Color3.fromRGB(60, 120, 60)
	as.Thickness = 3
	local tag = Instance.new("TextLabel")
	tag.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
	tag.Size = UDim2.fromScale(1, 0.3)
	tag.Font = Enum.Font.FredokaOne
	tag.TextScaled = true
	tag.TextColor3 = Color3.fromRGB(95, 65, 40)
	tag.Parent = marker
	Instance.new("UICorner", tag).CornerRadius = UDim.new(1, 0)
	local ts = Instance.new("UIStroke")
	ts.Color = Color3.fromRGB(110, 190, 90)
	ts.Thickness = 2
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ts.Parent = tag

	-- screen-space pointer for the equip step: bobs above the Fruits menu
	-- button in the left panel (that step's target is a UI button, not a
	-- world object, so the billboard marker cannot show it)
	local pointerGui = Instance.new("ScreenGui")
	pointerGui.Name = "GuideFruitsPointer"
	pointerGui.ResetOnSpawn = false
	-- must match the Main HUD's screen space, or AbsolutePosition is offset by the
	-- top bar / notch insets on phones and the arrow lands off target
	local hudGui = _L.PlayerGui:FindFirstChild("Main")
	if hudGui and hudGui:IsA("ScreenGui") then
		pointerGui.IgnoreGuiInset = hudGui.IgnoreGuiInset
		pointerGui.ScreenInsets = hudGui.ScreenInsets
		pointerGui.ClipToDeviceSafeArea = hudGui.ClipToDeviceSafeArea
	end
	pointerGui.DisplayOrder = 2
	pointerGui.Enabled = false
	pointerGui.Parent = _L.PlayerGui
	local pointer = Instance.new("TextLabel")
	pointer.Name = "Arrow"
	pointer.AnchorPoint = Vector2.new(0.5, 1)
	pointer.Size = UDim2.fromOffset(46, 46)
	pointer.BackgroundTransparency = 1
	pointer.Font = Enum.Font.FredokaOne
	pointer.TextScaled = true
	pointer.Text = "▼"
	pointer.TextColor3 = ARROW_COLOR
	pointer.Parent = pointerGui
	local pointerStroke = Instance.new("UIStroke")
	pointerStroke.Color = Color3.fromRGB(60, 120, 60)
	pointerStroke.Thickness = 3
	pointerStroke.Parent = pointer

	-- faint chevrons on the ground pointing the way
	local folder = Instance.new("Folder")
	folder.Name = "GuideChevrons"
	folder.Parent = workspace
	local chevrons = {}
	local template = _L.Assets.Models:FindFirstChild("Arrow")
	for i = 1, CHEVRONS do
		local c
		if template and template:IsA("BasePart") then
			c = template:Clone()
			c.Size = Vector3.new(template.Size.X * 0.7, template.Size.Y * 0.7, 0.25)
		else
			c = Instance.new("Part")
			c.Size = Vector3.new(1.6, 0.2, 1.6)
		end
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		c.Material = Enum.Material.Neon
		c.Color = ARROW_COLOR
		c.Transparency = 1
		c.Parent = folder
		chevrons[i] = c
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- shop labels ("Seed Shop" / "Crop Seller" above the NPCs): fade out with distance and
	-- step aside while the tutorial arrow points at that NPC, so they never overlap
	local LABEL_FADE_START, LABEL_FADE_END = 50, 78
	local shopLabels = {}
	local function collectShopLabels()
		table.clear(shopLabels)
		local village = _L.Map:FindFirstChild("Village")
		if not village then
			return
		end
		for _, npc in ipairs({village:FindFirstChild("CropSeller"), village:FindFirstChild("Shops") and village.Shops:FindFirstChild("Seed Shop") and village.Shops["Seed Shop"]:FindFirstChild("Gardener_Seed")}) do
			local torso = npc and npc:FindFirstChild("Torso")
			local gui = torso and torso:FindFirstChild("NPCName")
			local label = gui and gui:FindFirstChildWhichIsA("TextLabel")
			if label then
				table.insert(shopLabels, {npc = npc, gui = gui, label = label, stroke = label:FindFirstChildOfClass("UIStroke")})
			end
		end
	end
	collectShopLabels()
	local lastLabelScan = os.clock()

	local anchor = Instance.new("Part")
	anchor.Name = "GuideAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Parent = folder

	local step, stepInfo, target, targetPart
	local lastCheck = 0

	RunService.RenderStepped:Connect(function()
		local character = _L.Player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local now = os.clock()

		if root and now - lastCheck > 0.5 then
			lastCheck = now
			step, stepInfo = Guide._step(data)
			target = step and Guide._target(step, root.Position)
			if step and not rootOf(target) then
				local position = Guide._fallbackPosition(step)
				if position then
					anchor.Position = position
					target = anchor
				end
			end
			targetPart = rootOf(target)
		end

		local active = root ~= nil and step ~= nil and stepInfo ~= nil
		local menuOpen = UI._current and UI._current:Get() ~= nil
		local showMarker = active and targetPart ~= nil and not menuOpen

		if now - lastLabelScan > 10 and #shopLabels < 2 then
			lastLabelScan = now
			collectShopLabels()
		end
		local camera = workspace.CurrentCamera
		for _, entry in ipairs(shopLabels) do
			local isTarget = showMarker and target ~= nil and (target == entry.npc or target:IsDescendantOf(entry.npc))
			local fade = 1
			if camera and entry.gui.Parent then
				local distance = (camera.CFrame.Position - entry.gui.Parent.Position).Magnitude
				fade = 1 - math.clamp((distance - LABEL_FADE_START) / (LABEL_FADE_END - LABEL_FADE_START), 0, 1)
			end
			entry.gui.Enabled = fade > 0 and not isTarget
			entry.label.TextTransparency = 1 - fade
			if entry.stroke then
				entry.stroke.Transparency = 1 - fade
			end
		end

		-- equip step: point at the Fruits button instead of a world object
		local showPointer = false
		if active and step == "equip" and not menuOpen then
			local main = _L.PlayerGui:FindFirstChild("Main")
			local left = main and main:FindFirstChild("Left")
			local content = left and left:FindFirstChild("Content")
			local fruitsButton = content and content:FindFirstChild("Fruits")
			if fruitsButton and fruitsButton.Visible then
				local absPos = fruitsButton.AbsolutePosition
				local absSize = fruitsButton.AbsoluteSize
				if absSize.X > 0 and absSize.Y > 0 then
					local screen = pointerGui.AbsoluteSize
					local x = math.clamp(absPos.X + absSize.X / 2, 24, math.max(24, screen.X - 24))
					local y = math.clamp(absPos.Y - 6 - math.abs(math.sin(now * 2.2)) * 10, 48, math.max(48, screen.Y))
					pointer.Position = UDim2.new(0, x, 0, y)
					showPointer = true
				end
			end
		end
		pointerGui.Enabled = showPointer
		pill.Visible = active and not menuOpen
		if active then
			local stepMarker = data:Get("tutorial_marker")
			header.Text = stepInfo.title
			progress.Text = (if typeof(stepMarker) == "number" then math.min(stepMarker, STEP_COUNT) else 1) .. "/" .. STEP_COUNT
			body.Text = stepInfo.text
			tag.Text = stepInfo.label
		end
		marker.Enabled = showMarker
		if not showMarker then
			for _, c in ipairs(chevrons) do
				c.Transparency = 1
			end
			return
		end

		-- marker gently bobs above the target
		local height = if target == anchor then 6 else 3
		if target:IsA("Model") then
			local _, size = target:GetBoundingBox()
			height = size.Y / 2 + 2
		end
		marker.Adornee = targetPart
		marker.StudsOffsetWorldSpace = Vector3.new(0, height + 1.5 + math.sin(now * 2.2) * 0.6, 0)

		-- chevrons: only while the target is a bit away, fading forward in a slow wave
		local flat = Vector3.new(targetPart.Position.X - root.Position.X, 0, targetPart.Position.Z - root.Position.Z)
		local distance = flat.Magnitude
		local dir = if distance > 0.01 then flat.Unit else Vector3.zAxis
		rayParams.FilterDescendantsInstances = {character, folder}
		-- arrows glide from the player toward the target, pointing at the target
		local span = CHEVRONS * CHEVRON_GAP
		local pathLength = math.min(span, distance - 4)
		for i, c in ipairs(chevrons) do
			local along = 3 + ((i - 1) * CHEVRON_GAP + now * CHEVRON_SPEED) % span
			if distance < 9 or along > 3 + pathLength then
				c.Transparency = 1
			else
				local pos = root.Position + dir * along
				local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
				local y = if hit then hit.Position.Y + 0.2 else root.Position.Y - 2.8
				local ground = Vector3.new(pos.X, y, pos.Z)
				c.CFrame = CFrame.lookAt(ground, ground - dir) * CFrame.Angles(math.rad(-90), 0, math.rad(-90))
				-- fade in near the player, fade out at the end of the path
				local k = (along - 3) / math.max(pathLength, 1)
				local fade = math.clamp(math.min(k * 4, (1 - k) * 4), 0, 1)
				c.Transparency = 1 - fade * 0.85
			end
		end
	end)
end

function Guide._init()
	BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
	EggUtility = _L.Get {"Common", "Modules", "Utilities", "EggUtility"}
end

function Guide._start()
	task.spawn(function()
		local ok, err = pcall(Guide._build)
		if not ok then
			warn("[Guide] failed:", err)
		end
	end)
end

return Guide
