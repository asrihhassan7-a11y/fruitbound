--> FruitBook (server)
-- Discovery is tracked HERE only, from the player's real saved fruit list (data "fruits"):
--   any fruit that shows up in the inventory (eggs, starter pick, codes, trades, rewards...) becomes
--   discovered_fruits[name] = true, forever (selling / deleting / trading it away keeps the entry).
-- The client can never unlock anything: it only reads discovered_fruits and gets C_Fruit_Discovered.
-- Existing players: on join everything they already own is filled in silently (no popup spam).

local _L = _G._L

local Players = game:GetService("Players")

local Network
local FruitUtility
local TableUtility

local FruitBook = {}

local function sync(player, data, announce)
	local found = data:Get("discovered_fruits") or {}
	local new = {}
	for _, f in ipairs(data:Get("fruits") or {}) do
		local name = f.name
		if typeof(name) == "string" and not found[name] and not table.find(new, name) then
			local info = FruitUtility.getInfo(name)
			if info and not info.admin_only then
				table.insert(new, name)
			end
		end
	end
	if #new == 0 then
		return
	end
	local updated = TableUtility.deep.clone(found)
	for _, name in ipairs(new) do
		updated[name] = true
	end
	data:Set("discovered_fruits", updated)
	if announce then
		Network.Remote.Fire("C_Fruit_Discovered", player, new)
	end
end

local function watch(player)
	local client
	for _ = 1, 120 do
		client = Network.Bindable.Invoke("S_Client_Get", player)
		if client and client.data then
			break
		end
		task.wait(0.5)
		if not player.Parent then
			return
		end
	end
	if not client or not client.data then
		return
	end
	local data = client.data
	sync(player, data, false) -- backfill what they already own, silently
	data:Bind("fruits", function()
		if player.Parent then
			sync(player, data, true)
		end
	end)
end

function FruitBook._init()
	Network = _L.Get {"Common", "Library", "Network"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
end

function FruitBook._start()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(watch, p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(watch, p)
	end
end

return FruitBook
