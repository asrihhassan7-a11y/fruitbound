--> Leaderboard (server, V1.1)
-- ONE Village leaderboard board (Workspace.__MAP.Village.VillageLeaderboard) that rotates through a few
-- global categories. Global ranks use OrderedDataStores; writes are throttled (per player, per category,
-- only when the value changed, at most every WRITE_INTERVAL) and reads are cached (READ_INTERVAL).
local _L = _G._L

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Network
local NumberUtility
local FishingUtility

local WRITE_INTERVAL = 180 -- seconds between saves of one player's value in one category
local READ_INTERVAL = 120 -- seconds between global top-10 reads of one category
local ROTATE_SECONDS = 10 -- the board shows the next category after this long
local TOP = 10
local LOG_SCALE = 1e9 -- huge values (Coins / Gems) are stored as log10(value + 1) * LOG_SCALE

local CATEGORIES = {
	{id = "Coins", title = "💰 Coins", log = true, get = function(client)
		return client.data:Get({"stats", "Strength"})
	end},
	{id = "Gems", title = "💎 Gems", log = true, get = function(client)
		return client.data:Get({"stats", "Gems"})
	end},
	{id = "FishingLevel", title = "🎣 Fishing Level", get = function(client)
		local f = client.data:Get("fishing")
		return if typeof(f) == "table" then (FishingUtility.levelFromXp(tonumber(f.xp) or 0)) else 1
	end},
	{id = "FishCaught", title = "🐟 Fish Caught", get = function(client)
		local f = client.data:Get("fishing")
		return if typeof(f) == "table" then tonumber(f.catches) or 0 else 0
	end},
	{id = "FruitsCollected", title = "🍓 Fruits Collected", get = function(client)
		return client.data:Get({"stats", "Fruits_Collected"})
	end},
}

local Leaderboard = {}

local stores = {}
local lastWrite = {} -- [userId][categoryId] = {t, value}
local cache = {} -- [categoryId] = {t, rows = {{rank, userId, value}}}
local names = {} -- [userId] = name
local board -- {gui, title, tabs, rows}

local function finite(n)
	return typeof(n) == "number" and n == n and math.abs(n) ~= math.huge
end

local function encode(category, value)
	value = math.max(0, value)
	if category.log then
		return math.floor(math.log10(value + 1) * LOG_SCALE)
	end
	return math.floor(math.min(value, 2^52))
end

local function decode(category, stored)
	if category.log then
		return math.max(0, math.floor(10 ^ (stored / LOG_SCALE) - 1 + 0.5))
	end
	return stored
end

local function isMockSession()
	local ok, settings = pcall(_L.Get, {"Common", "Modules", "Settings"})
	return game:GetService("RunService"):IsStudio() and ok and typeof(settings) == "table" and settings.data and settings.data.mock == true
end

local function store(category)
	if stores[category.id] == nil then
		local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "LB_V11_" .. category.id)
		stores[category.id] = if ok then result else false
	end
	return stores[category.id] or nil
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return names[userId]
	end
	local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and typeof(result) == "string" then result else "Player"
	return names[userId]
end

-- save changed values of the players in this server (throttled)
local function writeAll()
	if isMockSession() then
		return -- Studio test profiles must never reach the global leaderboards
	end
	local clients = Network.Bindable.Invoke("S_Client_GetAll") or {}
	local now = os.clock()
	for player, client in pairs(clients) do
		if typeof(player) == "Instance" and player.Parent and client and client.data then
			local mine = lastWrite[player.UserId] or {}
			lastWrite[player.UserId] = mine
			for _, category in ipairs(CATEGORIES) do
				local ok, value = pcall(category.get, client)
				local last = mine[category.id]
				if ok and finite(value) and (not last or (now - last.t >= WRITE_INTERVAL and last.value ~= value)) then
					local ds = store(category)
					if ds then
						mine[category.id] = {t = now, value = value}
						local encoded = encode(category, value)
						task.spawn(function()
							local okSet, err = pcall(ds.SetAsync, ds, tostring(player.UserId), encoded)
							if not okSet then
								warn("[Leaderboard] save failed:", category.id, err)
							end
						end)
					end
				end
			end
		end
	end
end

local function readTop(category)
	local entry = cache[category.id]
	if entry and os.clock() - entry.t < READ_INTERVAL then
		return entry.rows
	end
	local rows = if entry then entry.rows else {}
	cache[category.id] = {t = os.clock(), rows = rows}
	local ds = store(category)
	if not ds then
		return rows
	end
	local ok, pages = pcall(ds.GetSortedAsync, ds, false, TOP)
	if ok and pages then
		local fresh = {}
		for rank, item in ipairs(pages:GetCurrentPage()) do
			local userId = tonumber(item.key)
			if userId then
				table.insert(fresh, {rank = rank, user_id = userId, value = decode(category, item.value)})
			end
		end
		cache[category.id].rows = fresh
		return fresh
	end
	return rows
end

-- ============================================================
-- BOARD (SurfaceGui on the Village board, built once)
-- ============================================================
local function text(parent, name, value, size, pos, maxSize, color, align)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = value
	t.Size = size
	t.Position = pos
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextXAlignment = align or Enum.TextXAlignment.Left
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = t
	t.Parent = parent
	return t
end

local function buildBoard()
	local map = workspace:FindFirstChild("__MAP")
	local model = map and map:FindFirstChild("Village") and map.Village:FindFirstChild("VillageLeaderboard")
	local part = model and model:FindFirstChild("Board")
	if not part then
		warn("[Leaderboard] Village.VillageLeaderboard.Board not found")
		return nil
	end
	local old = part:FindFirstChild("LeaderboardGui")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	gui.MaxDistance = 120
	gui.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(45, 70, 45)
	bg.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.03, 0)
	pad.PaddingBottom = UDim.new(0.03, 0)
	pad.PaddingLeft = UDim.new(0.03, 0)
	pad.PaddingRight = UDim.new(0.03, 0)
	pad.Parent = bg

	local title = text(bg, "Title", "🏆 LEADERBOARD", UDim2.fromScale(1, 0.12), UDim2.fromScale(0, 0), 60, Color3.fromRGB(255, 225, 120), Enum.TextXAlignment.Center)

	local tabs = {}
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.fromScale(0, 0.13)
	tabRow.Size = UDim2.fromScale(1, 0.085)
	tabRow.Parent = bg
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Padding = UDim.new(0.01, 0)
	tabLayout.Parent = tabRow
	for index, category in ipairs(CATEGORIES) do
		local tab = text(tabRow, category.id, category.title, UDim2.fromScale(0.19, 1), UDim2.new(), 26, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
		tab.LayoutOrder = index
		tab.BackgroundTransparency = 0
		tab.BackgroundColor3 = Color3.fromRGB(70, 100, 70)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = tab
		tabs[category.id] = tab
	end

	local rows = {}
	for i = 1, TOP do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.Position = UDim2.fromScale(0, 0.235 + (i - 1) * 0.0765)
		row.Size = UDim2.fromScale(1, 0.07)
		row.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(55, 82, 55) else Color3.fromRGB(62, 92, 62)
		row.Parent = bg
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = row
		local rankColor = ({Color3.fromRGB(255, 215, 0), Color3.fromRGB(205, 205, 215), Color3.fromRGB(215, 145, 80)})[i] or Color3.new(1, 1, 1)
		rows[i] = {
			frame = row,
			rank = text(row, "Rank", "#" .. i, UDim2.fromScale(0.1, 0.9), UDim2.fromScale(0.02, 0.05), 34, rankColor, Enum.TextXAlignment.Left),
			name = text(row, "Name", "-", UDim2.fromScale(0.55, 0.9), UDim2.fromScale(0.13, 0.05), 34, Color3.new(1, 1, 1)),
			value = text(row, "Value", "", UDim2.fromScale(0.3, 0.9), UDim2.fromScale(0.68, 0.05), 34, Color3.fromRGB(255, 235, 160), Enum.TextXAlignment.Right),
		}
	end
	return {gui = gui, title = title, tabs = tabs, rows = rows}
end

local function show(category)
	if not board then
		return
	end
	for id, tab in pairs(board.tabs) do
		tab.BackgroundColor3 = if id == category.id then Color3.fromRGB(240, 170, 60) else Color3.fromRGB(70, 100, 70)
	end
	local list = readTop(category)
	for i, row in ipairs(board.rows) do
		local item = list[i]
		if item then
			row.name.Text = nameOf(item.user_id)
			row.value.Text = NumberUtility.short(item.value)
		else
			row.name.Text = "-"
			row.value.Text = ""
		end
	end
end

function Leaderboard._init()
	Network = _L.Get {"Common", "Library", "Network"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	FishingUtility = _L.Get {"Common", "Modules", "Utilities", "FishingUtility"}
end

function Leaderboard._start()
	board = buildBoard()
	task.spawn(function()
		task.wait(15) -- let profiles load
		local index = 0
		local lastWriteTick = 0
		while true do
			if os.clock() - lastWriteTick >= 60 then
				lastWriteTick = os.clock()
				local ok, err = pcall(writeAll)
				if not ok then
					warn("[Leaderboard] write pass failed:", err)
				end
			end
			index = index % #CATEGORIES + 1
			local ok, err = pcall(show, CATEGORIES[index])
			if not ok then
				warn("[Leaderboard] board update failed:", err)
			end
			task.wait(ROTATE_SECONDS)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- one last throttle-free save of the leaving player's values
		local client = Network.Bindable.Invoke("S_Client_Get", player)
		if client and client.data and not isMockSession() then
			for _, category in ipairs(CATEGORIES) do
				local ok, value = pcall(category.get, client)
				local last = lastWrite[player.UserId] and lastWrite[player.UserId][category.id]
				local ds = store(category)
				if ok and finite(value) and ds and (not last or last.value ~= value) then
					task.spawn(pcall, ds.SetAsync, ds, tostring(player.UserId), encode(category, value))
				end
			end
		end
		lastWrite[player.UserId] = nil
	end)
end

return Leaderboard
