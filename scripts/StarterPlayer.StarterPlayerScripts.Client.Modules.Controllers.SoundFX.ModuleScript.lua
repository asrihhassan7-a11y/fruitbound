--> SoundFX (client)
-- Cozy sound design layer. All sounds live in ReplicatedStorage.Assets.Sounds.Fruitbound (organised by folder)
-- and are played through the existing Audio library. Each Sound can have attributes:
--   Group     "SFX" / "Ambient" / "Music"   (volume slider it follows)
--   PitchMin / PitchMax   random pitch range, so repeats never sound identical
-- This controller adds: volume sliders in Settings, button hover/click, menu open/close,
-- footsteps per floor material, water + weather ambience and day/night/event music.

local _L = _G._L

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local Audio
local Network
local UIAnimationController

local SoundFX = {}

local VOLUMES = {
	{key = "MusicVolume", group = "MusicGroup", title = "🎵 Music Volume", default = 0.7},
	{key = "SFXVolume", group = "SFXGroup", title = "🔊 SFX Volume", default = 0.8},
	{key = "AmbientVolume", group = "AmbientGroup", title = "🌿 Ambient Volume", default = 0.6},
}

local function lib(name)
	return _L.Assets.Sounds:FindFirstChild(name, true)
end

function SoundFX.play(name, props)
	props = props or {}
	props.name = name
	pcall(Audio.Play, props)
end

-- ============================================================
-- VOLUME SLIDERS
-- ============================================================
function SoundFX._volumes(data)
	local function apply()
		local s = data:Get("settings") or {}
		for _, v in ipairs(VOLUMES) do
			local g = SoundService:FindFirstChild(v.group)
			if g then
				g.Volume = if s[v.key] ~= nil then s[v.key] else v.default
			end
		end
	end
	data:Bind("settings", apply)
	apply()

	-- rows in the Settings menu (made from the existing "Popups" row so they match the style)
	task.spawn(function()
		local gui = _L.PlayerGui:WaitForChild("Settings", 30)
		local list = gui and gui:WaitForChild("Main"):WaitForChild("Middle"):WaitForChild("Settings")
		local template = list and list:WaitForChild("Popups", 10)
		if not template then
			return
		end
		task.wait(1) -- let the Settings script wire its own rows first
		for i, v in ipairs(VOLUMES) do
			local row = template:Clone()
			row.Name = "Volume_" .. v.key
			row.LayoutOrder = 0
			local main = row:FindFirstChild("Main")
			local btn = main:FindFirstChild("StateBtn")
			if btn then
				btn:Destroy()
			end
			local icon = main:FindFirstChild("ImageLabel")
			if icon then
				icon.Visible = false
			end
			local title = main:FindFirstChild("Title")
			if title then
				title.Text = v.title
				title.AnchorPoint = Vector2.new(0, 0.5)
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.Size = UDim2.new(0.5, 0, 0.5, 0)
				title.Position = UDim2.new(0.04, 0, 0.5, 0)
			end
			local function mk(text, x, w)
				local b = Instance.new("TextButton")
				b.AnchorPoint = Vector2.new(0, 0.5)
				b.Position = UDim2.new(x, 0, 0.5, 0)
				b.Size = UDim2.new(w, 0, 0.62, 0)
				b.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
				b.Font = Enum.Font.FredokaOne
				b.TextScaled = true
				b.TextColor3 = Color3.fromRGB(95, 65, 40)
				b.Text = text
				b.Parent = main
				Instance.new("UICorner", b).CornerRadius = UDim.new(0.3, 0)
				local st = Instance.new("UIStroke", b)
				st.Color = Color3.fromRGB(70, 50, 40)
				st.Thickness = 2
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				return b
			end
			local minus = mk("-", 0.58, 0.11)
			local value = mk("80%", 0.71, 0.14)
			value.AutoButtonColor = false
			local plus = mk("+", 0.87, 0.11)
			local function current()
				local s = data:Get("settings") or {}
				return if s[v.key] ~= nil then s[v.key] else v.default
			end
			local function refresh()
				value.Text = math.floor(current() * 100 + 0.5) .. "%"
			end
			local function change(d)
				local new = math.clamp(math.round((current() + d) * 10) / 10, 0, 1)
				Network.Remote.Invoke("S_Settings_SetVolume", v.key, new)
				if v.key == "SFXVolume" then
					SoundFX.play("UI_Click")
				end
			end
			minus.MouseButton1Click:Connect(function()
				change(-0.1)
			end)
			plus.MouseButton1Click:Connect(function()
				change(0.1)
			end)
			data:Bind("settings", refresh)
			refresh()
			row.Parent = list
		end
	end)
end

-- ============================================================
-- BUTTON HOVER / CLICK + MENU OPEN / CLOSE
-- ============================================================
-- subtle hover scale + click press for HUD buttons. Only touches buttons that have no
-- UIScale of their own (or the HUD stack's "HudScale"), so existing animations are never fought.
function SoundFX._ui()
	local lastHover = 0
	local hooked = setmetatable({}, {__mode = "k"})
	local function hook(b)
		if hooked[b] or not b:IsA("GuiButton") or b:GetAttribute("NoSound") then
			return
		end
		hooked[b] = true
		-- Defer until builders have added any custom scales and tags.
		task.defer(function()
			if b.Parent then
				UIAnimationController.RegisterButton(b)
			end
		end)
		b.MouseEnter:Connect(function()
			local t = os.clock()
			if t - lastHover > 0.08 then
				lastHover = t
				SoundFX.play("UI_Hover")
			end
		end)
		local lastClick = 0
		b.MouseButton1Down:Connect(function()
			local t = os.clock()
			if t - lastClick > 0.06 then
				lastClick = t
				SoundFX.play("UI_Click")
			end
		end)
	end
	for _, d in ipairs(_L.PlayerGui:GetDescendants()) do
		hook(d)
	end
	_L.PlayerGui.DescendantAdded:Connect(hook)

	local UI = _L.Get {"Client", "Modules", "UI"}
	pcall(function()
		UI.Await()
		local last = UI._current:Get()
		UI._current:Bind(function(value)
			if value == last then
				return
			end
			if value then
				SoundFX.play("UI_Open")
			elseif last then
				SoundFX.play("UI_Close")
			end
			last = value
		end)
	end)
end

-- ============================================================
-- FOOTSTEPS (grass / wood / stone)
-- ============================================================
local STEP_KIND = {
	[Enum.Material.Grass] = "grass", [Enum.Material.LeafyGrass] = "grass", [Enum.Material.Ground] = "grass",
	[Enum.Material.Mud] = "grass", [Enum.Material.Sand] = "grass", [Enum.Material.Fabric] = "grass",
	[Enum.Material.Wood] = "wood", [Enum.Material.WoodPlanks] = "wood",
	[Enum.Material.Cobblestone] = "stone", [Enum.Material.Slate] = "stone", [Enum.Material.Brick] = "stone",
	[Enum.Material.Concrete] = "stone", [Enum.Material.Rock] = "stone", [Enum.Material.Pavement] = "stone",
}
local STEP_PITCH = {grass = 1, wood = 1.35, stone = 1.6, other = 1.2}
local STEP_VOL = {grass = 0.18, wood = 0.14, stone = 0.11, other = 0.12}

function SoundFX._footsteps()
	local function mute(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		local function silence(s)
			if s:IsA("Sound") and s.Name == "Running" then
				s.Volume = 0
			end
		end
		for _, s in ipairs(root:GetChildren()) do
			silence(s)
		end
		root.ChildAdded:Connect(silence)
	end
	if _L.Player.Character then
		task.spawn(mute, _L.Player.Character)
	end
	_L.Player.CharacterAdded:Connect(mute)

	local nextStep = 0
	local steps = {"Step_Grass1", "Step_Grass2", "Step_Grass3"}
	local lastIndex = 0
	RunService.Heartbeat:Connect(function()
		local character = _L.Player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then
			return
		end
		local moving = humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
		if not moving or root.AssemblyLinearVelocity.Magnitude < 3 then
			return
		end
		local t = os.clock()
		if t < nextStep then
			return
		end
		nextStep = t + math.clamp(5.2 / math.max(humanoid.WalkSpeed, 1), 0.2, 0.42)
		-- riding a Fruit mount: softer, slower steps
		if _L.Player:GetAttribute("MountedFruit") then
			nextStep += 0.15
		end
		local kind = STEP_KIND[humanoid.FloorMaterial] or "other"
		local i
		repeat
			i = math.random(1, #steps)
		until i ~= lastIndex or #steps == 1
		lastIndex = i
		local base = lib(steps[i])
		SoundFX.play(steps[i], {
			speed = STEP_PITCH[kind] * (0.92 + math.random() * 0.16),
			volume = STEP_VOL[kind] * (base and 1 or 1),
		})
	end)
end

-- ============================================================
-- MUSIC + EVENT AUDIO (river water, day/night music, weather layers)
-- Birds by day / crickets + frogs by night are owned by the FruitBoundAmbience
-- LocalScript (one loop each, no duplicates here).
-- Music priority: active event MusicOverride > night music > day music.
-- Event ambience (Rain, Storm, ...) layers on top. Configure it per event in
-- Databases.WorldEvents with an optional `audio` table:
--   audio = {AmbientSound = "Amb_Rain", Volume = 1, FadeTime = 3, MusicVolume = 0.75, MusicOverride = "SoundName"}
-- ============================================================
local DEFAULT_FADE = 3
local NIGHT_MUSIC_FALLBACK = 0.65 -- no night track yet: the day track plays softer at night

-- 0 during the day, 1 at night, eased over dusk (18.5-20) and dawn (5-6.5)
local function nightness(clock)
	if clock >= 20 or clock < 5 then
		return 1
	elseif clock >= 18.5 then
		return (clock - 18.5) / 1.5
	elseif clock < 6.5 then
		return 1 - (clock - 5) / 1.5
	end
	return 0
end

function SoundFX._ambience(data)
	local ambientGroup = SoundService:FindFirstChild("AmbientGroup")
	local musicGroup = SoundService:FindFirstChild("MusicGroup")
	local WorldEventsDB = _L.Get {"Common", "Modules", "Databases", "WorldEvents"}

	local function loop(name, parent, group)
		local src = lib(name)
		if not src or not src:IsA("Sound") then
			return nil
		end
		local s = src:Clone()
		s.Looped = true
		s.SoundGroup = group or ambientGroup
		s:SetAttribute("BaseVolume", src.Volume)
		s.Volume = 0
		s.Parent = parent or SoundService
		s:Play()
		return s
	end

	-- 3D water sounds: the village river + fountain (heard only nearby)
	task.spawn(function()
		local map = _L.Map
		local village = map:WaitForChild("Village", 30)
		if not village then
			return
		end
		local spots = {}
		local river = village:FindFirstChild("River")
		if river then
			for z = 60, 340, 70 do
				local a = Instance.new("Attachment")
				a.WorldPosition = Vector3.new(1400, -299.5, z)
				a.Parent = workspace.Terrain
				table.insert(spots, a)
			end
		end
		local fountain = village:FindFirstChild("Fountain")
		if fountain and fountain:FindFirstChild("Basin") then
			table.insert(spots, fountain.Basin)
		end
		for _, spot in ipairs(spots) do
			local s = loop("Amb_Water", spot)
			if s then
				s.RollOffMode = Enum.RollOffMode.InverseTapered
				s.RollOffMinDistance = 8
				s.RollOffMaxDistance = 70
				s.Volume = s:GetAttribute("BaseVolume")
				s.TimePosition = math.random() * 20
			end
		end
	end)

	-- music tracks: the existing day track, an optional night track, and per-event overrides
	local dayMusic = SoundService:FindFirstChild("Music")
	if dayMusic and dayMusic:IsA("Sound") then
		dayMusic:SetAttribute("BaseVolume", dayMusic:GetAttribute("BaseVolume") or dayMusic.Volume)
	else
		dayMusic = nil
	end
	local nightMusic = SoundService:FindFirstChild("MusicNight")
	if nightMusic and nightMusic:IsA("Sound") then
		nightMusic.Looped = true
		nightMusic.SoundGroup = nightMusic.SoundGroup or musicGroup
		nightMusic:SetAttribute("BaseVolume", nightMusic:GetAttribute("BaseVolume") or nightMusic.Volume)
		nightMusic.Volume = 0
	else
		nightMusic = loop("Music_Night", SoundService, musicGroup)
	end

	-- [sound name] = looping Sound, created once and reused (no duplicate loops on repeat events or respawn)
	local ambientLayers, musicLayers = {}, {}
	local function layer(pool, name, group)
		if typeof(name) ~= "string" or name == "" then
			return nil
		end
		if pool[name] == nil then
			pool[name] = loop(name, SoundService, group) or false
		end
		return pool[name] or nil
	end

	local function eventAudio(eventId)
		if not eventId then
			return nil
		end
		for _, e in ipairs(WorldEventsDB.Events or {}) do
			if e.id == eventId then
				return e.audio
			end
		end
		return nil
	end

	local function fadeTo(s, target, dt, fadeTime)
		if s then
			local goal = target * (s:GetAttribute("BaseVolume") or 1)
			s.Volume += (goal - s.Volume) * math.clamp(dt / math.max(fadeTime, 0.1) * 2.5, 0, 1)
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		local clock = game:GetService("Lighting").ClockTime
		local n = nightness(clock)
		local audio = eventAudio(workspace:GetAttribute("Event"))
		local fadeTime = (audio and audio.FadeTime) or DEFAULT_FADE
		local settings = data:Get("settings") or {}
		local musicOn = settings.Music ~= false

		-- weather / event ambience layers on top of everything
		local activeLayer = audio and layer(ambientLayers, audio.AmbientSound, ambientGroup)
		for _, s in pairs(ambientLayers) do
			if s then
				fadeTo(s, if s == activeLayer then (audio.Volume or 1) else 0, dt, fadeTime)
			end
		end

		-- music: event override > night > day; the event may also lower it a little
		local override = audio and layer(musicLayers, audio.MusicOverride, musicGroup)
		for _, s in pairs(musicLayers) do
			if s then
				fadeTo(s, if s == override then 1 else 0, dt, fadeTime)
			end
		end
		local duck = (audio and audio.MusicVolume) or 1
		local dayTarget, nightTarget
		if override then
			dayTarget, nightTarget = 0, 0
		elseif nightMusic then
			dayTarget, nightTarget = 1 - n, n
		else
			dayTarget, nightTarget = 1 - n * (1 - NIGHT_MUSIC_FALLBACK), 0
		end
		fadeTo(dayMusic, dayTarget * duck, dt, fadeTime)
		fadeTo(nightMusic, nightTarget * duck, dt, fadeTime)

		-- the Music setting (client-main toggles the day track) applies to every music track
		local function follow(s)
			if s and s.Playing ~= musicOn then
				s.Playing = musicOn
			end
		end
		follow(nightMusic)
		for _, s in pairs(musicLayers) do
			follow(s or nil)
		end
	end)
end

function SoundFX._init()
	Audio = _L.Get {"Common", "Library", "Audio"}
	Network = _L.Get {"Common", "Library", "Network"}
	UIAnimationController = _L.Get {"Client", "Modules", "Controllers", "UIAnimationController"}
end

function SoundFX._start()
	task.spawn(function()
		local Data = _L.Get {"Client", "Library", "Classes", "Data"}
		local data = Data.Await()
		for _, step in ipairs({"_volumes", "_ui", "_footsteps", "_ambience"}) do
			local ok, err = pcall(SoundFX[step], data)
			if not ok then
				warn("[SoundFX] " .. step .. " failed:", err)
			end
		end
	end)
end

return SoundFX
