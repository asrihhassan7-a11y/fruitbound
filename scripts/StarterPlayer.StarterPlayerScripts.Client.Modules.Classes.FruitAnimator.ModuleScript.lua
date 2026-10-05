--> FruitAnimator (client) - small "alive" layer shared by every fruit model
-- Used by the existing movers (FruitGroup = followers, FruitPen = pen residents); it adds NO loop of its own.
--   local anim = FruitAnimator.attach(model)       -- once, when the fruit model is built
--   local extra = FruitAnimator.step(anim, dt)     -- every frame the mover already runs: returns an offset CFrame (hop/spin)
--   FruitAnimator.afterPivot(anim)                  -- right after the mover pivots the model (keeps blinking lids on the face)
--   FruitAnimator.react(anim)                       -- happy "collected!" hop + sparkle
--   FruitAnimator.setSleeping(anim, on)             -- eyes stay closed while asleep (Fruit_Sleep)
-- The anim table is also the AnimationPack one-shot state (AnimationPack.play(anim, "Fruit_Happy")).
-- Blinking: a fruit model blinks if its main part has Attachments named "Eye"
--   (CFrame = on the face, -Z out of the face; attributes Size: Vector2 (w, h), LidColor, RefHeight).
--   No Eye attachments -> no lids, it simply doesn't blink (never breaks the face).

local FruitAnimator = {}

local BLINK_EVERY = {2.2, 6.5} -- seconds between blinks (random per fruit)
local BLINK_TIME = 0.16 -- close + open
local DOUBLE_BLINK = 0.18 -- chance of a quick double blink
local REACT_TIME = 0.5
local REACT_HOP = 1.4

local function rand(a, b)
	return a + math.random() * (b - a)
end

local function mainPart(model)
	if model:IsA("BasePart") then
		return model
	end
	-- the fruit mesh is "Handle" (with an animation rig the PrimaryPart is the invisible Root)
	return model:FindFirstChild("Handle") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

function FruitAnimator.attach(model)
	local handle = mainPart(model)
	local anim = {
		model = model,
		handle = handle,
		lids = {},
		nextBlink = rand(0.5, BLINK_EVERY[2]),
		blinkT = nil,
		doubleLeft = 0,
		reactT = nil,
	}
	if not handle then
		return anim
	end
	local hasSA = handle:FindFirstChildOfClass("SurfaceAppearance") ~= nil
	for _, eye in ipairs(handle:GetChildren()) do
		if eye:IsA("Attachment") and eye.Name == "Eye" then
			local size = eye:GetAttribute("Size")
			if typeof(size) == "Vector2" then
				local color = eye:GetAttribute("LidColor") or handle.Color
				if not hasSA and handle.Color ~= Color3.new(1, 1, 1) then
					-- stage tint: vertex colours are multiplied by the part colour, do the same for the lid
					color = Color3.new(color.R * handle.Color.R, color.G * handle.Color.G, color.B * handle.Color.B)
				end
				local lid = Instance.new("Part")
				lid.Name = "Eyelid"
				lid.Shape = Enum.PartType.Cylinder
				lid.Anchored = true
				lid.CanCollide = false
				lid.CanQuery = false
				lid.CanTouch = false
				lid.Massless = true
				lid.CastShadow = false
				lid.Material = Enum.Material.SmoothPlastic
				lid.Color = color
				lid.Transparency = 1
				lid.Size = Vector3.new(0.05, 0.05, 0.05)
				lid.Parent = model
				table.insert(anim.lids, {part = lid, eye = eye, size = size, ref = eye:GetAttribute("RefHeight") or handle.Size.Y})
			end
		end
	end
	return anim
end

-- closed amount 0..1 during a blink
local function blinkAmount(t)
	local half = BLINK_TIME / 2
	if t < half then
		return t / half
	end
	return math.max(0, 1 - (t - half) / half)
end

local function placeLids(anim, amount)
	local handle = anim.handle
	if not handle or not handle.Parent then
		return
	end
	for _, l in ipairs(anim.lids) do
		if amount <= 0.02 then
			l.part.Transparency = 1
		else
			local scale = handle.Size.Y / l.ref -- evolution stages scale the fruit
			local w, h = l.size.X * 1.15 * scale, l.size.Y * 1.15 * scale
			-- the lid closes from the top down (eyelid), a flattened disc hugging the face
			local hh = math.max(h * amount, 0.02)
			l.part.Size = Vector3.new(0.1 * scale, hh, w)
			l.part.CFrame = handle.CFrame * l.eye.CFrame * CFrame.new(0, (h - hh) / 2, -0.04 * scale) * CFrame.Angles(0, math.rad(90), 0)
			l.part.Transparency = 0
		end
	end
end

-- call every frame from the mover; returns an extra offset for the fruit (identity most of the time)
function FruitAnimator.step(anim, dt)
	if not anim then
		return CFrame.identity
	end
	-- blink timer (cheap: one number per fruit); asleep = eyes stay shut
	if #anim.lids > 0 and not anim.sleeping then
		if anim.blinkT then
			anim.blinkT += dt
			if anim.blinkT >= BLINK_TIME then
				if anim.doubleLeft > 0 then
					anim.doubleLeft -= 1
					anim.blinkT = -0.08 -- tiny gap, then blink again
				else
					anim.blinkT = nil
					anim.nextBlink = rand(BLINK_EVERY[1], BLINK_EVERY[2])
				end
				anim.needsHide = true
			end
		else
			anim.nextBlink -= dt
			if anim.nextBlink <= 0 then
				anim.blinkT = 0
				anim.doubleLeft = if math.random() < DOUBLE_BLINK then 1 else 0
			end
		end
	end

	-- happy reaction: hop + little spin + squash on landing
	if anim.reactT then
		anim.reactT += dt
		if anim.reactT < 0 then
			return CFrame.identity -- staggered start (several fruits don't jump in sync)
		end
		local p = anim.reactT / REACT_TIME
		if p >= 1 then
			anim.reactT = nil
			return CFrame.identity
		end
		local hop = math.sin(p * math.pi) * REACT_HOP
		local spin = (1 - (1 - p) ^ 3) * math.pi * 2
		return CFrame.new(0, hop, 0) * CFrame.Angles(0, spin, 0)
	end
	return CFrame.identity
end

-- after the model moved this frame: keep lids glued to the face while blinking
function FruitAnimator.afterPivot(anim)
	if not anim or #anim.lids == 0 then
		return
	end
	if anim.sleeping then
		placeLids(anim, 1)
	elseif anim.blinkT and anim.blinkT >= 0 then
		placeLids(anim, blinkAmount(anim.blinkT))
	elseif anim.needsHide or anim.blinkT then
		anim.needsHide = false
		placeLids(anim, 0)
	end
end

-- "collected!" reaction (hop, spin, a few sparkles). Safe to call often: ignored while already reacting.
function FruitAnimator.react(anim, delay)
	if not anim or anim.reactT or not anim.handle or not anim.handle.Parent then
		return
	end
	anim.reactT = -(delay or 0)
	anim.blinkT = 0 -- happy squint
	anim.doubleLeft = 0
	local emitter = anim.emitter
	if not emitter then
		local att = Instance.new("Attachment")
		att.Name = "ReactFX"
		att.Parent = anim.handle
		emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 180, 220))
		emitter.LightEmission = 0.7
		emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0)})
		emitter.Lifetime = NumberRange.new(0.4, 0.7)
		emitter.Speed = NumberRange.new(4, 7)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -8, 0)
		emitter.Rate = 0
		emitter.Enabled = false
		emitter.Parent = att
		anim.emitter = emitter
	end
	emitter:Emit(7)
end

-- eyes closed while asleep; opening them hides the lids again on the next afterPivot
function FruitAnimator.setSleeping(anim, on)
	if not anim or anim.sleeping == on then
		return
	end
	anim.sleeping = on
	if not on then
		anim.blinkT = nil
		anim.needsHide = true
	end
end

-- random little happy hop while idling (pens), so residents feel alive
function FruitAnimator.maybeIdleHop(anim, dt, chancePerSecond)
	if anim and not anim.reactT and math.random() < dt * (chancePerSecond or 0.02) then
		anim.reactT = 0.12 -- starts a smaller hop (skips the first part)
	end
end

return FruitAnimator
