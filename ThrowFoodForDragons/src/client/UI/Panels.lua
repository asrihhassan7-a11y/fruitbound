-- All menu panels. Each panel builds once and exposes refresh(data); only the open panel refreshes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Util = require(Shared.Util)
local Foods = require(Shared.Config.Foods)
local Zones = require(Shared.Config.Zones)
local Upgrades = require(Shared.Config.Upgrades)
local DragonDefs = require(Shared.Config.Dragons)
local Rarities = require(Shared.Config.Rarities)
local Companions = require(Shared.Config.Companions)
local Quests = require(Shared.Config.Quests)
local Products = require(Shared.Config.Products)
local Controllers = script.Parent.Parent.Controllers
local State = require(Controllers.State)
local Audio = require(Controllers.Audio)
local Lib = require(script.Parent.Lib)
local HUD = require(script.Parent.HUD)
local T = Lib.Theme

local Panels = {}
local defs = {}
local built: { [string]: { frame: Frame, scale: UIScale, refresh: (any) -> () } } = {}
local current: string? = nil
local root: ScreenGui
local refreshQueued = false

-- helpers ------------------------------------------------------------------------
local function scroll(parent: Instance, pos: UDim2, size: UDim2, grid: Vector2?): ScrollingFrame
	local s = Lib.new("ScrollingFrame", { Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = T.Sub, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = parent })
	if grid then
		Lib.new("UIGridLayout", { CellSize = UDim2.fromOffset(grid.X, grid.Y), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = s })
	else
		Lib.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = s })
	end
	Lib.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), Parent = s })
	return s
end

local function tabs(parent: Instance, names: { string }, onSwitch: (string) -> ()): () -> string
	local bar = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = parent })
	Lib.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = bar })
	local active = names[1]
	local buttons = {}
	local function paint()
		for n, b in buttons do
			Lib.setButton(b, nil, n == active and T.Yellow or T.Card)
		end
	end
	for i, n in names do
		buttons[n] = Lib.button({ Text = n, Color = T.Card, Size = UDim2.fromOffset(170, 38), LayoutOrder = i, Parent = bar, OnClick = function()
			active = n
			paint()
			onSwitch(n)
		end })
	end
	paint()
	return function()
		return active
	end
end

local function affordColor(d, cost: number): Color3
	return d.Coins >= cost and T.Green or T.Grey
end

-- Panel shell ---------------------------------------------------------------------
local function buildPanel(name: string)
	local def = defs[name]
	local frame = Lib.new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromOffset(700, 460), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 10, Parent = root })
	Lib.corner(frame, 22)
	Lib.stroke(frame, T.Stroke, 4)
	Lib.gradient(frame, T.Panel)
	local sc = Lib.new("UIScale", { Scale = 0, Parent = frame })
	local header = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Color3.new(1, 1, 1), Parent = frame })
	Lib.corner(header, 22)
	Lib.gradient(header, def.color)
	Lib.text({ Text = def.icon .. "  " .. def.title, Size = UDim2.new(1, -120, 0, 42), Position = UDim2.fromOffset(20, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	Lib.button({ Text = "✕", Color = T.Red, Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Radius = 23, Parent = header, OnClick = function()
		Panels.close()
	end })
	local content = Lib.new("Frame", { Name = "Content", Position = UDim2.fromOffset(16, 68), Size = UDim2.new(1, -32, 1, -80), BackgroundTransparency = 1, Parent = frame })
	built[name] = { frame = frame, scale = sc, refresh = def.build(content) }
end

function Panels.open(name: string)
	if current == name then
		return
	end
	Panels.close()
	if not built[name] then
		buildPanel(name)
	end
	local p = built[name]
	current = name
	p.frame.Visible = true
	p.scale.Scale = 0.6
	Lib.tween(p.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	if State.data then
		p.refresh(State.data)
	end
end

function Panels.close()
	if not current then
		return
	end
	local p = built[current]
	current = nil
	local tw = Lib.tween(p.scale, 0.15, { Scale = 0 })
	tw.Completed:Once(function()
		if p.scale.Scale == 0 then
			p.frame.Visible = false
		end
	end)
end

function Panels.toggle(name: string)
	if current == name then
		Panels.close()
	else
		Panels.open(name)
	end
end

-- SHOP (upgrades) -------------------------------------------------------------------
defs.Shop = { title = "Upgrades", icon = "🛒", color = T.Green, build = function(content)
	local list = scroll(content, UDim2.new(), UDim2.fromScale(1, 1))
	local rows = {}
	for i, key in Upgrades.Order do
		local u = Upgrades.Defs[key]
		local row = Lib.card({ Size = UDim2.new(1, -10, 0, 78), LayoutOrder = i, Parent = list })
		Lib.text({ Text = u.icon, Stroke = false, Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(8, 9), Parent = row })
		local title = Lib.text({ Text = u.name, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, -70, 0, 30), Position = UDim2.fromOffset(76, 8), Parent = row })
		local info = Lib.text({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Sub, Size = UDim2.new(0.6, -70, 0, 24), Position = UDim2.fromOffset(76, 42), Parent = row })
		local btn = Lib.button({ Text = "", Size = UDim2.fromOffset(170, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = row, OnClick = function()
			local r = State.action("BuyUpgrade", key)
			if r.ok then
				Audio.play("Unlock")
			end
		end })
		rows[key] = { title = title, info = info, btn = btn }
	end
	return function(d)
		for key, r in rows do
			local lvl = d.Upgrades[key] or 0
			local u = Upgrades.Defs[key]
			local cost = Upgrades.cost(key, lvl)
			r.title.Text = u.name .. "  (Lv " .. lvl .. "/" .. u.max .. ")"
			r.info.Text = cost and (u.desc .. ": " .. Upgrades.describe(key, lvl)) or (u.desc .. " — MAXED")
			Lib.setButton(r.btn, cost and ("🪙 " .. Util.fmt(cost)) or "MAX", cost and affordColor(d, cost) or T.Purple)
		end
	end
end }

-- FOOD -------------------------------------------------------------------------------
defs.Food = { title = "Dragon Food", icon = "🍖", color = T.Orange, build = function(content)
	local grid = scroll(content, UDim2.new(), UDim2.fromScale(1, 1), Vector2.new(150, 186))
	local cards = {}
	for _, f in Foods.List do
		local card = Lib.card({ LayoutOrder = f.order, Parent = grid })
		Lib.text({ Text = f.icon, Stroke = false, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 6), Parent = card })
		Lib.text({ Text = f.name, Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 68), Parent = card })
		Lib.text({ Text = "+" .. Util.fmt(f.value) .. " 🪙 / feed", TextColor3 = T.Yellow, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 94), Parent = card })
		local btn = Lib.button({ Text = "", Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -52), Parent = card, OnClick = function()
			local d = State.data
			if not d then
				return
			end
			if d.Foods[f.id] then
				State.action("EquipFood", f.id)
			else
				State.action("BuyFood", f.id)
			end
		end })
		cards[f.id] = { card = card, btn = btn }
	end
	return function(d)
		for id, c in cards do
			local f = Foods.ById[id]
			local stroke = c.card:FindFirstChildOfClass("UIStroke")
			if d.EquippedFood == id then
				Lib.setButton(c.btn, "EQUIPPED", T.Yellow)
				stroke.Color = T.Yellow
			elseif d.Foods[id] then
				Lib.setButton(c.btn, "Equip", T.Blue)
				stroke.Color = T.Stroke
			elseif f.zone > d.MaxZone then
				Lib.setButton(c.btn, "🔒 " .. Zones.List[f.zone].name, T.Grey)
				stroke.Color = T.Stroke
			else
				Lib.setButton(c.btn, "🪙 " .. Util.fmt(f.cost), affordColor(d, f.cost))
				stroke.Color = T.Stroke
			end
		end
	end
end }

-- DRAGONS (collection) --------------------------------------------------------------
defs.Dragons = { title = "Dragon Collection", icon = "🐉", color = T.Purple, build = function(content)
	local progress = Lib.text({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 0, 30), Parent = content })
	local _, fill = Lib.bar(content, UDim2.new(0.5, 0, 0, 6), UDim2.new(0.5, 0, 0, 22), T.Purple)
	local grid = scroll(content, UDim2.fromOffset(0, 40), UDim2.new(1, 0, 1, -40), Vector2.new(120, 140))
	local detail
	local function showDetail(def)
		if detail then
			detail:Destroy()
		end
		local rarity = Rarities.Info[def.rarity]
		detail = Lib.card({ Size = UDim2.fromScale(1, 1), Color = T.PanelDark, StrokeColor = rarity.color, Parent = content })
		detail.ZIndex = 5
		HUD.viewport(def, detail, UDim2.new(0.5, 0, 1, -20), UDim2.fromOffset(10, 10))
		local x = UDim.new(0.5, 10)
		Lib.text({ Text = def.name, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, -30, 0, 40), Position = UDim2.new(x, UDim.new(0, 20)), Parent = detail })
		Lib.text({ Text = def.rarity .. "  •  x" .. rarity.mult .. " rewards", TextColor3 = rarity.color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, -30, 0, 28), Position = UDim2.new(x, UDim.new(0, 64)), Parent = detail })
		local zoneName = def.zone == 0 and "Anywhere (event)" or Zones.List[def.zone].name
		Lib.text({ Text = "📍 " .. zoneName, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Sub, Size = UDim2.new(0.5, -30, 0, 24), Position = UDim2.new(x, UDim.new(0, 100)), Parent = detail })
		Lib.text({ Text = "🍽️ Fed " .. Util.fmt((State.data and State.data.Dragons[def.id]) or 0) .. " times", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Sub, Size = UDim2.new(0.5, -30, 0, 24), Position = UDim2.new(x, UDim.new(0, 130)), Parent = detail })
		Lib.text({ Text = def.desc, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(0.5, -30, 0, 80), Position = UDim2.new(x, UDim.new(0, 166)), Parent = detail })
		Lib.button({ Text = "Back", Color = T.Blue, Size = UDim2.fromOffset(130, 44), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Parent = detail, OnClick = function()
			detail:Destroy()
			detail = nil
		end })
	end
	local cards = {}
	for _, def in DragonDefs.List do
		local rarity = Rarities.Info[def.rarity]
		local card = Lib.card({ LayoutOrder = def.order, StrokeColor = rarity.color, Parent = grid })
		local circle = Lib.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = def.body, Parent = card })
		Lib.corner(circle, 32)
		Lib.stroke(circle, def.accent, 3)
		local icon = Lib.text({ Text = "🐉", Stroke = false, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Parent = circle })
		local nameL = Lib.text({ Text = def.name, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 78), Parent = card })
		Lib.text({ Text = def.rarity, TextColor3 = rarity.color, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 102), Parent = card })
		local click = Lib.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = card })
		click.Activated:Connect(function()
			if State.data and State.data.Dragons[def.id] then
				Audio.play("Click")
				showDetail(def)
			end
		end)
		cards[def.id] = { circle = circle, icon = icon, name = nameL }
	end
	return function(d)
		local n = 0
		for id, c in cards do
			local def = DragonDefs.ById[id]
			local found = d.Dragons[id] ~= nil
			if found then
				n += 1
			end
			c.circle.BackgroundColor3 = found and def.body or Color3.fromRGB(25, 20, 40)
			c.icon.Text = found and "🐉" or "❔"
			c.name.Text = found and def.name or "???"
		end
		progress.Text = "Discovered " .. n .. " / " .. #DragonDefs.List
		fill.Size = UDim2.fromScale(n / #DragonDefs.List, 1)
	end
end }

-- EGGS / COMPANIONS ------------------------------------------------------------------
defs.Eggs = { title = "Companion Dragons", icon = "🥚", color = T.Pink, build = function(content)
	local eggsView, petsView
	local active = tabs(content, { "Eggs", "My Companions" }, function(n)
		eggsView.Visible = n == "Eggs"
		petsView.Visible = n ~= "Eggs"
		if State.data then
			Panels.refreshNow()
		end
	end)
	eggsView = scroll(content, UDim2.fromOffset(0, 48), UDim2.new(1, 0, 1, -48))
	petsView = Lib.new("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, Visible = false, Parent = content })
	local petsInfo = Lib.text({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.6, 0, 0, 30), Parent = petsView })
	Lib.button({ Text = "⭐ Equip Best", Color = T.Yellow, Size = UDim2.fromOffset(170, 38), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Parent = petsView, OnClick = function()
		State.action("EquipBest")
	end })
	local petGrid = scroll(petsView, UDim2.fromOffset(0, 44), UDim2.new(1, 0, 1, -44), Vector2.new(124, 170))

	local eggButtons = {}
	for i, egg in Companions.Eggs do
		local row = Lib.card({ Size = UDim2.new(1, -10, 0, 120), LayoutOrder = i, Parent = eggsView })
		Lib.text({ Text = egg.icon, Stroke = false, Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(10, 18), Parent = row })
		Lib.text({ Text = egg.name, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.4, 0, 0, 30), Position = UDim2.fromOffset(104, 8), Parent = row })
		local odds = {}
		for _, p in egg.pets do
			table.insert(odds, string.format("%s %s%%", DragonDefs.ById[p.look].name, p.weight >= 1 and tostring(p.weight) or string.format("%.1f", p.weight)))
		end
		Lib.text({ Text = table.concat(odds, "  •  "), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Sub, Size = UDim2.new(1, -300, 0, 66), Position = UDim2.fromOffset(104, 42), Parent = row })
		local b1 = Lib.button({ Text = "", Size = UDim2.fromOffset(170, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Parent = row, OnClick = function()
			local r = State.action("HatchEgg", { egg = egg.id, count = 1 })
			if r.ok and r.data then
				HUD.hatch(egg.id, r.data)
			end
		end })
		local b3 = Lib.button({ Text = "", Size = UDim2.fromOffset(170, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 62), Parent = row, OnClick = function()
			local r = State.action("HatchEgg", { egg = egg.id, count = 3 })
			if r.ok and r.data then
				HUD.hatch(egg.id, r.data)
			end
		end })
		eggButtons[egg.id] = { b1 = b1, b3 = b3 }
	end

	local lastPetsKey = ""
	return function(d)
		for id, b in eggButtons do
			local egg = Companions.EggById[id]
			if egg.zone > d.MaxZone then
				Lib.setButton(b.b1, "🔒 " .. Zones.List[egg.zone].name, T.Grey)
				Lib.setButton(b.b3, "🔒 Locked", T.Grey)
			else
				Lib.setButton(b.b1, "x1  🪙 " .. Util.fmt(egg.cost), affordColor(d, egg.cost))
				Lib.setButton(b.b3, "x3  🪙 " .. Util.fmt(egg.cost * 3), affordColor(d, egg.cost * 3))
			end
		end
		if active() ~= "My Companions" then
			return
		end
		local total = Util.count(d.Pets)
		petsInfo.Text = string.format("Equipped %d/%d  •  Storage %d/%d", #d.Equipped, d.Computed.equipSlots, total, d.Computed.storage)
		local key = table.concat(d.Equipped, ",") .. "|" .. total .. "|" .. d.NextUid
		if key == lastPetsKey then
			return
		end
		lastPetsKey = key
		Lib.clear(petGrid)
		local list = {}
		for uid, petId in d.Pets do
			local p = Companions.Pets[petId]
			if p then
				table.insert(list, { uid = uid, pet = p, eq = table.find(d.Equipped, uid) ~= nil })
			end
		end
		table.sort(list, function(a, b)
			if a.eq ~= b.eq then
				return a.eq
			end
			return a.pet.score > b.pet.score
		end)
		for i, e in ipairs(list) do
			local rarity = Rarities.Info[e.pet.rarity]
			local look = DragonDefs.ById[e.pet.look]
			local card = Lib.card({ LayoutOrder = i, StrokeColor = e.eq and T.Yellow or rarity.color, Parent = petGrid })
			local circle = Lib.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = look.body, Parent = card })
			Lib.corner(circle, 26)
			Lib.stroke(circle, look.accent, 3)
			Lib.text({ Text = "🐲", Stroke = false, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Parent = circle })
			Lib.text({ Text = look.name, Size = UDim2.new(1, -6, 0, 20), Position = UDim2.fromOffset(3, 60), Parent = card })
			local bonus = "+" .. math.floor(e.pet.bonus.coins * 100 + 0.5) .. "% 🪙"
			if e.pet.bonus.power then
				bonus ..= " +" .. math.floor(e.pet.bonus.power * 100 + 0.5) .. "% 💪"
			elseif e.pet.bonus.crit then
				bonus ..= " +" .. math.floor(e.pet.bonus.crit * 100 + 0.5) .. "% 🍀"
			elseif e.pet.bonus.xp then
				bonus ..= " +" .. math.floor(e.pet.bonus.xp * 100 + 0.5) .. "% ⭐"
			end
			Lib.text({ Text = bonus, TextColor3 = rarity.color, Size = UDim2.new(1, -6, 0, 18), Position = UDim2.fromOffset(3, 82), Parent = card })
			Lib.button({ Text = e.eq and "Unequip" or "Equip", Color = e.eq and T.Orange or T.Green, Size = UDim2.new(1, -12, 0, 32), Position = UDim2.fromOffset(6, 104), Parent = card, OnClick = function()
				State.action(e.eq and "UnequipPet" or "EquipPet", e.uid)
			end })
			Lib.button({ Text = "Release", Color = T.Red, Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromOffset(6, 140), Parent = card, OnClick = function()
				State.action("DeletePet", e.uid)
			end })
		end
	end
end }

-- ZONES -----------------------------------------------------------------------------
defs.Zones = { title = "World Map", icon = "🗺️", color = T.Blue, build = function(content)
	local list = scroll(content, UDim2.new(), UDim2.fromScale(1, 1))
	local rows = {}
	for i, z in Zones.List do
		local row = Lib.card({ Size = UDim2.new(1, -10, 0, 70), LayoutOrder = i, Parent = list })
		local bg = Lib.new("Frame", { Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = z.ground, Parent = row })
		Lib.corner(bg, 12)
		Lib.stroke(bg, z.accent, 2)
		Lib.text({ Text = z.icon, Stroke = false, Size = UDim2.fromScale(0.85, 0.85), Position = UDim2.fromScale(0.075, 0.075), Parent = bg })
		Lib.text({ Text = i .. ". " .. z.name, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.55, -70, 0, 30), Position = UDim2.fromOffset(72, 6), Parent = row })
		Lib.text({ Text = "Rewards x" .. z.mult, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Yellow, Size = UDim2.new(0.5, -70, 0, 22), Position = UDim2.fromOffset(72, 40), Parent = row })
		local btn = Lib.button({ Text = "", Size = UDim2.fromOffset(190, 48), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = row, OnClick = function()
			local d = State.data
			if not d then
				return
			end
			if i <= d.MaxZone then
				local r = State.action("Teleport", i)
				if r.ok then
					Panels.close()
				end
			elseif i == d.MaxZone + 1 then
				State.action("UnlockZone", i)
			end
		end })
		rows[i] = btn
	end
	return function(d)
		for i, btn in rows do
			local z = Zones.List[i]
			if i <= d.MaxZone then
				Lib.setButton(btn, "✈️ Teleport", T.Blue)
			elseif i == d.MaxZone + 1 then
				Lib.setButton(btn, "🔓 🪙 " .. Util.fmt(z.cost), affordColor(d, z.cost))
			else
				Lib.setButton(btn, "🔒 Locked", T.Grey)
			end
		end
	end
end }

-- QUESTS / ACHIEVEMENTS -------------------------------------------------------------
defs.Quests = { title = "Quests", icon = "📜", color = T.Yellow, build = function(content)
	local questsView, achView
	local active = tabs(content, { "Daily Quests", "Achievements" }, function(n)
		questsView.Visible = n == "Daily Quests"
		achView.Visible = n ~= "Daily Quests"
	end)
	questsView = scroll(content, UDim2.fromOffset(0, 48), UDim2.new(1, 0, 1, -48))
	achView = scroll(content, UDim2.fromOffset(0, 48), UDim2.new(1, 0, 1, -48))
	achView.Visible = false
	local _ = active

	local qRows = {}
	for i = 1, Quests.PerDay do
		local row = Lib.card({ Size = UDim2.new(1, -10, 0, 86), LayoutOrder = i, Parent = questsView })
		local title = Lib.text({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -220, 0, 28), Position = UDim2.fromOffset(14, 8), Parent = row })
		local reward = Lib.text({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Yellow, Size = UDim2.new(0.4, 0, 0, 20), Position = UDim2.fromOffset(14, 58), Parent = row })
		local _, fill = Lib.bar(row, UDim2.fromOffset(14, 38), UDim2.new(1, -230, 0, 16), T.Green)
		local btn = Lib.button({ Text = "Claim", Size = UDim2.fromOffset(170, 50), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = row, OnClick = function()
			local r = State.action("ClaimQuest", i)
			if r.ok then
				Audio.play("Coin")
			end
		end })
		qRows[i] = { row = row, title = title, reward = reward, fill = fill, btn = btn }
	end
	local aRows = {}
	for i, a in Quests.Achievements do
		local row = Lib.card({ Size = UDim2.new(1, -10, 0, 74), LayoutOrder = i, Parent = achView })
		Lib.text({ Text = a.icon, Stroke = false, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(10, 11), Parent = row })
		Lib.text({ Text = a.name, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, -70, 0, 26), Position = UDim2.fromOffset(70, 6), Parent = row })
		local prog = Lib.text({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Sub, Size = UDim2.new(1, -270, 0, 20), Position = UDim2.fromOffset(70, 44), Parent = row })
		local btn = Lib.button({ Text = "", Size = UDim2.fromOffset(170, 48), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = row, OnClick = function()
			local r = State.action("ClaimAchievement", a.id)
			if r.ok then
				Audio.play("Unlock")
			end
		end })
		aRows[a.id] = { prog = prog, btn = btn, def = a }
	end
	local statNames = { Feeds = "Feeds", Throws = "Throws", Discovered = "Dragons found", MaxZone = "Zones", RareFeeds = "Rare+ feeds", MythicFeeds = "Mythic feeds", Hatches = "Eggs hatched", Level = "Level" }
	return function(d)
		for i, r in qRows do
			local q = d.Quests.List[i]
			r.row.Visible = q ~= nil
			if q then
				r.title.Text = q.text .. "  (" .. Util.fmt(q.progress) .. "/" .. Util.fmt(q.goal) .. ")"
				r.reward.Text = "Reward: 🪙 " .. Util.fmt(q.coins * d.Computed.rewardMult) .. "  ⭐ " .. q.xp * d.Computed.rewardMult
				r.fill.Size = UDim2.fromScale(math.clamp(q.progress / q.goal, 0, 1), 1)
				if q.claimed then
					Lib.setButton(r.btn, "✓ Done", T.Purple)
				elseif q.progress >= q.goal then
					Lib.setButton(r.btn, "Claim!", T.Green)
				else
					Lib.setButton(r.btn, math.floor(q.progress / q.goal * 100) .. "%", T.Grey)
				end
			end
		end
		for id, r in aRows do
			local a = r.def
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
			r.prog.Text = statNames[a.stat] .. ": " .. Util.fmt(math.min(v, a.goal)) .. "/" .. Util.fmt(a.goal) .. "   •   🪙 " .. Util.fmt(a.coins * d.Computed.rewardMult)
			if d.Achievements[id] then
				Lib.setButton(r.btn, "✓ Claimed", T.Purple)
			elseif v >= a.goal then
				Lib.setButton(r.btn, "Claim!", T.Green)
			else
				Lib.setButton(r.btn, "In progress", T.Grey)
			end
		end
	end
end }

-- DAILY -----------------------------------------------------------------------------
defs.Daily = { title = "Daily Rewards", icon = "🎁", color = T.Red, build = function(content)
	local row = Lib.new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, Parent = content })
	Lib.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Parent = row })
	local cards = {}
	for i, r in Quests.Daily do
		local c = Lib.card({ Size = UDim2.fromOffset(84, 190), LayoutOrder = i, Parent = row })
		Lib.text({ Text = "Day " .. i, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 6), Parent = c })
		Lib.text({ Text = i == 7 and "👑" or (r.boost and "🎁" or "🪙"), Stroke = false, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 36), Parent = c })
		local amt = Lib.text({ Text = "", TextColor3 = T.Yellow, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 100), Parent = c })
		if r.boost then
			Lib.text({ Text = "+" .. Products.Boosts[r.boost[1]].icon .. " " .. math.floor(r.boost[2] / 60) .. "m", TextColor3 = T.Green, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 126), Parent = c })
		end
		local check = Lib.text({ Text = "✓", TextColor3 = T.Green, Visible = false, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 150), Parent = c })
		cards[i] = { card = c, amt = amt, check = check }
	end
	local timer = Lib.text({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 214), Parent = content })
	local btn = Lib.button({ Text = "Claim!", Size = UDim2.fromOffset(240, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 254), Parent = content, OnClick = function()
		local r = State.action("ClaimDaily")
		if r.ok then
			Audio.play("Unlock")
		end
	end })
	local preview = nil
	local lastFetch = 0
	return function(d)
		if not preview or os.clock() - lastFetch > 30 then
			lastFetch = os.clock()
			task.spawn(function()
				local r = State.action("DailyPreview")
				if r.ok then
					preview = r.data
					Panels.refreshNow()
				end
			end)
		end
		local now = State.serverNow()
		local available = now - d.Daily.Last >= Quests.DailyCooldown
		local reset = d.Daily.Last == 0 or now - d.Daily.Last > Quests.DailyResetAfter
		local nextDay = reset and 1 or (d.Daily.Streak % #Quests.Daily + 1)
		for i, c in cards do
			c.amt.Text = preview and preview[i] and Util.fmt(preview[i] * d.Computed.rewardMult) or "…"
			c.check.Visible = not reset and i <= d.Daily.Streak and not (available and nextDay == 1)
			c.card:FindFirstChildOfClass("UIStroke").Color = (i == nextDay and available) and T.Yellow or T.Stroke
		end
		if available then
			timer.Text = "Day " .. nextDay .. " reward is ready!"
			Lib.setButton(btn, "Claim!", T.Green)
		else
			timer.Text = "Next reward in " .. Util.time(Quests.DailyCooldown - (now - d.Daily.Last))
			Lib.setButton(btn, "Come back later", T.Grey)
		end
	end
end }

-- STORE -----------------------------------------------------------------------------
defs.Store = { title = "Store", icon = "💎", color = Color3.fromRGB(0, 200, 200), build = function(content)
	local grid = scroll(content, UDim2.new(), UDim2.fromScale(1, 1), Vector2.new(196, 170))
	local passBtns = {}
	local function item(order, icon, name, desc, onClick)
		local c = Lib.card({ LayoutOrder = order, Parent = grid })
		Lib.text({ Text = icon, Stroke = false, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 6), Parent = c })
		Lib.text({ Text = name, Size = UDim2.new(1, -10, 0, 24), Position = UDim2.fromOffset(5, 52), Parent = c })
		Lib.text({ Text = desc, TextWrapped = true, TextColor3 = T.Sub, Size = UDim2.new(1, -14, 0, 38), Position = UDim2.fromOffset(7, 78), Parent = c })
		return Lib.button({ Text = "Buy", Color = Color3.fromRGB(0, 200, 120), Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 1, -48), Parent = c, OnClick = onClick })
	end
	for i, key in Products.PassOrder do
		local p = Products.Passes[key]
		passBtns[key] = item(i, p.icon, p.name, p.desc, function()
			State.action("Prompt", { kind = "pass", key = key })
		end)
	end
	for i, key in Products.ProductOrder do
		local p = Products.DevProducts[key]
		local desc = p.kind == "coins" and ("Instantly get " .. p.minutes .. " min of income") or (p.boost == "Lucky" and "Better eggs + more crits" or "Double coins from feeding")
		local b = item(100 + i, p.icon, p.name, desc, function()
			State.action("Prompt", { kind = "product", key = key })
		end)
		if p.id == 0 then
			Lib.setButton(b, "Soon", T.Grey)
		end
	end
	return function(d)
		for key, b in passBtns do
			if d.Passes[key] then
				Lib.setButton(b, "✓ Owned", T.Purple)
			elseif Products.Passes[key].id == 0 then
				Lib.setButton(b, "Soon", T.Grey)
			else
				Lib.setButton(b, "Buy", Color3.fromRGB(0, 200, 120))
			end
		end
	end
end }

-- SETTINGS --------------------------------------------------------------------------
defs.Settings = { title = "Settings", icon = "⚙️", color = T.Grey, build = function(content)
	local list = scroll(content, UDim2.new(), UDim2.fromScale(1, 1))
	local controls = {}
	local function row(i, label, key, kind)
		local r = Lib.card({ Size = UDim2.new(1, -10, 0, 64), LayoutOrder = i, Parent = list })
		Lib.text({ Text = label, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 0, 34), Position = UDim2.fromOffset(16, 15), Parent = r })
		local b = Lib.button({ Text = "", Size = UDim2.fromOffset(170, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Parent = r, OnClick = function()
			local d = State.data
			if not d then
				return
			end
			local v = d.Settings[key]
			local nv
			if kind == "volume" then
				nv = (math.floor((v or 0) * 4 + 0.5) + 1) % 5 / 4
			else
				nv = not v
			end
			State.action("SetSetting", { key = key, value = nv })
		end })
		controls[key] = { b = b, kind = kind }
	end
	row(1, "🎵 Music volume", "Music", "volume")
	row(2, "🔊 Sound effects", "Sfx", "volume")
	row(3, "📱 Low graphics (faster on mobile)", "LowGfx", "toggle")
	row(4, "👀 Show other players' throws", "ShowOthers", "toggle")
	Lib.text({ Text = "Tip: click or hold on the ground to throw. Mobile: tap the ground or press THROW. Console: R2.", TextWrapped = true, TextColor3 = T.Sub, Size = UDim2.new(1, -10, 0, 50), LayoutOrder = 10, Parent = list })
	return function(d)
		for key, c in controls do
			local v = d.Settings[key]
			if c.kind == "volume" then
				Lib.setButton(c.b, math.floor((v or 0) * 100 + 0.5) .. "%", (v or 0) > 0 and T.Blue or T.Grey)
			else
				Lib.setButton(c.b, v and "ON" or "OFF", v and T.Green or T.Grey)
			end
		end
	end
end }

-- refresh plumbing ------------------------------------------------------------------
function Panels.refreshNow()
	if current and built[current] and State.data then
		built[current].refresh(State.data)
	end
end

function Panels.start(gui: ScreenGui)
	root = gui
	State.Changed:Connect(function()
		if refreshQueued or not current then
			return
		end
		refreshQueued = true
		task.delay(0.3, function()
			refreshQueued = false
			Panels.refreshNow()
		end)
	end)
	-- live timers (daily countdown)
	task.spawn(function()
		while true do
			task.wait(1)
			if current == "Daily" then
				Panels.refreshNow()
			end
		end
	end)
end

return Panels
