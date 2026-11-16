-- Always-on HUD: coins, level, menu, zone banner, boosts, food hotbar, throw/auto buttons, toasts, popups.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Util = require(Shared.Util)
local Formulas = require(Shared.Formulas)
local Foods = require(Shared.Config.Foods)
local Zones = require(Shared.Config.Zones)
local Quests = require(Shared.Config.Quests)
local Products = require(Shared.Config.Products)
local DragonDefs = require(Shared.Config.Dragons)
local Rarities = require(Shared.Config.Rarities)
local Companions = require(Shared.Config.Companions)
local Upgrades = require(Shared.Config.Upgrades)
local DragonBuilder = require(Shared.DragonBuilder)
local Controllers = script.Parent.Parent.Controllers
local State = require(Controllers.State)
local FX = require(Controllers.FX)
local Audio = require(Controllers.Audio)
local ThrowController = require(Controllers.ThrowController)
local ZoneController = require(Controllers.ZoneController)
local Lib = require(script.Parent.Lib)
local T = Lib.Theme

local HUD = {}
local gui: ScreenGui
local refs: { [string]: any } = {}
local shownCoins = 0
local coinValue = Instance.new("NumberValue")

local MENU = {
	{ "Shop", "🛒", T.Green },
	{ "Food", "🍖", T.Orange },
	{ "Dragons", "🐉", T.Purple },
	{ "Eggs", "🥚", T.Pink },
	{ "Zones", "🗺️", T.Blue },
	{ "Quests", "📜", T.Yellow },
	{ "Daily", "🎁", T.Red },
	{ "Store", "💎", Color3.fromRGB(0, 200, 200) },
	{ "Settings", "⚙️", T.Grey },
}

local function responsiveScale(scale: UIScale)
	local function update()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local v = cam.ViewportSize
		scale.Scale = math.clamp(math.min(v.X / 1150, v.Y / 680), 0.55, 1.25)
	end
	update()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
end

-- Toasts ---------------------------------------------------------------------------
local TOAST_COLORS = {
	error = T.Red,
	success = T.Green,
	unlock = T.Yellow,
	level = T.Purple,
	quest = T.Yellow,
	purchase = Color3.fromRGB(0, 200, 200),
	Mythic = Rarities.Info.Mythic.color,
	Secret = Color3.fromRGB(40, 40, 40),
}
function HUD.toast(text: string, kind: string)
	if not refs.toasts then
		return
	end
	if #refs.toasts:GetChildren() > 5 then
		return
	end
	local f = Lib.new("Frame", { Size = UDim2.fromOffset(460, 40), BackgroundColor3 = Color3.new(1, 1, 1), Parent = refs.toasts })
	Lib.corner(f, 10)
	Lib.stroke(f)
	Lib.gradient(f, TOAST_COLORS[kind] or T.Panel)
	Lib.text({ Text = text, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = f })
	local sc = Lib.new("UIScale", { Scale = 0.6, Parent = f })
	Lib.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if kind == "error" then
		Audio.play("Error")
	elseif kind == "unlock" or kind == "Mythic" or kind == "Secret" then
		Audio.play("Unlock")
	end
	task.delay((kind == "Mythic" or kind == "Secret") and 6 or 2.6, function()
		Lib.tween(sc, 0.2, { Scale = 0 })
		task.wait(0.2)
		f:Destroy()
	end)
end

-- Viewport preview of a dragon (used by popups and the collection panel)
function HUD.viewport(def, parent: Instance, size: UDim2, position: UDim2?): ViewportFrame
	local vp = Lib.new("ViewportFrame", { Size = size, Position = position or UDim2.new(), BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.new(1, 1, 1), Parent = parent })
	local rig = DragonBuilder.build(def, { lowGfx = true })
	rig.model.Parent = vp
	DragonBuilder.pose(rig, CFrame.new(), {})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	local s = rig.scale
	cam.CFrame = CFrame.lookAt(Vector3.new(-9, 6, -11) * s, Vector3.new(0, 2.8 * s, 0.5 * s))
	cam.Parent = vp
	vp.CurrentCamera = cam
	-- slow spin
	local angle = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not vp.Parent then
			conn:Disconnect()
			return
		end
		angle += dt * 0.8
		DragonBuilder.pose(rig, CFrame.Angles(0, angle, 0), {})
	end)
	return vp
end

local function popupFrame(color: Color3): (Frame, () -> ())
	local back = Lib.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 40, Parent = gui })
	local card = Lib.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 360), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 41, Parent = back })
	Lib.corner(card, 20)
	Lib.stroke(card, color, 5)
	Lib.gradient(card, T.Panel)
	local sc = Lib.new("UIScale", { Scale = 0.2, Parent = card })
	Lib.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Lib.tween(sc, 0.2, { Scale = 0 })
		task.delay(0.2, function()
			back:Destroy()
		end)
	end
	return card, close
end

function HUD.discover(defId: string)
	local def = DragonDefs.ById[defId]
	if not def or not gui then
		return
	end
	local rarity = Rarities.Info[def.rarity]
	local card, close = popupFrame(rarity.color)
	Audio.play("Discover")
	Lib.text({ Text = "NEW DRAGON DISCOVERED!", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 12), TextColor3 = T.Yellow, Parent = card })
	HUD.viewport(def, card, UDim2.new(1, -40, 0, 200), UDim2.fromOffset(20, 56))
	Lib.text({ Text = def.name, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 256), Parent = card })
	Lib.text({ Text = def.rarity .. "  •  x" .. rarity.mult .. " rewards", TextColor3 = rarity.color, Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 298), Parent = card })
	Lib.button({ Text = "Awesome!", Color = T.Green, Size = UDim2.fromOffset(150, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Parent = card, OnClick = close })
	task.delay(rarity.rank >= 5 and 6 or 3.5, close)
end

function HUD.hatch(eggId: string, results: { string })
	local egg = Companions.EggById[eggId]
	if not egg or not gui then
		return
	end
	local best = Companions.Pets[results[1]]
	for _, id in results do
		local p = Companions.Pets[id]
		if Rarities.Info[p.rarity].rank > Rarities.Info[best.rarity].rank then
			best = p
		end
	end
	local card, close = popupFrame(Rarities.Info[best.rarity].color)
	local eggL = Lib.text({ Text = egg.icon, Stroke = false, Size = UDim2.fromOffset(160, 160), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Parent = card })
	-- shake, then crack
	task.spawn(function()
		for i = 1, 8 do
			eggL.Rotation = (i % 2 == 0 and 1 or -1) * (6 + i * 2)
			task.wait(0.09)
		end
		eggL:Destroy()
		Audio.play("Unlock")
		local row = Lib.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 230), Position = UDim2.fromOffset(10, 20), Parent = card })
		Lib.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Parent = row })
		for _, id in results do
			local pet = Companions.Pets[id]
			local def = table.clone(DragonDefs.ById[pet.look])
			def.rarity = pet.rarity
			local w = #results == 1 and 300 or 130
			local cell = Lib.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(w, 230), Parent = row })
			HUD.viewport(def, cell, UDim2.new(1, 0, 0, w == 300 and 170 or 130))
			Lib.text({ Text = def.name, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, w == 300 and 172 or 134), Parent = cell })
			Lib.text({ Text = pet.rarity, TextColor3 = Rarities.Info[pet.rarity].color, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, w == 300 and 200 or 162), Parent = cell })
			Lib.text({ Text = "+" .. math.floor(pet.bonus.coins * 100 + 0.5) .. "% coins", TextColor3 = T.Yellow, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, w == 300 and 222 or 184), Parent = cell })
		end
		Lib.button({ Text = "Nice!", Color = T.Green, Size = UDim2.fromOffset(150, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Parent = card, OnClick = close })
	end)
end

-- Build -----------------------------------------------------------------------------
function HUD.build(Panels)
	local player = Players.LocalPlayer
	gui = Lib.new("ScreenGui", { Name = "TFFD_HUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	responsiveScale(Lib.new("UIScale", { Parent = gui }))
	FX.screenGui = gui
	HUD.gui = gui

	-- coins
	local coins = Lib.new("Frame", { Name = "Coins", Position = UDim2.fromOffset(14, 66), Size = UDim2.fromOffset(250, 56), BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui })
	Lib.corner(coins, 28)
	Lib.stroke(coins)
	Lib.gradient(coins, T.Yellow)
	local coinIcon = Lib.text({ Text = "🪙", Stroke = false, Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(6, 5), Parent = coins })
	refs.coinLabel = Lib.text({ Text = "0", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -66, 1, -14), Position = UDim2.fromOffset(56, 7), Parent = coins })
	FX.coinTarget = coinIcon
	coinValue.Changed:Connect(function(v)
		refs.coinLabel.Text = Util.fmt(v)
	end)

	-- level
	local lvl = Lib.new("Frame", { Position = UDim2.fromOffset(14, 128), Size = UDim2.fromOffset(250, 34), BackgroundTransparency = 1, Parent = gui })
	refs.levelText = Lib.text({ Text = "Lv 1", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(70, 30), Parent = lvl })
	local _, xpFill = Lib.bar(lvl, UDim2.fromOffset(72, 6), UDim2.new(1, -72, 0, 22), T.Purple)
	refs.xpFill = xpFill

	-- menu
	local menu = Lib.new("Frame", { Name = "Menu", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.56, 0), Size = UDim2.fromOffset(164, 430), BackgroundTransparency = 1, Parent = gui })
	Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(76, 76), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	refs.badges = {}
	for i, m in MENU do
		local b = Lib.button({ Name = m[1], Text = "", Color = m[3], Size = UDim2.fromOffset(76, 76), LayoutOrder = i, Radius = 18, Parent = menu, OnClick = function()
			Panels.toggle(m[1])
		end })
		Lib.text({ Text = m[2], Stroke = false, Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.04), Parent = b })
		Lib.text({ Text = m[1], Size = UDim2.new(1, -6, 0.3, 0), Position = UDim2.new(0, 3, 0.66, 0), Parent = b })
		local badge = Lib.new("Frame", { Name = "Badge", Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = T.Red, ZIndex = 3, Parent = b })
		Lib.corner(badge, 11)
		Lib.stroke(badge, Color3.new(1, 1, 1), 2)
		Lib.text({ Text = "!", ZIndex = 4, Parent = badge })
		refs.badges[m[1]] = badge
	end

	-- zone banner + boosts
	local banner = Lib.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(330, 46), BackgroundColor3 = Color3.new(1, 1, 1), Parent = gui })
	Lib.corner(banner, 23)
	Lib.stroke(banner)
	Lib.gradient(banner, T.Panel)
	refs.zoneText = Lib.text({ Text = "🌄 Dragon Valley", Size = UDim2.new(1, -24, 1, -10), Position = UDim2.fromOffset(12, 5), Parent = banner })
	refs.boosts = Lib.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(500, 30), BackgroundTransparency = 1, Parent = gui })
	Lib.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = refs.boosts })
	ZoneController.Changed:Connect(function(i)
		local z = Zones.List[i]
		refs.zoneText.Text = z.icon .. " " .. z.name .. "  •  x" .. z.mult
		local sc = banner:FindFirstChildOfClass("UIScale") or Lib.new("UIScale", { Parent = banner })
		sc.Scale = 1.25
		Lib.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	-- toasts
	refs.toasts = Lib.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(460, 260), BackgroundTransparency = 1, ZIndex = 30, Parent = gui })
	Lib.new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = refs.toasts })

	-- food hotbar
	local hot = Lib.new("ScrollingFrame", { Name = "Hotbar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(560, 86), BackgroundTransparency = 1, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollBarThickness = 4, Parent = gui })
	Lib.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = hot })
	refs.hotbar = hot

	-- throw + auto
	local isTouch = UserInputService.TouchEnabled
	local throw = Lib.button({ Name = "Throw", Text = "", Color = T.Orange, Size = UDim2.fromOffset(122, 122), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -26, 1, isTouch and -180 or -24), Radius = 61, Parent = gui, OnClick = function()
		ThrowController.throwAssist()
	end })
	refs.throwIcon = Lib.text({ Text = "🫐", Stroke = false, Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.1), Parent = throw })
	Lib.text({ Text = isTouch and "THROW" or "THROW [F]", Size = UDim2.new(0.8, 0, 0.22, 0), Position = UDim2.fromScale(0.1, 0.66), Parent = throw })
	refs.auto = Lib.button({ Name = "Auto", Text = "🤖 AUTO", Color = T.Grey, Size = UDim2.fromOffset(110, 46), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -160, 1, isTouch and -186 or -30), Parent = gui, OnClick = function()
		local d = State.data
		if d then
			State.action("SetAutoThrow", not d.AutoThrow)
		end
	end })

	-- cooldown ring on throw button
	refs.cd = Lib.new("Frame", { Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, ZIndex = 2, Parent = throw })
	Lib.corner(refs.cd, 61)

	State.Toast:Connect(HUD.toast)
	State.Changed:Connect(HUD.refresh)
	RunService.Heartbeat:Connect(HUD.tick)
	return gui
end

local lastHotbarKey = ""
local function refreshHotbar(d)
	local key = d.EquippedFood
	for _, f in Foods.List do
		if d.Foods[f.id] then
			key ..= f.id
		end
	end
	if key == lastHotbarKey then
		return
	end
	lastHotbarKey = key
	Lib.clear(refs.hotbar)
	for _, f in Foods.List do
		if d.Foods[f.id] then
			local eq = d.EquippedFood == f.id
			local b = Lib.button({ Text = "", Color = eq and T.Yellow or T.Card, Size = UDim2.fromOffset(70, 70), LayoutOrder = f.order, Radius = 16, Parent = refs.hotbar, OnClick = function()
				State.action("EquipFood", f.id)
			end })
			Lib.text({ Text = f.icon, Stroke = false, Size = UDim2.new(1, 0, 0.65, 0), Parent = b })
			Lib.text({ Text = "+" .. Util.fmt(f.value), Size = UDim2.new(1, -4, 0.3, 0), Position = UDim2.new(0, 2, 0.68, 0), Parent = b })
		end
	end
	refs.throwIcon.Text = Foods.ById[d.EquippedFood] and Foods.ById[d.EquippedFood].icon or "🫐"
end

function HUD.refresh(d)
	if not gui then
		return
	end
	-- coins count-up
	if d.Coins ~= shownCoins then
		local up = d.Coins > shownCoins
		shownCoins = d.Coins
		if up and math.abs(d.Coins - coinValue.Value) < 1e15 then
			Lib.tween(coinValue, 0.35, { Value = d.Coins })
			local sc = refs.coinLabel.Parent:FindFirstChildOfClass("UIScale") or Lib.new("UIScale", { Parent = refs.coinLabel.Parent })
			sc.Scale = 1.08
			Lib.tween(sc, 0.25, { Scale = 1 })
		else
			coinValue.Value = d.Coins
		end
	end
	refs.levelText.Text = "Lv " .. d.Level
	Lib.tween(refs.xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(d.XP / Formulas.xpForLevel(d.Level), 0, 1), 1) })
	refreshHotbar(d)
	Lib.setButton(refs.auto, d.AutoThrow and "🤖 AUTO ON" or "🤖 AUTO", d.AutoThrow and T.Green or T.Grey)
	-- badges
	local now = State.serverNow()
	refs.badges.Daily.Visible = now - d.Daily.Last >= Quests.DailyCooldown
	local questReady = false
	for _, q in d.Quests.List do
		if not q.claimed and q.progress >= q.goal then
			questReady = true
		end
	end
	if not questReady then
		for _, a in Quests.Achievements do
			if not d.Achievements[a.id] then
				local v
				if a.stat == "Discovered" then
					v = Util.count(d.Dragons)
				elseif a.stat == "MaxZone" then
					v = d.MaxZone
				elseif a.stat == "Level" then
					v = d.Level
				else
					v = d.Stats[a.stat] or 0
				end
				if v >= a.goal then
					questReady = true
					break
				end
			end
		end
	end
	refs.badges.Quests.Visible = questReady
	local nextZone = Zones.List[d.MaxZone + 1]
	refs.badges.Zones.Visible = nextZone ~= nil and d.Coins >= nextZone.cost
	local upgradeReady = false
	for _, key in Upgrades.Order do
		local c = Upgrades.cost(key, d.Upgrades[key] or 0)
		if c and d.Coins >= c then
			upgradeReady = true
		end
	end
	refs.badges.Shop.Visible = upgradeReady
	local foodReady = false
	for _, f in Foods.List do
		if not d.Foods[f.id] and f.zone <= d.MaxZone and d.Coins >= f.cost then
			foodReady = true
		end
	end
	refs.badges.Food.Visible = foodReady
end

local boostKey = ""
function HUD.tick()
	local d = State.data
	if not d or not gui then
		return
	end
	-- cooldown overlay
	local since = os.clock() - ThrowController.lastThrowTime()
	local frac = math.clamp(1 - since / d.Computed.cooldown, 0, 1)
	refs.cd.Size = UDim2.fromScale(1, frac)
	-- boosts (rebuild once per second)
	local now = State.serverNow()
	local key = tostring(math.floor(now))
	if key ~= boostKey then
		boostKey = key
		Lib.clear(refs.boosts)
		for name, expiry in d.Boosts do
			if expiry > now then
				local info = Products.Boosts[name]
				local f = Lib.new("Frame", { Size = UDim2.fromOffset(130, 28), BackgroundColor3 = Color3.new(1, 1, 1), Parent = refs.boosts })
				Lib.corner(f, 14)
				Lib.stroke(f, nil, 2)
				Lib.gradient(f, name == "Lucky" and T.Green or T.Yellow)
				Lib.text({ Text = (info and info.icon or "⏱️") .. " " .. Util.time(expiry - now), Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Parent = f })
			end
		end
	end
end

return HUD
