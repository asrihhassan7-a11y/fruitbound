--> FruitStageUtility
-- The 6 evolution stages every fruit goes through:
--   0 Normal -> 1 Golden -> 2 Crystal -> 3 Magma -> 4 Galaxy -> 5 Divine
-- A fruit's stage is saved as fruitData.stage (nil = 0).
-- Each stage: higher level cap, x2 boost, costs Coins to evolve, and looks more magical.

local _L = _G._L

---------->
local FruitStageUtility

local STAGES = {
	[0] = {
		name = "Normal", prefix = "", boost = 1, cost = 0, scale = 1,
		color = nil, material = nil, light = nil, particles = nil, vines = 0, halo = false,
	},
	[1] = {
		name = "Golden", prefix = "Golden ", boost = 2, cost = 5000, scale = 1.15,
		color = Color3.fromRGB(255, 200, 50), material = Enum.Material.Foil,
		light = Color3.fromRGB(255, 210, 90), particles = {Color3.fromRGB(255, 235, 120), Color3.fromRGB(255, 190, 40)}, rate = 4,
		vines = 2, halo = false,
	},
	[2] = {
		name = "Crystal", prefix = "Crystal ", boost = 4, cost = 500000, scale = 1.3,
		color = Color3.fromRGB(140, 230, 255), material = Enum.Material.Glass, transparency = 0.25,
		light = Color3.fromRGB(120, 220, 255), particles = {Color3.fromRGB(200, 245, 255), Color3.fromRGB(110, 200, 255)}, rate = 7,
		vines = 3, halo = false,
	},
	[3] = {
		name = "Magma", prefix = "Magma ", boost = 8, cost = 50000000, scale = 1.5,
		color = Color3.fromRGB(255, 90, 30), material = Enum.Material.CrackedLava,
		light = Color3.fromRGB(255, 110, 40), particles = {Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 60, 20)}, rate = 10,
		vines = 4, halo = false,
	},
	[4] = {
		name = "Galaxy", prefix = "Galaxy ", boost = 16, cost = 5000000000, scale = 1.75,
		color = Color3.fromRGB(120, 60, 230), material = Enum.Material.ForceField,
		light = Color3.fromRGB(160, 110, 255), particles = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 120, 255), Color3.fromRGB(90, 200, 255)}, rate = 14,
		vines = 5, halo = false,
	},
	[5] = {
		name = "Divine", prefix = "Divine ", boost = 32, cost = 500000000000, scale = 2,
		color = Color3.fromRGB(255, 236, 170), material = Enum.Material.Glass, transparency = 0.05,
		light = Color3.fromRGB(255, 235, 170), particles = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 215, 90)}, rate = 20,
		vines = 6, halo = true, wings = true,
	},
}

local MAX_STAGE = 5

FruitStageUtility = {
	MAX_STAGE = MAX_STAGE,

	getStage = function(fruitData)
		return math.clamp((fruitData and fruitData.stage) or 0, 0, MAX_STAGE)
	end,

	getInfo = function(stage)
		return STAGES[math.clamp(stage or 0, 0, MAX_STAGE)]
	end,

	-- "Golden Apple", "Divine Flame Fruit", ...
	getDisplayName = function(fruitName, stage)
		return STAGES[math.clamp(stage or 0, 0, MAX_STAGE)].prefix .. fruitName
	end,

	-- Level cap grows with each stage: 1/6 of max_level at Normal ... full max_level at Divine
	getLevelCap = function(fruitInfo, fruitData)
		local maxLevel = (fruitInfo and fruitInfo.max_level) or 50
		local stage = FruitStageUtility.getStage(fruitData)
		return math.max(5, math.floor(maxLevel * (stage + 1) / (MAX_STAGE + 1)))
	end,

	-- Cost (in Coins) to evolve FROM this stage to the next one
	getEvolveCost = function(stage)
		local nextInfo = STAGES[(stage or 0) + 1]
		return nextInfo and nextInfo.cost or math.huge
	end,

	----------------------------------------------------------------
	-- VISUALS (client): transform a cloned fruit model for its stage
	----------------------------------------------------------------
	applyVisuals = function(instance, stage)
		local info = STAGES[math.clamp(stage or 0, 0, MAX_STAGE)]
		if not info or stage == 0 or not instance then
			return
		end

		local parts = {}
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
		for _, d in ipairs(instance:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		local main = (instance:IsA("Model") and instance.PrimaryPart) or parts[1]
		if not main then
			return
		end

		-- 1) Size
		if instance:IsA("Model") then
			pcall(function()
				instance:ScaleTo(instance:GetScale() * info.scale)
			end)
		else
			instance.Size *= info.scale
		end

		-- 2) Colour + material
		if stage == 1 then
			-- GOLDEN: keep the original fruit exactly as it is (ColorMap, decals,
			-- textures, face/eyes/leaves are all painted in the original maps) and
			-- only tint the surface with a subtle warm gold.
			-- Most fruits render through a SurfaceAppearance ColorMap, which ignores
			-- BasePart.Color, so they are tinted via SurfaceAppearance.Color: it
			-- multiplies the original colormap so every painted detail (face, eyes,
			-- leaves, shading) stays visible. Meshes without a SurfaceAppearance get
			-- the same warm tint on their part colour, which also multiplies their
			-- texture instead of replacing it. Nothing is destroyed or flattened.
			local tint = Color3.new(1, 1, 1):Lerp(info.color, 0.45)
			for _, p in ipairs(parts) do
				local sa = p:FindFirstChildOfClass("SurfaceAppearance")
				if sa then
					pcall(function()
						sa.Color = tint
					end)
				end
				p.Color = p.Color:Lerp(info.color, 0.45)
			end
		else
			for _, p in ipairs(parts) do
				for _, sa in ipairs(p:GetChildren()) do
					if sa:IsA("SurfaceAppearance") or sa:IsA("Decal") or sa:IsA("Texture") then
						sa:Destroy()
					end
				end
				if p:IsA("MeshPart") then
					p.TextureID = ""
				end
				p.Color = info.color
				p.Material = info.material
				if info.transparency then
					p.Transparency = info.transparency
				end
			end
		end

		-- 3) Glow
		local light = Instance.new("PointLight")
		light.Name = "StageGlow"
		light.Color = info.light
		light.Brightness = 1 + stage * 0.6
		light.Range = 6 + stage * 2
		light.Parent = main

		-- 4) Aura particles
		local attachment = Instance.new("Attachment")
		attachment.Name = "StageAura"
		attachment.Parent = main
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Sparkles"
		local keys = {}
		for i, c in ipairs(info.particles) do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #info.particles - 1), c))
		end
		if #keys == 1 then
			table.insert(keys, ColorSequenceKeypoint.new(1, info.particles[1]))
		end
		emitter.Color = ColorSequence.new(keys)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25 + stage * 0.05), NumberSequenceKeypoint.new(1, 0)})
		emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Rate = info.rate
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Parent = attachment

		-- 5) Magical vines curling around the fruit (they move with it)
		local radius = math.max(main.Size.X, main.Size.Z) * 0.55
		local height = main.Size.Y
		local vineColor = if stage >= 4 then Color3.fromRGB(190, 150, 255) elseif stage == 3 then Color3.fromRGB(255, 140, 60) else Color3.fromRGB(90, 200, 90)
		for v = 1, info.vines do
			local ang = (v / info.vines) * math.pi * 2
			for seg = 1, 3 do
				local a2 = ang + seg * 0.5
				local y = -height * 0.35 + seg * height * 0.22
				local vine = Instance.new("Part")
				vine.Name = "Vine"
				vine.Shape = Enum.PartType.Ball
				vine.Size = Vector3.new(0.35, 0.35, 0.35) * (1 + stage * 0.08)
				vine.Color = vineColor
				vine.Material = if stage >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				vine.CanCollide = false
				vine.CanTouch = false
				vine.CanQuery = false
				vine.Massless = true
				vine.Anchored = main.Anchored
				vine.CFrame = main.CFrame * CFrame.new(math.cos(a2) * radius, y, math.sin(a2) * radius)
				vine.Parent = instance
				if not main.Anchored then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = main
					weld.Part1 = vine
					weld.Parent = vine
				end
			end
		end

		-- 7) Divine wings: 3 soft feathers on each side
		if info.wings then
			local w = main.Size.X
			for side = -1, 1, 2 do
				for f = 1, 3 do
					local feather = Instance.new("Part")
					feather.Name = "Wing"
					feather.Size = Vector3.new(w * (0.95 - f * 0.12), w * 0.28, w * 0.08)
					feather.Color = Color3.fromRGB(255, 252, 240)
					feather.Material = Enum.Material.SmoothPlastic
					feather.CanCollide = false
					feather.CanTouch = false
					feather.CanQuery = false
					feather.Massless = true
					feather.Anchored = main.Anchored
					local mesh = Instance.new("SpecialMesh")
					mesh.MeshType = Enum.MeshType.Sphere
					mesh.Parent = feather
					local tilt = math.rad(20 + f * 18) * side
					feather.CFrame = main.CFrame
						* CFrame.new(side * w * 0.55, main.Size.Y * 0.15, main.Size.Z * 0.2)
						* CFrame.Angles(0, 0, tilt)
						* CFrame.new(side * feather.Size.X * 0.45, 0, 0)
					feather.Parent = instance
					if not main.Anchored then
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = main
						weld.Part1 = feather
						weld.Parent = feather
					end
				end
			end
		end

		-- 6) Divine halo
		if info.halo then
			local haloY = height * 0.75
			for h = 1, 10 do
				local a = (h / 10) * math.pi * 2
				local bead = Instance.new("Part")
				bead.Name = "Halo"
				bead.Shape = Enum.PartType.Ball
				bead.Size = Vector3.new(0.3, 0.3, 0.3)
				bead.Color = Color3.fromRGB(255, 225, 110)
				bead.Material = Enum.Material.Neon
				bead.CanCollide = false
				bead.CanTouch = false
				bead.CanQuery = false
				bead.Massless = true
				bead.Anchored = main.Anchored
				bead.CFrame = main.CFrame * CFrame.new(math.cos(a) * radius * 0.7, haloY, math.sin(a) * radius * 0.7)
				bead.Parent = instance
				if not main.Anchored then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = main
					weld.Part1 = bead
					weld.Parent = bead
				end
			end
		end
	end,

	-- (wings are added inside applyVisuals, see addWings)

	-- One-off burst when a fruit evolves
	playEvolveBurst = function(instance, stage)
		local info = STAGES[math.clamp(stage or 0, 0, MAX_STAGE)]
		local main = instance and ((instance:IsA("Model") and instance.PrimaryPart) or (instance:IsA("BasePart") and instance))
		if not main or not info or not info.particles then
			return
		end
		local aura = main:FindFirstChild("StageAura")
		local emitter = aura and aura:FindFirstChild("Sparkles")
		if emitter then
			emitter:Emit(60)
		end
	end,

	_init = function() end,
}

return FruitStageUtility
