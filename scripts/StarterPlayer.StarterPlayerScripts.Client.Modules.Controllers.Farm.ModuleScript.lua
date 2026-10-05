--> Farm (client)
-- * "My Farm" button (left menu) teleports you to your farm
-- * Purchase pads turn green when you can afford them, red when you can't
-- * New farm sections grow in with a pop animation + sparkles
-- * Gnome helpers walk between the plants of their farm
-- * Windmill blades spin

local _L = _G._L

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Network
local Data
local Audio
local UI

---------->
local Farm = {}

local GROW_TIME = 0.9

-- Section grow-in: every part rises out of the ground and pops to full size
local function growIn(section)
	local builtAt = section:GetAttribute("BuiltAt") or 0
	if builtAt <= 0 or workspace:GetServerTimeNow() - builtAt > 3 then
		return
	end
	local parts = {}
	local centre = section:GetBoundingBox().Position
	for _, p in ipairs(section:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then
			table.insert(parts, p)
		end
	end
	for _, p in ipairs(parts) do
		local finalCf, finalSize = p.CFrame, p.Size
		local delayTime = math.clamp((p.Position - centre).Magnitude / 60, 0, 0.6)
		p.Size = finalSize * 0.05
		p.CFrame = finalCf - Vector3.new(0, 3, 0)
		p.LocalTransparencyModifier = 1
		task.delay(delayTime, function()
			if not p.Parent then return end
			p.LocalTransparencyModifier = 0
			TweenService:Create(p, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = finalSize, CFrame = finalCf}):Play()
		end)
	end

	-- sparkle burst in the middle
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(centre)
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 90)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 240, 110)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 200))})
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.8, 0)
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(12, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -12, 0)
	e.Rate = 0
	e.Parent = holder
	e:Emit(120)
	game:GetService("Debris"):AddItem(holder, 3)
end

-- Gnome helpers walk from plant to plant on their own farm
local helpers = {}

local function plantsOf(plotModel)
	local list = {}
	local built = plotModel:FindFirstChild("Built")
	if not built then return list end
	for _, m in ipairs(built:GetDescendants()) do
		if m:IsA("Model") and CollectionService:HasTag(m, "HarvestBush") and m.PrimaryPart then
			table.insert(list, m.PrimaryPart.Position)
		end
	end
	return list
end

local function addHelper(model)
	if helpers[model] or not model.PrimaryPart then return end
	helpers[model] = {pos = model:GetPivot().Position, target = nil, wait = math.random() * 2, t = math.random() * 10}
end

local function updateHelpers(dt)
	for model, h in pairs(helpers) do
		if not model.Parent then
			helpers[model] = nil
			continue
		end
		h.t += dt
		if not h.target then
			h.wait -= dt
			if h.wait <= 0 then
				local plotModel = model:FindFirstAncestorWhichIsA("Model")
				while plotModel and not plotModel:GetAttribute("PlotId") do
					plotModel = plotModel.Parent and plotModel.Parent:FindFirstAncestorWhichIsA("Model")
				end
				local plants = plotModel and plantsOf(plotModel) or {}
				if #plants > 0 then
					local p = plants[math.random(#plants)]
					local a = math.random() * math.pi * 2
					h.target = Vector3.new(p.X + math.cos(a) * 3.2, h.pos.Y, p.Z + math.sin(a) * 3.2)
					h.look = Vector3.new(p.X, h.pos.Y, p.Z)
				end
				h.wait = 1.5
			end
		else
			local diff = h.target - h.pos
			local step = 9 * dt
			if diff.Magnitude <= step then
				h.pos = h.target
				h.target = nil
				h.wait = 1.2 + math.random() * 1.5 -- "harvesting"
			else
				h.pos += diff.Unit * step
				h.look = h.pos + diff.Unit
			end
		end
		local moving = h.target ~= nil
		local hop = if moving then math.abs(math.sin(h.t * 12)) * 0.6 else math.abs(math.sin(h.t * 5)) * 0.15
		local tilt = if moving then math.sin(h.t * 12) * 0.12 else 0
		local look = h.look or (h.pos + Vector3.new(0, 0, -1))
		local cf = CFrame.lookAt(h.pos, Vector3.new(look.X, h.pos.Y, look.Z))
		model:PivotTo(cf * CFrame.new(0, hop, 0) * CFrame.Angles(0, 0, tilt))
	end
end

-- Windmill blades etc.
local spinners = {}
local function addSpinner(model)
	if model.PrimaryPart then
		spinners[model] = model:GetPivot()
	end
end

function Farm._init()
	Network = _L.Get {"Common", "Library", "Network"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	UI = _L.Get {"Client", "Modules", "UI"}
end

function Farm._start()
	local player = Players.LocalPlayer

	-- My Farm button
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		local main = playerGui:WaitForChild("Main", 60)
		local button = main and main:WaitForChild("Left"):WaitForChild("Content"):WaitForChild("MyFarm", 30)
		if button then
			-- Travel menu: just My Farm and the Village. Shops, Fishing, Wild Fruit areas and the
			-- Mystic Glade are reached on foot from the Village (the server only accepts these ids)
			local DESTINATIONS = {
				{id = "MyFarm", text = "🏡 My Farm", color = Color3.fromRGB(110, 190, 80)},
				{id = "Village", text = "🌻 Village", color = Color3.fromRGB(255, 185, 70)},
			}
			local ROW = 72
			local busy = false
			local menu
			local function go(id)
				if busy then return end
				busy = true
				if menu then menu.Enabled = false end
				local ok = Network.Remote.Invoke("S_Farm_Teleport", id)
				if ok and Audio then
					Audio.Play({name = "Success1"})
				end
				task.wait(3) -- matches the server's travel cooldown
				busy = false
			end
			-- the left button shows the area you're in now; the server sets TravelArea on every
			-- teleport (travel, respawn, Back to Spawn), so it can't disagree with where you are
			local AREA_TEXT = {MyFarm = "My Farm", Village = "Village"}
			local function showArea()
				local title = button:FindFirstChild("Title")
				local text = AREA_TEXT[player:GetAttribute("TravelArea")]
				if text and title and title:IsA("TextLabel") then
					title.Text = text
				end
			end
			showArea()
			player:GetAttributeChangedSignal("TravelArea"):Connect(showArea)
			local function buildMenu()
				menu = Instance.new("ScreenGui")
				menu.Name = "TravelMenu"
				menu.ResetOnSpawn = false
				menu.DisplayOrder = 8
				menu.Enabled = false
				menu.Parent = playerGui
				local dim = Instance.new("TextButton")
				dim.Text = ""
				dim.AutoButtonColor = false
				dim.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
				dim.BackgroundTransparency = 0.6
				dim.Size = UDim2.fromScale(1, 1)
				dim.Parent = menu
				dim.MouseButton1Click:Connect(function() menu.Enabled = false end)
				local panel = Instance.new("Frame")
				panel.AnchorPoint = Vector2.new(0.5, 0.5)
				panel.Position = UDim2.fromScale(0.5, 0.52)
				panel.Size = UDim2.fromOffset(320, 60 + #DESTINATIONS * ROW)
				panel.BackgroundColor3 = Color3.fromRGB(245, 232, 200)
				panel.Parent = menu
				Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
				local ps = Instance.new("UIStroke") ps.Color = Color3.fromRGB(70, 140, 60) ps.Thickness = 4 ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border ps.Parent = panel
				local sc = Instance.new("UIScale") sc.Parent = panel
				local function rescale()
					local vp = workspace.CurrentCamera.ViewportSize
					sc.Scale = math.clamp((vp.Y - 60) / (60 + #DESTINATIONS * ROW), 0.55, 1)
				end
				rescale()
				workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
				local title = Instance.new("TextLabel")
				title.BackgroundTransparency = 1
				title.Size = UDim2.new(1, -60, 0, 34)
				title.Position = UDim2.fromOffset(14, 10)
				title.Font = Enum.Font.FredokaOne
				title.TextScaled = true
				title.TextXAlignment = Enum.TextXAlignment.Left
				title.TextColor3 = Color3.fromRGB(90, 60, 30)
				title.Text = "🧭 Travel"
				title.Parent = panel
				local close = Instance.new("TextButton")
				close.AnchorPoint = Vector2.new(1, 0)
				close.Position = UDim2.new(1, -10, 0, 10)
				close.Size = UDim2.fromOffset(36, 36)
				close.BackgroundColor3 = Color3.fromRGB(235, 80, 80)
				close.Font = Enum.Font.FredokaOne
				close.TextScaled = true
				close.TextColor3 = Color3.new(1, 1, 1)
				close.Text = "X"
				close.Parent = panel
				Instance.new("UICorner", close).CornerRadius = UDim.new(0, 10)
				close.MouseButton1Click:Connect(function() menu.Enabled = false end)
				for i, d in ipairs(DESTINATIONS) do
					local b = Instance.new("TextButton")
					b.Name = d.id
					b.Size = UDim2.new(1, -24, 0, ROW - 10)
					b.Position = UDim2.fromOffset(12, 52 + (i - 1) * ROW)
					b.BackgroundColor3 = d.color
					b.Font = Enum.Font.FredokaOne
					b.TextScaled = true
					b.TextColor3 = Color3.new(1, 1, 1)
					b.Text = d.text
					b.Parent = panel
					Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
					local st = Instance.new("UIStroke") st.Color = Color3.fromRGB(40, 30, 20) st.Thickness = 1.5 st.Parent = b
					local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0, 12) pad.PaddingBottom = UDim.new(0, 12) pad.Parent = b
					b.MouseButton1Click:Connect(function() go(d.id) end)
				end
			end
			button.MouseButton1Click:Connect(function()
				if not menu then buildMenu() end
				menu.Enabled = not menu.Enabled
				if menu.Enabled and game:GetService("UserInputService"):GetLastInputType().Name:find("Gamepad") then
					game:GetService("GuiService").SelectedObject = menu:FindFirstChild("MyFarm", true)
				end
			end)
		end
	end)

	-- sections growing in (any farm: everyone sees farms grow)
	local island = workspace:WaitForChild("__MAP"):WaitForChild("FarmIsland", 60)
	if island then
		for _, plot in ipairs(island.Plots:GetChildren()) do
			local built = plot:WaitForChild("Built", 10)
			if built then
				built.ChildAdded:Connect(function(section)
					task.wait() -- let all parts arrive
					if section:IsA("Model") then
						growIn(section)
					end
				end)
			end
		end
	end

	-- helpers + spinners (they can stream in/out)
	for _, m in ipairs(CollectionService:GetTagged("FarmHelper")) do addHelper(m) end
	CollectionService:GetInstanceAddedSignal("FarmHelper"):Connect(function(m) task.wait() addHelper(m) end)
	for _, m in ipairs(CollectionService:GetTagged("FarmSpin")) do addSpinner(m) end
	CollectionService:GetInstanceAddedSignal("FarmSpin"):Connect(function(m) task.wait() addSpinner(m) end)

	local spinAngle = 0
	RunService.RenderStepped:Connect(function(dt)
		updateHelpers(dt)
		spinAngle += dt * 1.2
		for model, base in pairs(spinners) do
			if model.Parent then
				model:PivotTo(base * CFrame.Angles(0, 0, spinAngle))
			else
				spinners[model] = nil
			end
		end
	end)

	-- pad colours: green = affordable, red = not yet
	local data = Data.Await()
	if data then
		local function refreshPads()
			local coins = data:Get({"stats", "Strength"}) or 0
			for _, pad in ipairs(CollectionService:GetTagged("FarmPad")) do
				if pad:GetAttribute("Owner") == player.UserId then
					local can = coins >= (pad:GetAttribute("Cost") or 0)
					pad.Color = if can then Color3.fromRGB(120, 230, 100) else Color3.fromRGB(255, 110, 110)
					local gui = pad:FindFirstChild("PadGui")
					local price = gui and gui:FindFirstChild("Price", true)
					if price then
						price.TextColor3 = if can then Color3.fromRGB(80, 190, 70) else Color3.fromRGB(230, 80, 80)
					end
				else
					-- other players' pads are hidden to keep things clean
					for _, p in ipairs(pad.Parent and pad.Parent:GetDescendants() or {}) do
						if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end
					end
					local gui = pad:FindFirstChild("PadGui")
					if gui then gui.Enabled = false end
				end
			end
		end
		data:Bind({"stats", "Strength"}, refreshPads)
		CollectionService:GetInstanceAddedSignal("FarmPad"):Connect(function() task.wait() refreshPads() end)
	end

	Network.Remote.Fired("C_Farm_Upgraded", function(id)
		if Audio then
			Audio.Play({name = "Success2"})
		end
	end)

	Network.Remote.Fired("C_Farm_Collected", function(position)
		if Audio then
			Audio.Play({name = "Reward1"})
		end
		local holder = Instance.new("Part")
		holder.Anchored = true holder.CanCollide = false holder.CanQuery = false holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
		holder.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 215, 60))
		e.LightEmission = 0.5
		e.Size = NumberSequence.new(0.6, 0.2)
		e.Lifetime = NumberRange.new(0.8, 1.2)
		e.Speed = NumberRange.new(10, 16)
		e.SpreadAngle = Vector2.new(50, 50)
		e.Acceleration = Vector3.new(0, -35, 0)
		e.EmissionDirection = Enum.NormalId.Top
		e.Rate = 0
		e.Parent = holder
		e:Emit(50)
		game:GetService("Debris"):AddItem(holder, 2)
	end)
end

return Farm
