--> Variables
local _L = _G._L

local Services
local Maid
local Network
local Audio
local TableUtils
local Character
local Shared
local RandomUtility
local Timer
local Create
local NumberUtility
local TableUtility
local Tags
local DictionaryUtility
local cancellableDelay
local Tracker
local Powers
local PowerComponents
local PowerUtility
local AttributeUtility
local WheelRewards
local DailyGiftUtility
local FreeGiftUtility
local WheelRewardUtility
local PetUtility
local PowerComponentUtility
local TrainingAreaUtility
local RankUtility
local Codes
local CodesUtility
local EggUtility
local BoostUtility
local FreePetPackUtility
local Trade
local TradeRequest
local TradeUtility
local SettingUtility
local TableTracker
local SeasonUtility
local UpgradeUtility
local Clan
local RobuxMultiplierUtility
local ClanShopItemUtility
local QuestUtility
local HackerEventUtility
local TutorialQuestUtility
local ClanEmblems
local MasteryUtility
local MasteryDB

local CLANS_DATA_STORE
local MESSAGES_SORTED_MAP
local JOIN_CODES_DATA_STORE

--> Constants

------------->
local Player = {_objects = {}}
Player.__index = Player

function Player._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Character = _L.Get {"Server", "Modules", "Controllers", "Character"}
	Trade = _L.Get {"Server", "Modules", "Controllers", "Trade"}
	Clan = _L.Get {"Server", "Modules", "Controllers", "Clan"}
	TradeRequest = _L.Get {"Server", "Modules", "Controllers", "TradeRequest"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	TableTracker = _L.Get {"Common", "Library", "Classes", "Tracker", "TableTracker"}
	Shared = _L.Get {"Common", "Modules", "Shared"}
	Orb = _L.Get {"Server", "Modules", "Controllers", "Orb"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Tags = _L.Get {"Server", "Modules", "Tags"}
	DictionaryUtility = _L.Get {"Common", "Library", "Utilities", "DictionaryUtility"}
	Powers = _L.Get {"Common", "Modules", "Databases", "Powers", "Powers"}
	PowerComponents = _L.Get {"Common", "Modules", "Databases", "Powers", "Components"}
	_Stats = _L.Get {"Common", "Modules", "Databases", "Stats"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	WheelRewards = _L.Get {"Common", "Modules", "Databases", "WheelRewards"}
	DailyGiftUtility = _L.Get {"Common", "Modules", "Utilities", "DailyGiftUtility"}
	FreeGiftUtility = _L.Get {"Common", "Modules", "Utilities", "FreeGiftUtility"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	WheelRewardUtility = _L.Get {"Common", "Modules", "Utilities", "WheelRewardUtility"}
	PetUtility = _L.Get {"Common", "Modules", "Utilities", "PetUtility"}
	PowerComponentUtility = _L.Get {"Common", "Modules", "Utilities", "PowerComponentUtility"}
	PowerUtility = _L.Get {"Common", "Modules", "Utilities", "PowerUtility"}
	TrainingAreaUtility = _L.Get {"Common", "Modules", "Utilities", "TrainingAreaUtility"} 
	RobuxMultiplierUtility = _L.Get {"Common", "Modules", "Utilities", "RobuxMultiplierUtility"} 
	RankUtility = _L.Get {"Common", "Modules", "Utilities", "RankUtility"}
	CodesUtility = _L.Get {"Server", "Modules", "Utilities", "CodesUtility"} 
	Codes = _L.Get {"Server", "Modules", "Databases", "Codes"}
	EggUtility = _L.Get {"Common", "Modules", "Utilities", "EggUtility"}
	BoostUtility = _L.Get {"Common", "Modules", "Utilities", "BoostUtility"}
	FreePetPackUtility = _L.Get {"Common", "Modules", "Utilities", "FreePetPackUtility"}
	FreeHugeEventUtility = _L.Get {"Common", "Modules", "Utilities", "FreeHugeEventUtility"}
	HackerEventUtility = _L.Get {"Common", "Modules", "Utilities", "HackerEventUtility"}
	TradeUtility = _L.Get {"Common", "Modules", "Utilities", "TradeUtility"}
	SettingUtility = _L.Get {"Common", "Modules", "Utilities", "SettingUtility"}
	SeasonUtility = _L.Get {"Common", "Modules", "Utilities", "SeasonUtility"}
	TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
	CaseUtility = _L.Get {"Common", "Modules", "Utilities", "CaseUtility"}
	UpgradeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeUtility"}
	ClanQuestUtility = _L.Get {"Common", "Modules", "Utilities", "ClanQuestUtility"}
	ClanShopItemUtility = _L.Get {"Common", "Modules", "Utilities", "ClanShopItemUtility"}
	DailyQuestUtility = _L.Get {"Common", "Modules", "Utilities", "DailyQuestUtility"}
	WeeklyQuestUtility = _L.Get {"Common", "Modules", "Utilities", "WeeklyQuestUtility"}
	QuestUtility = _L.Get {"Common", "Modules", "Utilities", "QuestUtility"}
	TutorialQuestUtility = _L.Get {"Common", "Modules", "Utilities", "TutorialQuestUtility"}
	ClanEmblems = _L.Get {"Common", "Modules", "Databases", "ClanEmblems"}
	InviteRewardUtility = _L.Get {"Common", "Modules", "Utilities", "InviteRewardUtility"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	PlantUtility = _L.Get {"Common", "Modules", "Utilities", "PlantUtility"}
	MasteryUtility = _L.Get {"Common", "Modules", "Utilities", "MasteryUtility"}
	MasteryDB = _L.Get {"Common", "Modules", "Databases", "Mastery"}
end

function Player._start()
	task.spawn(function()
		CLANS_DATA_STORE = Services.DataStoreService:GetDataStore("Clans_001")
		_G.CLANS_DATA_STORE = CLANS_DATA_STORE
	end)
	
	task.spawn(function()
		JOIN_CODES_DATA_STORE = Services.DataStoreService:GetDataStore("Join_Codes_001")
		_G.JOIN_CODES_DATA_STORE = JOIN_CODES_DATA_STORE
	end)
	
	task.spawn(function()
		MESSAGES_SORTED_MAP = Services.MemoryStoreService:GetSortedMap("Messages_001")
		_G.MESSAGES_SORTED_MAP = MESSAGES_SORTED_MAP
	end)
end

function Player.new(props)
	local self = setmetatable({}, Player)
	
	self._client = props.client
	
	self._data = self._client.data
	self._purchases = self._client.purchases
	
	self._instance = self._client.player
	self._character_controller = nil
	self._is_dead = Tracker.new(true)

	self._toolbar_data = Tracker.new({})
	self._main_power = Tracker.new(nil)
	self._current_power = {
		tracker = Tracker.new(nil),
		maid = Maid.new()
	}
	
	self._trade = Tracker.new(nil)
	self._trade_requests = {}
	
	self._flags = TableTracker.new({})
	
	self._last_cooldown = 0
	self._egg_hatch_busy = false
	self._last_egg_hatch = 0
	self._paid_random_items_restricted = nil
	
	self._training_area = Tracker.new(nil)
	self._safezone = Tracker.new(nil)
	
	self._last_animation = 1
	self._active_wheel_spins = {}
	self._active_case_spins = {}
	self._last_clan_action = Tracker.new(tick())
	
	self._maid = Maid.new()
	
	self._maid:GiveTask(self._flags)

	self:_construct()

	return self
end

function Player:_construct()
	Player._objects[self._instance] = self

	self._maid:GiveTask(function()
		Player._objects[self._instance] = nil
	end)

	task.spawn(function()
		self:_setup()
	end)
end

function Player:_setup()
	self:_add_character(self._instance.Character or self._instance.CharacterAdded:Wait())

	self._instance.CharacterAdded:Connect(function(...)
		self:_add_character(...)
	end)

	-- Profiles from the earlier inferred guide did not store each core-loop step.
	-- Migrate them once; new profiles already start on tutorial version 2.
	if (self._data:Get("tutorial_version") or 0) < 2 then
		local migratedStep = 1
		local plants = self._data:Get("plants") or {}
		if (self._data:Get("seed_planted_count") or 0) > 0 then
			migratedStep = 7
		elseif self._data:Get("tutorial_sold") then
			migratedStep = 3
		elseif (self._data:Get({"stats", "Food_Collected"}) or 0) > 0 or next(plants) ~= nil then
			migratedStep = 2
		end
		self._data:Set("tutorial_marker", migratedStep)
		self._data:Set("tutorial_version", 2)
	end

	if (self._data:Get("tutorial_version") or 0) < 3 then
		if self._data:Get("tutorial_marker") == 7 then
			self._data:Set("tutorial_marker", 8)
		end
		self._data:Set("tutorial_version", 3)
	end

	-- prices changed in the final economy pass: players waiting on step 3 / 6 can still afford it
	local waitingStep = self._data:Get("tutorial_marker")
	if waitingStep == 3 or waitingStep == 6 then
		self:_tutorial_cover_costs(waitingStep)
	end

	-- look up the hatch policy early: restricted accounts hatch from a guaranteed order and the
	-- client shows the exact next Fruit (attribute read by the Egg stands)
	task.spawn(function()
		local restricted = self:_paid_random_items_policy()
		if restricted ~= nil and self._instance.Parent then
			self._instance:SetAttribute("GuaranteedHatch", restricted)
		end
	end)

	local leaderstats = Create("Folder", {
		Name = "leaderstats",
		Parent = self._instance
	})

	for _, statInfo in pairs(_Stats) do
		if not statInfo.leaderstats then
			continue
		end
		
		local statInstance = Create("StringValue", {
			Name = statInfo.display_name,
			Parent = leaderstats,
			Value = "..."
		})

		self._data:Bind({"stats", statInfo.name}, function(value)
			statInstance.Value = NumberUtility.short(value)
		end)
	end
	
	AttributeUtility.set(self._instance, "visited_best_training_area", true)
	
	local total = Tracker.new(TrainingAreaUtility.getTotalCount(self._data))

	self._maid:GiveTask(total:Bind(function(value)
		local oldValue = total:GetLast()

		if oldValue and value and value > oldValue then
			AttributeUtility.set(self._instance, "visited_best_training_area", false)
		end
	end))
	
	self._maid:GiveTask(self._data:Bind({"stats", "Strength"}, function(value)
		total:Set(TrainingAreaUtility.getTotalCount(self._data))
		self:_update_toolbar_data()
	end))
	
	self._maid:GiveTask(self._flags:Bind({}, function(value)
		AttributeUtility.set(self._instance, "flags", value)
	end))
	
	self._maid:GiveTask(self._last_clan_action:Bind(function(value)
		AttributeUtility.set(self._instance, "last_clan_action", value)
	end))
	
	self._maid:GiveTask(self._toolbar_data:Bind(function(value)
		AttributeUtility.set(self._instance, "toolbar_data", value)
	end))
	
	self._maid:GiveTask(self._trade:Bind(function(value)
		AttributeUtility.set(self._instance, "trade", value)
	end))
	
	self._maid:GiveTask(self._data:Bind("clan", function(value)
		local newValue = value
		
		for _, clan in pairs(Clan._objects) do
			if (clan._uid ~= value and clan._data) or (clan._data and clan._data:Get("deleted")) then
				local success = clan:_kick(self._instance.UserId)
			end
		end

		for _, clan in pairs(Clan._objects) do
			task.spawn(function()
				if clan._uid == value and clan._data then
					local _, playerPacket = TableUtility.match(clan._data:Get("players"), function(i, v)
						return v[1] == self._instance.UserId
					end)

					if not playerPacket or clan._data:Get("deleted") then
						newValue = nil
						self._data:Set("clan", newValue)
					end
				end

				clan:_should_destroy()
			end)
		end
		
		if not newValue then
			return
		end
		
		local clan = Clan._objects[value]
		
		if not clan then
			Clan.new({uid = value})
		end
	end))
	
	self._maid:GiveTask(Tracker.Subscribe({self._safezone, self._data:Track({"boosts", "Protection_Potion"})}, function()
		local safeZoneValue = self._safezone:Get()
		local protectionPotionTime = self._data:Get({"boosts", "Protection_Potion", "time_left"})
		
		if protectionPotionTime > 0 or safeZoneValue then
			self:add_flag("protection")
		else
			self:remove_flag("protection")
		end
	end))
	
	self._maid:GiveTask(Tracker.Subscribe({self._current_power.tracker, self._is_dead}, function()
		self._last_animation = 1
		
		local value = self._current_power.tracker:Get()
		local isDead = self._is_dead:Get()

		self._current_power.maid:DoCleaning()

		for _, oldPowerComponentInfo in pairs(PowerComponents) do
			if not oldPowerComponentInfo.idle_animation then
				continue
			end
			
			self._character_controller:stop_animation({
				name = oldPowerComponentInfo.idle_animation
			})
		end
		
		if value and not isDead then
			local _, powerInfo = TableUtility.match(Powers, function(i, v)
				return v.name == value
			end)

			if powerInfo then
				local _, powerComponentInfo = TableUtility.match(PowerComponents, function(i, v)
					return v.name == powerInfo.component
				end)

				local powerName = powerInfo.name

				if self._character_controller then
					if powerComponentInfo.idle_animation then
						self._character_controller:play_animation({
							name = powerComponentInfo.idle_animation,
							fade_time = 0.2
						})
					end

					self._current_power.maid:GiveTask(cancellableDelay(0.2, function()
						local powerInstance = _L.Assets.Models.Powers:FindFirstChild(powerName)
						if powerInstance then
							local newPowerInstance = powerInstance:Clone()

							self._current_power.maid:GiveTask(newPowerInstance)

							newPowerInstance.Parent = self._character_controller._instance
						end
					end))
				end
			end
		end

		self._instance:SetAttribute("current_power", value)
	end))
	
	self._instance:SetAttribute("last_wheel_time", os.time())
	self._instance:SetAttribute("join_time", os.time())
	AttributeUtility.set(self._instance, "free_gifts", {})
	
	self._maid:GiveTask(Timer.Simple(0.5, function()
		self._data:Set({"stats", "Total_Time"}, self._data:Get({"stats", "Total_Time"}) + 0.5)
		
		if self._data:Get("auto_collect") then
			-- Auto Collect (V1.1): while standing on your own farm, harvests ONE whole mature crop of the
			-- closest mature crop of yours within 30 studs, every 3.5s (down to 2s with good
			-- equipped Fruits, FruitFarmUtility). Slower than tapping crops yourself on purpose.
			local _, reason = self:_auto_collect_tick()
			-- tell the player ONCE per "backpack full" episode (no repeating spam)
			if reason == "full" then
				if not self._full_hinted then
					self._full_hinted = true
					self:_notify({text = "🎒 Backpack full!", color = Color3.fromRGB(255, 170, 60)})
				end
			elseif reason ~= nil then
				-- a real attempt that was not "full" (cooldown / off-farm ticks return nil)
				self._full_hinted = false
			end
		elseif self._data:Get("auto_punch") then
			self._current_power.tracker:Set("Punch")
			self:_power_click()
		end
		
		if self._data:Get({"settings", "Auto_Rebirth"}) then
			self:_rebirth()
		end
		
		if WheelRewardUtility.canClaim(self._instance) then
			self._instance:SetAttribute("last_wheel_time", os.time())
			
			PlayerRewardUtility.give(self._client, {{name = "Stat", props = {
				name = "Wheel_Spin",
				value = 1
			}}}, false)
		end
		
		local currentDailyRound = DailyQuestUtility.getCurrentRound()
		local dataDailyRound = self._data:Get({"quests", "daily", "t"})
		
		if dataDailyRound ~= currentDailyRound then
			self._data:Set({"quests", "daily"}, {
				t = currentDailyRound,
				v = DailyQuestUtility.generateList(self._client)
			})
		end
		
		local currentWeeklyRound = WeeklyQuestUtility.getCurrentRound()
		local dataWeeklyRound = self._data:Get({"quests", "weekly", "t"})

		if dataWeeklyRound ~= currentWeeklyRound then
			self._data:Set({"quests", "weekly"}, {
				t = currentWeeklyRound,
				v = WeeklyQuestUtility.generateList(self._client)
			})
		end
		
		if not self._data:Get({"quests", "tutorial", "c"}) and TableUtility.length(self._data:Get({"quests", "tutorial", "v"})) == 0 then
			self._data:Set({"quests", "tutorial"}, {
				c = false,
				v = TutorialQuestUtility.getList(self._client)
			})
		end
	end))
	
	self._maid:GiveTask(Tracker.Subscribe({self._data:Track({"upgrades", "3"}), self._data:Track({"gamepasses"})}, function()
		local v1 = self._purchases:OwnsGamepass("5_Pets_Equipped")
		local v2 = self._purchases:OwnsGamepass("8_Pets_Equipped")
		local v3 = self._data:Get({"upgrades", "3"})
		self._data:Set({"stats", "Pet_Equip_Space"}, 3 + (v3 - 1) + (if v1 then 5 else 0) + (if v2 then 8 else 0))
	end))

	-- Upgrade Tree: fruit storage / equip slots follow the tree levels
	self._maid:GiveTask(self._data:Bind("tree", function()
		local UpgradeTreeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeTreeUtility"}
		self._data:Set({"stats", "Fruit_Storage_Space"}, 35 + UpgradeTreeUtility.getBonus(self._data, "fruit_storage"))
		self._data:Set({"stats", "Fruit_Equip_Space"}, 3 + UpgradeTreeUtility.getBonus(self._data, "fruit_equip"))
	end))

	-- Food was renamed to plant names: move any saved food to its new name
	do
		local FOOD_RENAMES = {
			["Apple"] = "Clover", ["Berry"] = "Mint Leaf", ["Coconut"] = "Sunflower Seed",
			["Mango"] = "Glow Mushroom", ["Melon"] = "Honey Blossom", ["Pineapple"] = "Aloe Leaf",
			["Dragon Berry"] = "Dragon Lily", ["Star Fruit"] = "Star Petal", ["Golden Apple"] = "Golden Sprout",
			["Crystal Mango"] = "Crystal Bloom", ["Cosmic Fruit"] = "Cosmic Fern", ["Divine Fruit"] = "Divine Lotus",
		}
		local plants = self._data:Get("plants") or {}
		local changed = false
		local newPlants = table.clone(plants)
		for oldName, newName in pairs(FOOD_RENAMES) do
			if newPlants[oldName] then
				newPlants[newName] = (newPlants[newName] or 0) + newPlants[oldName]
				newPlants[oldName] = nil
				changed = true
			end
		end
		if changed then
			self._data:Set("plants", newPlants)
		end
	end

	-- Titles: everyone owns the starter title; equip it if nothing is equipped
	do
		local starterId = "seedling"
		if not TitleUtility.owns(self._data, starterId) then
			TitleUtility.give(self._client, {id = starterId})
		end
		if not TitleUtility.getEquipped(self._data) then
			self:_titles_toggle_equip(starterId)
		end
	end

	-- Achievements: fill in counters for players who played before they existed
	do
		local fruits = self._data:Get("fruits") or {}
		if (self._data:Get({"stats", "Fruits_Collected"}) or 0) < #fruits then
			self._data:Set({"stats", "Fruits_Collected"}, #fruits)
		end
		local best = 0
		for _, f in ipairs(fruits) do
			best = math.max(best, f.stage or 0)
		end
		if (self._data:Get({"stats", "Best_Fruit_Stage"}) or 0) < best then
			self._data:Set({"stats", "Best_Fruit_Stage"}, best)
		end
	end

	-- Safety: a normal player should never own an ADMIN ONLY fruit - remove it if they somehow do
	do
		local AdminUtility = _L.Get {"Common", "Modules", "Utilities", "AdminUtility"}
		if not AdminUtility.isAdmin(self._instance) then
			local bad = {}
			for _, f in ipairs(self._data:Get("fruits") or {}) do
				local info = FruitUtility.getInfo(f.name)
				if info and info.admin_only then
					table.insert(bad, f.uid)
				end
			end
			if #bad > 0 then
				FruitUtility.remove(self._data, bad)
			end
		end
	end

	-- Starter fruit: brand-new players start with NO fruit and pick Strawberry or Apple in the
	-- "Choose Your Starter Fruit!" menu (client StarterSelect -> S_Starter_Choose -> Player:_starter_choose).
	-- Players who already own a fruit are marked as done so they never see the menu, and keep their fruits.
	if not self._data:Get("received_starter_fruit") and #(self._data:Get("fruits") or {}) > 0 then
		self._data:Set("received_starter_fruit", true)
	end

	-- One-time fix: the starter Apple should never be Rainbow.
	-- (Before, the Rainbow Eggs gamepass could make it Rainbow.) Turns any saved Rainbow Apple back to normal on join.
	do
		local newFruits = TableUtility.deep.clone(self._data:Get("fruits") or {})
		local changed = false

		for _, fruit in pairs(newFruits) do
			if fruit.name == "Apple" and fruit.tier == "Rainbow" then
				fruit.tier = nil
				changed = true
			end
		end

		if changed then
			self._data:Set("fruits", newFruits)
		end
	end

	-- Default the equipped power to Punch so combat hits validate immediately on join.
	-- The tracker starts nil each session, which previously made _get_current_power_info
	-- return nil and reject every hit until the player manually equipped a power.
	if self._current_power.tracker:Get() == nil then
		self._current_power.tracker:Set("Punch")
	end
end

function Player:_add_character(character)
	repeat Services.RunService.Heartbeat:Wait() until workspace:IsAncestorOf(character)

	if self._character_controller then
		self._character_controller:Destroy()
	end

	self._character_controller = Character.new({
		instance = self._instance.Character or self._instance.CharacterAdded:Wait(),
		player_controller = self
	})

	self._is_dead:Set(false)
end

function Player:add_flag(flagName)
	self._flags:Set({flagName}, true)
end

function Player:remove_flag(flagName)
	self._flags:Set({flagName}, nil)
end

function Player:has_flag(flagName)
	return self._flags:Get({})[flagName] ~= nil
end

function Player:_filter_text(text)
	local function get_text_object(message, fromPlayerId)
		local textObject
		local success, errorMessage = pcall(function()
			textObject = Services.TextService:FilterStringAsync(message, self._instance.UserId)
		end)
		if success then
			return true, textObject
		elseif errorMessage then
			print("Error generating TextFilterResult:", errorMessage)
		end
		return false
	end

	local function get_filtered_message(textObject)
		local filteredMessage
		local success, errorMessage = pcall(function()
			filteredMessage = textObject:GetNonChatStringForBroadcastAsync()
		end)
		if success then
			return true, filteredMessage
		elseif errorMessage then
			print("Error filtering message:", errorMessage)
		end
		return false
	end

	local success, messageObject = get_text_object(text, self._instance.UserId)
	
	if success then
		local filteredText = ""
		local success, filteredText = get_filtered_message(messageObject)
		
		if success then
			return true, filteredText
		else
			return false
		end
	end
	
	return false
end

function Player:_clans_create(props)
	if self._data:Get("clan") then
		return false
	end
	
	if (self._data:Get({"stats", "Gems"}) - Constants.CLAN_CREATION_GEMS_COST) < 0 then
		return false, "enough"
	end
	
	if tick() - self._last_clan_action:Get() < Constants.CLAN_ACTION_DELAY then
		return false, "delay", tick()
	end

	self._last_clan_action:Set(tick())
	
	local clanUid = Services.HttpService:GenerateGUID(false)
	local clanNameSuccess, clanName = self:_filter_text(props.name)

	if clanNameSuccess then
	--	local clanDescriptionSuccess, clanDescription = self:_filter_text(props.description)
		
		--if clanDescriptionSuccess then
			self._data:Set({"stats", "Gems"}, self._data:Get({"stats", "Gems"}) - Constants.CLAN_CREATION_GEMS_COST)

			local clanEmblem = props.emblem

			if not CLANS_DATA_STORE then
				repeat task.wait() until CLANS_DATA_STORE
			end

			local success, result = pcall(function()
				return CLANS_DATA_STORE:SetAsync(clanUid, {
					name = {clanName, tick()},
					emblem = {clanEmblem, tick()},
					uid = clanUid,
					players = {{self._instance.UserId, tick(), "Owner"}},
					kills = 0,
					deaths = 0,
					eggs_opened = 0,
					max_players = Constants.DEFAULT_CLAN_MAX_PLAYERS,
					quests = {},
					join_code = nil,
					--description = {clanDescription, tick()}
				})
			end)

			if success then
				self._data:Set("clan", clanUid)
				return true
			else
				return false
			end
		--end
	end
	
	return false
end

function Player:get_clan()
	local clanUid = self._data:Get("clan")
	if not clanUid then
		return
	end
	return Clan._objects[clanUid]
end

function Player:_discord_verification_submit(code)
	if self._data:Get("discord_verified") then
		return false
	end

	code = string.lower(code)

	if code == "hotsimulators" then
		self._data:Set("discord_verified", true)

		task.spawn(function()
			Services.BadgeService:AwardBadge(self._instance.UserId, 2150108502)
		end)

		PlayerRewardUtility.give(self._client, {
			{
				name = "Pet",
				props = {
					name = "Community Beast",
					value = 1
				}
			}
		}, true)

		return true
	end

	return false, "invalid"
end

function Player:_clans_leave()
	if tick() - self._last_clan_action:Get() < Constants.CLAN_ACTION_DELAY then
		return false, "delay", tick()
	end

	self._last_clan_action:Set(tick())
	
	local clan = self:get_clan()
	
	if not clan then
		return false
	end
	
	local success = false
	
	if clan and clan._data then
		local owner = clan:get_owner()
		
		if owner and owner[1] == self._instance.UserId then
			clan._data:Set("deleted", true)
			
			success = clan:_kick(TableUtility.map(clan._data:Get("players"), function(i, v)
				return i, v[1]
			end), true)
		else
			success = clan:_kick(self._instance.UserId, true)
		end
	end
	
	if success then
		self._data:Set("clan", nil)
	end
	
	return true
end

function Player:_clans_kick(userId)
	if tick() - self._last_clan_action:Get() < Constants.CLAN_ACTION_DELAY then
		return false, "delay", tick()
	end

	self._last_clan_action:Set(tick())

	local clan = self:get_clan()

	if not clan then
		return false
	end

	local success = false

	if clan and clan._data then
		local owner = clan:get_owner()
		
		if owner and owner[1] == self._instance.UserId then
			success = clan:_kick(userId, true)
		end
	end

	return true
end

function Player:_clans_direct_join(clan)
	local success, err = false, nil

	if clan then
		success, err = clan:_join(self._instance.UserId, true)
	end

	if success then
		task.spawn(function()
			Services.BadgeService:AwardBadge(self._instance.UserId, 2149922634)
		end)
		self._data:Set("clan", clan._uid)
		return true
	end
	
	return false, err
end

function Player:_clans_join(clanKey, withCode)
	if tick() - self._last_clan_action:Get() < Constants.CLAN_ACTION_DELAY then
		return false, "delay", tick()
	end
	
	self._last_clan_action:Set(tick())
	
	local otherClanUid = self._data:Get("clan")
	
	if otherClanUid then
		return false, "error"
	end
	
	if not clanKey then
		return false, "invalid"
	end
	
	if withCode then
		if not tonumber(clanKey) then
			return false, "invalid"
		end
		
		local clan = TableUtility.match(Clan._objects, function(i, v)
			return v._data and v._data:Get("join_code") == clanKey
		end)
		
		if clan then
			return self:_clans_direct_join(clan)
		else
			local success, clanUid = pcall(function()
				return JOIN_CODES_DATA_STORE:GetAsync(clanKey)
			end)
			
			if success and clanUid then
				local clan = Clan._objects[clanUid]
				if not clan then
					clan = Clan.new({uid = clanUid})
				end
				local success, err = self:_clans_direct_join(clan)
				if not success or clan._data:Get("deleted") then
					clan:Destroy()
				end
				return success, err
			elseif success then
				return false, "invalid"
			else
				return false, "error"
			end
		end
	else
		local clan = Clan._objects[clanKey]
		
		if clan then
			return self:_clans_direct_join(clan)
		else
			return false, "error"
		end
	end
end

function Player:_is_available()
	if self._instance and self._instance.Parent == Services.Players then
		return true
	else
		return false
	end
end

function Player:_invite_rewards_claim(inviteRewardId)
	if self._claiming_invite_reward then
		return false
	end
	
	self._claiming_invite_reward = true
	
	if InviteRewardUtility.canClaim(self._data, inviteRewardId) then
		local inviteRewardInfo = InviteRewardUtility.getInfo(inviteRewardId)
		if inviteRewardId == "5" then
			task.spawn(function()
				Services.BadgeService:AwardBadge(self._instance.UserId, 2150491191)
			end)
		end
		self._data:Set({"invite_rewards", inviteRewardId}, true)
		PlayerRewardUtility.give(self._client, inviteRewardInfo.reward, true)
		self._claiming_invite_reward = false
		return true
	end
	
	self._claiming_invite_reward = false
	
	return false
end

function Player:_season_claim(tierType, tierId)
	if self._claiming_season then
		return
	end
	
	self._claiming_season = true
	
	local currentSeasonInfo = SeasonUtility.getCurrentInfo()
	local tierInfo = currentSeasonInfo.tiers[tierId]
	
	if tierInfo.required > self._data:Get({"seasons", currentSeasonInfo.id, "total_strength_gained"}) and not table.find(self._data:Get({"seasons", currentSeasonInfo.id, "skipped"}), tierInfo.id) then
		self._claiming_season = false
		return
	end
	
	if tierType == "Premium" then
		if self._data:Get({"seasons", currentSeasonInfo.id, "owns_premium"}) then
			local newTiers = self._data:Get({"seasons", currentSeasonInfo.id, "premium"})
			
			if not table.find(newTiers, tierId) then
				table.insert(newTiers, tierId)
			end
			
			PlayerRewardUtility.give(self._client, tierInfo.premium, true)

			self._data:Set({"seasons", currentSeasonInfo.id, "premium"}, newTiers)
		end
	elseif tierType == "Free" then
		local newTiers = self._data:Get({"seasons", currentSeasonInfo.id, "free"})
		
		if not table.find(newTiers, tierId) then
			table.insert(newTiers, tierId)
		end
		
		PlayerRewardUtility.give(self._client, tierInfo.free, true)
		
		self._data:Set({"seasons", currentSeasonInfo.id, "free"}, newTiers)
	end
	
	task.spawn(function()
		if tierId == TableUtility.length(currentSeasonInfo.tiers) then
			Services.BadgeService:AwardBadge(self._instance.UserId, 2149635466)
		end
	end)
	
	self._claiming_season = false
end

function Player:_clans_quests_claim(clanQuestId)
	local clanUid = self._data:Get("clan")

	if not clanUid then
		return false
	end
	
	local clan = Clan._objects[clanUid]
	
	if not clan then
		return false
	end
	
	local canClaim = ClanQuestUtility.canClaimServer(clanQuestId, clan, self._client)
	
	if canClaim then
		local clanQuestInfo = ClanQuestUtility.getInfo(clanQuestId)

		if not clanQuestInfo then
			return false
		end
		
		self._data:Set({"clan_quests", clanQuestId}, true)
		PlayerRewardUtility.give(self._client, clanQuestInfo.reward, true)

		if TableUtility.length(self._data:Get("clan_quests")) >= 1 then
			task.spawn(function()
				Services.BadgeService:AwardBadge(self._instance.UserId, 2149974978)
			end)
		end

		return true
	end
	
	return false
end

function Player:_notify(...)
	Network.Remote.Fire("C_Notifications_Add", self._instance, ...)
end

-- Upgrade Tree: buy one level of a node with Coins (stat "Strength" internally)
function Player:_tree_upgrade(nodeId)
	if typeof(nodeId) ~= "string" or self._tree_buying then
		return false, "invalid"
	end

	local UpgradeTreeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeTreeUtility"}
	local node = UpgradeTreeUtility.getInfo(nodeId)

	if not node then
		return false, "invalid"
	end

	if not UpgradeTreeUtility.isUnlocked(self._data, nodeId) then
		return false, "locked"
	end

	if UpgradeTreeUtility.isMaxed(self._data, nodeId) then
		return false, "maxed"
	end

	self._tree_buying = true

	local level = UpgradeTreeUtility.getLevel(self._data, nodeId)
	local cost = UpgradeTreeUtility.getCost(nodeId, level)
	local coins = self._data:Get({"stats", "Strength"})

	if coins < cost then
		self._tree_buying = false
		return false, "afford"
	end

	self._data:Set({"stats", "Strength"}, coins - cost)

	local newTree = TableUtility.deep.clone(self._data:Get("tree") or {})
	newTree[nodeId] = level + 1
	self._data:Set("tree", newTree)

	self._tree_buying = false

	return true
end

function Player:_upgrade_request(upgradeId, wasSkipped)
	local currentUpgradeStage = self._data:Get({"upgrades", upgradeId})
	
	if currentUpgradeStage then
		local upgradeInfo = UpgradeUtility.getInfo(upgradeId)

		if currentUpgradeStage < upgradeInfo.max_stages and upgradeInfo.predicate(self._client, wasSkipped) then
			local upgradeCost = UpgradeUtility.getCost(upgradeId, currentUpgradeStage)
			
			if upgradeCost > self._data:Get({"stats", "Gems"}) then
				return false, "afford"
			end
			
			self._data:Set({"stats", "Gems"}, self._data:Get({"stats", "Gems"}) - upgradeCost)
			
			local success = upgradeInfo.callback(self._client, wasSkipped)

			if success then
				self._data:Set({"upgrades", upgradeId}, currentUpgradeStage + 1)
				return true
			else
				return false
			end
		end
	end
	
	return false
end

-- Auto Collect step, called from the 0.5s timer. Has its own cooldown (never blocks manual taps).
-- The cooldown is kept per PLAYER (not per controller) and reserved before harvesting, so even
-- if two timers ever tick for the same player, only one pick happens per cooldown.
local AUTO_FARM_HALF = 70 -- farm plots are 140 x 140 (Farm controller PLOT_HALF)
local autoCollectNext = setmetatable({}, {__mode = "k"}) -- [Player] = os.clock() of the next allowed pick
function Player:_auto_collect_tick()
	local now = os.clock()
	if now < (autoCollectNext[self._instance] or 0) then
		return false
	end
	local root = self._character_controller and self._character_controller._root
	if not root or self._is_dead:Get() then
		return false
	end
	-- only while the player is on their OWN farm plot
	local Farm = _L.Get {"Server", "Modules", "Controllers", "Farm"}
	local state = Farm._farms and Farm._farms[self._instance]
	if not state or not state.plot then
		return false
	end
	local rel = state.plot.cf:PointToObjectSpace(root.Position)
	if math.abs(rel.X) > AUTO_FARM_HALF or math.abs(rel.Z) > AUTO_FARM_HALF or math.abs(rel.Y) > 40 then
		return false
	end
	local Harvest = _L.Get {"Server", "Modules", "Controllers", "Harvest"}
	local FruitFarmUtility = _L.Get {"Common", "Modules", "Utilities", "FruitFarmUtility"}
	local okCooldown, cooldown = pcall(FruitFarmUtility.getAutoCollectCooldown, self._data)
	if not okCooldown or typeof(cooldown) ~= "number" or cooldown ~= cooldown then
		cooldown = FruitFarmUtility.AUTO_BASE
	end
	autoCollectNext[self._instance] = now + math.max(cooldown, FruitFarmUtility.AUTO_FLOOR)
	local ok, reason = self:_power_click(nil, Harvest.AUTO_COLLECT_RANGE, true)
	if not ok then
		-- nothing picked: try again on the next timer tick
		autoCollectNext[self._instance] = now + 0.4
	end
	return ok, reason
end

-- Harvest click (replaces punching). Only pays out when the player stands next to a bush.
-- auto = true: an Auto Collect pick (own cooldown, no harvest luck, no rare Seed, no tutorial step).
function Player:_power_click(position, range, auto)
	if not self._character_controller or not self._character_controller._root then
		return false
	end

	-- Harvesting always uses the base "Punch" power entry (its coin value grows with progression)
	local currentPowerInfo = PowerUtility.getInfo("Punch")
	local isDead = self._is_dead:Get()
	
	if currentPowerInfo and not isDead then
		local currentPowerName = currentPowerInfo.name
		local currentPowerComponentInfo = PowerComponentUtility.getInfo(currentPowerInfo.component)
		
		-- title "harvest_speed" boost shortens the time between harvests
		if not auto and tick() - self._last_cooldown < currentPowerComponentInfo.cooldown / TitleUtility.getMultiplier(self._data, "harvest_speed") then
			return false
		end
		
		local Harvest = _L.Get {"Server", "Modules", "Controllers", "Harvest"}
		local bush, reason, pickedPlant, mutationMult, harvestedSeedId, plantFinished = Harvest.tryHarvest(self, range, position, auto == true)
		
		if not bush then
			return false, reason or "no_bush"
		end
		
		position = if bush.model.PrimaryPart then bush.model.PrimaryPart.Position else bush.position
		if not auto then
			self._last_cooldown = tick()
		end
		
		-- REAL crop counter: +1 per finished plant (a Seed crop = 1 plant = 1 harvest = 1 crop item).
		-- Drives the harvest quest "1", the clan crop counter, achievements and ranks. The legacy
		-- stats.Kills / clan "kills" (old 6-item harvests) are frozen and never written here.
		if plantFinished then
			self._data:Set({"stats", "Crops_Harvested"}, (self._data:Get({"stats", "Crops_Harvested"}) or 0) + 1)
			self:_quests_progress("1", 1)
			local harvestClan = self:get_clan()
			if harvestClan then
				harvestClan:increment("crops_harvested", 1)
			end
		end
		
		if currentPowerComponentInfo then
			self._character_controller:play_animation({
				name = currentPowerComponentInfo.click_animation[self._last_animation]
			})

			if self._last_animation >= #currentPowerComponentInfo.click_animation then
				self._last_animation = 1
			else
				self._last_animation += 1
			end
			
			local audioToPlay
			local strengthGiven

			strengthGiven = if typeof(currentPowerInfo.strength) == "function" then currentPowerInfo.strength(self) else currentPowerInfo.strength
			audioToPlay = currentPowerComponentInfo.click_audio
			
			local new = TableUtility.clone(audioToPlay)

			audioToPlay.position = self._character_controller._root.Position

			Audio.Play(audioToPlay)
			
			local powerStrengthGiven
			
			if currentPowerName == "Punch" then
				-- farm plants carry a CoinMultiplier (plant value x farm bonuses)
				local plantMultiplier = (bush and bush.model and bush.model:GetAttribute("CoinMultiplier")) or 1
				-- Every harvested unit has a FIXED base value: a Seed crop sells for its Seed's sell_value,
				-- any other farm plant (decor patches) for 1. The old Coins-based power tier is not used
				-- here any more (it made income grow with income). Equipped Fruits speed up crop growth
				-- (FarmingV2), so they are not applied to the sell value a second time.
				local baseValue = (bush and bush.model and bush.model:GetAttribute("SellValue")) or 1
				-- No instant Coins: the picked plant goes to the backpack with its coin worth.
				-- Sell it to the Gardener or feed it to your fruits.
				local worth = self:_calc_strength(baseValue * plantMultiplier, nil, true) * (mutationMult or 1)
				if pickedPlant then
					-- V1.1 Fruit harvest luck: one server roll per successful MANUAL harvest of a mature
					-- Seed crop (never for Auto Collect) -> the ONE crop item is worth a bit more
					local SeedPacksDB = _L.Get {"Common", "Modules", "Databases", "SeedPacks"}
					local lucky = false
					local isManual = not auto and range == nil
					if isManual and bush.model:GetAttribute("SeedCropSlot") and bush.model:GetAttribute("Owner") == self._instance.UserId then
						local FruitFarmUtility = _L.Get {"Common", "Modules", "Utilities", "FruitFarmUtility"}
						local okLuck, luck = pcall(FruitFarmUtility.getHarvestLuck, self._data)
						self._harvest_luck_rng = self._harvest_luck_rng or Random.new()
						if okLuck and typeof(luck) == "number" and luck > 0 and self._harvest_luck_rng:NextNumber() < luck then
							lucky = true
							worth *= 1 + (SeedPacksDB.HARVEST_LUCK_VALUE_BONUS or 0)
						end
					end
					-- exactly ONE crop item per harvest (Harvest.tryHarvest already refused a full backpack)
					local BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
					local added = false
					if not BackpackUtility.isFull(self._data) then
						self:_backpack_add(pickedPlant, worth)
						added = true
					end
					if lucky and added then
						self:_notify({text = "🍀 Fruit Luck! +" .. math.round((SeedPacksDB.HARVEST_LUCK_VALUE_BONUS or 0) * 100) .. "% value " .. tostring(pickedPlant), color = Color3.fromRGB(170, 240, 120)})
					end
					if added and not auto then
						local tutorialStep = self._data:Get("tutorial_marker")
						if tutorialStep == 1 then
							self._data:Set("tutorial_marker", 2)
						elseif tutorialStep == 5 and bush.model:GetAttribute("SeedCropSlot") and not bush.model:GetAttribute("TutorialCrop") then
							-- restricted accounts hatch too (guaranteed order), so every account gets the Egg step
							local canHatch = EggUtility.isContentApproved()
							self._data:Set("tutorial_marker", if canHatch then 6 else 7)
							PlayerRewardUtility.give(self._client, {{name = "Stat", props = {name = "Gems", value = self:_tutorial_egg_price()}}})
						end
						-- crop weight (FarmingV2 overgrowth): show how heavy the crop was and if it is a record
						local cropWeight = harvestedSeedId and bush.model:GetAttribute("Weight")
						if typeof(cropWeight) == "number" and not bush.model:GetAttribute("TutorialCrop") then
							local SeedPacksDB = _L.Get {"Common", "Modules", "Databases", "SeedPacks"}
							-- NewRecord: set by FarmingV2.completeHarvest when this harvest beat heaviest_crop
							local isBest = bush.model:GetAttribute("NewRecord") == true
							local sizeLabel = bush.model:GetAttribute("SizeLabel")
							self:_notify({
								text = if isBest
									then "🏆 NEW HEAVIEST CROP! " .. SeedPacksDB.formatWeight(cropWeight) .. " " .. tostring(pickedPlant)
									else "⚖️ " .. SeedPacksDB.formatWeight(cropWeight) .. " " .. (if sizeLabel then sizeLabel .. " " else "") .. tostring(pickedPlant),
								color = if isBest then Color3.fromRGB(255, 215, 90) else Color3.fromRGB(235, 225, 200),
							})
						end
						-- rare bonus Seed: only for a manual harvest (no range = a player click, not
						-- Auto Collect) that completed a mature seed crop and paid its normal reward
						if harvestedSeedId and range == nil then
							local FarmingV2 = _L.Get {"Server", "Modules", "Controllers", "FarmingV2"}
							local okDrop, dropped = pcall(FarmingV2.rollHarvestSeedDrop, self._instance, harvestedSeedId)
							local seedInfo = okDrop and dropped and _L.Get({"Common", "Modules", "Databases", "SeedPacks"}).getSeed(dropped)
							if seedInfo then
								self:_notify({text = "🌱 Lucky Harvest! You found a " .. (seedInfo.display_name or dropped) .. "!", color = Color3.fromRGB(140, 230, 120), audio = {name = "Reward1"}})
							end
						end
					end
				end
			end
			
			-- Mastery XP: track per equipped power + overall player mastery
			do
				local equippedPowerName = self._current_power.tracker:Get() or currentPowerName
				local _, powerLeveledUp = MasteryUtility.addXp(self._data, "power", equippedPowerName, MasteryDB.power.xp_per_use)
				MasteryUtility.addXp(self._data, "player", nil, MasteryDB.power.xp_per_use)
				if powerLeveledUp then
					self:_notify({text = "\u{2b06}\u{fe0f} " .. equippedPowerName .. " Mastery leveled up!", color = Color3.fromRGB(255, 210, 80)})
				end
			end


			Network.Remote.FireAll("C_Power_Play", {
				player = self._client.player,
				strength_given = powerStrengthGiven,
				name = currentPowerInfo.name,
				position = position
			})

			return true, powerStrengthGiven
		end
	end

	return false
end

function Player:_give_strength(strengthGiven)
	local powerStrengthGiven = self:_calc_strength(strengthGiven)
	self:_add_coins(powerStrengthGiven)
	return powerStrengthGiven
end

-- Coins earned (all boosts included) for a harvest worth `strengthGiven`, without giving them.
-- ignoreArea = true skips the garden multiplier (used for farm helpers).
-- ignoreFruits = true skips the equipped Fruit boost (crop harvests: Fruits boost growth speed instead).
function Player:_calc_strength(strengthGiven, ignoreArea, ignoreFruits)
	local trainingAreaId = if ignoreArea then nil else TrainingAreaUtility.find(self)
	local trainingAreaInfo
	local friendBoost = 1

	if trainingAreaId then
		trainingAreaInfo = TrainingAreaUtility.getInfo(trainingAreaId)
	end

	if self._instance:GetAttribute("friends_in_game") then
		friendBoost += self._instance:GetAttribute("friends_in_game") * 0.5
	end

	local petsBoost = PetUtility.getTotalBoost(self._data)
	local fruitsBoost = if ignoreFruits then 1 else FruitUtility.getTotalBoost(self._data)

	local i = self._data:Get("robux_multiplier")
	local vvvv

	if i then
		vvvv = RobuxMultiplierUtility.getInfo(i)
	end

	local powerStrengthGiven = math.round(workspace.GlobalStrengthMultiplier.Value * (if self._purchases:OwnsGamepass("x2_Strength") then 2 else 1) * (if vvvv then vvvv.value else 1) * self._data:Get({"upgrades", "4"}) * (if self._purchases:OwnsGamepass("VIP") then 3 else 1) * strengthGiven * (if BoostUtility.has(self._data, "x2_Strength") then 2 else 1) * petsBoost * fruitsBoost * friendBoost * (1 + self._data:Get({"stats", "Rebirths"}) / 10 * _L.Get({"Common", "Modules", "Utilities", "UpgradeTreeUtility"}).getRebirthPowerMultiplier(self._data)) * _L.Get({"Common", "Modules", "Utilities", "UpgradeTreeUtility"}).getCoinMultiplier(self._data) * TitleUtility.getMultiplier(self._data, "coins") * (if trainingAreaInfo then trainingAreaInfo.multiplier elseif self._instance:GetAttribute("is_king") then 5 else 1))

	-- Apply mastery multipliers (player mastery + current power mastery)
	do
		local masteryMult = MasteryUtility.getPlayerStrengthMultiplier(self._data)
		local currentPowerInfo = self:_get_current_power_info()
		if currentPowerInfo and currentPowerInfo.component then
			masteryMult *= MasteryUtility.getPowerStrengthMultiplier(self._data, currentPowerInfo.component)
		end
		powerStrengthGiven = math.round(powerStrengthGiven * masteryMult)
	end

	return powerStrengthGiven
end

-- Adds Coins and counts them for seasons, clans and quests
function Player:_add_coins(powerStrengthGiven)
	self._data:Set({"seasons", Constants.CURRENT_SEASON_ID, "total_strength_gained"}, self._data:Get({"seasons", Constants.CURRENT_SEASON_ID, "total_strength_gained"}) + powerStrengthGiven)
	self._data:Set({"stats", "Strength"}, self._data:Get({"stats", "Strength"}) + powerStrengthGiven)
	self._data:Set({"stats", "Total_Strength"}, self._data:Get({"stats", "Total_Strength"}) + powerStrengthGiven)

	local clan = self:get_clan()

	if clan then
		clan:increment("strength", powerStrengthGiven)
	end

	self:_quests_progress("7", powerStrengthGiven)
	self:_tutorial_quests_progress("3", powerStrengthGiven)

	return powerStrengthGiven
end

function Player:_combat_hit(targetModel, hitPosition)
	local currentPowerInfo = self:_get_current_power_info()

	if not currentPowerInfo then
		return false
	end

	-- Reuses the full click pipeline: cooldown, animation, swing audio, strength reward and power effect
	local success, strengthGiven = self:_power_click(hitPosition)

	if not success then
		return false
	end

	-- Damage dealt to the combat target (Punch falls back to a base damage of 10)
	local damage = currentPowerInfo.damage or 10

	return true, damage, strengthGiven
end

function Player:_clans_shop_buy(clanShopItemId)
	local clanShopItemInfo = ClanShopItemUtility.getInfo(clanShopItemId)
	local clanShopItemPrice = clanShopItemInfo.price
	
	if self._data:Get({"stats", "Crowns"}) >= clanShopItemPrice then
		self._data:Set({"stats", "Crowns"}, self._data:Get({"stats", "Crowns"}) - clanShopItemPrice)
		PlayerRewardUtility.give(self._client, clanShopItemInfo.reward, true)
		task.spawn(function()
			Services.BadgeService:AwardBadge(self._instance.UserId, 2149933943)
		end)
		return true
	end
	
	return false
end

function Player:_get_toolbar_data()
	return self._toolbar_data:Get()
end

function Player:_update_toolbar_data()
	local currentStrength = self._data:Get({"stats", "Strength"})

	local currentPowerInfo = Shared.GetCurrentPowerInfoFromStrength(currentStrength)
	local currentPowerName = currentPowerInfo.name
	
	self._main_power:Set(currentPowerInfo.name)
	
	local toolbarData = {"Punch", currentPowerName}
	
	for _, ownedPowerName in pairs(self._data:Get({"owned_powers"})) do
		table.insert(toolbarData, ownedPowerName)
	end
	
	local oldPowerName = self._current_power.tracker:Get()

	local _, oldPowerInfo = TableUtility.match(Powers, function(i, v)
		return if oldPowerName then v.name == oldPowerName else false
	end)
	
	if not table.find(toolbarData, oldPowerName) then
		self._current_power.tracker:Set(nil)
	end
	
	if oldPowerInfo and oldPowerInfo.required then
		self._current_power.tracker:Set(currentPowerName)
	end
	
	self._toolbar_data:Set(toolbarData)
end

function Player:_trade_toggle_add(petUid)
	if true then
		return false, "legacy" -- V1.1: legacy pet trading is off; Fruit trading is Controllers.FruitTrade
	end
	local _, petData = TableUtility.match(self._data:Get("pets"), function(xi, v)
		return v.uid == petUid
	end)
	
	if not petData then
		return
	end
	
	local tradeUid = self._trade:Get()

	if tradeUid then
		local trade = Trade._objects[tradeUid]

		if trade then
			local traderIndex = TradeUtility.getTraderIndex(trade, self._instance)

			if traderIndex and trade._state.tracker:Get() == "Default" then
				trade:_unready_all()
				
				local trader = trade._traders[traderIndex]
				local petIndex = table.find(trader.pets, petUid)
				
				if petIndex then
					table.remove(trader.pets, petIndex)
				else
					table.insert(trader.pets, petUid)
				end
				
				trade:_update_traders()
			end
		end
	end
end

-- Settings > Skip Tutorial. Only marks the saved tutorial as complete (8); grants nothing
-- and touches no Coins / Gems / Seeds / Fruits. Repeated calls are harmless.
function Player:_tutorial_skip()
	local marker = self._data:Get("tutorial_marker")
	if typeof(marker) ~= "number" or marker >= 8 then
		return true
	end
	self._data:Set("tutorial_marker", 8)
	return true
end

function Player:_tutorial_complete()
	if (self._data:Get("tutorial_version") or 0) >= 2 then
		return false, "legacy"
	end
	self._data:Set("tutorial_marker", 4)
	PlayerRewardUtility.give(self._client, {{
		name = "Stat",
		props = {
			name = "Gems",
			value = 500
		}
	}}, true)
	task.spawn(function()
		Services.BadgeService:AwardBadge(self._instance.UserId, 2150108471)
	end)
end

function Player:_quests_claim(questType, questIndex)
	local sub = if questType == "Daily" then "daily" elseif questType == "Weekly" then "weekly" else "tutorial"
	local questData = self._data:Get({"quests", sub, "v", questIndex})
	
	if not questData then
		return false
	end
	
	local progress = questData.progress
	local canClaim = progress >= questData.required and not questData.completed

	if canClaim then
		local questInfo = (if questType == "Tutorial" then TutorialQuestUtility else QuestUtility).getInfo(questData.id)

		if not questInfo then
			return false
		end

		self._data:Set({"quests", sub, "v", questIndex, "completed"}, true)
		PlayerRewardUtility.give(self._client, questInfo.reward(questData.reward), true)
		
		task.spawn(function()
			if questType ~= "Tutorial" then
				Services.BadgeService:AwardBadge(self._instance.UserId, 2150030018)
			end
		end)
		
		return true
	end

	return false
end

function Player:_quests_progress(questId, questProgressValue)
	local new = TableUtility.deep.clone(self._data:Get("quests"))
	
	for k, v in pairs(new) do
		if k == "tutorial" then
			continue
		end
		for _, vv in pairs(v.v) do
			vv.progress = vv.progress + if questId == vv.id then questProgressValue else 0
		end
	end
	
	self._data:Set("quests", new)
end

function Player:_tutorial_quests_progress(questId, questProgressValue)
	local new = TableUtility.deep.clone(self._data:Get("quests"))

	for k, v in pairs(new) do
		if k == "tutorial" then
			for _, vv in pairs(v.v) do
				vv.progress = vv.progress + if questId == vv.id then questProgressValue else 0
			end
		end
	end

	self._data:Set("quests", new)
end

-- Achievements: claim the reward of a completed achievement
function Player:_achievement_claim(achievementId)
	if typeof(achievementId) ~= "string" or self._claiming_achievement then
		return false
	end

	local AchievementUtility = _L.Get {"Common", "Modules", "Utilities", "AchievementUtility"}
	local info = AchievementUtility.getInfo(achievementId)

	if not info or AchievementUtility.getState(self._data, achievementId) ~= "Claimable" then
		return false
	end

	self._claiming_achievement = true

	local claimed = TableUtility.deep.clone(self._data:Get("achievements") or {})
	claimed[achievementId] = true
	self._data:Set("achievements", claimed)

	-- titles are given quietly, everything else shows the normal reward popup
	local others = {}
	for _, reward in ipairs(info.rewards or {}) do
		if reward.name == "Title" then
			TitleUtility.give(self._client, reward.props)
		else
			table.insert(others, reward)
		end
	end
	if #others > 0 then
		pcall(PlayerRewardUtility.give, self._client, others, true)
	end

	self._claiming_achievement = false

	return true
end

function Player:_titles_toggle_equip(titleId)
	local titleInfo = TitleUtility.getInfo(titleId)
	local _, titleData = TableUtility.match(self._data:Get("titles"), function(i, v)
		return v.id == titleId
	end)

	if not titleData then
		return
	end

	local wasEquipped = titleData.equipped

	self._data:Set("titles", TableUtility.map(self._data:Get("titles"), function(i, v)
		return i, {id = v.id, equipped = not wasEquipped and titleId == v.id}
	end))
end

function Player:_trade_cancel()
	if true then
		return false, "legacy"
	end
	local tradeUid = self._trade:Get()
	
	if tradeUid then
		local trade = Trade._objects[tradeUid]
		
		if trade._state.tracker:Get() == "Default" then
			trade._state.tracker:Set("Cancelled")
		end
	end
end
function Player:_toggle_power(powerName)
	local toolbarData = self:_get_toolbar_data()

	if table.find(toolbarData, powerName) then
		if self._current_power.tracker:Get() == powerName then
			self._current_power.tracker:Set(nil)
		else
			self._current_power.tracker:Set(powerName)
		end
	end
end

function Player:_clans_settings_type(value)
	local clan = self:get_clan()

	if clan and clan._data and value == "Public" or value == "Private" then
		clan._data:Set("_type", {value, tick()})
	end
end

function Player:_clans_settings_emblem(value)
	local clan = self:get_clan()

	if clan and clan._data and value >= 1 and value <= #ClanEmblems then
		clan._data:Set("emblem", {value, tick()})
	end
end

function Player:_rebirth(skipped)
	local currentRebirths = self._data:Get({"stats", "Rebirths"})
	local currentStrength = self._data:Get({"stats", "Strength"})
	local currentGems = self._data:Get({"stats", "Gems"})
	local nextRebirths = currentRebirths + if self._purchases:OwnsGamepass("x2_Rebirths") then 2 else 1
	
	local UpgradeTreeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeTreeUtility"}
	local gemsGiven = math.floor(Shared.GetGemsGivenForRebirth(nextRebirths) * self._data:Get({"upgrades", "2"}) * UpgradeTreeUtility.getRebirthGemsMultiplier(self._data))
	
	local strengthRequired = if currentRebirths then Shared.GetStrengthRequiredForRebirth(nextRebirths) * UpgradeTreeUtility.getRebirthCostMultiplier(self._data) else nil
	
	if not skipped then
		if not strengthRequired or strengthRequired > currentStrength then
			return false, 1
		end

		self._data:Set({"stats", "Strength"}, 0)
	end
	
	self._data:Set({"stats", "Gems"}, currentGems + gemsGiven)
	local rebirthsGiven = if self._purchases:OwnsGamepass("x2_Rebirths") then 2 else 1
	self._data:Set({"stats", "Rebirths"}, self._data:Get({"stats", "Rebirths"}) + rebirthsGiven)
	
	local clan = self:get_clan()

	if clan then
		clan:increment("rebirths", rebirthsGiven)
	end
	
	self:_quests_progress("4", rebirthsGiven)
	self:_tutorial_quests_progress("2", rebirthsGiven)
	
	task.spawn(function()
		Services.BadgeService:AwardBadge(self._instance.UserId, 2149635621)
	end)

	Network.Remote.FireAll("C_Character_Rebirth", self._instance)

	return true
end

function Player:_trade_ready_toggle()
	if true then
		return false, "legacy"
	end
	local tradeUid = self._trade:Get()

	if tradeUid then
		local trade = Trade._objects[tradeUid]

		if trade then
			local traderIndex = TradeUtility.getTraderIndex(trade, self._instance)
			
			if traderIndex and trade._state.tracker:Get() ~= "Completed" then
				local trader = trade._traders[traderIndex]
				trader.ready:Set(not trader.ready:Get())
			end
		end
	end
end

-- Tutorial safety: the next required purchase must always be affordable, whatever the prices are.
-- step 3 = buy the Starter Seed Pack (Coins), step 6 = hatch the Farm Egg (Gems). Tops up only the
-- missing amount, only while the tutorial waits on that step.
function Player:_tutorial_egg_price()
	local eggInfo = EggUtility.getInfo("Farm_Egg")
	return (eggInfo and eggInfo.price) or 750
end

function Player:_tutorial_cover_costs(step)
	if step == 3 then
		local starter = _L.Get({"Common", "Modules", "Databases", "SeedPacks"}).getPack("starter")
		local coins = self._data:Get({"stats", "Strength"}) or 0
		if starter and coins < starter.price then
			self._data:Set({"stats", "Strength"}, starter.price)
		end
	elseif step == 6 then
		local price = self:_tutorial_egg_price()
		local gems = self._data:Get({"stats", "Gems"}) or 0
		if gems < price then
			self._data:Set({"stats", "Gems"}, price)
		end
	end
end

function Player:_rank_reward_claim()
	if self._rank_reward_claiming or self._data:Get({"stats", "Total_Time"}) < (30 * 60) then
		return
	end
	
	self._rank_reward_claiming = true
	
	local canClaim = RankUtility.canClaim(self._data)
	
	if canClaim then
		self._data:Set("rank_reward", os.time())
		
		local currentRankInfo, i = RankUtility.getInfoFromData(self._data)
		
		local rew = {{name = "Stat", props = {
			name = "Gems",
			value = 150 * i
		}},{name = "Boost", props = {
			name = "x2_Strength",
			value = 1
		}},{name = "Boost", props = {
			name = "Lucky_Potion",
			value = 1
		}}}
		
		if math.random(1, 100) == 1 and i >= 2 then
			table.insert(rew, {
				name = "Pet",
				props = {
					name = "Emerald Monkey",
					value = 1
				}
			})
		end
		
		PlayerRewardUtility.give(self._client, rew, true)
		
		self._rank_reward_claiming = false
		
		return true
	end
	
	self._rank_reward_claiming = false
end

function Player:_get_current_power_info()
	local currentPowerName = self._current_power.tracker:Get() 

	local currentPowerInfo = PowerUtility.getInfo(currentPowerName)

	return currentPowerInfo
end

function Player:_cases_open(caseId)
	local caseInfo = CaseUtility.getInfo(caseId)
	
	if caseInfo and caseInfo.predicate(self._client) then
		local success = caseInfo.callback(self._client)
		
		if success then
			if caseInfo.id == 1 then
				self._data:Set("last_daily_case", os.time())
			elseif caseInfo.id == 2 then
				self._data:Set("last_premium_case", os.time())
			end
			
			local randomRewardId = RandomUtility.chance(TableUtility.map(caseInfo.rewards, function(i, v)
				return i, v[2]
			end))
			
			local caseSpinId = Services.HttpService:GenerateGUID(false)
			local randomReward = caseInfo.rewards[randomRewardId]
			
			self._active_case_spins[caseSpinId] = randomReward[1]
			
			task.spawn(function()
				Services.BadgeService:AwardBadge(self._instance.UserId, 2149769642)
			end)
						
			return true, randomRewardId, caseSpinId
		end
	end
	
	return false
end

function Player:_spin_request()
	local currentWheelSpins = self._data:Get({"stats", "Wheel_Spin"})
	
	if currentWheelSpins <= 0 then
		return false, "notenough"
	end
	
	self._data:Set({"stats", "Wheel_Spin"}, currentWheelSpins - 1)
	
	-- Egg slices hatch a random Fruit: never for accounts where paid random items are restricted
	-- (or the policy lookup failed); those spins roll among the other slices instead.
	local allowEgg = self:_paid_random_items_policy() == false
	local wheelRewardId = RandomUtility.chance(TableUtility.map(WheelRewards, function(i, v)
		return i, if v.reward_name == "Egg" and not allowEgg then 0 else v.chance
	end))
	
	local wheelSpinId = Services.HttpService:GenerateGUID(false)
	
	-- the server decides AND grants right away (leaving mid-animation can't lose the reward,
	-- and the reward shown is exactly this one). Confirm only closes the spin for the UI.
	local wheelRewardInfo = WheelRewardUtility.getInfo(wheelRewardId)
	local shown = nil -- what was really given, for the reward popup (rolled Seeds, the hatched Fruit...)
	if wheelRewardInfo then
		local given, rewardData = PlayerRewardUtility.give(self._client, {{
			name = wheelRewardInfo.reward_name,
			props = {
				name = wheelRewardInfo.name,
				value = wheelRewardInfo.value
			}
		}})
		if not given and wheelRewardInfo.reward_name == "Egg" then
			-- Fruit inventory full: the Egg is paid out as its Gem price, never lost
			local eggInfo = EggUtility.getInfo(wheelRewardInfo.name)
			given, rewardData = PlayerRewardUtility.give(self._client, {{name = "Stat", props = {name = "Gems", value = (eggInfo and eggInfo.price or 0) * (wheelRewardInfo.value or 1)}}})
			self:_notify({text = "🎒 Fruit inventory full! Your Egg was paid out as Gems.", color = Color3.fromRGB(255, 200, 90)})
		end
		if given and typeof(rewardData) == "table" and #rewardData > 0 then
			shown = rewardData
		end
	end
	self._active_wheel_spins[wheelSpinId] = {id = wheelRewardId, rewards = shown}
	
	return true, nil, {id = wheelRewardId}, wheelSpinId
end

function Player:_trade_request(targetPlayer)
	if true then
		return false, "legacy"
	end
	local players = {self._instance, targetPlayer}
	local success, err = TradeUtility.canOccur(players)
	
	if not success then
		return false, err
	end
	
	if self._trade_requests[targetPlayer] then
		return false, "already"
	end
	
	table.clear(self._trade_requests)
	
	local newTradeRequest = TradeRequest.new({players = players})
	
	self._trade_requests[targetPlayer] = newTradeRequest

	return true
end

function Player:_spin_confirm(wheelSpinId)
	local spin = self._active_wheel_spins[wheelSpinId]
	if spin then
		-- reward was already granted in _spin_request; this just closes the spin (no double reward)
		-- and returns what was really given so the popup shows it
		self._active_wheel_spins[wheelSpinId] = nil
		return true, if typeof(spin) == "table" then spin.rewards else nil
	end
	
	return false
end

function Player:_cases_confirm(caseSpinId)
	local a = self._active_case_spins[caseSpinId]
	
	if a then
		self._active_case_spins[caseSpinId] = nil
		
		PlayerRewardUtility.give(self._client, a)

		return true
	end

	return false
end

function Player:_daily_gifts_claim(dailyGiftId)
	if not dailyGiftId then
		return false
	end
	
	local canClaim = DailyGiftUtility.canClaim(self._data, dailyGiftId)
	local nextDailyGiftId = DailyGiftUtility.getNextId(self._data)
	
	if canClaim then
		self._data:Set("last_daily_gift", {i = if nextDailyGiftId == 7 then 0 else nextDailyGiftId, t = os.time()})
		
		local dailyGiftInfo = DailyGiftUtility.getInfo(nextDailyGiftId)
		
		PlayerRewardUtility.give(self._client, {{
			name = dailyGiftInfo.reward_name,
			props = {
				name = dailyGiftInfo.name,
				value = dailyGiftInfo.value
			}
		}})
		
		return true, {{
			reward_name = dailyGiftInfo.reward_name,
			name = dailyGiftInfo.name,
			value = dailyGiftInfo.value
		}}
	end
end

function Player:_free_gifts_claim(freeGiftId)
	local currentFreeGifts = TableUtility.deep.clone(AttributeUtility.get(self._instance, "free_gifts"))
	
	if not freeGiftId or not currentFreeGifts then
		return false
	end

	local canClaim = FreeGiftUtility.canClaim(self._instance, freeGiftId)

	if canClaim then
		currentFreeGifts[freeGiftId] = true
		
		AttributeUtility.set(self._instance, "free_gifts", currentFreeGifts)

		local freeGiftInfo = FreeGiftUtility.getInfo(freeGiftId)
		
		PlayerRewardUtility.give(self._client, {{
			name = freeGiftInfo.reward_name,
			props = {
				name = freeGiftInfo.name,
				value = freeGiftInfo.value
			}
		}})

		return true, {{
			reward_name = freeGiftInfo.reward_name,
			name = freeGiftInfo.name,
			value = freeGiftInfo.value
		}}
	end
end

function Player:_egg_auto_delete_toggle(fruitName)
	if typeof(fruitName) ~= "string" or not FruitUtility.getInfo(fruitName) then
		return false
	end

	self._data:Set({"auto_delete", fruitName}, if self._data:Get({"auto_delete", fruitName}) then nil else true)
	return true
end

function Player:_pets_toggle_equip(petUid)
	local petData = PetUtility.getData(self._data, petUid)
	
	if not petData then
		return false
	end
	
	local equipState = PetUtility.isEquipped(self._data, petUid)
	local newState = not equipState
	
	PetUtility.setEquipped(self._data, petUid, newState)
	
	return true, newState
end

function Player:_pets_equip_best()
	local petsData = self._data:Get("pets")
	local petEquipSpace = self._data:Get({"stats", "Pet_Equip_Space"})
	
	local petUids = TableUtility.filter(TableUtility.map(TableUtility.sort(petsData, function(a, b)
		local aPetInfo = PetUtility.getInfo(a.name)
		local bPetInfo = PetUtility.getInfo(b.name)
		return (PetUtility.getBoost(self._data, a.uid) or 0) > (PetUtility.getBoost(self._data, b.uid) or 0)
	end), function(i, v)
		return i, v.uid
	end), function(i, v)
		return i <= petEquipSpace
	end)
	
	self._data:Set("pets", TableUtility.map(TableUtility.deep.clone(petsData), function(i, v)
		v.equipped = false
		return i, v
	end))
	
	self._data:Set("pets", TableUtility.map(TableUtility.deep.clone(petsData), function(i, v)
		v.equipped = if table.find(petUids, v.uid) then true else false
		return i, v
	end))
	
	return true, petUids
end

function Player:_pets_delete(petUids)
	PetUtility.remove(self._data, petUids)
	return true
end
function Player:_settings_toggle(settingName)
	local settingInfo = SettingUtility.getInfo(settingName)
	
	if settingInfo then
		local success, err = settingInfo.callback(self._client)
		
		if success then
			local newSettingsData = TableUtility.deep.clone(self._data:Get("settings"))

			newSettingsData[settingName] = not newSettingsData[settingName]

			self._data:Set("settings", newSettingsData)
			
			return true
		else
			return false, err
		end
	end
	
	return false
end

function Player:_submit_code(code)
	if table.find(self._data:Get("used_codes"), code) then
		return false, "used"
	end
	
	local codeInfo = CodesUtility.getInfo(code)
	
	if codeInfo then
		local new = TableUtility.deep.clone(self._client.data:Get("used_codes"))
		
		table.insert(new, code)
		
		self._client.data:Set("used_codes", new)
		
		return codeInfo.callback(self._client)
	else
		return false, "invalid"
	end
end

function Player:_free_pet_pack_claim()
	if self._client.data:Get("claimed_free_pet_pack") then
		return false, "claimed"
	end
	
	local canClaim = FreePetPackUtility.canClaim(self._instance)
	
	if canClaim then
		self._client.data:Set("claimed_free_pet_pack", true)
		
		local success = PlayerRewardUtility.give(self._client, {{
			name = "Pet",
			props = {
				name = "Blue Angel",
				value = 1
			}
		},{
			name = "Pet",
			props = {
				name = "Green Angel",
				value = 1
			}
		},{
			name = "Pet",
			props = {
				name = "Pink Angel",
				value = 1
			}
		}}, true)
		
		task.spawn(function()
			Services.BadgeService:AwardBadge(self._instance.UserId, 2149635205)
		end)
		
		return success
	end

	return false
end

function Player:_huge_event_reward_claim(bypass)
	if not bypass and self._client.data:Get("claimed_huge_event_reward") then
		return false, "claimed"
	end

	local canClaim = FreeHugeEventUtility.canClaim(self._client)

	if bypass or canClaim then
		self._client.data:Set("claimed_huge_event_reward", true)

		local success = PlayerRewardUtility.give(self._client, {{
			name = "Pet",
			props = {
				name = "Huge Cthulhu",
				value = 1
			}
		}}, true)
		
		task.spawn(function()
			Services.BadgeService:AwardBadge(self._instance.UserId, 2149635402)
		end)

		return success
	end

	return false
end

function Player:_pets_craft(petUid)
	local craftable = PetUtility.getCraftable(self._data, petUid)
	
	local petName = TableUtility.once(craftable, function(i, v)
		return v.name
	end)
	
	if TableUtility.length(craftable) < Constants.PETS_NEEDED_FOR_CRAFT then
		return false
	end
	
	local n = 0
	
	local new = TableUtility.deep.clone(self._data:Get("pets"))
	
	for _, a in pairs(craftable) do
		local i, v = TableUtility.match(new, function(i, v)
			return a.uid == v.uid
		end)
		
		if v and n < Constants.PETS_NEEDED_FOR_CRAFT then
			n += 1
			table.remove(new, i)
		end
	end
	
	self._data:Set("pets", new)
	
	PetUtility.give(self._client, {
		name = petName,
		tier = "Rainbow",
		value = 1
	}, true)
	
	return true
end

function Player:_hacker_event_reward_claim(bypass)
	if not bypass and self._client.data:Get("claimed_hacker_event_reward") then
		return false, "claimed"
	end

	local canClaim = HackerEventUtility.canClaim(self._client)

	if bypass or canClaim then
		self._client.data:Set("claimed_hacker_event_reward", true)

		local success = PlayerRewardUtility.give(self._client, {{
			name = "Pet",
			props = {
				name = "Hacker Dominus",
				value = 1
			}
		}}, true)

		task.spawn(function()
			Services.BadgeService:AwardBadge(self._instance.UserId, 2150032952)
		end)

		return success
	end

	return false
end

-- STARTER FRUIT CHOICE (one time only). Validated fully here:
--  * only "Strawberry" or "Apple"
--  * only if the player never received a starter fruit AND owns no fruit
--  * the flag is locked BEFORE the fruit is given (no yield in between), so spamming the remote
--    or firing it from two places can never give both fruits
local STARTER_CHOICES = {Strawberry = true, Apple = true}

function Player:_starter_choose(fruitName)
	if typeof(fruitName) ~= "string" or not STARTER_CHOICES[fruitName] then
		return false, "invalid"
	end
	if self._data:Get("received_starter_fruit") then
		return false, "claimed"
	end
	if #(self._data:Get("fruits") or {}) > 0 then
		self._data:Set("received_starter_fruit", true)
		return false, "claimed"
	end

	self._data:Set("received_starter_fruit", true) -- lock first
	local ok, given = pcall(FruitUtility.give, self._client, {name = fruitName, value = 1})
	if not ok or not given then
		warn("[Starter fruit] could not give", fruitName, given)
		self._data:Set("received_starter_fruit", false) -- let them try again
		return false, "error"
	end
	self._data:Set("starter_fruit", fruitName)

	local fruits = self._data:Get("fruits") or {}
	local newest = fruits[#fruits]
	if newest then
		pcall(FruitUtility.setEquipped, self._data, newest.uid, true)
	end
	return true, fruitName
end

function Player:_auto_collect_toggle()
	self._data:Set("auto_collect", not self._data:Get("auto_collect"))
	return true, self._data:Get("auto_collect")
end

function Player:_auto_punch_toggle()
	self._data:Set("auto_punch", not self._data:Get("auto_punch"))
	return true
end

-- PolicyService: true = paid random items are restricted for this account, false = allowed,
-- nil = the lookup failed (callers fail closed and simply let the player retry later).
-- A successful answer is cached for the session; a failure is not.
function Player:_paid_random_items_policy()
	if self._paid_random_items_restricted == nil then
		if Services.RunService:IsStudio() then
			-- Studio only: set the player attribute StudioForceRestricted = true to test the restricted path
			self._paid_random_items_restricted = self._instance:GetAttribute("StudioForceRestricted") == true
		else
			local policySuccess, policyInfo = pcall(Services.PolicyService.GetPolicyInfoForPlayerAsync, Services.PolicyService, self._instance)
			if not policySuccess or typeof(policyInfo) ~= "table" then
				return nil
			end
			self._paid_random_items_restricted = policyInfo.ArePaidRandomItemsRestricted == true
		end
	end
	return self._paid_random_items_restricted
end

local EGG_HATCH_DISTANCE = 12
local EGG_HATCH_COOLDOWN = 0.25

function Player:_egg_open(eggName, n, shouldPrompt)
	if typeof(eggName) ~= "string" or (n ~= 1 and n ~= 3) then
		return false, "invalid"
	end

	if not EggUtility.isContentApproved(eggName) then
		return false, "content"
	end

	local eggInfo = EggUtility.getInfo(eggName)
	local eggFolder = workspace:FindFirstChild("__MAP") and workspace.__MAP:FindFirstChild("Eggs")
	local eggInstance = eggFolder and eggFolder:FindFirstChild(eggName)
	local eggModel = eggInstance and eggInstance:FindFirstChild("Egg")
	local price = eggInfo and eggInfo.price
	local fruitRewards = EggUtility.getFruitRewards(eggName)

	if not eggInfo or eggInfo.is_exclusive or typeof(price) ~= "number" or price <= 0 or price ~= price or price == math.huge or not eggModel or not fruitRewards then
		return false, "invalid"
	end

	local totalChance = 0
	local fruitModels = game:GetService("ReplicatedStorage").Assets.Models.Fruits
	for _, fruitReward in ipairs(fruitRewards) do
		local chance = fruitReward.chance
		local fruitInfo = typeof(fruitReward.name) == "string" and FruitUtility.getInfo(fruitReward.name) or nil
		local modelName = fruitInfo and (fruitInfo.model or fruitInfo.name) or nil
		if typeof(chance) ~= "number" or chance ~= chance or math.abs(chance) == math.huge or chance <= 0 or not modelName or not fruitModels:FindFirstChild(modelName) then
			return false, "invalid"
		end
		totalChance += chance
	end
	if math.abs(totalChance - 100) > 0.001 then
		return false, "invalid"
	end

	if n == 3 and not self._client.purchases:OwnsGamepass("Triple_Eggs") then
		if shouldPrompt == true then
			self._client.purchases:PromptGamepass("Triple_Eggs")
		end
		return false, "gamepass"
	end

	local hatchCharacter = self._instance.Character
	local function isNearEgg()
		local character = self._instance.Character
		if character ~= hatchCharacter then
			return false
		end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = self._character_controller and self._character_controller._root
		return root ~= nil and humanoid ~= nil and humanoid.Health > 0 and (root.Position - eggModel:GetPivot().Position).Magnitude <= EGG_HATCH_DISTANCE
	end

	if not isNearEgg() then
		return false, "distance"
	end

	local now = os.clock()
	if self._egg_hatch_busy or now - self._last_egg_hatch < EGG_HATCH_COOLDOWN then
		return false, "cooldown"
	end
	self._egg_hatch_busy = true

	local function finish(success, err, rewardData)
		self._egg_hatch_busy = false
		if success then
			self._last_egg_hatch = os.clock()
		end
		return success, err, rewardData
	end

	local restricted = self:_paid_random_items_policy()
	if restricted == nil then
		return finish(false, "policy")
	end
	-- Gem Eggs are paid random items (Gems are sold for Robux). Restricted accounts never get a
	-- random roll: they hatch the next Fruits of a fixed order, shown before purchase, no luck.
	local guaranteed = nil
	local hatchedSoFar = 0
	if restricted then
		hatchedSoFar = self._data:Get({"restricted_hatch", eggName}) or 0
		if typeof(hatchedSoFar) ~= "number" or hatchedSoFar ~= hatchedSoFar or hatchedSoFar < 0 or hatchedSoFar == math.huge then
			hatchedSoFar = 0
		end
		hatchedSoFar = math.floor(hatchedSoFar)
		guaranteed = {}
		for k = 0, n - 1 do
			local fruitName = EggUtility.getGuaranteedNext(self._data, eggName, k)
			if not fruitName then
				return finish(false, "invalid")
			end
			table.insert(guaranteed, fruitName)
		end
	end
	if not self._instance.Parent or not eggModel.Parent or not isNearEgg() then
		return finish(false, "distance")
	end

	local currency = "Gems"
	local gems = self._data:Get({"stats", currency})
	local cost = price * n
	if typeof(gems) ~= "number" or gems ~= gems or math.abs(gems) == math.huge or gems < cost then
		return finish(false, "afford")
	end
	if not FruitUtility.hasInventorySpace(self._data, n) then
		return finish(false, "space")
	end

	self._data:Set({"stats", currency}, gems - cost)
	local callSuccess, rewardSuccess, rewardData = pcall(PlayerRewardUtility.give, self._client, {{name = "Egg", props = {
		name = eggInfo.name,
		value = n,
		guaranteed = guaranteed
	}}})
	if not callSuccess or not rewardSuccess then
		self._data:Set({"stats", currency}, gems)
		warn("[Egg] Hatch reward failed:", eggName, rewardSuccess)
		return finish(false, "error")
	end
	if guaranteed then
		self._data:Set({"restricted_hatch", eggName}, hatchedSoFar + n)
	end

	if eggName == "250K_Event_Egg" then
		self._data:Set({"stats", "Event_Eggs_1_Opened"}, self._data:Get({"stats", "Event_Eggs_1_Opened"}) + n)
	end

	Network.Remote.Fire("C_Eggs_Open", self._instance, {
		name = eggName,
		reward_data = rewardData
	})
	if self._data:Get("tutorial_marker") == 6 then
		self._data:Set("tutorial_marker", 7)
	end

	return finish(true, nil, rewardData)
end

function Player:_boosts_use(boostName, boostValue)
	-- the client picks which potion and how many: only whole, positive counts it actually owns
	-- (a negative or NaN count used to add potions instead of spending them)
	if typeof(boostName) ~= "string" or typeof(boostValue) ~= "number" or boostValue ~= boostValue
		or boostValue < 1 or boostValue > 1000 or boostValue % 1 ~= 0 then
		return false
	end
	local boostInfo = BoostUtility.getInfo(boostName)
	local owned = (self._data:Get("boosts") or {})[boostName]
	if not boostInfo or typeof(owned) ~= "table" or (owned.quantity or 0) < boostValue then
		return false
	end
	
	if boostInfo.active then
		-- Mastery XP: player mastery for using boosts
		MasteryUtility.addXp(self._data, "player", nil, 5)
		return BoostUtility.use(self._client, {
			name = boostName,
			value = boostValue
		})
	end
end

function Player:_damage_register(p2, n)
	local pcc2 = Network.Bindable.Invoke("S_Client_Get", p2)

	if not pcc2 then
		return false
	end

	local pc2 = pcc2.player_controller

	if pc2 and not self._safezone:Get() then
		return pc2:_damage(self, n)
	end
end

function Player:_damage(pc2, n)
	n = if self._client.purchases:OwnsGamepass("x2_Damage") or BoostUtility.has(pc2._data, "x2_Damage") then n * 2 else n
	
	if not self:has_flag("protection") then
		local characterController = self._character_controller

		if characterController then
			local c = characterController:get_health()

			if c-n <= 0 then
				if self._instance:GetAttribute("is_king") and Network.Bindable.Invoke("check", pc2._instance) then
					Network.Bindable.Fire("setKing", pc2._instance)
				end
				local clan1 = pc2:get_clan()
				if clan1 then
					clan1:increment("kills", 1)
				end
				pc2:_quests_progress("1", 1)
				pc2._data:Set({"stats", "Kills"}, pc2._data:Get({"stats", "Kills"}) + 1)
				pc2._data:Set({"stats", "Huge_Event_Kills"}, pc2._data:Get({"stats", "Huge_Event_Kills"}) + 1)
				pc2._data:Set({"stats", "Hacker_Event_Kills"}, pc2._data:Get({"stats", "Hacker_Event_Kills"}) + 1)
				local clan2 = self:get_clan()
				if clan2 then
					clan2:increment("deaths", 1)
				end
				self:_quests_progress("2", 1)
				self._data:Set({"stats", "Deaths"}, self._data:Get({"stats", "Deaths"}) + 1)
				
				Network.Remote.Fire("C_Kill", pc2._instance, self._instance)
				
				if workspace:GetAttribute("special_event") == "deathmatch" then
					local n = math.random(50, 100)
					local total = math.max(math.ceil(pc2._data:Get({"stats", "Gems"}) * 0.005), n)

					local orbs = {}

					for i = 1, n do
						table.insert(orbs, Orb.new({
							client = pc2._client,
							position = characterController._root.Position,
							image = PlayerRewardUtility.getInfo("Stat").getInfo("Gems").image,
							callback = function()
								PlayerRewardUtility.give(pc2._client, {{
									name = "Stat",
									props = {
										name = "Gems",
										value = math.ceil(total / n)
									}
								}})
							end,
						}))
					end

					Network.Remote.Fire("C_Orb_Bulk", pc2._instance, TableUtility.map(orbs, function(i, v)
						return i, v:package()
					end))

					if self._data:Get({"stats", "Gems"}) >= 1000 then
						local after = self._data:Get({"stats", "Gems"}) - self._data:Get({"stats", "Gems"}) * 0.001
						self._data:Set({"stats", "Gems"}, after)
					end
				end
			end
			
			self:_quests_progress("6", n)

			if c then
				Network.Remote.Fire("hit", self._instance)
				characterController:set_health(c - n)
				return true
			end
		end
	end
	
	return false
end

-- ============================================================
-- FRUIT SYSTEM METHODS
-- ============================================================

function Player:_fruits_toggle_equip(fruitUid)
	local fruitData = FruitUtility.getData(self._data, fruitUid)
	
	if not fruitData or fruitData.daycare then
		return false
	end
	
	-- ADMIN ONLY fruits: normal players can never equip them
	local equipInfo = FruitUtility.getInfo(fruitData.name)
	if equipInfo and equipInfo.admin_only and not _L.Get({"Common", "Modules", "Utilities", "AdminUtility"}).isAdmin(self._instance) then
		return false
	end
	
	local equipState = FruitUtility.isEquipped(self._data, fruitUid)
	local newState = not equipState
	
	FruitUtility.setEquipped(self._data, fruitUid, newState)
	if self._data:Get("tutorial_marker") == 7 and FruitUtility.isEquipped(self._data, fruitUid) then
		self._data:Set("tutorial_marker", 8)
	end
	
	return true, newState
end

function Player:_fruits_equip_best()
	FruitUtility.equipBest(self._data)
	
	local equipped = FruitUtility.getEquipped(self._data)
	if self._data:Get("tutorial_marker") == 7 and #equipped > 0 then
		self._data:Set("tutorial_marker", 8)
	end
	local equippedUids = TableUtility.map(equipped, function(i, v)
		return i, v.uid
	end)
	
	return true, equippedUids
end

function Player:_fruits_delete(fruitUids)
	-- the detail panel sends a single uid, the delete mode sends a list
	if typeof(fruitUids) == "string" then
		fruitUids = {fruitUids}
	end
	if typeof(fruitUids) ~= "table" or #fruitUids == 0 or #fruitUids > 500 then
		return false
	end
	local unique = {}
	for _, fruitUid in ipairs(fruitUids) do
		if typeof(fruitUid) ~= "string" or #fruitUid > 80 then
			return false
		end
		local fruitData = FruitUtility.getData(self._data, fruitUid)
		if not fruitData or fruitData.daycare then
			return false
		end
		if not table.find(unique, fruitUid) then
			table.insert(unique, fruitUid)
		end
	end
	-- a player must always keep at least one fruit
	local owned = 0
	for _, fruitData in ipairs(self._data:Get("fruits") or {}) do
		if not fruitData.daycare then
			owned += 1
		end
	end
	if owned - #unique < 1 then
		return false, "last"
	end
	FruitUtility.remove(self._data, unique)
	return true
end

-- BACKPACK: add one picked plant worth `worth` coins
function Player:_backpack_add(plantName, worth)
	local plants = table.clone(self._data:Get("plants") or {})
	plants[plantName] = (plants[plantName] or 0) + 1
	self._data:Set("plants", plants)

	local values = table.clone(self._data:Get("plant_values") or {})
	local entry = values[plantName] or {c = 0, v = 0}
	values[plantName] = {c = entry.c + 1, v = entry.v + (worth or 0)}
	self._data:Set("plant_values", values)
end

-- Coins for one plant of `plantName` that has no stored worth (from rewards etc.)
function Player:_plant_base_price(plantName)
	local BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
	local price = BackpackUtility.RARITY_PRICE[BackpackUtility.getRarity(plantName)] or 1
	local mutationMult = _L.Get({"Common", "Modules", "Utilities", "MutationUtility"}).getMultiplier(plantName)
	return self:_calc_strength(price, true) * mutationMult
end

-- Sell plants to the Gardener. plantName = nil sells everything, amount = nil sells all of that plant.
function Player:_backpack_sell(plantName, amount)
	local character = self._character_controller and self._character_controller._root
	if not character then
		return false, "far"
	end
	-- must stand next to a Gardener
	local near = false
	for _, npc in ipairs(game:GetService("CollectionService"):GetTagged("Gardener")) do
		local ok, pivot = pcall(npc.GetPivot, npc)
		if ok and (pivot.Position - character.Position).Magnitude < 25 then
			near = true
			break
		end
	end
	if not near then
		return false, "far"
	end

	local BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
	local plants = self._data:Get("plants") or {}
	local toSell = {}
	if typeof(plantName) == "string" then
		local have = plants[plantName] or 0
		local n = if typeof(amount) == "number" then math.clamp(math.floor(amount), 0, have) else have
		if n > 0 then
			toSell[plantName] = n
		end
	else
		for name, count in pairs(plants) do
			if count > 0 then
				toSell[name] = count
			end
		end
	end
	if next(toSell) == nil then
		return false, "empty"
	end

	local total, sold = 0, 0
	for name, n in pairs(toSell) do
		local before = (self._data:Get("plants") or {})[name] or 0
		total += BackpackUtility.getWorth(self._data, name, n, self:_plant_base_price(name))
		BackpackUtility.removeWorth(self._data, name, n, before)
		local newPlants = table.clone(self._data:Get("plants") or {})
		newPlants[name] = before - n
		if newPlants[name] <= 0 then
			newPlants[name] = nil
		end
		self._data:Set("plants", newPlants)
		sold += n
	end

	total = math.max(math.floor(total), 0)
	self:_add_coins(total)
	self._data:Set("tutorial_sold", true)
	if self._data:Get("tutorial_marker") == 2 then
		self:_tutorial_cover_costs(3)
		self._data:Set("tutorial_marker", 3)
	end
	return true, total, sold
end

function Player:_fruits_feed(fruitUid, plantName, plantCount)
	if typeof(fruitUid) ~= "string" or typeof(plantName) ~= "string" then
		return false
	end
	local fruitData = FruitUtility.getData(self._data, fruitUid)
	if not fruitData or fruitData.daycare then
		return false, "unavailable"
	end
	plantCount = if typeof(plantCount) == "number" and plantCount == plantCount then math.clamp(math.floor(plantCount), 1, 1000) else 1

	local countBefore = (self._data:Get("plants") or {})[plantName] or 0
	local success, info = FruitUtility.feed(self._data, fruitUid, plantName, plantCount)

	if success then
		-- fed plants leave the backpack: drop their stored coin worth too
		local countAfter = (self._data:Get("plants") or {})[plantName] or 0
		if countBefore > countAfter then
			local BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
			BackpackUtility.removeWorth(self._data, plantName, countBefore - countAfter, countBefore)
		end
	end

	if success then
		-- quest "5" = feed your fruits, quest "6" = level up fruits
		self:_quests_progress("5", plantCount)
		if info and info.levelsGained and info.levelsGained > 0 then
			self:_quests_progress("6", info.levelsGained)
		end
		local clan = self:get_clan()
		if clan then
			clan:increment("kings", plantCount) -- clan counter reused for "feed fruits"
		end

		-- Mastery XP: track per fruit + overall player mastery
		do
			local fruitData = FruitUtility.getData(self._data, fruitUid)
			if fruitData then
				local fruitXp = MasteryDB.fruit.xp_per_feed * plantCount
				local _, fruitLeveledUp = MasteryUtility.addXp(self._data, "fruit", fruitData.name, fruitXp)
				MasteryUtility.addXp(self._data, "player", nil, fruitXp)
				if fruitLeveledUp then
					self:_notify({text = "\u{2b06}\u{fe0f} " .. fruitData.name .. " Mastery leveled up!", color = Color3.fromRGB(255, 210, 80)})
				end
			end
		end
	end

	return success, info
end

function Player:_fruits_evolve(fruitUid)
	local fruitData = FruitUtility.getData(self._data, fruitUid)
	if not fruitData or fruitData.daycare then
		return false, "unavailable"
	end

	local canEvolve = FruitUtility.canEvolve(self._data, fruitUid)
	if not canEvolve then
		return false, "Cannot evolve this fruit"
	end
	
	local success, info = FruitUtility.evolve(self._data, fruitUid)
	return success, info
end

function Player:_fruits_awaken(fruitUid)
	local fruitData = FruitUtility.getData(self._data, fruitUid)
	if not fruitData or fruitData.daycare then
		return false, "unavailable"
	end

	local canAwaken = FruitUtility.canAwaken(self._data, fruitUid)
	if not canAwaken then
		return false, "Cannot awaken this fruit"
	end
	
	local success, info = FruitUtility.awaken(self._data, fruitUid)
	return success, info
end

function Player:_fruits_get_summary(fruitUid)
	return FruitUtility.getSummary(self._data, fruitUid)
end

function Player:_fruits_get_all_summaries()
	local fruits = self._data:Get("fruits")
	local summaries = {}
	
	for _, fruitData in ipairs(fruits) do
		local summary = FruitUtility.getSummary(self._data, fruitData.uid)
		if summary then
			table.insert(summaries, summary)
		end
	end
	
	return summaries
end

-- ============================================================
-- PLANT SYSTEM METHODS
-- ============================================================

function Player:_plants_get_inventory()
	return PlantUtility.getOwnedPlants(self._data)
end

function Player:_mastery_get_summary()
	return MasteryUtility.getSummary(self._data)
end

-- ============================================================
-- GARDEN PLACEMENT SYSTEM METHODS
-- ============================================================
-- Players can place decorative/functional items on their farm island.
-- Garden expansion increases the placement limit, tied to progression.

local GARDEN_BASE_SLOTS = 10
local GARDEN_SLOTS_PER_EXPANSION = 5

function Player:_garden_get_state()
	local garden = self._data:Get("garden") or {}
	local expansion = garden.expansion or 0
	local maxSlots = GARDEN_BASE_SLOTS + expansion * GARDEN_SLOTS_PER_EXPANSION
	local placements = garden.placements or {}

	-- Count current placements
	local count = 0
	for _ in pairs(placements) do
		count += 1
	end

	-- Calculate next expansion cost
	local nextExpansionCost = 500 * (expansion + 1) ^ 2

	return {
		expansion = expansion,
		max_slots = maxSlots,
		used_slots = count,
		next_expansion_cost = nextExpansionCost,
		placements = placements,
	}
end

function Player:_garden_place(itemType, itemId, cframe)
	-- old Gear garden (disabled LegacySystems): no client uses this, and it stored any id at any
	-- position for free. Garden decorations go through Farm's S_Decor_Place.
	if true then return false, "legacy" end
	if typeof(itemType) ~= "string" or typeof(itemId) ~= "string" then
		return false, "invalid"
	end

	local garden = self._data:Get("garden") or {}
	local expansion = garden.expansion or 0
	local maxSlots = GARDEN_BASE_SLOTS + expansion * GARDEN_SLOTS_PER_EXPANSION
	local placements = garden.placements or {}

	-- Check slot limit
	local count = 0
	for _ in pairs(placements) do
		count += 1
	end
	if count >= maxSlots then
		return false, "full"
	end

	-- Generate a unique placement ID
	local placementId = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))

	-- Store the placement (serialize CFrame to components for data saving)
	placements[placementId] = {
		type = itemType,
		id = itemId,
		pos = {cframe.X, cframe.Y, cframe.Z},
		rot = {cframe.Rotation.X, cframe.Rotation.Y, cframe.Rotation.Z},
	}

	self._data:Set("garden", {
		expansion = expansion,
		placements = placements,
	})

	return true, placementId
end

function Player:_garden_move(placementId, cframe)
	if true then return false, "legacy" end -- see _garden_place
	if typeof(placementId) ~= "string" then
		return false, "invalid"
	end

	local garden = self._data:Get("garden") or {}
	local placements = garden.placements or {}

	if not placements[placementId] then
		return false, "not_found"
	end

	placements[placementId].pos = {cframe.X, cframe.Y, cframe.Z}
	placements[placementId].rot = {cframe.Rotation.X, cframe.Rotation.Y, cframe.Rotation.Z}

	self._data:Set("garden", {
		expansion = garden.expansion or 0,
		placements = placements,
	})

	return true
end

function Player:_garden_remove(placementId)
	if typeof(placementId) ~= "string" then
		return false, "invalid"
	end

	local garden = self._data:Get("garden") or {}
	local placements = garden.placements or {}

	if not placements[placementId] then
		return false, "not_found"
	end

	placements[placementId] = nil

	self._data:Set("garden", {
		expansion = garden.expansion or 0,
		placements = placements,
	})

	return true
end

function Player:_garden_expand()
	local garden = self._data:Get("garden") or {}
	local expansion = garden.expansion or 0
	local cost = 500 * (expansion + 1) ^ 2
	local coins = self._data:Get({"stats", "Strength"})

	if coins < cost then
		return false, "afford"
	end

	self._data:Set({"stats", "Strength"}, coins - cost)

	self._data:Set("garden", {
		expansion = expansion + 1,
		placements = garden.placements or {},
	})

	return true, expansion + 1
end

function Player:Destroy()
	self._maid:Destroy()
end

return Player