repeat task.wait() until _G._L

--> Variables
local _L = _G._L

local Network = _L.Get {"Common", "Library", "Network"}
local Services = _L.Get {"Common", "Library", "Services"}
local NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
local Products = _L.Get {"Common", "Modules", "Databases", "Products"}
local Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
local RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
local TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
local ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
local Maid = _L.Get {"Common", "Library", "Classes", "Maid"}
local ColourUtility = _L.Get {"Common", "Library", "Utilities", "ColourUtility"}
local AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
local Shared = _L.Get {"Common", "Modules", "Shared"}
local Audio = _L.Get {"Common", "Library", "Audio"}
local Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
local Zone = _L.Get {"Common", "Library", "Physics", "Zone"}
local Region = _L.Get {"Common", "Library", "Physics", "Region"}
local TableTracker = _L.Get {"Common", "Library", "Classes", "Tracker", "TableTracker"}
local Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
local cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
local scaleModel = _L.Get {"Common", "Library", "Functions", "scaleModel"}
local Settings = _L.Get {"Server", "Modules", "Settings"}
local Create = _L.Get {"Common", "Library", "Functions", "Create"}
local User = _L.Get {"Server", "Modules", "Classes", "User"}
local Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
local Player = _L.Get {"Server", "Modules", "Controllers", "Player"}
local Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
local Constants = _L.Get {"Common", "Modules", "Constants"}
local PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
local DailyGiftUtility = _L.Get {"Common", "Modules", "Utilities", "DailyGiftUtility"}
local TrainingAreaUtility = _L.Get {"Common", "Modules", "Utilities", "TrainingAreaUtility"}
local TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
local SpecialEventUtility = _L.Get {"Common", "Modules", "Utilities", "SpecialEventUtility"}
--> Constants

---------->
local clients = {}

local friendsTrove = Trove.new()

local function update_friends()
	friendsTrove:Clean()
	
	for player, client in pairs(clients) do
		task.spawn(function()
			local total = 0

			local p = {}
			local n = {}
			
			for _, otherPlayer in pairs(Services.Players:GetPlayers()) do
				if otherPlayer == player then
					continue
				end
				
				table.insert(p, Promise.new(function(resolve)
					local success, result = pcall(function()
						return otherPlayer:IsFriendsWith(player.UserId)
					end)

					if success and result then
						total += 1
						table.insert(n, otherPlayer.UserId)
					end

					resolve()
				end))
			end

			friendsTrove:AddPromise(Promise.all(p):andThen(function()
				player:SetAttribute("friends_in_game", total)
				-- Friend Growth Boost: +10% per friend, max +50%
				player:SetAttribute("friend_growth_boost", math.min(total * 0.10, 0.50))
				if #n > 0 then
					local new = TableUtility.deep.clone(client.data:Get("friends_invited"))
					for _, a in pairs(n) do
						if not table.find(new, a) then
							table.insert(new, a)
						end
					end
					client.data:Set("friends_invited", new)
				end
			end))
		end)
	end
end

local function add_client(user)
	repeat Services.RunService.Heartbeat:Wait() until user._data and user._purchases

	local clientPlayer = user._player
	local clientTrove = Trove.new()
	local clientData = user._data
	local clientPurchases = user._purchases

	local newClient = {
		user = user,
		player = clientPlayer,
		trove = clientTrove,
		data = clientData,
		purchases = clientPurchases,
		player_controller = nil
	}
	
	if not clientData or not clientPurchases then
		clientPlayer:Kick("Error while loading your data. Please rejoin.")
		return
	end

	clients[clientPlayer] = newClient
	
	clientTrove:Add(function()
		clients[clientPlayer] = nil
		update_friends()
	end)
	
	user._trove:Add(function()
		clientTrove:Destroy()
	end)
	
	local newPlayerController = Player.new({
		client = newClient
	})
	
	newClient.player_controller = newPlayerController
	
	clientTrove:Add(newPlayerController)
		
	task.spawn(function()
		Services.BadgeService:AwardBadge(clientPlayer.UserId, 2149567602)
		update_friends()
	end)

	return newClient
end

local function get_client(player)
	return clients[player]
end

User.Added:Connect(add_client)

for _, player in pairs(Services.Players:GetPlayers()) do
	local user = User.Await(player, true)

	if user then
		add_client(user)
	end
end

Network.Bindable.Invoked("S_Client_GetAll", function(player)
	return clients
end)

Network.Bindable.Invoked("S_Client_Get", function(player)
	return clients[player]
end)

Network.Remote.Invoked("S_Toolbar_Request", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_get_toolbar_data()
end)

Network.Remote.Fired("S_Toolbar_Toggle_Power", function(player, powerName)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_toggle_power(powerName)
end)

Network.Remote.Invoked("S_Clans_Create", function(player, props)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_clans_create(props)
end)

Network.Remote.Invoked("S_Clans_Shop_Buy", function(player, clanShopItemId)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_clans_shop_buy(clanShopItemId)
end)

Network.Remote.Invoked("S_Clans_Quests_Claim", function(player, clanQuestId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_clans_quests_claim(clanQuestId)
end)

Network.Remote.Invoked("S_Achievements_Claim", function(player, achievementId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_achievement_claim(achievementId)
end)

Network.Remote.Invoked("S_Tree_Upgrade", function(player, nodeId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_tree_upgrade(nodeId)
end)

Network.Remote.Invoked("S_Quests_Claim", function(player, questType, questIndex)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_quests_claim(questType, questIndex)
end)

Network.Remote.Invoked("S_Clans_Leave", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_clans_leave()
end)

Network.Remote.Invoked("S_Clans_Kick", function(player, userId)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_clans_kick(userId)
end)

Network.Remote.Invoked("S_Clans_Join", function(player, clanUid, withCode)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_clans_join(clanUid, withCode)
end)

Network.Remote.Invoked("S_Power_Click", function(player, position)
	if typeof(position) ~= "Vector3" then
		return false, "invalid"
	end

	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_power_click(position)
end)

-- Combat removed: training dummies are gone
Network.Remote.Invoked("S_Upgrade_Request", function(player, upgradeId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_upgrade_request(upgradeId)
end)

Network.Remote.Fired("S_Trade_Cancel", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_trade_cancel()
end)

Network.Remote.Fired("S_Titles_Toggle_Equip", function(player, titleId)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_titles_toggle_equip(titleId)
end)

Network.Remote.Fired("S_Trade_Toggle_Add", function(player, petUid)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_trade_toggle_add(petUid)
end)

Network.Remote.Invoked("S_Cases_Open", function(player, caseId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_cases_open(caseId)
end)

Network.Remote.Fired("S_Season_Claim", function(player, tierType, tierName)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	client.player_controller:_season_claim(tierType, tierName)
end)

Network.Remote.Invoked("S_Rebirth_Request", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false, 1
	end

	return client.player_controller:_rebirth()
end)

Network.Remote.Invoked("S_Wheel_Spin_Request", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_spin_request()
end)

Network.Remote.Invoked("S_Wheel_Spin_Confirm", function(player, spinId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_spin_confirm(spinId)
end)

Network.Remote.Invoked("S_Cases_Confirm", function(player, spinId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_cases_confirm(spinId)
end)

Network.Remote.Invoked("S_Daily_Gifts_Claim", function(player, dailyGiftId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_daily_gifts_claim(dailyGiftId)
end)

Network.Remote.Invoked("S_Rank_Reward_Claim", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_rank_reward_claim()
end)

Network.Remote.Invoked("S_Free_Gifts_Claim", function(player, freeGiftId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_free_gifts_claim(freeGiftId)
end)

Network.Remote.Invoked("S_Pets_Toggle_Equip", function(player, petUid)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_pets_toggle_equip(petUid)
end)
Network.Remote.Invoked("S_Pets_Delete", function(player, petUids)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_pets_delete(petUids)
end)

Network.Remote.Invoked("S_Starter_Choose", function(player, fruitName)
	local client = clients[player]

	if not client or not client.player_controller then
		return false, "error"
	end

	return client.player_controller:_starter_choose(fruitName)
end)

Network.Remote.Invoked("S_Pets_Craft", function(player, petUid)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_pets_craft(petUid)
end)

Network.Remote.Invoked("S_Discord_Verification_Submit", function(player, code)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_discord_verification_submit(code)
end)

Network.Remote.Invoked("S_Pets_Equip_Best", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_pets_equip_best()
end)

Network.Remote.Invoked("S_Codes_Submit", function(player, code)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_submit_code(code)
end)

Network.Remote.Invoked("S_Free_Pet_Pack_Claim", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_free_pet_pack_claim()
end)

Network.Remote.Invoked("S_Clans_Settings_Type", function(player, value)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_clans_settings_type(value)
end)

Network.Remote.Invoked("S_Clans_Settings_Emblem", function(player, value)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_clans_settings_emblem(value)
end)

Network.Remote.Invoked("S_Huge_Event_Reward_Claim", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_huge_event_reward_claim()
end)

Network.Remote.Invoked("S_Invite_Rewards_Claim", function(player, inviteRewardId)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_invite_rewards_claim(inviteRewardId)
end)

Network.Remote.Invoked("S_Hacker_Event_Reward_Claim", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_hacker_event_reward_claim()
end)


-- volume sliders (Settings menu): Music / SFX / Ambient, 0..1, saved in data settings
Network.Remote.Invoked("S_Settings_SetVolume", function(player, which, value)
	local client = clients[player]
	if not client or not client.player_controller then
		return false
	end
	if which ~= "MusicVolume" and which ~= "SFXVolume" and which ~= "AmbientVolume" then
		return false
	end
	if typeof(value) ~= "number" or value ~= value then
		return false
	end
	local data = client.player_controller._data
	local settings = table.clone(data:Get("settings") or {})
	settings[which] = math.clamp(math.round(value * 10) / 10, 0, 1)
	data:Set("settings", settings)
	return true
end)

Network.Remote.Invoked("S_Backpack_Sell", function(player, plantName, amount)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_backpack_sell(plantName, amount)
end)

Network.Remote.Invoked("S_Auto_Collect_Toggle", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_auto_collect_toggle()
end)

Network.Remote.Invoked("S_Auto_Punch_Toggle", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_auto_punch_toggle()
end)

Network.Remote.Invoked("S_Egg_Open_1", function(player, eggName)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_egg_open(eggName, 1)
end)

Network.Remote.Invoked("S_Egg_Open_3", function(player, eggName, s)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_egg_open(eggName, 3, s)
end)

Network.Remote.Invoked("S_Trade_Request", function(player, targetPlayer)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_trade_request(targetPlayer)
end)

Network.Remote.Invoked("S_Boosts_Use", function(player, boostName, boostValue)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_boosts_use(boostName, boostValue)
end)

Network.Remote.Invoked("S_Damage_Register", function(p1, p2, n)
	local client = clients[p1]

	if not client or not client.player_controller then
		return false
	end
	
	return false -- PvP removed
end)

Network.Remote.Invoked("S_Settings_Toggle", function(player, state)
	local client = clients[player]

	if not client or not client.player_controller then
		return false
	end

	return client.player_controller:_settings_toggle(state)
end)

Network.Remote.Fired("S_Egg_Auto_Delete_Toggle", function(player, petName)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_egg_auto_delete_toggle(petName)
end)

Network.Remote.Fired("S_Trade_Ready_Toggle", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_trade_ready_toggle()
end)

Network.Remote.Fired("S_Tutorial_Complete", function(player)
	local client = clients[player]

	if not client or not client.player_controller then
		return
	end

	return client.player_controller:_tutorial_complete()
end)

Network.Remote.Invoked("S_Tutorial_Skip", function(player)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_tutorial_skip()
end)

-- ============================================================
-- FRUIT SYSTEM HANDLERS
-- ============================================================

Network.Remote.Invoked("S_Fruits_Toggle_Equip", function(player, fruitUid)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_fruits_toggle_equip(fruitUid)
end)

Network.Remote.Invoked("S_Fruits_Equip_Best", function(player)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_fruits_equip_best()
end)

Network.Remote.Invoked("S_Fruits_Delete", function(player, fruitUids)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_fruits_delete(fruitUids)
end)

Network.Remote.Invoked("S_Fruits_Feed", function(player, fruitUid, plantName, plantCount)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_fruits_feed(fruitUid, plantName, plantCount)
end)

Network.Remote.Invoked("S_Fruits_Evolve", function(player, fruitUid)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_fruits_evolve(fruitUid)
end)

Network.Remote.Invoked("S_Fruits_Awaken", function(player, fruitUid)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_fruits_awaken(fruitUid)
end)

Network.Remote.Invoked("S_Fruits_Get_Summary", function(player, fruitUid)
	local client = clients[player]
	if not client or not client.player_controller then return nil end
	return client.player_controller:_fruits_get_summary(fruitUid)
end)

Network.Remote.Invoked("S_Fruits_Get_All_Summaries", function(player)
	local client = clients[player]
	if not client or not client.player_controller then return {} end
	return client.player_controller:_fruits_get_all_summaries()
end)

-- ============================================================
-- PLANT SYSTEM HANDLERS
-- ============================================================

Network.Remote.Invoked("S_Plants_Get_Inventory", function(player)
	local client = clients[player]
	if not client or not client.player_controller then return {} end
	return client.player_controller:_plants_get_inventory()
end)

-- ============================================================
-- MASTERY SYSTEM HANDLERS
-- ============================================================

Network.Remote.Invoked("S_Mastery_Get_Summary", function(player)
	local client = clients[player]
	if not client or not client.player_controller then return nil end
	return client.player_controller:_mastery_get_summary()
end)

-- ============================================================
-- GARDEN PLACEMENT HANDLERS
-- ============================================================

Network.Remote.Invoked("S_Garden_Place", function(player, itemType, itemId, cframe)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_garden_place(itemType, itemId, cframe)
end)

Network.Remote.Invoked("S_Garden_Move", function(player, placementId, cframe)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_garden_move(placementId, cframe)
end)

Network.Remote.Invoked("S_Garden_Remove", function(player, placementId)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_garden_remove(placementId)
end)

Network.Remote.Invoked("S_Garden_Expand", function(player)
	local client = clients[player]
	if not client or not client.player_controller then return false end
	return client.player_controller:_garden_expand()
end)

Network.Remote.Invoked("S_Garden_Get_State", function(player)
	local client = clients[player]
	if not client or not client.player_controller then return nil end
	return client.player_controller:_garden_get_state()
end)

Timer.Simple(1, function()
	for player, client in pairs(clients) do
		local newBoostsData = TableUtility.deep.clone(client.data:Get("boosts"))
		
		for boostName, boostData in pairs(newBoostsData) do
			local boostTimeLeft = boostData.time_left
			local boostQuantity = boostData.quantity
			newBoostsData[boostName] = {time_left = math.clamp(boostTimeLeft - 1, 0, math.huge), quantity = boostQuantity}
		end
		
		client.data:Set("boosts", newBoostsData)
	end
end)

-- King of the Hill removed (FRUITBOUND is a peaceful fruit game)
Network.Bindable.Invoked("check", function()
	return false
end)
local newSafeZones = {}

for _, safeZoneInstance in pairs(_L.Map.Safezones:GetChildren()) do
	local zonePart = safeZoneInstance:FindFirstChild("Zone2")
	if not zonePart then
		continue -- empty / broken safezone model, skip it instead of breaking the rest of the script
	end
	local newZone = Zone.new(zonePart)
	
	newZone.playerEntered:Connect(function(player)
		local client = clients[player]
		
		if client then
			local playerController = client.player_controller
			
			if playerController then
				playerController._safezone:Set(safeZoneInstance)
			end
		end
	end)
	
	newZone.playerExited:Connect(function(player)
		local client = clients[player]

		if client then
			local playerController = client.player_controller

			if playerController then
				playerController._safezone:Set(nil)
			end
		end
	end)
	
	newSafeZones[safeZoneInstance] = newZone
end

Network.Bindable.Invoked("S_Safe_Zones_Get_All", function()
	return newSafeZones
end)

Network.Bindable.Invoked("getzone", function(p)
	return newSafeZones[p]
end)

task.spawn(function()
	local ChatService = require(Services.ServerScriptService:WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))

	ChatService.SpeakerAdded:Connect(function(playerName)
		local _, player = TableUtility.match(Services.Players:GetPlayers(), function(i, v)
			return v.Name == playerName
		end)

		if not player then
			return
		end

		local client = get_client(player)

		if not client then
			repeat task.wait() client = get_client(player) until client
		end

		local speaker = ChatService:GetSpeaker(playerName)	

		client.data:Bind("titles", function(value)
			local _, equippedTitleData = TableUtility.match(value, function(i, v)
				return v.equipped
			end)

			if equippedTitleData then
				local equippedTitleId = equippedTitleData.id
				local equippedTitleInfo = TitleUtility.getInfo(equippedTitleId)

				if equippedTitleInfo then
					speaker:SetExtraData("Tags", {{TagText = equippedTitleInfo.text, TagColor = equippedTitleInfo.color}})
				end

				return
			end

			speaker:SetExtraData("Tags", nil)
		end)
	end)
end)

local function start_special_event()
	task.wait(Constants.SPECIAL_EVENT_BETWEEN_TIME)

	local randomSpecialEventInfo = SpecialEventUtility.getRandomInfo()
	local randomSpecialEventId = randomSpecialEventInfo.id

	local cleanup = randomSpecialEventInfo.callback()

	workspace:SetAttribute("special_event", randomSpecialEventId)

	task.wait(randomSpecialEventInfo.duration)

	cleanup()

	workspace:SetAttribute("special_event", nil)

	start_special_event()
end

start_special_event()