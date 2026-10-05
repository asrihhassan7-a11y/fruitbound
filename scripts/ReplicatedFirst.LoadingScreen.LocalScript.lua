--> FRUITBOUND loading screen
-- Tropical, magical intro shown while the game loads. Built fully in code (no assets needed).

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

-- hide the Roblox hotbar / Backpack (Seed Tools) under the loading screen; it comes back when
-- loading finishes or Skip is pressed (BackpackVisibility keeps it hidden while other reasons remain)
local BackpackVisibility = require(script.Parent:WaitForChild("BackpackVisibility"))
BackpackVisibility.hide("Loading")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

--> Settings
local MIN_TIME = 4 -- seconds the screen stays at least
local MAX_TIME = 25 -- safety: never block the player longer than this
task.delay(60, BackpackVisibility.show, "Loading") -- safety: the hotbar always comes back, even if this script fails
local FRUITS = {"🍎", "🍌", "🍇", "🍓", "🍉", "🍍", "🥭", "🍑", "🍒", "🥝", "🍋", "🫐"}
local TIPS = {
	"Tip: Harvest plants to collect food for your fruits!",
	"Tip: Evolved fruits give way more coins.",
	"Tip: Upgrades boost your luck, coins and more.",
	"Tip: Rainbow fruits are extra rare and extra strong.",
	"Tip: Explore new areas to discover rarer fruits.",
	"Tip: Rebirth to multiply everything you earn!",
}

local function make(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	return inst
end

local FONT = Enum.Font.FredokaOne

--> Build UI
local gui = make("ScreenGui", {
	Name = "LoadingScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local bg = make("Frame", {
	Name = "Background",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = gui,
}, {
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 214, 255)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(140, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 190)),
		}),
	}),
})

-- Floating fruits layer
local fruitLayer = make("Frame", {
	Name = "Fruits",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	Parent = bg,
})

local floaters = {}
for i = 1, 22 do
	local size = math.random(40, 90)
	local lbl = make("TextLabel", {
		Text = FRUITS[math.random(#FRUITS)],
		Font = FONT,
		TextScaled = true,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextTransparency = 0.25,
		Parent = fruitLayer,
	})
	table.insert(floaters, {
		label = lbl,
		x = math.random(),
		y = math.random() * 1.2,
		speed = 0.03 + math.random() * 0.05,
		sway = math.random() * math.pi * 2,
		spin = (math.random() - 0.5) * 60,
	})
end

-- Center card
local center = make("Frame", {
	Name = "Center",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromScale(0.8, 0.5),
	BackgroundTransparency = 1,
	Parent = bg,
}, {
	make("UISizeConstraint", {MaxSize = Vector2.new(900, 420)}),
})

local logoFruit = make("TextLabel", {
	Name = "LogoFruit",
	Text = "🍎",
	Font = FONT,
	TextScaled = true,
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.18),
	Size = UDim2.fromScale(0.2, 0.36),
	Parent = center,
}, {
	make("UIAspectRatioConstraint", {AspectRatio = 1}),
})

local title = make("TextLabel", {
	Name = "Title",
	Text = "FRUITBOUND",
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromScale(1, 0.34),
	Parent = center,
}, {
	make("UIStroke", {Thickness = 5, Color = Color3.fromRGB(60, 30, 110), LineJoinMode = Enum.LineJoinMode.Round}),
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 170)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 60)),
		}),
	}),
})

local tagline = make("TextLabel", {
	Name = "Tagline",
	Text = "DISCOVER • GROW • EVOLVE • EXPLORE",
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.82),
	Size = UDim2.fromScale(0.8, 0.11),
	Parent = center,
}, {
	make("UIStroke", {Thickness = 2.5, Color = Color3.fromRGB(60, 30, 110)}),
})

-- Progress bar
local barHolder = make("Frame", {
	Name = "Bar",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.78),
	Size = UDim2.fromScale(0.5, 0.045),
	BackgroundColor3 = Color3.fromRGB(60, 30, 110),
	BackgroundTransparency = 0.35,
	Parent = bg,
}, {
	make("UICorner", {CornerRadius = UDim.new(1, 0)}),
	make("UIStroke", {Thickness = 3, Color = Color3.new(1, 1, 1)}),
	make("UISizeConstraint", {MaxSize = Vector2.new(620, 34), MinSize = Vector2.new(220, 18)}),
})

local fill = make("Frame", {
	Name = "Fill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = barHolder,
}, {
	make("UICorner", {CornerRadius = UDim.new(1, 0)}),
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 170)),
		}),
	}),
})

local percent = make("TextLabel", {
	Name = "Percent",
	Text = "Loading... 0%",
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 0.8),
	ZIndex = 2,
	Parent = barHolder,
}, {
	make("UIStroke", {Thickness = 2, Color = Color3.fromRGB(60, 30, 110)}),
})

local tip = make("TextLabel", {
	Name = "Tip",
	Text = TIPS[math.random(#TIPS)],
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.86),
	Size = UDim2.fromScale(0.7, 0.035),
	Parent = bg,
}, {
	make("UIStroke", {Thickness = 2, Color = Color3.fromRGB(60, 30, 110)}),
})

local skip = make("TextButton", {
	Name = "Skip",
	Text = "SKIP",
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 120, 170),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -24),
	Size = UDim2.fromOffset(120, 46),
	Visible = false,
	AutoButtonColor = true,
	Parent = bg,
}, {
	make("UICorner", {CornerRadius = UDim.new(0.4, 0)}),
	make("UIStroke", {Thickness = 3, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border}),
	make("UIPadding", {PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0)}),
})

gui.Parent = playerGui

--> Animation loop
local startTime = os.clock()
local shown = 0 -- displayed progress (0..1)
local target = 0 -- real progress (0..1)
local fruitIndex = 1
local nextFruitSwap = 0.6
local nextTip = 3.5

local conn = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - startTime

	for _, f in ipairs(floaters) do
		f.y -= f.speed * dt
		if f.y < -0.1 then
			f.y = 1.1
			f.x = math.random()
			f.label.Text = FRUITS[math.random(#FRUITS)]
		end
		f.label.Position = UDim2.fromScale(f.x + math.sin(t + f.sway) * 0.02, f.y)
		f.label.Rotation = math.sin(t * 0.8 + f.sway) * 15 + f.spin * 0.1
	end

	-- bouncy logo fruit
	local bounce = math.abs(math.sin(t * 3))
	logoFruit.Position = UDim2.fromScale(0.5, 0.2 - bounce * 0.06)
	logoFruit.Rotation = math.sin(t * 3) * 10
	if t >= nextFruitSwap then
		nextFruitSwap = t + 0.6
		fruitIndex = fruitIndex % #FRUITS + 1
		logoFruit.Text = FRUITS[fruitIndex]
	end

	-- title breathing
	title.Rotation = math.sin(t * 1.5) * 2

	-- tips
	if t >= nextTip then
		nextTip = t + 3.5
		tip.Text = TIPS[math.random(#TIPS)]
	end

	-- smooth progress
	local timeProgress = math.clamp(t / MIN_TIME, 0, 1)
	local goal = math.min(target, timeProgress)
	shown += (goal - shown) * math.clamp(dt * 5, 0, 1)
	fill.Size = UDim2.fromScale(shown, 1)
	percent.Text = "Loading... " .. math.floor(shown * 100 + 0.5) .. "%"
end)

--> Real loading
local skipped = false
skip.MouseButton1Click:Connect(function()
	skipped = true
end)
task.delay(6, function()
	if skip.Parent then
		skip.Visible = true
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
target = 0.4

-- Preload the game's interface images
local toPreload = {}
for _, d in ipairs(playerGui:GetDescendants()) do
	if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then
		table.insert(toPreload, d)
	end
end
local total = math.max(#toPreload, 1)
local done = 0
local batch = {}
for i, inst in ipairs(toPreload) do
	table.insert(batch, inst)
	if #batch >= 25 or i == #toPreload then
		if skipped or os.clock() - startTime > MAX_TIME then
			break
		end
		pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		done += #batch
		batch = {}
		target = 0.4 + 0.5 * (done / total)
	end
end

-- Wait for the main game UI to exist
local waited = 0
while not playerGui:FindFirstChild("Main") and not skipped and os.clock() - startTime < MAX_TIME do
	waited += task.wait(0.1)
end
target = 1

-- Respect minimum time so the animation can play
while not skipped and (os.clock() - startTime < MIN_TIME or shown < 0.98) and os.clock() - startTime < MAX_TIME do
	task.wait()
end

--> Fade out
skip.Visible = false
percent.Text = "Let's grow! 🌱"

-- Request teleport to farm so the player spawns at their own farm
-- Access the RemoteFunction directly (Network module may not be initialized yet in ReplicatedFirst)
task.spawn(function()
	pcall(function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local rf = ReplicatedStorage:WaitForChild("Common", 30)
			rf = rf and rf:WaitForChild("Library", 10)
			rf = rf and rf:WaitForChild("Network", 10)
			rf = rf and rf:WaitForChild("RemoteFunction", 10)
			if rf then
				rf:InvokeServer("S_Spawn_At_Farm", {})
			end
		end)
end)

task.wait(0.4)

BackpackVisibility.show("Loading")

local fadeInfo = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
TweenService:Create(bg, fadeInfo, {BackgroundTransparency = 1}):Play()
TweenService:Create(center, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.fromScale(0.5, -0.4)}):Play()
for _, d in ipairs(gui:GetDescendants()) do
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, fadeInfo, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fadeInfo, {Transparency = 1}):Play()
	elseif d:IsA("Frame") and d ~= bg and d.BackgroundTransparency < 1 then
		TweenService:Create(d, fadeInfo, {BackgroundTransparency = 1}):Play()
	end
end
task.wait(0.75)

conn:Disconnect()
gui:Destroy()
