--> WorldEvents (client)
--  * Day/night: smooth lighting from the server's day clock (Morning / Day / Evening / Night)
--  * Event visuals: rain, thunderstorm, sunny motes, rainbow arc, moonlight fireflies
--  * Top-right banner: current event + time left, and the time of day
--  * Mutated crops (model attribute "Mutation") get a colourful effect + small label

local _L = _G._L

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local DB

local START_HOUR = 7

-- lighting keyframes by hour (loops around midnight)
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local KEYS = {
	{h = 5, bright = 1.2, amb = rgb(105, 95, 115), out = rgb(125, 115, 145), top = rgb(255, 170, 130), atm = rgb(255, 190, 170), decay = rgb(160, 140, 200), dens = 0.3, tint = rgb(255, 235, 225), exp = 0.15},
	{h = 8, bright = 2.0, amb = rgb(120, 112, 105), out = rgb(160, 150, 140), top = rgb(255, 220, 180), atm = rgb(255, 230, 205), decay = rgb(150, 185, 235), dens = 0.27, tint = rgb(255, 248, 236), exp = 0.05},
	{h = 13, bright = 2.4, amb = rgb(125, 115, 105), out = rgb(170, 160, 145), top = rgb(255, 238, 212), atm = rgb(255, 238, 215), decay = rgb(150, 190, 240), dens = 0.25, tint = rgb(255, 250, 240), exp = 0},
	{h = 17.5, bright = 1.9, amb = rgb(125, 105, 95), out = rgb(178, 145, 120), top = rgb(255, 180, 110), atm = rgb(255, 200, 150), decay = rgb(200, 150, 190), dens = 0.3, tint = rgb(255, 235, 210), exp = 0.05},
	{h = 20, bright = 1.1, amb = rgb(100, 90, 120), out = rgb(125, 108, 150), top = rgb(230, 140, 150), atm = rgb(220, 160, 190), decay = rgb(110, 100, 170), dens = 0.32, tint = rgb(235, 222, 245), exp = 0.15},
	{h = 23, bright = 0.8, amb = rgb(90, 96, 130), out = rgb(105, 115, 165), top = rgb(140, 160, 230), atm = rgb(120, 140, 200), decay = rgb(60, 70, 130), dens = 0.3, tint = rgb(215, 225, 255), exp = 0.25},
	{h = 29, bright = 1.2, amb = rgb(105, 95, 115), out = rgb(125, 115, 145), top = rgb(255, 170, 130), atm = rgb(255, 190, 170), decay = rgb(160, 140, 200), dens = 0.3, tint = rgb(255, 235, 225), exp = 0.15},
}

-- how each event changes the mood (blended in/out smoothly)
local MOODS = {
	Rain = {bright = 0.75, dens = 0.12, tint = rgb(215, 225, 240), out = rgb(140, 150, 170)},
	Storm = {bright = 0.55, dens = 0.2, tint = rgb(190, 195, 225), out = rgb(115, 118, 150)},
	Sunny = {bright = 1.12, dens = -0.05, tint = rgb(255, 245, 220)},
	Rainbow = {bright = 1.05, dens = -0.03, tint = rgb(255, 245, 250)},
	Moonlight = {bright = 1.35, dens = -0.05, tint = rgb(205, 220, 255), out = rgb(140, 155, 215)},
}

local WorldEvents = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clockNow()
	local start = workspace:GetAttribute("DayStart")
	local len = workspace:GetAttribute("DayLength") or DB.DAY_LENGTH
	if not start then
		return 13
	end
	return (START_HOUR + (workspace:GetServerTimeNow() - start) / len * 24) % 24
end

local function sample(hour)
	if hour < 5 then
		hour += 24
	end
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if hour >= a.h and hour <= b.h then
			local t = (hour - a.h) / (b.h - a.h)
			t = t * t * (3 - 2 * t)
			return {
				bright = lerp(a.bright, b.bright, t), amb = a.amb:Lerp(b.amb, t), out = a.out:Lerp(b.out, t),
				top = a.top:Lerp(b.top, t), atm = a.atm:Lerp(b.atm, t), decay = a.decay:Lerp(b.decay, t),
				dens = lerp(a.dens, b.dens, t), tint = a.tint:Lerp(b.tint, t), exp = lerp(a.exp, b.exp, t),
			}
		end
	end
	return KEYS[3]
end

function WorldEvents.getPhase(hour)
	local h = if hour < 5 then hour + 24 else hour
	for _, p in ipairs(DB.PHASES) do
		if h >= p.from and h < p.to then
			return p
		end
	end
	return DB.PHASES[2]
end

local function eventInfo(id)
	for _, e in ipairs(DB.Events) do
		if e.id == id then
			return e
		end
	end
	return nil
end

-- ============================================================
-- WEATHER VISUALS (all local, follow the camera)
-- ============================================================
local weather = {}

local function makeEmitterPart(name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(120, 1, 120)
	p.Parent = workspace.CurrentCamera
	return p
end

function WorldEvents._buildWeather()
	-- rain
	local rainPart = makeEmitterPart("RainArea")
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Speed = NumberRange.new(70, 85)
	rain.Lifetime = NumberRange.new(0.9, 1.1)
	rain.Size = NumberSequence.new(0.35)
	rain.Squash = NumberSequence.new(2.5)
	rain.Color = ColorSequence.new(rgb(225, 240, 255))
	rain.Transparency = NumberSequence.new(0.25)
	rain.LightEmission = 0.4
	rain.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	rain.Rate = 0
	rain.Parent = rainPart
	weather.rain = rain
	weather.rainPart = rainPart

	-- floating motes (sunny = warm, moonlight = blue fireflies)
	local motesPart = makeEmitterPart("MotesArea")
	motesPart.Size = Vector3.new(70, 20, 70)
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	motes.Speed = NumberRange.new(0.5, 1.5)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Lifetime = NumberRange.new(4, 7)
	motes.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0)})
	motes.LightEmission = 1
	motes.Rate = 0
	motes.Parent = motesPart
	weather.motes = motes
	weather.motesPart = motesPart

	-- rainbow arc (7 bands) far away in the sky over the island
	local arc = Instance.new("Model")
	arc.Name = "RainbowArc"
	local colors = {rgb(255, 80, 80), rgb(255, 160, 60), rgb(255, 230, 70), rgb(90, 220, 110), rgb(80, 170, 255), rgb(110, 110, 240), rgb(190, 110, 240)}
	local center = Vector3.new(1000, -330, -350)
	for band, color in ipairs(colors) do
		local radius = 380 - band * 9
		local segments = 26
		for i = 0, segments - 1 do
			local a0 = math.pi * i / segments
			local a1 = math.pi * (i + 1) / segments
			local p0 = center + Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
			local p1 = center + Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
			local seg = Instance.new("Part")
			seg.Anchored = true
			seg.CanCollide = false
			seg.CanQuery = false
			seg.CanTouch = false
			seg.CastShadow = false
			seg.Material = Enum.Material.Neon
			seg.Color = color
			seg.Transparency = 1
			seg.Size = Vector3.new(9.5, (p1 - p0).Magnitude + 1, 2)
			seg.CFrame = CFrame.lookAt((p0 + p1) / 2, (p0 + p1) / 2 + Vector3.zAxis) * CFrame.Angles(0, 0, -(a0 + a1) / 2)
			seg.Parent = arc
		end
	end
	arc.Parent = workspace
	weather.arc = arc
	weather.arcAlpha = 0
end

local function setArc(alpha)
	if math.abs(alpha - weather.arcAlpha) < 0.01 then
		return
	end
	weather.arcAlpha = alpha
	for _, seg in ipairs(weather.arc:GetChildren()) do
		seg.Transparency = 1 - alpha * 0.55
	end
end

-- ============================================================
-- BANNER
-- ============================================================
local banner = {}

function WorldEvents._buildBanner()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorldEvents"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = _L.PlayerGui

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -14, 0, 14)
	holder.Size = UDim2.fromOffset(230, 80)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local list = Instance.new("UIListLayout", holder)
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right

	local function pill(height)
		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(230, height)
		f.BackgroundColor3 = rgb(255, 248, 230)
		f.BackgroundTransparency = 0.05
		f.Parent = holder
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 12)
		local s = Instance.new("UIStroke", f)
		s.Color = rgb(70, 50, 40)
		s.Thickness = 2.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		return f, s
	end
	local function label(parent, props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = rgb(95, 65, 40)
		l.TextXAlignment = Enum.TextXAlignment.Left
		for k, v in pairs(props) do
			l[k] = v
		end
		l.Parent = parent
		return l
	end

	-- time of day
	-- one small pill: "☀️ Morning • 07:40" or, during an event, "🌧️ Rain • 07:40"
	local timePill, timeStroke = pill(28)
	timePill.Size = UDim2.fromOffset(158, 28)
	banner.timeStroke = timeStroke
	banner.time = label(timePill, {Size = UDim2.new(1, -18, 1, -8), Position = UDim2.fromOffset(9, 4), TextXAlignment = Enum.TextXAlignment.Center})

	-- current event
	local eventPill, eventStroke = pill(48)
	eventPill.Visible = false
	banner.event = eventPill
	banner.eventStroke = eventStroke
	banner.title = label(eventPill, {Size = UDim2.new(1, -60, 0, 22), Position = UDim2.fromOffset(10, 4)})
	banner.desc = label(eventPill, {Size = UDim2.new(1, -60, 0, 16), Position = UDim2.fromOffset(10, 27), TextColor3 = rgb(130, 100, 70)})
	banner.timer = label(eventPill, {Size = UDim2.fromOffset(46, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Right})

	-- big toast when an event starts
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, -80)
	toast.Size = UDim2.fromOffset(420, 52)
	toast.BackgroundColor3 = rgb(255, 248, 230)
	toast.Font = Enum.Font.FredokaOne
	toast.TextScaled = true
	toast.TextColor3 = rgb(95, 65, 40)
	toast.Visible = false
	toast.Parent = gui
	Instance.new("UICorner", toast).CornerRadius = UDim.new(1, 0)
	local ts = Instance.new("UIStroke", toast)
	ts.Thickness = 3
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local pad = Instance.new("UIPadding", toast)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	banner.toast = toast
	banner.toastStroke = ts
end

local function sfx(name, props)
	local ok, SoundFX = pcall(_L.Get, {"Client", "Modules", "Controllers", "SoundFX"})
	if ok and SoundFX and SoundFX.play then
		SoundFX.play(name, props)
	end
end

local function showToast(text, color)
	local toast = banner.toast
	toast.Text = text
	banner.toastStroke.Color = color
	toast.Visible = true
	toast.Position = UDim2.new(0.5, 0, 0, -80)
	TweenService:Create(toast, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 215)}):Play()
	task.delay(4.5, function()
		if toast.Text == text then
			local out = TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0, -120)})
			out.Completed:Connect(function()
				if toast.Text == text then
					toast.Visible = false
				end
			end)
			out:Play()
		end
	end)
end

-- ============================================================
-- MUTATED CROPS
-- ============================================================
local mutated = {} -- [model] = {id, trove parts...}

local function clearMutationFx(model)
	local fx = mutated[model]
	if not fx then
		return
	end
	mutated[model] = nil
	for _, inst in ipairs(fx.instances) do
		inst:Destroy()
	end
	for part, color in pairs(fx.colors) do
		if part.Parent then
			part.Color = color
		end
	end
end

local function applyMutationFx(model)
	clearMutationFx(model)
	local id = model:GetAttribute("Mutation")
	local info = id and DB.Mutations[id]
	local root = model.PrimaryPart
	if not info or not root then
		return
	end
	local fx = {id = id, instances = {}, colors = {}, blooms = {}}
	mutated[model] = fx

	-- tint the blooms toward the mutation colour
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "Bloom" and d:IsA("BasePart") then
			fx.colors[d] = d.Color
			table.insert(fx.blooms, d)
			if info.effect ~= "rainbow" then
				d.Color = d.Color:Lerp(info.color, 0.45)
			end
		end
	end

	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 1, 0)
	att.Parent = root
	table.insert(fx.instances, att)

	local pe = Instance.new("ParticleEmitter")
	pe.LightEmission = 0.6
	pe.Rate = 6
	pe.Lifetime = NumberRange.new(1, 1.6)
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
	pe.Color = ColorSequence.new(info.color)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.Speed = NumberRange.new(1, 2.5)
	if info.effect == "drops" then
		pe.Acceleration = Vector3.new(0, -10, 0)
		pe.Squash = NumberSequence.new(1.5)
	elseif info.effect == "sparks" then
		pe.Speed = NumberRange.new(4, 7)
		pe.Lifetime = NumberRange.new(0.3, 0.5)
		pe.Rate = 14
		pe.Size = NumberSequence.new(0.18)
	elseif info.effect == "rainbow" then
		pe.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 90, 90)), ColorSequenceKeypoint.new(0.33, rgb(255, 230, 80)),
			ColorSequenceKeypoint.new(0.66, rgb(90, 200, 255)), ColorSequenceKeypoint.new(1, rgb(200, 110, 255)),
		})
		pe.Rate = 10
	elseif info.effect == "glow" or info.effect == "sun" then
		pe.Acceleration = Vector3.new(0, 1.5, 0)
		local light = Instance.new("PointLight")
		light.Color = info.color
		light.Brightness = 1.2
		light.Range = 10
		light.Parent = root
		table.insert(fx.instances, light)
	end
	pe.Parent = att

	-- small label above the crop
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 26)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = 70
	gui.AlwaysOnTop = true
	gui.Adornee = root
	gui.Parent = root
	local l = Instance.new("TextLabel", gui)
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = info.color
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = info.name .. "  x" .. info.value
	Instance.new("UICorner", l).CornerRadius = UDim.new(1, 0)
	local st = Instance.new("UIStroke", l)
	st.Color = rgb(70, 50, 40)
	st.Thickness = 1.5
	table.insert(fx.instances, gui)
	fx.label = l
end

local function watchCrop(model)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Mutation"):Connect(function()
		applyMutationFx(model)
		-- chime when one of YOUR crops mutates
		local info = DB.Mutations[model:GetAttribute("Mutation") or ""]
		if info and model:GetAttribute("Owner") == _L.Player.UserId then
			local root = model.PrimaryPart
			sfx(if (info.tier or 1) >= 4 then "Mutation_Rare" else "Mutation", {position = root and root.Position})
		end
	end)
	if model:GetAttribute("Mutation") then
		applyMutationFx(model)
	end
end

-- ============================================================
-- Village Event Board: shows the current event (and time left) or when the next one comes
function WorldEvents._eventBoard()
	local function fmt(sec)
		sec = math.max(0, math.floor(sec))
		return string.format("%d:%02d", sec // 60, sec % 60)
	end
	local list = {}
	for _, e in ipairs(DB.Events) do
		table.insert(list, e.emoji .. " " .. e.name)
	end
	local listText = table.concat(list, "   ")
	while true do
		local village = _L.Map:FindFirstChild("Village")
		local boardModel = village and village:FindFirstChild("EventBoard")
		local board = boardModel and boardModel:FindFirstChild("Board")
		local paper = board and board:FindFirstChild("Display") and board.Display:FindFirstChild("Paper")
		if paper then
			local t = workspace:GetServerTimeNow()
			local id = workspace:GetAttribute("Event")
			local info
			for _, e in ipairs(DB.Events) do
				if e.id == id then
					info = e
				end
			end
			if info then
				paper.Now.Text = info.emoji .. " " .. info.name .. " • " .. fmt((workspace:GetAttribute("EventEnds") or t) - t)
				paper.Now.TextColor3 = info.color
				paper.Info.Text = info.description or ""
			else
				local hour = game:GetService("Lighting").ClockTime
				paper.Now.Text = if hour >= 20.5 or hour < 5 then "🌙 Calm night" else "☀️ Clear skies"
				paper.Now.TextColor3 = Color3.fromRGB(70, 150, 60)
				local nextAt = workspace:GetAttribute("NextEvent")
				paper.Info.Text = if nextAt and nextAt > t then "Next event in " .. fmt(nextAt - t) else "An event could start any moment!"
			end
			paper.List.Text = listText
		end
		task.wait(1)
	end
end

function WorldEvents._init()
	DB = _L.Get {"Common", "Modules", "Databases", "WorldEvents"}
end

function WorldEvents._start()
	task.spawn(function()
		local ok, err = pcall(WorldEvents._eventBoard)
		if not ok then
			warn("[WorldEvents] event board:", err)
		end
	end)
	task.spawn(function()
		local ok, err = pcall(function()
			WorldEvents._buildWeather()
			WorldEvents._buildBanner()
		end)
		if not ok then
			warn("[WorldEvents] build failed:", err)
			return
		end

		for _, m in ipairs(CollectionService:GetTagged("HarvestBush")) do
			watchCrop(m)
		end
		CollectionService:GetInstanceAddedSignal("HarvestBush"):Connect(watchCrop)

		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		local flash = Instance.new("ColorCorrectionEffect")
		flash.Name = "LightningFlash"
		flash.Parent = Lighting

		local moodBlend = 0
		local moodId = nil
		local lastEvent = nil
		local nextFlash = 0

		RunService.RenderStepped:Connect(function(dt)
			local hour = clockNow()
			local k = sample(hour)
			local eventId = workspace:GetAttribute("Event")
			local ends = workspace:GetAttribute("EventEnds")

			-- event start/end
			if eventId ~= lastEvent then
				lastEvent = eventId
				local info = eventId and eventInfo(eventId)
				if info then
					moodId = eventId
					sfx(if eventId == "Rainbow" or eventId == "Storm" then "Event_Rare" else "Event_Start")
					showToast(info.emoji .. " " .. info.name .. "!  " .. info.description, info.color)
				end
			end

			-- smooth mood blend in/out
			local target = if eventId then 1 else 0
			moodBlend += (target - moodBlend) * math.clamp(dt * 0.6, 0, 1)
			local mood = moodId and MOODS[moodId]

			local bright, dens, tint, out = k.bright, k.dens, k.tint, k.out
			if mood then
				bright = lerp(bright, bright * (mood.bright or 1), moodBlend)
				dens = dens + (mood.dens or 0) * moodBlend
				tint = tint:Lerp(mood.tint or tint, moodBlend)
				out = out:Lerp(mood.out or out, moodBlend)
			end

			Lighting.ClockTime = hour
			Lighting.Brightness = bright
			Lighting.Ambient = k.amb
			Lighting.OutdoorAmbient = out
			Lighting.ColorShift_Top = k.top
			Lighting.ExposureCompensation = k.exp
			if atm then
				atm.Color = k.atm
				atm.Decay = k.decay
				atm.Density = math.clamp(dens, 0.05, 0.6)
			end
			if cc then
				cc.TintColor = tint
			end

			-- weather follows the camera
			local cam = workspace.CurrentCamera
			local cpos = cam.CFrame.Position
			weather.rainPart.CFrame = CFrame.new(cpos + Vector3.new(0, 40, 0))
			weather.motesPart.CFrame = CFrame.new(cpos)
			local wet = eventId == "Rain" or eventId == "Storm"
			weather.rain.Rate = if wet then (if eventId == "Storm" then 1500 else 850) * moodBlend else 0
			if eventId == "Sunny" then
				weather.motes.Color = ColorSequence.new(rgb(255, 230, 140))
				weather.motes.Rate = 10
			elseif eventId == "Moonlight" then
				weather.motes.Color = ColorSequence.new(rgb(170, 210, 255))
				weather.motes.Rate = 14
			else
				weather.motes.Rate = 0
			end
			setArc(if eventId == "Rainbow" then moodBlend else 0)

			-- lightning
			local t = os.clock()
			if eventId == "Storm" and t > nextFlash then
				nextFlash = t + math.random(5, 11)
				flash.Brightness = 0.35
				task.delay(0.2 + math.random() * 0.8, sfx, "Thunder")
				TweenService:Create(flash, TweenInfo.new(0.35), {Brightness = 0}):Play()
			end

			-- rainbow crops cycle colours
			for model, fx in pairs(mutated) do
				if not model.Parent then
					mutated[model] = nil
				elseif fx.id == "Rainbow" then
					local c = Color3.fromHSV((t * 0.25) % 1, 0.55, 1)
					for _, b in ipairs(fx.blooms) do
						b.Color = c
					end
					if fx.label then
						fx.label.BackgroundColor3 = c
					end
				end
			end

			-- banner
			local phase = WorldEvents.getPhase(hour)
			local hh = math.floor(hour)
			local mm = math.floor((hour - hh) * 60 / 10) * 10
			local pillInfo = eventId and eventInfo(eventId)
			if pillInfo then
				banner.time.Text = string.format("%s %s • %02d:%02d", pillInfo.emoji, pillInfo.name, hh, mm)
				banner.timeStroke.Color = pillInfo.color
			else
				banner.time.Text = string.format("%s %s • %02d:%02d", phase.emoji, phase.id, hh, mm)
				banner.timeStroke.Color = rgb(70, 50, 40)
			end
			local info = eventId and eventInfo(eventId)
			banner.event.Visible = false -- event name lives in the time pill; the toast announces it
			if info then
				local left = math.max(0, math.floor((ends or 0) - workspace:GetServerTimeNow()))
				banner.title.Text = info.emoji .. " " .. info.name
				banner.desc.Text = info.description
				banner.timer.Text = string.format("%d:%02d", left // 60, left % 60)
				banner.eventStroke.Color = info.color
			end
		end)
	end)
end

return WorldEvents
