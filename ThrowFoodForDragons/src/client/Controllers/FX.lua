-- Visual effects: food projectiles, landing puffs, eat bursts, floating reward numbers, coin fly-to-HUD.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Util = require(Shared.Util)
local Foods = require(Shared.Config.Foods)
local Trajectory = require(Shared.Trajectory)

local FX = {}
local folder: Folder
local emitterPart: Part
local sparkle: ParticleEmitter
local puff: ParticleEmitter
local projectiles = {}
local floatingCount = 0
FX.lowGfx = false
FX.coinTarget = nil :: GuiObject? -- set by HUD
FX.screenGui = nil :: ScreenGui?

local function newEmitter(tex: string, parent: Instance): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = tex
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -25, 0)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0, 1)
	pe.LightEmission = 0.5
	pe.Parent = parent
	return pe
end

function FX.burst(pos: Vector3, color: Color3, count: number?, smoke: boolean?)
	if FX.lowGfx then
		count = math.ceil((count or 12) / 3)
	end
	emitterPart.Position = pos
	local pe = smoke and puff or sparkle
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe:Emit(count or 12)
end

function FX.projectile(foodId: string, origin: Vector3, vel: Vector3, g: number, flight: number)
	local food = Foods.ById[foodId]
	if not food then
		return
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * food.size
	p.Color = food.color
	p.Material = food.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Position = origin
	if not FX.lowGfx then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, food.size * 0.35, 0)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -food.size * 0.35, 0)
		a1.Parent = p
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(food.trail, food.color)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.25
		trail.LightEmission = food.neon and 0.8 or 0.3
		trail.Parent = p
	end
	p.Parent = folder
	table.insert(projectiles, { part = p, origin = origin, vel = vel, g = g, t0 = os.clock(), flight = flight, food = food })
end

local function stepProjectiles()
	local now = os.clock()
	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		local t = now - pr.t0
		if t >= pr.flight then
			local land = Trajectory.at(pr.origin, pr.vel, pr.g, pr.flight)
			FX.burst(land, pr.food.color, 8, true)
			pr.part:Destroy()
			table.remove(projectiles, i)
		else
			pr.part.CFrame = CFrame.new(Trajectory.at(pr.origin, pr.vel, pr.g, t)) * CFrame.Angles(t * 9, t * 6, 0)
		end
	end
end

-- Floating "+123" text in the world.
function FX.floating(text: string, pos: Vector3, color: Color3, big: boolean?)
	if floatingCount > 40 then
		return
	end
	floatingCount += 1
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 220 or 150, big and 70 or 46)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 200
	bb.Adornee = att
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
	l.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = l
	bb.Parent = att
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(bb, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
	task.delay(0.6, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(1.15, function()
		att:Destroy()
		floatingCount -= 1
	end)
end

-- Little coins that fly from a world position to the HUD coin counter.
function FX.coinFly(worldPos: Vector3, n: number)
	local target = FX.coinTarget
	local gui = FX.screenGui
	local cam = workspace.CurrentCamera
	if not target or not gui or not cam or FX.lowGfx then
		return
	end
	local sp, onScreen = cam:WorldToViewportPoint(worldPos)
	if not onScreen then
		return
	end
	-- HUD ScreenGui uses IgnoreGuiInset, so viewport and GUI coordinates match
	local dest = target.AbsolutePosition + target.AbsoluteSize / 2
	for i = 1, n do
		local c = Instance.new("TextLabel")
		c.BackgroundTransparency = 1
		c.Text = "💰"
		c.TextScaled = true
		c.Size = UDim2.fromOffset(26, 26)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromOffset(sp.X + math.random(-20, 20), sp.Y + math.random(-20, 20))
		c.ZIndex = 50
		c.Parent = gui
		local tw = TweenService:Create(c, TweenInfo.new(0.55 + i * 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(dest.X, dest.Y) })
		tw:Play()
		tw.Completed:Once(function()
			c:Destroy()
		end)
	end
end

function FX.fmtReward(coins: number, crit: boolean): string
	return (crit and "CRIT! " or "") .. "+" .. Util.fmt(coins) .. " 💰"
end

function FX.start()
	folder = Instance.new("Folder")
	folder.Name = "TFFD_FX"
	folder.Parent = workspace
	emitterPart = Instance.new("Part")
	emitterPart.Name = "Emitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.one * 0.5
	emitterPart.Parent = folder
	sparkle = newEmitter("rbxasset://textures/particles/sparkles_main.dds", emitterPart)
	puff = newEmitter("rbxasset://textures/particles/smoke_main.dds", emitterPart)
	puff.Speed = NumberRange.new(3, 6)
	puff.Acceleration = Vector3.new(0, 4, 0)
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2) })
	RunService.Heartbeat:Connect(stepProjectiles)
end

return FX
