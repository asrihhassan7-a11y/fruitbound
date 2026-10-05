--> Items (server)
-- Backpack item actions. EVERYTHING is validated here, the client only asks.
--   S_Item_Hold(name)            hold one of your items in your hand (again = put away)
--   S_Item_Unhold()              put it away
--   S_Item_Delete(name, amount)  throw items away (amount nil = 1, "all" = all)
--   S_Item_Gift(userId, name, amount)  give items to a player standing next to you
-- Anti-dupe: every check + both inventory changes happen in one go with no yields in between,
-- the receiver is credited first and the sender is only debited after that succeeded.
-- Holding does NOT take the item out of the backpack (it is a preview of one you own): if you
-- no longer own it (sold / fed / gifted / deleted) it is put away automatically.

local _L = _G._L

local Network
local BackpackUtility
local CropModelUtility
local MutationUtility

local Players = game:GetService("Players")

local GIFT_DISTANCE = 22
local GIFT_COOLDOWN = 1.5
local ACTION_COOLDOWN = 0.25

local HOLD_ANIM = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://507768375", -- default "toolnone" arm pose
	[Enum.HumanoidRigType.R6] = "rbxassetid://182393478",
}

---------->
local Items = {
	_held = {}, -- [player] = {name, model, track, died}
	_lastGift = {},
	_lastAction = {},
}

local function getClient(player)
	local ok, client = pcall(Network.Bindable.Invoke, "S_Client_Get", player)
	return ok and client or nil
end

local function notify(player, text, color)
	Network.Remote.Fire("C_Notifications_Add", player, {text = text, color = color or Color3.fromRGB(120, 230, 120)})
end

local function validName(name)
	return typeof(name) == "string" and #name > 0 and #name <= 80
end

local function owned(data, name)
	local n = (data:Get("plants") or {})[name]
	return if typeof(n) == "number" then math.floor(n) else 0
end

local function throttle(player)
	local now = os.clock()
	if now - (Items._lastAction[player] or 0) < ACTION_COOLDOWN then
		return false
	end
	Items._lastAction[player] = now
	return true
end

-- remove `amount` of `name` from a backpack (keeps stored worth in sync). No checks: callers validate.
local function removeItems(data, name, amount)
	local before = owned(data, name)
	BackpackUtility.removeWorth(data, name, amount, before)
	local plants = table.clone(data:Get("plants") or {})
	plants[name] = before - amount
	if plants[name] <= 0 then
		plants[name] = nil
	end
	data:Set("plants", plants)
end

-- add `amount` of `name` worth `worth` coins in total
local function addItems(data, name, amount, worth)
	local plants = table.clone(data:Get("plants") or {})
	plants[name] = (plants[name] or 0) + amount
	data:Set("plants", plants)
	if worth and worth > 0 then
		local values = table.clone(data:Get("plant_values") or {})
		local entry = values[name] or {c = 0, v = 0}
		values[name] = {c = entry.c + amount, v = entry.v + worth}
		data:Set("plant_values", values)
	end
end

------------------------------------------------------------ HOLD
function Items.unhold(player)
	local state = Items._held[player]
	if not state then
		return false
	end
	Items._held[player] = nil
	player:SetAttribute("HeldItem", nil)
	if state.died then
		state.died:Disconnect()
	end
	if state.track then
		pcall(function()
			state.track:Stop(0.25)
		end)
	end
	if state.model then
		state.model:Destroy()
	end
	return true
end

function Items.hold(player, name)
	if not validName(name) then
		return false, "missing"
	end
	local client = getClient(player)
	local data = client and client.data
	if not data or owned(data, name) < 1 then
		return false, "missing"
	end
	local state = Items._held[player]
	if state and state.name == name then
		Items.unhold(player)
		return true, nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "dead"
	end
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local hand = character:FindFirstChild(if r15 then "RightHand" else "Right Arm")
	if not hand then
		return false, "dead"
	end

	Items.unhold(player)

	local model = CropModelUtility.build(name)
	model.Name = "HeldItem"
	local handle = model.PrimaryPart
	-- sits on top of the fist, standing upright while the arm is held forward (hold pose)
	local weld = Instance.new("Weld")
	weld.Name = "HoldWeld"
	weld.Part0 = hand
	weld.Part1 = handle
	weld.C0 = CFrame.new(0, -hand.Size.Y / 2 - 0.05, -0.1) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, 0, 0.15)
	weld.Parent = handle
	model:PivotTo(hand.CFrame * weld.C0)
	model.Parent = character

	local track
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local anim = Instance.new("Animation")
		anim.AnimationId = HOLD_ANIM[humanoid.RigType]
		track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.25)
	end)

	local newState = {name = name, model = model, track = track}
	newState.died = humanoid.Died:Connect(function()
		Items.unhold(player)
	end)
	Items._held[player] = newState
	player:SetAttribute("HeldItem", name)
	return true, name
end

------------------------------------------------------------ DELETE
function Items.delete(player, name, amount)
	if not validName(name) or not throttle(player) then
		return false
	end
	local client = getClient(player)
	local data = client and client.data
	if not data then
		return false
	end
	local have = owned(data, name)
	local n = if amount == "all" then have elseif typeof(amount) == "number" and amount == amount then math.floor(amount) else 1
	n = math.clamp(n, 0, have)
	if n <= 0 then
		return false
	end
	removeItems(data, name, n)
	return true, n
end

------------------------------------------------------------ GIFT
-- returns true, amount | false, reason ("missing", "target", "far", "full", "cooldown", "self")
function Items.gift(sender, targetUserId, name, amount)
	if not validName(name) then
		return false, "missing"
	end
	local now = os.clock()
	if now - (Items._lastGift[sender] or 0) < GIFT_COOLDOWN then
		return false, "cooldown"
	end
	if typeof(targetUserId) ~= "number" then
		return false, "target"
	end
	local receiver = Players:GetPlayerByUserId(targetUserId)
	if not receiver then
		return false, "target"
	end
	if receiver == sender then
		return false, "self"
	end

	local senderClient, receiverClient = getClient(sender), getClient(receiver)
	local sData = senderClient and senderClient.data
	local rData = receiverClient and receiverClient.data
	if not sData or not rData then
		return false, "target"
	end

	-- both must be alive and close to each other
	local sRoot = sender.Character and sender.Character:FindFirstChild("HumanoidRootPart")
	local rRoot = receiver.Character and receiver.Character:FindFirstChild("HumanoidRootPart")
	if not sRoot or not rRoot or (sRoot.Position - rRoot.Position).Magnitude > GIFT_DISTANCE then
		return false, "far"
	end

	-- ownership + amount (NaN / negatives / decimals rejected)
	local have = owned(sData, name)
	local n = if amount == "all" then have elseif typeof(amount) == "number" and amount == amount then math.floor(amount) else 1
	n = math.clamp(n, 0, have)
	if n <= 0 then
		return false, "missing"
	end

	-- receiver needs room
	local space = BackpackUtility.getCapacity(rData) - BackpackUtility.getCount(rData)
	if space <= 0 then
		return false, "full"
	end
	n = math.min(n, space)

	Items._lastGift[sender] = now

	-- the gift keeps its value (stored worth moves with the items)
	local worth = BackpackUtility.getWorth(sData, name, n, nil)
	local receiverBefore = owned(rData, name)

	-- 1) credit the receiver
	addItems(rData, name, n, worth)
	if owned(rData, name) ~= receiverBefore + n then
		return false, "target"
	end
	-- 2) only then debit the sender (re-checked, nothing yielded in between)
	if owned(sData, name) < n then
		-- should never happen: undo the credit
		removeItems(rData, name, n)
		return false, "missing"
	end
	removeItems(sData, name, n)

	local _, mutation = MutationUtility.split(name)
	Network.Remote.Fire("C_Gift_Received", receiver, {from = sender.DisplayName, fromId = sender.UserId, name = name, amount = n, rare = mutation ~= nil})
	return true, n
end

------------------------------------------------------------
function Items._init()
	Network = _L.Get {"Common", "Library", "Network"}
	BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
	CropModelUtility = _L.Get {"Common", "Modules", "Utilities", "CropModelUtility"}
	MutationUtility = _L.Get {"Common", "Modules", "Utilities", "MutationUtility"}
end

function Items._start()
	Network.Remote.Invoked("S_Item_Hold", function(player, name)
		if not throttle(player) then
			return false, "cooldown"
		end
		return Items.hold(player, name)
	end)
	Network.Remote.Invoked("S_Item_Unhold", function(player)
		return Items.unhold(player)
	end)
	Network.Remote.Invoked("S_Item_Delete", function(player, name, amount)
		return Items.delete(player, name, amount)
	end)
	Network.Remote.Invoked("S_Item_Gift", function(player, targetUserId, name, amount)
		local ok, result = Items.gift(player, targetUserId, name, amount)
		return ok, result
	end)

	local function setup(player)
		player.CharacterRemoving:Connect(function()
			Items.unhold(player)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		Items.unhold(player)
		Items._lastGift[player] = nil
		Items._lastAction[player] = nil
	end)

	-- put the item away when it is no longer in the backpack (sold, fed, gifted, deleted)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player, state in pairs(Items._held) do
				local client = getClient(player)
				if not client or not client.data or owned(client.data, state.name) < 1 or not state.model.Parent then
					Items.unhold(player)
				end
			end
		end
	end)
end

return Items
