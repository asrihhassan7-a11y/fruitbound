--> Fishing (UI, V1.1) - Fisher Finn's menu at the FISHING stall.
-- Tabs: Bag (sell), Bait (shop + crafting), Rods (upgrades + cosmetics), Journal (species +
-- collection rewards), Quests (daily). Everything shown comes from the replicated data.fishing;
-- every button is a server request (the server checks distance, price, ownership, once-only).
local _L = _G._L

local Services
local Tracker
local Data
local Network
local Spr
local UI
local Config
local U
local NumberUtility

local CREAM = Color3.fromRGB(255, 248, 230)
local CREAM_DARK = Color3.fromRGB(242, 228, 200)
local WOOD = Color3.fromRGB(110, 72, 38)
local WOOD_TEXT = Color3.fromRGB(90, 60, 30)
local MUTED = Color3.fromRGB(140, 115, 90)
local GREEN = Color3.fromRGB(110, 190, 80)
local BLUE = Color3.fromRGB(70, 150, 230)
local GOLD = Color3.fromRGB(230, 165, 30)
local GREY = Color3.fromRGB(175, 165, 145)
local RED = Color3.fromRGB(215, 95, 80)
local FONT = Enum.Font.FredokaOne

local TABS = {
	{id = "bag", text = "🎒 Bag"},
	{id = "bait", text = "🪱 Bait"},
	{id = "rods", text = "🎣 Rods"},
	{id = "journal", text = "📖 Journal"},
	{id = "quests", text = "📜 Quests"},
}

local ERRORS = {
	distance = "Talk to Fisher Finn at the FISHING stall to do that.",
	afford = "Not enough Coins!",
	level = "Your Fishing Level is too low for that.",
	materials = "You need more materials.",
	order = "Unlock the previous Rod first.",
	locked = "Not unlocked yet.",
	incomplete = "Not complete yet.",
	claimed = "Already claimed.",
	empty = "Nothing to sell.",
}

local FishingUI = {name = script.Name}

------------------------------------------------------------ builders
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0, 12)
	c.Parent = p
end

local function stroke(p, t, c)
	local s = Instance.new("UIStroke")
	s.Thickness = t or 3
	s.Color = c or WOOD
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
end

local function label(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = WOOD_TEXT
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent, text, color, props)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	corner(b, UDim.new(0, 10))
	stroke(b, 2.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.15, 0)
	pad.PaddingBottom = UDim.new(0.15, 0)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Thickness = 1.5
	ts.Color = Color3.fromRGB(60, 40, 20)
	ts.Parent = b
	b.Parent = parent
	return b
end

local function row(parent, order, height)
	local r = Instance.new("Frame")
	r.LayoutOrder = order
	r.Size = UDim2.new(1, -10, 0, height or 56)
	r.BackgroundColor3 = CREAM_DARK
	r.Parent = parent
	corner(r, UDim.new(0, 10))
	return r
end

local function header(parent, order, text)
	return label(parent, text, {LayoutOrder = order, Size = UDim2.new(1, -10, 0, 30), TextColor3 = WOOD})
end

local function notify(text, color)
	pcall(function()
		UI.Get("Notifications"):add({text = text, color = color or Color3.fromRGB(150, 210, 255)})
	end)
end

local function request(remote, ...)
	local ok, success, a, b = pcall(Network.Remote.Invoke, remote, ...)
	if not ok then
		notify("Something went wrong, try again.", RED)
		return false
	end
	if not success then
		notify(ERRORS[a] or "Can't do that right now.", Color3.fromRGB(255, 160, 90))
	end
	return success, a, b
end

local function fish()
	local data = Data.Await()
	return U.normalize(data and data:Get("fishing")), data
end

local function rewardText(r)
	local parts = {}
	if r.coins then table.insert(parts, NumberUtility.short(r.coins) .. " Coins") end
	if r.gems then table.insert(parts, r.gems .. " Gems") end
	if r.bait then local b = Config.bait(r.bait) table.insert(parts, r.count .. " " .. (b and b.name or r.bait)) end
	if r.cosmetic then local c = Config.cosmetic(r.cosmetic) table.insert(parts, c and c.name or r.cosmetic) end
	if r.xp then table.insert(parts, r.xp .. " XP") end
	return table.concat(parts, " + ")
end

------------------------------------------------------------ build
function FishingUI:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FishingMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = _L.PlayerGui
	self.object = gui

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.Size = UDim2.fromScale(0.92, 0.82)
	main.BackgroundColor3 = CREAM
	main.Visible = false
	main.Parent = gui
	corner(main, UDim.new(0, 22))
	stroke(main, 5)
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(820, 520)
	size.MinSize = Vector2.new(330, 280)
	size.Parent = main
	self._main = main

	label(main, "🎣 FISHING - Fisher Finn", {Position = UDim2.new(0, 18, 0, 10), Size = UDim2.new(0.5, -18, 0, 36), TextColor3 = WOOD})
	self._level = label(main, "", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -76, 0, 14), Size = UDim2.new(0.4, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Right})
	local close = button(main, "X", RED, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(52, 52)})
	close.Activated:Connect(function()
		UI.Close({name = self.name})
	end)

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.new(0, 14, 0, 62)
	tabs.Size = UDim2.new(1, -28, 0, 44)
	tabs.Parent = main
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 6)
	tl.Parent = tabs
	self._tabButtons = {}
	for i, t in ipairs(TABS) do
		local b = button(tabs, t.text, GREY, {LayoutOrder = i, Size = UDim2.new(1 / #TABS, -6, 1, 0)})
		b.Activated:Connect(function()
			self._tab = t.id
			self:_render()
		end)
		self._tabButtons[t.id] = b
	end

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0, 14, 0, 114)
	body.Size = UDim2.new(1, -28, 1, -184)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 8
	body.Parent = main
	local bl = Instance.new("UIListLayout")
	bl.Padding = UDim.new(0, 6)
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Parent = body
	self._body = body

	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 14, 1, -12)
	footer.Size = UDim2.new(1, -28, 0, 54)
	footer.Parent = main
	self._footer = footer
end

function FishingUI:_clear()
	for _, c in ipairs(self._body:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for _, c in ipairs(self._footer:GetChildren()) do
		c:Destroy()
	end
end

------------------------------------------------------------ tabs
function FishingUI:_renderBag(f)
	local body = self._body
	local selected = self._selected
	local total, selTotal, selCount = 0, 0, 0
	header(body, 0, "Fishing Bag " .. #f.bag .. "/" .. U.bagCapacity(f) .. " - tap fish to select")
	if #f.bag == 0 then
		label(body, "Your bag is empty. Go catch some fish!", {LayoutOrder = 1, Size = UDim2.new(1, -10, 0, 30), TextColor3 = MUTED})
	end
	for i, entry in ipairs(f.bag) do
		local info = Config.fish(entry.f)
		local rarity = info and Config.RARITIES[info.rarity]
		total += entry.v or 0
		local isSel = selected[entry.u] == true
		if isSel then
			selTotal += entry.v or 0
			selCount += 1
		end
		local b = Instance.new("TextButton")
		b.Text = ""
		b.LayoutOrder = i
		b.Size = UDim2.new(1, -10, 0, 50)
		b.BackgroundColor3 = if isSel then Color3.fromRGB(205, 235, 190) else CREAM_DARK
		b.Parent = body
		corner(b, UDim.new(0, 10))
		stroke(b, 2, if isSel then GREEN else (rarity and rarity.color or WOOD))
		label(b, (isSel and "✔ " or "") .. (info and info.name or entry.f) .. (if entry.q == "perfect" then " ✨" else ""), {Position = UDim2.fromScale(0.03, 0.1), Size = UDim2.fromScale(0.45, 0.8), TextColor3 = rarity and rarity.color or WOOD_TEXT})
		label(b, entry.w .. " kg  " .. (info and U.weightTier(info, entry.w) or ""), {Position = UDim2.fromScale(0.5, 0.15), Size = UDim2.fromScale(0.28, 0.7)})
		label(b, "💰 " .. entry.v, {Position = UDim2.fromScale(0.8, 0.15), Size = UDim2.fromScale(0.18, 0.7), TextColor3 = GOLD})
		local uid = entry.u
		b.Activated:Connect(function()
			selected[uid] = if selected[uid] then nil else true
			self:_render()
		end)
	end
	local sellSel = button(self._footer, "SELL SELECTED (" .. selCount .. ") - " .. NumberUtility.short(selTotal), if selCount > 0 then GREEN else GREY, {Size = UDim2.new(0.49, 0, 1, 0)})
	sellSel.Activated:Connect(function()
		local uids = {}
		for uid in pairs(selected) do
			table.insert(uids, uid)
		end
		if #uids == 0 then
			return
		end
		local ok, coins, n = request("S_Fishing_Sell", uids)
		if ok then
			notify("💰 Sold " .. n .. " fish for " .. NumberUtility.short(coins) .. " Coins!", GOLD)
			self._selected = {}
		end
		task.delay(0.15, function() self:_render() end)
	end)
	local sellAll = button(self._footer, "SELL ALL - " .. NumberUtility.short(total), if #f.bag > 0 then GOLD else GREY, {Position = UDim2.new(0.51, 0, 0, 0), Size = UDim2.new(0.49, 0, 1, 0)})
	sellAll.Activated:Connect(function()
		local ok, coins, n = request("S_Fishing_Sell", "all")
		if ok then
			notify("💰 Sold " .. n .. " fish for " .. NumberUtility.short(coins) .. " Coins!", GOLD)
			self._selected = {}
		end
		task.delay(0.15, function() self:_render() end)
	end)
end

function FishingUI:_renderBait(f, data)
	local body = self._body
	local coins = data and data:Get({"stats", "Strength"}) or 0
	local o = 0
	local function nextO() o += 1 return o end
	header(body, nextO(), "Your Bait (choose it with the BAIT button while holding your rod)")
	for _, bait in ipairs(Config.BAITS) do
		if bait.id ~= "none" then
			local r = row(body, nextO(), 40)
			label(r, bait.icon .. " " .. bait.name .. "  x" .. (f.bait[bait.id] or 0) .. (if f.selected_bait == bait.id then "  (selected)" else ""), {Position = UDim2.fromScale(0.03, 0.12), Size = UDim2.fromScale(0.45, 0.76)})
			label(r, bait.desc, {Position = UDim2.fromScale(0.5, 0.18), Size = UDim2.fromScale(0.48, 0.64), TextColor3 = MUTED})
		end
	end
	header(body, nextO(), "Bait Shop")
	for i, offer in ipairs(Config.BAIT_SHOP) do
		local bait = Config.bait(offer.bait)
		local r = row(body, nextO(), 50)
		label(r, bait.icon .. " " .. bait.name .. " x" .. offer.count, {Position = UDim2.fromScale(0.03, 0.15), Size = UDim2.fromScale(0.5, 0.7)})
		local locked = f.level < offer.level
		local b = button(r, if locked then ("🔒 Fishing Lv " .. offer.level) else ("💰 " .. NumberUtility.short(offer.price)), if locked or coins < offer.price then GREY else GREEN, {Position = UDim2.fromScale(0.62, 0.12), Size = UDim2.fromScale(0.36, 0.76)})
		b.Activated:Connect(function()
			if request("S_Fishing_BuyBait", i) then
				notify("Bought " .. offer.count .. " " .. bait.name .. "!", GREEN)
			end
			task.delay(0.15, function() self:_render() end)
		end)
	end
	header(body, nextO(), "Materials: " .. (function()
		local parts = {}
		for _, mt in ipairs(Config.MATERIALS) do
			table.insert(parts, mt.icon .. " " .. mt.name .. " " .. (f.materials[mt.id] or 0))
		end
		return table.concat(parts, "   ")
	end)())
	for _, recipe in ipairs(Config.RECIPES) do
		local r = row(body, nextO(), 50)
		local cost = {}
		local can = true
		for mat, n in pairs(recipe.cost) do
			local mt = Config.material(mat)
			table.insert(cost, n .. " " .. (mt and mt.name or mat))
			if (f.materials[mat] or 0) < n then
				can = false
			end
		end
		if recipe.coins then
			table.insert(cost, NumberUtility.short(recipe.coins) .. " Coins")
			can = can and coins >= recipe.coins
		end
		label(r, "Craft " .. recipe.name, {Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.55, 0.45)})
		label(r, table.concat(cost, " + "), {Position = UDim2.fromScale(0.03, 0.52), Size = UDim2.fromScale(0.55, 0.4), TextColor3 = MUTED})
		local b = button(r, "CRAFT", if can then BLUE else GREY, {Position = UDim2.fromScale(0.66, 0.12), Size = UDim2.fromScale(0.32, 0.76)})
		b.Activated:Connect(function()
			if request("S_Fishing_Craft", recipe.id) then
				notify("Crafted " .. recipe.name .. "!", BLUE)
			end
			task.delay(0.15, function() self:_render() end)
		end)
	end
end

function FishingUI:_renderRods(f, data)
	local body = self._body
	local coins = data and data:Get({"stats", "Strength"}) or 0
	local o = 0
	local function nextO() o += 1 return o end
	header(body, nextO(), "Rods (better control, faster bites, new fishing spots)")
	local rank = U.rodRank(f)
	for _, rod in ipairs(Config.RODS) do
		local r = row(body, nextO(), 66)
		local zone = nil
		for _, z in ipairs(Config.ZONES) do
			if z.rod == rod.rank then zone = z end
		end
		label(r, rod.name .. (if f.rod_id == rod.id then "  (using)" else ""), {Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.55, 0.42), TextColor3 = rod.color})
		label(r, string.format("Control %d%%  -  Bites %d%% faster  -  Up to %s fish%s", math.floor(rod.zone * 100 / 0.24 * 100 / 100), math.floor((1 - rod.bite) * 100), (function()
			for name, info in pairs(Config.RARITIES) do
				if info.difficulty == rod.max then return name end
			end
			return "?"
		end)(), if zone then ("  -  Unlocks " .. zone.name) else ""), {Position = UDim2.fromScale(0.03, 0.52), Size = UDim2.fromScale(0.6, 0.38), TextColor3 = MUTED})
		if f.rods[rod.id] then
			label(r, "✔ Owned", {Position = UDim2.fromScale(0.7, 0.2), Size = UDim2.fromScale(0.27, 0.6), TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Center})
		else
			local reqs = {}
			if rod.price > 0 then table.insert(reqs, NumberUtility.short(rod.price)) end
			for mat, n in pairs(rod.materials or {}) do
				local mt = Config.material(mat)
				table.insert(reqs, n .. " " .. (mt and mt.name or mat))
			end
			local locked = rank ~= rod.rank - 1 or f.level < rod.level
			local text = if rank < rod.rank - 1 then "🔒 Previous rod first" elseif f.level < rod.level then ("🔒 Fishing Lv " .. rod.level) else ("💰 " .. table.concat(reqs, " + "))
			local b = button(r, text, if locked or coins < rod.price then GREY else GOLD, {Position = UDim2.fromScale(0.64, 0.14), Size = UDim2.fromScale(0.34, 0.72)})
			b.Activated:Connect(function()
				request("S_Fishing_BuyRod", rod.id)
				task.delay(0.15, function() self:_render() end)
			end)
		end
	end
	header(body, nextO(), "Style (bobbers and rod skins)")
	for _, c in ipairs(Config.COSMETICS) do
		local r = row(body, nextO(), 46)
		local owned = f.cosmetics.owned[c.id]
		local using = f.cosmetics[c.slot] == c.id
		label(r, (if c.slot == "bobber" then "🔴 " else "🎨 ") .. c.name, {Position = UDim2.fromScale(0.03, 0.15), Size = UDim2.fromScale(0.55, 0.7), TextColor3 = c.color or WOOD_TEXT})
		local text, color, action
		if using then
			text, color = "Using", GREEN
		elseif owned then
			text, color, action = "EQUIP", BLUE, function() request("S_Fishing_EquipCosmetic", c.id) end
		elseif c.price then
			local lockedReason = if c.level and f.level < c.level then ("Lv " .. c.level) elseif c.catches and f.catches < c.catches then (c.catches .. " catches") else nil
			text = if lockedReason then ("🔒 " .. lockedReason) else ("💰 " .. NumberUtility.short(c.price))
			color = if lockedReason or coins < c.price then GREY else GOLD
			action = function() request("S_Fishing_BuyCosmetic", c.id) end
		else
			text, color = "🏆 " .. (c.source or "Reward"), GREY
		end
		local b = button(r, text, color, {Position = UDim2.fromScale(0.6, 0.12), Size = UDim2.fromScale(0.38, 0.76)})
		if action then
			b.Activated:Connect(function()
				action()
				task.delay(0.15, function() self:_render() end)
			end)
		end
	end
end

function FishingUI:_renderJournal(f)
	local body = self._body
	local o = 0
	local function nextO() o += 1 return o end
	header(body, nextO(), "Journal: " .. U.discoveredCount(f) .. "/" .. #Config.FISH .. " species")
	for _, zone in ipairs(Config.ZONES) do
		header(body, nextO(), zone.name .. " - " .. zone.desc)
		for _, info in ipairs(Config.FISH) do
			if table.find(info.zones, zone.id) then
				local j = f.journal[info.id]
				local found = j and (j.n or 0) > 0
				local rarity = Config.RARITIES[info.rarity]
				local r = row(body, nextO(), 54)
				local name = if found then info.name else (if info.secret then "??? (secret)" else "???")
				label(r, name .. "  -  " .. info.rarity, {Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.6, 0.46), TextColor3 = rarity.color})
				local hint
				if found then
					hint = "Caught " .. j.n .. "  -  Best " .. j.best .. "kg  -  " .. info.desc
				else
					local likes = {}
					for baitId, like in pairs(info.likes or {}) do
						if like == "preferred" then
							local b = Config.bait(baitId)
							table.insert(likes, b and b.name or baitId)
						end
					end
					hint = (if info.time then (info.time == "night" and "Night only. " or "Day only. ") else "") .. (if info.rain then "Loves rain. " else "") .. (if info.needs then ("Needs " .. Config.bait(info.needs).name .. ". ") else "") .. (if #likes > 0 and not info.secret then ("Likes " .. table.concat(likes, ", ")) else "")
				end
				label(r, hint, {Position = UDim2.fromScale(0.03, 0.54), Size = UDim2.fromScale(0.94, 0.38), TextColor3 = MUTED})
			end
		end
	end
	header(body, nextO(), "Collection Rewards")
	for _, col in ipairs(Config.COLLECTIONS) do
		local r = row(body, nextO(), 56)
		local done = if col.need == "all" then U.discoveredCount(f) >= #Config.FISH else U.collectionDone(f, col)
		local claimed = f.claimed[col.id]
		label(r, col.name .. ": " .. col.text, {Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.62, 0.46)})
		label(r, "Reward: " .. rewardText(col.reward), {Position = UDim2.fromScale(0.03, 0.54), Size = UDim2.fromScale(0.62, 0.38), TextColor3 = GOLD})
		local b = button(r, if claimed then "✔ Claimed" elseif done then "CLAIM" else "In progress", if claimed then GREY elseif done then GREEN else GREY, {Position = UDim2.fromScale(0.68, 0.14), Size = UDim2.fromScale(0.3, 0.72)})
		if done and not claimed then
			b.Activated:Connect(function()
				local ok, lines = request("S_Fishing_ClaimCollection", col.id)
				if ok then
					notify("🎉 " .. col.name .. ": " .. table.concat(lines or {}, ", "), GOLD)
				end
				task.delay(0.15, function() self:_render() end)
			end)
		end
	end
end

function FishingUI:_renderQuests(f)
	local body = self._body
	local left = 86400 - (os.time() % 86400)
	header(body, 0, string.format("Daily Fishing Quests - new ones in %dh %dm", left // 3600, (left % 3600) // 60))
	for i, entry in ipairs(f.quests.list or {}) do
		local info = Config.quest(entry.id)
		if info then
			local r = row(body, i, 64)
			label(r, info.text .. "  (" .. math.min(entry.p or 0, info.goal) .. "/" .. info.goal .. ")", {Position = UDim2.fromScale(0.03, 0.06), Size = UDim2.fromScale(0.62, 0.42)})
			label(r, "Reward: " .. rewardText(info.reward), {Position = UDim2.fromScale(0.03, 0.52), Size = UDim2.fromScale(0.62, 0.36), TextColor3 = GOLD})
			local done = (entry.p or 0) >= info.goal
			local b = button(r, if entry.claimed then "✔ Claimed" elseif done then "CLAIM" else "In progress", if done and not entry.claimed then GREEN else GREY, {Position = UDim2.fromScale(0.68, 0.16), Size = UDim2.fromScale(0.3, 0.68)})
			if done and not entry.claimed then
				b.Activated:Connect(function()
					local ok, lines = request("S_Fishing_ClaimQuest", i)
					if ok then
						notify("📜 Quest done: " .. table.concat(lines or {}, ", "), GOLD)
					end
					task.delay(0.15, function() self:_render() end)
				end)
			end
		end
	end
	if #(f.quests.list or {}) == 0 then
		label(body, "Quests appear after your first cast.", {LayoutOrder = 1, Size = UDim2.new(1, -10, 0, 30), TextColor3 = MUTED})
	end
end

function FishingUI:_render()
	if not self._main.Visible then
		return
	end
	local f, data = fish()
	self:_clear()
	local level, into, need = U.levelFromXp(f.xp)
	self._level.Text = "Fishing Lv " .. level .. (if need > 0 then ("  (" .. into .. "/" .. need .. " XP)") else "  (MAX)")
	for id, b in pairs(self._tabButtons) do
		b.BackgroundColor3 = if id == self._tab then BLUE else GREY
	end
	if self._tab == "bag" then
		self:_renderBag(f)
	elseif self._tab == "bait" then
		self:_renderBait(f, data)
	elseif self._tab == "rods" then
		self:_renderRods(f, data)
	elseif self._tab == "journal" then
		self:_renderJournal(f)
	else
		self:_renderQuests(f)
	end
end

------------------------------------------------------------ lifecycle
function FishingUI:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Network = _L.Get {"Common", "Library", "Network"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	UI = _L.Get {"Client", "Modules", "UI"}
	Config = _L.Get {"Common", "Modules", "Databases", "Fishing"}
	U = _L.Get {"Common", "Modules", "Utilities", "FishingUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	self.is_open = Tracker.new(false)
	self._tab = "bag"
	self._selected = {}
end

function FishingUI:_start()
	self:_build()
	self.is_open:Bind(function(value)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	local data = Data.Await()
	if data then
		data:Bind({"fishing"}, function()
			if self._main.Visible then
				self:_render()
			end
		end)
	end
end

function FishingUI:Open()
	self._main.Visible = true
	self._selected = {}
	pcall(Network.Remote.Invoke, "S_Fishing_Refresh")
	self:_render()
	pcall(function()
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 20})
	end)
end

function FishingUI:Close()
	self._main.Visible = false
	pcall(function()
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 0})
	end)
end

return FishingUI
