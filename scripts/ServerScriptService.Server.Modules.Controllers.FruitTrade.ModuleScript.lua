-- // VARIABLES // --
-- V1.1 Fruit Trading. The server owns every trade:
--   request (15 s, cooldown, privacy setting) -> OPEN (both edit offers by Fruit UID)
--   -> both READY -> LOCKED (final review, offers frozen) -> both CONFIRM -> 3 s countdown
--   -> COMPLETING (one non-yielding swap after re-checking everything) -> COMPLETED
-- Any offer change sets BOTH players back to not ready. Leaving, dying or any failed check
-- cancels the whole trade; nothing changes owner before the final swap.
-- The exact Fruit records move (same UID, level, stage, tier, ...); only `equipped` is cleared.
local _L = _G._L

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Network
local FruitUtility
local FruitStageUtility

local REQUEST_SECONDS = 15
local REQUEST_COOLDOWN = 8 -- seconds between requests to the same player
local ACTION_COOLDOWN = 0.15
local MAX_OFFER = 12
local COUNTDOWN = 3
local HISTORY_SIZE = 20
local VALUABLE = {Epic = true, Legendary = true, Mythical = true, Mythic = true, Huge = true, Secret = true, Divine = true}

local FruitTrade = {}
local trades = {} -- [id] = trade
local byPlayer = {} -- [player] = trade
local requests = {} -- [requestId] = {from, to, expires}
local lastRequestTo = {} -- [from][to] = os.clock()
local lastAction = {}

-- // FUNCTIONS // --

local function getClient(player)
    return Network.Bindable.Invoke("S_Client_Get", player)
end

local function notify(player, text, color)
    local client = getClient(player)
    if client and client.player_controller then
        pcall(function()
            client.player_controller:_notify({text = text, color = color or Color3.fromRGB(150, 210, 255)})
        end)
    end
end

local function passRate(player)
    local now = os.clock()
    if lastAction[player] and now - lastAction[player] < ACTION_COOLDOWN then
        return false
    end
    lastAction[player] = now
    return true
end

local function findFruit(fruits, uid)
    for i, f in ipairs(fruits) do
        if typeof(f) == "table" and f.uid == uid then
            return f, i
        end
    end
    return nil
end

-- why a Fruit record can't be traded right now (nil = tradeable)
local function blockReason(player, fruit)
    if typeof(fruit) ~= "table" or typeof(fruit.uid) ~= "string" then
        return "invalid"
    end
    if fruit.daycare then
        return "daycare"
    end
    local info = FruitUtility.getInfo(fruit.name)
    if not info or info.admin_only or fruit.untradeable or info.untradeable then
        return "untradeable"
    end
    if player:GetAttribute("MountedFruit") == fruit.uid then
        return "mounted"
    end
    return nil
end

-- display data the CLIENT shows (built from the server's records only)
local function view(fruit)
    local info = FruitUtility.getInfo(fruit.name)
    local stage = tonumber(fruit.stage) or 0
    local base = info and (info.display_name or info.name) or tostring(fruit.name)
    local ok, stageName = pcall(FruitStageUtility.getDisplayName, base, stage)
    return {
        uid = fruit.uid,
        name = fruit.name,
        display = if ok then stageName else base,
        rarity = info and info.rarity or "Common",
        image = info and info.image or "",
        level = fruit.level or 1,
        stage = stage,
        tier = fruit.tier,
        equipped = fruit.equipped == true,
    }
end

local function sideOf(trade, player)
    return if trade.sides[1].player == player then trade.sides[1] elseif trade.sides[2].player == player then trade.sides[2] else nil
end

local function otherSide(trade, side)
    return if trade.sides[1] == side then trade.sides[2] else trade.sides[1]
end

-- the offered Fruits of a side, read fresh from its owner's save (missing ones dropped)
local function offerViews(side)
    local client = getClient(side.player)
    local fruits = client and client.data and client.data:Get("fruits") or {}
    local list = {}
    for _, uid in ipairs(side.offer) do
        local f = findFruit(fruits, uid)
        if f then
            table.insert(list, view(f))
        end
    end
    return list
end

local function snapshot(views)
    local parts = {}
    for _, v in ipairs(views) do
        table.insert(parts, table.concat({v.uid, tostring(v.name), tostring(v.level), tostring(v.stage), tostring(v.tier)}, ":"))
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function sendState(trade)
    for _, side in ipairs(trade.sides) do
        local other = otherSide(trade, side)
        Network.Remote.Fire("C_FTrade_State", side.player, {
            id = trade.id,
            state = trade.state,
            countdownEnd = trade.countdownEnd and (workspace:GetServerTimeNow() + (trade.countdownEnd - os.clock())) or nil,
            me = {offer = offerViews(side), ready = side.ready, confirmed = side.confirmed},
            them = {name = other.player.DisplayName, userId = other.player.UserId, offer = offerViews(other), ready = other.ready, confirmed = other.confirmed},
        })
    end
end

local function unreadyAll(trade)
    for _, side in ipairs(trade.sides) do
        side.ready = false
        side.confirmed = false
    end
    trade.countdownEnd = nil
    trade.token += 1
    if trade.state == "LOCKED" then
        trade.state = "OPEN"
    end
end

local function close(trade, reason, completed)
    if trade.closed then
        return
    end
    trade.closed = true
    trade.state = if completed then "COMPLETED" else "CANCELLED"
    trades[trade.id] = nil
    for _, side in ipairs(trade.sides) do
        if byPlayer[side.player] == trade then
            byPlayer[side.player] = nil
        end
        for _, c in ipairs(side.conns or {}) do
            pcall(function()
                if typeof(c) == "RBXScriptConnection" then
                    c:Disconnect()
                elseif typeof(c) == "function" then
                    c()
                elseif typeof(c) == "table" then
                    (c.Disconnect or c.Destroy or c.disconnect)(c)
                end
            end)
        end
        if side.player.Parent then
            Network.Remote.Fire("C_FTrade_Closed", side.player, {id = trade.id, completed = completed == true, reason = reason})
        end
    end
end

------------------------------------------------------------ the swap
local function execute(trade)
    if trade.closed or trade.state ~= "LOCKED" then
        return
    end
    trade.state = "COMPLETING" -- from here every other request is ignored
    local a, b = trade.sides[1], trade.sides[2]
    local clientA, clientB = getClient(a.player), getClient(b.player)
    local function fail(reason)
        if not trade.closed then
            trade.state = "OPEN"
            unreadyAll(trade)
            if a.player.Parent and b.player.Parent then
                notify(a.player, "Trade stopped: " .. reason, Color3.fromRGB(255, 150, 90))
                notify(b.player, "Trade stopped: " .. reason, Color3.fromRGB(255, 150, 90))
                sendState(trade)
            else
                close(trade, "left")
            end
        end
        return false
    end
    if not a.player.Parent or not b.player.Parent or not clientA or not clientB or not clientA.data or not clientB.data then
        close(trade, "left")
        return false
    end
    -- 1) re-validate everything from the saves (nothing yields from here on)
    local fruitsA = clientA.data:Get("fruits") or {}
    local fruitsB = clientB.data:Get("fruits") or {}
    if snapshot(offerViews(a)) ~= trade.locked[1] or snapshot(offerViews(b)) ~= trade.locked[2] then
        return fail("an offered Fruit changed. Check the offers again.")
    end
    local seen = {}
    local moveA, moveB = {}, {}
    for _, pair in ipairs({{a, fruitsA, moveA}, {b, fruitsB, moveB}}) do
        local side, fruits, move = pair[1], pair[2], pair[3]
        for _, uid in ipairs(side.offer) do
            if seen[uid] then
                return fail("a Fruit was offered twice.")
            end
            seen[uid] = true
            local f = findFruit(fruits, uid)
            if not f then
                return fail("an offered Fruit is gone.")
            end
            local why = blockReason(side.player, f)
            if why then
                return fail("an offered Fruit can't be traded (" .. why .. ").")
            end
            move[uid] = f
        end
    end
    -- a UID may only ever exist once across both inventories
    for _, f in ipairs(fruitsB) do
        if moveA[f.uid] then
            return fail("duplicate Fruit detected.")
        end
    end
    for _, f in ipairs(fruitsA) do
        if moveB[f.uid] then
            return fail("duplicate Fruit detected.")
        end
    end
    local function count(t)
        local n = 0
        for _ in pairs(t) do
            n += 1
        end
        return n
    end
    local nA, nB = count(moveA), count(moveB)
    if nA + nB == 0 then
        return fail("both offers are empty.")
    end
    local spaceA = (tonumber(clientA.data:Get({"stats", "Fruit_Storage_Space"})) or 0) - (#fruitsA - nA + nB)
    local spaceB = (tonumber(clientB.data:Get({"stats", "Fruit_Storage_Space"})) or 0) - (#fruitsB - nB + nA)
    if spaceA < 0 or spaceB < 0 then
        return fail("a Fruit inventory would be too full.")
    end
    -- 2) build both new inventories: the SAME records move (deep copies of the exact data)
    local function moved(f)
        local copy = table.clone(f)
        for k, v in pairs(copy) do
            if typeof(v) == "table" then
                copy[k] = table.clone(v)
            end
        end
        copy.equipped = false -- never auto-equipped for the receiver, giver loses its bonus
        return copy
    end
    local newA, newB = {}, {}
    for _, f in ipairs(fruitsA) do
        if not moveA[f.uid] then
            table.insert(newA, f)
        end
    end
    for _, f in ipairs(fruitsB) do
        if not moveB[f.uid] then
            table.insert(newB, f)
        end
    end
    local gaveA, gaveB = {}, {}
    for _, uid in ipairs(a.offer) do
        table.insert(newB, moved(moveA[uid]))
        table.insert(gaveA, {uid = uid, name = moveA[uid].name, stage = moveA[uid].stage, tier = moveA[uid].tier, level = moveA[uid].level})
    end
    for _, uid in ipairs(b.offer) do
        table.insert(newA, moved(moveB[uid]))
        table.insert(gaveB, {uid = uid, name = moveB[uid].name, stage = moveB[uid].stage, tier = moveB[uid].tier, level = moveB[uid].level})
    end
    -- 3) commit both in the same frame (no yield between the two writes)
    clientA.data:Set("fruits", newA)
    clientB.data:Set("fruits", newB)
    -- 4) Fruit Book + small history (after the commit; failures here can't undo the trade)
    local now = os.time()
    for _, pair in ipairs({{clientA, gaveB, gaveA, b.player.UserId}, {clientB, gaveA, gaveB, a.player.UserId}}) do
        pcall(function()
            local client, got, gave, otherId = pair[1], pair[2], pair[3], pair[4]
            local book = table.clone(client.data:Get("discovered_fruits") or {})
            for _, g in ipairs(got) do
                book[g.name] = true
            end
            client.data:Set("discovered_fruits", book)
            local history = table.clone(client.data:Get("trade_history") or {})
            table.insert(history, 1, {t = now, with = otherId, gave = gave, got = got})
            while #history > HISTORY_SIZE do
                table.remove(history)
            end
            client.data:Set("trade_history", history)
        end)
    end
    close(trade, "completed", true)
    return true
end

------------------------------------------------------------ requests
local function canTrade(player)
    return player.Parent == Players and byPlayer[player] == nil
end

function FruitTrade.request(player, target)
    if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player or target.Parent ~= Players then
        return false, "invalid"
    end
    if not passRate(player) then
        return false, "busy"
    end
    if not canTrade(player) then
        return false, "you_trading"
    end
    if not canTrade(target) then
        return false, "trading"
    end
    lastRequestTo[player] = lastRequestTo[player] or {}
    local last = lastRequestTo[player][target]
    if last and os.clock() - last < REQUEST_COOLDOWN then
        return false, "cooldown", math.ceil(REQUEST_COOLDOWN - (os.clock() - last))
    end
    local targetClient = getClient(target)
    if not targetClient or not targetClient.data then
        return false, "invalid"
    end
    local settings = targetClient.data:Get("settings") or {}
    if settings.Trades == false then
        return false, "disabled"
    end
    if settings.Trades_Friends_Only == true then
        local ok, friends = pcall(target.IsFriendsWith, target, player.UserId)
        if not ok or not friends then
            return false, "friends"
        end
    end
    lastRequestTo[player][target] = os.clock()
    local id = HttpService:GenerateGUID(false)
    requests[id] = {from = player, to = target, expires = os.clock() + REQUEST_SECONDS}
    Network.Remote.Fire("C_FTrade_Request", target, {id = id, from = player, name = player.DisplayName, seconds = REQUEST_SECONDS})
    task.delay(REQUEST_SECONDS + 0.5, function()
        if requests[id] then
            requests[id] = nil
            Network.Remote.Fire("C_FTrade_RequestClosed", target, {id = id})
        end
    end)
    return true
end

function FruitTrade.respond(player, id, accept)
    local req = typeof(id) == "string" and requests[id] or nil
    if not req or req.to ~= player then
        return false, "invalid"
    end
    requests[id] = nil
    if os.clock() > req.expires then
        return false, "expired"
    end
    if accept ~= true then
        if req.from.Parent then
            notify(req.from, player.DisplayName .. " declined your trade request.", Color3.fromRGB(255, 170, 90))
        end
        return true
    end
    if not canTrade(req.from) or not canTrade(player) then
        return false, "trading"
    end
    local trade = {
        id = HttpService:GenerateGUID(false), state = "OPEN", token = 0,
        sides = {
            {player = req.from, offer = {}, ready = false, confirmed = false},
            {player = player, offer = {}, ready = false, confirmed = false},
        },
    }
    trades[trade.id] = trade
    for _, side in ipairs(trade.sides) do
        byPlayer[side.player] = trade
        -- an inventory change (deleted / evolved / sent to Daycare...) drops gone Fruits from
        -- the offer and resets READY for both
        local client = getClient(side.player)
        side.conns = {}
        if client and client.data then
            local ok, conn = pcall(function()
                return client.data:Bind("fruits", function()
                    if trade.closed or trade.state == "COMPLETING" then
                        return
                    end
                    local fruits = client.data:Get("fruits") or {}
                    local keep, changed = {}, false
                    for _, uid in ipairs(side.offer) do
                        local f = findFruit(fruits, uid)
                        if f and not blockReason(side.player, f) then
                            table.insert(keep, uid)
                        else
                            changed = true
                        end
                    end
                    if changed then
                        side.offer = keep
                        unreadyAll(trade)
                        sendState(trade)
                    end
                end)
            end)
            if ok and conn ~= nil then
                table.insert(side.conns, conn)
            end
        end
        local character = side.player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            table.insert(side.conns, humanoid.Died:Connect(function()
                if trade.state ~= "COMPLETING" then
                    close(trade, "reset")
                end
            end))
        end
        table.insert(side.conns, side.player.CharacterRemoving:Connect(function()
            if trade.state ~= "COMPLETING" then
                close(trade, "reset")
            end
        end))
    end
    sendState(trade)
    return true
end

------------------------------------------------------------ in-trade actions
local function myTrade(player)
    local trade = byPlayer[player]
    if not trade or trade.closed then
        return nil
    end
    return trade, sideOf(trade, player)
end

function FruitTrade.add(player, uid)
    local trade, side = myTrade(player)
    if not trade or typeof(uid) ~= "string" or not passRate(player) then
        return false, "invalid"
    end
    if trade.state ~= "OPEN" then
        return false, "locked"
    end
    if table.find(side.offer, uid) then
        return false, "already"
    end
    if #side.offer >= MAX_OFFER then
        return false, "full"
    end
    local client = getClient(player)
    local f = client and client.data and findFruit(client.data:Get("fruits") or {}, uid)
    if not f then
        return false, "ownership"
    end
    local why = blockReason(player, f)
    if why then
        return false, why
    end
    table.insert(side.offer, uid)
    unreadyAll(trade)
    sendState(trade)
    return true
end

function FruitTrade.remove(player, uid)
    local trade, side = myTrade(player)
    if not trade or typeof(uid) ~= "string" or not passRate(player) then
        return false, "invalid"
    end
    if trade.state ~= "OPEN" then
        return false, "locked"
    end
    local i = table.find(side.offer, uid)
    if not i then
        return false, "missing"
    end
    table.remove(side.offer, i)
    unreadyAll(trade)
    sendState(trade)
    return true
end

function FruitTrade.ready(player, value)
    local trade, side = myTrade(player)
    if not trade or typeof(value) ~= "boolean" or not passRate(player) then
        return false, "invalid"
    end
    if trade.state == "COMPLETING" then
        return false, "busy"
    end
    if value == false then
        unreadyAll(trade) -- also leaves the final review
        sendState(trade)
        return true
    end
    if trade.state ~= "OPEN" then
        return false, "locked"
    end
    side.ready = true
    local other = otherSide(trade, side)
    if other.ready then
        if #side.offer + #other.offer == 0 then
            side.ready = false
            sendState(trade)
            return false, "empty"
        end
        -- both ready: freeze the offers for the final review
        trade.state = "LOCKED"
        trade.locked = {snapshot(offerViews(trade.sides[1])), snapshot(offerViews(trade.sides[2]))}
        for _, s in ipairs(trade.sides) do
            s.confirmed = false
        end
    end
    sendState(trade)
    return true
end

function FruitTrade.confirm(player)
    local trade, side = myTrade(player)
    if not trade or not passRate(player) then
        return false, "invalid"
    end
    if trade.state ~= "LOCKED" then
        return false, "locked"
    end
    if side.confirmed then
        return false, "already"
    end
    side.confirmed = true
    local other = otherSide(trade, side)
    if other.confirmed and not trade.countdownEnd then
        trade.countdownEnd = os.clock() + COUNTDOWN
        local token = trade.token
        task.delay(COUNTDOWN, function()
            if not trade.closed and trade.state == "LOCKED" and trade.token == token and trade.sides[1].confirmed and trade.sides[2].confirmed then
                local ok, err = pcall(execute, trade)
                if not ok then
                    warn("[FruitTrade] execute failed:", err)
                    close(trade, "error")
                end
            end
        end)
    end
    sendState(trade)
    return true
end

function FruitTrade.cancel(player)
    local trade = myTrade(player)
    if not trade then
        return false
    end
    if trade.state == "COMPLETING" then
        return false, "busy"
    end
    close(trade, "cancelled")
    return true
end

function FruitTrade._init()
    Network = _L.Get {"Common", "Library", "Network"}
    FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
    FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
end

function FruitTrade._start()
    Network.Remote.Invoked("S_FTrade_Request", FruitTrade.request)
    Network.Remote.Invoked("S_FTrade_Respond", FruitTrade.respond)
    Network.Remote.Invoked("S_FTrade_Add", FruitTrade.add)
    Network.Remote.Invoked("S_FTrade_Remove", FruitTrade.remove)
    Network.Remote.Invoked("S_FTrade_Ready", FruitTrade.ready)
    Network.Remote.Invoked("S_FTrade_Confirm", FruitTrade.confirm)
    Network.Remote.Invoked("S_FTrade_Cancel", FruitTrade.cancel)
    Players.PlayerRemoving:Connect(function(player)
        local trade = byPlayer[player]
        if trade and trade.state ~= "COMPLETING" then
            close(trade, "left")
        end
        for id, req in pairs(requests) do
            if req.from == player or req.to == player then
                requests[id] = nil
            end
        end
        lastRequestTo[player] = nil
        lastAction[player] = nil
    end)
end

-- read-only view for tests / debugging
FruitTrade._trades = trades
FruitTrade._byPlayer = byPlayer

return FruitTrade
