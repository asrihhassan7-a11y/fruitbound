--> Variables
local _L = _G._L

local Services
local TableUtility
local Trove
local FruitUtility
local FruitRarities
local ArrayUtility
local Rainbow
local FruitStageUtility
local FruitAnimator
local AnimationPack

--> Constants
local SPACE_BEHIND_CHARACTER = 6
local FRUITS_PER_ROW = 4
local PADDING_Z = 3
local PADDING_X = 3
local PRECISE_SPACING = true

-- Code-only animation: AnimationPack clips Fruit_Idle / Fruit_Walk / Fruit_Run / Fruit_Sleep (loops, blended)
-- plus one-shots Fruit_Happy (new / levelled / evolved fruit) and Fruit_Surprised (woken up)
local WALK_REF_SPEED = 16 -- player speed where Fruit_Walk plays at 1x (faster players = faster steps)
local RUN_SPEED = 20 -- player speed (studs/s) from which fruits run (mount riding, speed boosts)
local SLEEP_AFTER = 45 -- seconds the player stands still before the fruits doze off
local BLEND_SPEED = 8 -- how quickly fruits switch between idle / walk / run
local PHASE_PER_FRUIT = 0.9 -- offset so fruits don't all hop at the same time

-- Minimal rig for your uploaded Fruit animations (Databases.AnimationIds), built ONLY when a Fruit ID is set:
--   Root (invisible, anchored, new PrimaryPart at the mesh's exact CFrame) --Motor6D "RootJoint"--> Handle
-- Every Fruit gets the same names, so one Fruit animation works on all of them. Nothing visual changes
-- (same mesh, size, Golden / Rainbow look); stage decorations are welded to the Handle so they move with it.
-- A single-mesh Fruit can only animate as a whole body (bounce / tilt / sway), never separate limbs.
local function rigFruit(model)
	local handle = model:FindFirstChild("Handle")
	if not model:IsA("Model") or not handle or not handle:IsA("BasePart") or model:FindFirstChild("Root") then
		return false
	end
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Massless = true
	root.Anchored = true
	root.CFrame = handle.CFrame
	root.Parent = model
	local loose = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root and part ~= handle and part.Anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
			table.insert(loose, part)
		end
	end
	for _, part in ipairs(loose) do
		part.Anchored = false
	end
	handle.Anchored = false
	local joint = Instance.new("Motor6D")
	joint.Name = "RootJoint"
	joint.Part0 = root
	joint.Part1 = handle
	joint.Parent = root
	model.PrimaryPart = root
	return true
end

-- one-shot (Happy / Surprised): your uploaded animation when it has loaded, else the AnimationPack clip
local function fruitShot(fruit, action, delay)
	if AnimationPack.trackReady(fruit.tracks, action) then
		task.delay(delay or 0, function()
			if fruit.instance and fruit.instance.Parent then
				AnimationPack.trackShot(fruit.tracks, action)
			end
		end)
		return
	end
	AnimationPack.play(fruit.anim, "Fruit_" .. action, delay)
end

------------->
local FruitGroup = {r = {}}
FruitGroup.__index = FruitGroup

function FruitGroup._init()
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Services = _L.Get {"Common", "Library", "Services"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	FruitRarities = _L.Get {"Common", "Modules", "Databases", "Fruits", "Rarities"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	Rainbow = _L.Get {"Client", "Modules", "Classes", "Rainbow"}
	FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
	FruitAnimator = _L.Get {"Client", "Modules", "Classes", "FruitAnimator"}
	AnimationPack = _L.Get {"Client", "Modules", "Classes", "AnimationPack"}
end

function FruitGroup._start()
	Rainbow.new({
		speed = 6,
		callback = function(value)
			-- Soft pastel rainbow: blend the fully saturated hue toward white so the
			-- overlay stays a subtle shimmer and never drowns out the original
			-- fruit texture (no extreme blue/red saturation on top of the fruit).
			local pastel = Color3.new(1, 1, 1):Lerp(value, 0.55)
			for _, d in pairs(FruitGroup.r) do
				d.FillColor = pastel
			end
		end,
	})
end

function FruitGroup.new(props)
	local self = setmetatable({}, FruitGroup)

	self._player = props.player
	self._data = props.data

	self._fruits = {}

	self._trove = Trove.new()

	self:_construct()

	return self
end

function FruitGroup:_construct()
	self._trove:Add(self._data:Bind("fruits", function(value)
		local fruitUids = {}

		for _, fruit in pairs(self._fruits) do
			local fruitUid = fruit.uid
			local fruitInstance = fruit.instance

			local fruitData = FruitUtility.getData(self._data, fruitUid)

			if not fruitData or not fruitData.equipped then
				table.insert(fruitUids, fruitUid)
			elseif (fruitData.stage or 0) ~= (fruit.stage or 0) then
				-- evolved: rebuild it with the new look (and celebrate)
				table.insert(fruitUids, fruitUid)
				self._just_evolved = self._just_evolved or {}
				self._just_evolved[fruitUid] = true
			end
		end

		for _, fruitUid in pairs(fruitUids) do
			local fruitIndex, fruit = TableUtility.match(self._fruits, function(i, v)
				return v.uid == fruitUid
			end)

			if fruitIndex and fruit then
				table.remove(self._fruits, fruitIndex)
				fruit.trove:Destroy()
			end
		end

		local fruits = TableUtility.deep.clone(self._fruits)

		for _, fruitData in pairs(value) do
			local fruitUid = fruitData.uid
			local fruitName = fruitData.name
			local fruitInfo = FruitUtility.getInfo(fruitName)

			local fruit = self:get(fruitUid)

			if not fruit and fruitData.equipped then
				-- Look up the model name from the fruit database entry
				local modelName = fruitInfo and fruitInfo.model or fruitName
				local fruitInstance = _L.Assets.Models.Fruits:FindFirstChild(modelName)

				if fruitInstance then
					local newFruitInstance = fruitInstance:Clone()
					local newTrove = Trove.new()

					for _, part in ipairs(newFruitInstance:GetDescendants()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
							part.CanTouch = false
							part.CanQuery = false
							part.Massless = true
							part.PivotOffset = CFrame.new(0, 0, 0)
						end
					end

					-- Also handle the case where the model itself is a BasePart (e.g. MeshPart without a parent Model)
					if newFruitInstance:IsA("BasePart") then
						newFruitInstance.CanCollide = false
						newFruitInstance.CanTouch = false
						newFruitInstance.CanQuery = false
						newFruitInstance.Massless = true
						newFruitInstance.PivotOffset = CFrame.new(0, 0, 0)
					end

					-- Evolution stage look: size, colour, glow, sparkles, vines, halo
					local stage = fruitData.stage or 0
					FruitStageUtility.applyVisuals(newFruitInstance, stage)

					self._trove:Add(newTrove)

					newTrove:Add(function()
						for _, d in pairs(newFruitInstance:GetDescendants()) do
							local x = FruitGroup.r[d]

							if x then
								FruitGroup.r[d] = nil
								x:Destroy()
							end
						end

						local x = FruitGroup.r[newFruitInstance]
						if x then
							FruitGroup.r[newFruitInstance] = nil
							x:Destroy()
						end
					end)

					newTrove:Add(newFruitInstance)

					newFruitInstance.Name = fruitUid
					newFruitInstance.Parent = _L.Debris.Fruits

					-- Calculate fruit size for grid positioning
					local fruitSize = if newFruitInstance:IsA("BasePart") then newFruitInstance.Size elseif newFruitInstance.PrimaryPart then newFruitInstance.PrimaryPart.Size else newFruitInstance:GetExtentsSize()

					local i, rarityInfo = TableUtility.match(FruitRarities, function(i, v)
						return v.name == (fruitInfo and fruitInfo.rarity or "Common")
					end)

					local evolved = self._just_evolved and self._just_evolved[fruitUid]
					if evolved then
						self._just_evolved[fruitUid] = nil
						task.delay(0.1, function()
							FruitStageUtility.playEvolveBurst(newFruitInstance, stage)
						end)
					end

					-- uploaded Fruit animations need a joint: add the Root -> Handle rig only when IDs are set
					local rigged = AnimationPack.hasCustom("Fruit") and rigFruit(newFruitInstance)

					local newFruit = {
						stage = stage,
						uid = fruitUid,
						instance = newFruitInstance,
						size = fruitSize,
						info = fruitInfo,
						rarity_info = {i = i, v = rarityInfo},
						last_lerp = nil,
						trove = newTrove,
						walk_blend = 0, -- 0 = idle, 1 = walking
						anim = FruitAnimator.attach(newFruitInstance), -- blinking + happy reactions
					}

					fruit = newFruit

					if rigged then
						newFruit.tracks = AnimationPack.trackSet(newFruitInstance, "Fruit")
						newTrove:Add(function()
							AnimationPack.trackStop(newFruit.tracks)
						end)
					end

					-- a fruit that just joined you (hatched / equipped) or evolved celebrates (not on join)
					if evolved or self._loaded then
						fruitShot(newFruit, "Happy", 0.15 + math.random() * 0.1)
					end

					table.insert(fruits, newFruit)
				end
			end

			if fruit then
				-- level up: happy jump
				local level = fruitData.level or 1
				if fruit.level and level > fruit.level then
					fruitShot(fruit, "Happy")
				end
				fruit.level = level

				local effect = FruitGroup.r[fruit.instance]
				if fruitData.tier == "Rainbow" then
					if not effect then
						FruitGroup.r[fruit.instance] = Create("Highlight", {
							Name = "RainbowTint",
							Parent = fruit.instance,
							Adornee = fruit.instance,
							FillColor = Color3.fromRGB(255, 190, 220),
							FillTransparency = 0.68,
							OutlineColor = Color3.fromRGB(255, 245, 225),
							OutlineTransparency = 0.9,
							DepthMode = Enum.HighlightDepthMode.Occluded,
							Enabled = not fruit._mount_hidden
						})
					end
				elseif effect then
					FruitGroup.r[fruit.instance] = nil
					effect:Destroy()
				end
			end
		end

		local mega = {}

		for i, rarityInfo in pairs(FruitRarities) do
			local mini = ArrayUtility.filter(fruits, function(i, v)
				return v.rarity_info.v.name == rarityInfo.name
			end)

			table.sort(mini, function(a, b)
				return (a.size.X + a.size.Z) < (b.size.X + b.size.Z)
			end)

			for _, v in pairs(mini) do
				table.insert(mega, v)
			end
		end

		self._fruits = mega
		self._loaded = true
	end))

	self._trove:Add(function()
		table.clear(self._fruits)
	end)
end

local raycastParams = RaycastParams.new()

raycastParams.FilterDescendantsInstances = {_L.Debris.Fruits, _L.Map:FindFirstChild("Safezones"), _L.Map:FindFirstChild("TrainingAreas"), _L.Map:FindFirstChild("Gardens")}
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

function FruitGroup:render(dt)
	local character = self._player.Character

	if character then
		local root = character.PrimaryPart

		if root then
			local humanoid = character:FindFirstChild("Humanoid")

			if humanoid then
				local isMoving = humanoid.MoveDirection ~= Vector3.zero

				-- While the player harvests a plant, the fruits rush over and surround it
				local Harvest = _L.Get {"Client", "Modules", "Controllers", "Harvest"}
				local harvestTarget = Harvest and Harvest.getTarget(self._player)
				-- the harvest just finished: every fruit does a quick happy hop (staggered)
				if self._had_target and not harvestTarget then
					local i = 0
					for _, fruit in pairs(self._fruits) do
						i += 1
						FruitAnimator.react(fruit.anim, (i - 1) * 0.07 + math.random() * 0.05)
					end
				end
				self._had_target = harvestTarget ~= nil

				-- player speed picks walk vs run; standing still long enough puts the fruits to sleep
				local vel = root.AssemblyLinearVelocity
				local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
				local running = harvestTarget ~= nil or speed > RUN_SPEED
				if isMoving or harvestTarget then
					self._still_time = 0
					if self._asleep then
						-- woken up: a little startled jump (staggered), then off they go
						self._asleep = false
						local i = 0
						for _, fruit in pairs(self._fruits) do
							i += 1
							fruitShot(fruit, "Surprised", (i - 1) * 0.06)
						end
					end
				else
					self._still_time = (self._still_time or 0) + dt
					if self._still_time > SLEEP_AFTER then
						self._asleep = true
					end
				end
				local asleep = self._asleep == true

				-- the fruit being ridden (Mount system) is under the player, so hide its follower copy
				local mountedUid = self._player:GetAttribute("MountedFruit")
				for _, fruit in pairs(self._fruits) do
					local hide = fruit.uid == mountedUid
					if fruit._mount_hidden ~= hide and fruit.instance then
						fruit._mount_hidden = hide
						local list = fruit.instance:GetDescendants()
						table.insert(list, fruit.instance)
						for _, d in ipairs(list) do
							if d:IsA("BasePart") or d:IsA("Decal") then
								d.LocalTransparencyModifier = if hide then 1 else 0
							elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Highlight") then
								d.Enabled = not hide
							end
						end
					end
				end

				for fruitIndex, fruit in pairs(self._fruits) do
					fruit.last_lerp = fruit.last_lerp or root.CFrame

					local row = self:_get_row(fruitIndex)
					local column = self:_get_column(fruitIndex)

					local _, _, maxX = TableUtility.max(self:_get_row_fruits(row), function(i, v)
						return v.size.X
					end)

					local _, _, maxZ = TableUtility.max(self:_get_column_fruits(column), function(i, v)
						return v.size.Z
					end)

					local fruitInstance = fruit.instance
					local fruitUid = fruit.uid

					local fruitCf
					if harvestTarget then
						fruitCf = Harvest.getRingCFrame(harvestTarget, fruitIndex, #self._fruits, fruit.size, raycastParams)
					else
						fruitCf = self:_get_cf(fruitUid, root, maxX, maxZ)
					end

					-- zip to the plant fast, walk back normally
					local followSpeed = if harvestTarget then 14 else 8
					local lastCf = fruit.last_lerp:Lerp(fruitCf, math.clamp(dt * followSpeed, 0, 1))

					-- AnimationPack: blend Idle / Walk / Run / Sleep loops, then any one-shot on top
					local k = math.clamp(dt * BLEND_SPEED, 0, 1)
					local moveTarget = if isMoving or harvestTarget then 1 else 0
					fruit.walk_blend = (fruit.walk_blend or 0) + (moveTarget - (fruit.walk_blend or 0)) * k
					fruit.run_blend = (fruit.run_blend or 0) + ((if running then 1 else 0) - (fruit.run_blend or 0)) * k
					local sleepTarget = if asleep then 1 else 0
					fruit.sleep_blend = (fruit.sleep_blend or 0) + (sleepTarget - (fruit.sleep_blend or 0)) * math.clamp(dt * (if asleep then 1.2 else 8), 0, 1)
					local blend = fruit.walk_blend

					local t = os.clock()
					local phase = fruitIndex * PHASE_PER_FRUIT
					local stepRate = if moveTarget == 1 then math.clamp(speed / WALK_REF_SPEED, 0.8, 1.5) else 1
					fruit.move_t = (fruit.move_t or phase) + dt * stepRate
					local half = fruit.size.Y / 2

					-- your uploaded loop (Idle / Walk / Run / Sleep) drives the rig when it has loaded,
					-- otherwise the AnimationPack clips below (crossfades only when the action changes)
					local loopAction = if asleep then "Sleep" elseif moveTarget == 1 then (if running then "Run" else "Walk") else "Idle"
					local pose = CFrame.identity
					if not AnimationPack.trackLoop(fruit.tracks, loopAction, stepRate) then
						local idlePose = AnimationPack.sample("Fruit_Idle", t + phase, half)
						local movePose = AnimationPack.sample("Fruit_Walk", fruit.move_t, half):Lerp(AnimationPack.sample("Fruit_Run", fruit.move_t, half), fruit.run_blend)
						pose = idlePose:Lerp(movePose, blend):Lerp(AnimationPack.sample("Fruit_Sleep", t + phase, half), fruit.sleep_blend)
					end
					if not AnimationPack.trackBusy(fruit.tracks) then
						pose = AnimationPack.shot(fruit.anim, dt, pose, half)
					end
					FruitAnimator.setSleeping(fruit.anim, fruit.sleep_blend > 0.5)

					-- idle: slowly look around (left / right), fades out while walking or asleep
					local look = (math.sin(t * 0.45 + phase) * 0.6 + math.sin(t * 1.1 + phase * 2) * 0.2) * (1 - blend) * (1 - fruit.sleep_blend)
					local displayCf = lastCf * CFrame.Angles(0, look, 0) * pose
						* FruitAnimator.step(fruit.anim, dt)

					if fruitInstance:IsA("Model") then
						fruitInstance:PivotTo(displayCf)
					elseif fruitInstance:IsA("BasePart") then
						fruitInstance.CFrame = displayCf
					end
					FruitAnimator.afterPivot(fruit.anim)

					fruit.last_lerp = lastCf
				end
			end
		end
	end

	return
end

function FruitGroup:get(fruitUid)
	local fruitIndex, fruit = TableUtility.match(self._fruits, function(i, v)
		return v.uid == fruitUid
	end)

	return fruit, fruitIndex
end

function FruitGroup:_get_cf(fruitUid, root, maxX, maxZ)
	local fruit, fruitIndex = self:get(fruitUid)

	if fruit then
		local row = self:_get_row(fruitIndex)
		local column = self:_get_column(fruitIndex)

		local rowFruits = self:_get_row_fruits(row)
		local columnFruits = self:_get_column_fruits(column)

		local limitX = 0
		local fullX = 0

		for columnP, rowFruit in pairs(rowFruits) do
			local sx = if PRECISE_SPACING then rowFruit.size.X else maxX

			if columnP < #rowFruits then
				fullX += PADDING_X
			end

			if columnP < column then
				limitX += PADDING_X
			end

			if columnP == column then
				limitX += sx / 2
			elseif columnP < column then
				limitX += sx
			end

			fullX += sx
		end

		local limitZ = 0
		local fullZ = 0

		for rowP, columnFruit in pairs(columnFruits) do
			local sz = if PRECISE_SPACING then columnFruit.size.Z else maxZ

			if rowP < #columnFruits then
				fullZ += PADDING_Z
			end

			if rowP < row then
				limitZ += PADDING_Z
			end

			if rowP == row then
				limitZ += sz / 2
			elseif rowP < row then
				limitZ += sz
			end

			fullZ += sz
		end

		local cf = (root.CFrame - Vector3.new(0, root.Position.Y)) * CFrame.new(-fullX / 2 + limitX, 0, SPACE_BEHIND_CHARACTER + limitZ)
		local result = workspace:Raycast(cf.Position + Vector3.new(0, root.Position.Y + 15, 0), Vector3.new(0, -65, 0), raycastParams)
		local y = if result and result.Position then result.Position.Y + fruit.size.Y / 2 else root.Position.Y

		cf += Vector3.new(0, y, 0)

		return cf
	end
end

function FruitGroup:_get_row(fruitIndex)
	return math.ceil(fruitIndex / FRUITS_PER_ROW)
end

function FruitGroup:_get_column(fruitIndex)
	return if (fruitIndex % FRUITS_PER_ROW) == 0 then FRUITS_PER_ROW else (fruitIndex % FRUITS_PER_ROW)
end

function FruitGroup:_get_row_fruits(row)
	local filtered = ArrayUtility.filter(self._fruits, function(i, v)
		return self:_get_row(i) == row
	end)

	table.sort(filtered, function(a, b)
		local _, caa = self:get(a.uid)
		local _, cbb = self:get(b.uid)
		local ca = self:_get_column(caa)
		local cb = self:_get_column(cbb)
		return ca < cb
	end)

	return filtered
end

function FruitGroup:_get_column_fruits(column)
	local filtered = ArrayUtility.filter(self._fruits, function(i, v)
		return self:_get_column(i) == column
	end)

	table.sort(filtered, function(a, b)
		local _, caa = self:get(a.uid)
		local _, cbb = self:get(b.uid)
		local ca = self:_get_row(caa)
		local cb = self:_get_row(cbb)
		return ca < cb
	end)

	return filtered
end

function FruitGroup:Destroy()
	self._trove:Destroy()
end

return FruitGroup