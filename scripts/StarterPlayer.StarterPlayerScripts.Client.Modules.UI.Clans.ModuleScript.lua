--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Data
local TableUtility
local NumberUtility
local Spr
local Trove
local Audio
local Shared
local Timer
local FastTween
local cancellableDelay
local Constants
local AttributeUtility
local TrackerUtility
local ArrayUtility
local UI
local Network
local Notifications
local Purchases
local StatUtility
local ProgressBar
local ClanEmblems
local ClanQuests
local ClanShopItemUtility

--> Constants

------------->
local Clans = {
	name = script.Name
}

function Clans:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Network = _L.Get {"Common", "Library", "Network"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"}
	FastTween = _L.Get {"Common", "Library", "Functions", "FastTween"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	UI = _L.Get {"Client", "Modules", "UI"}
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	StatUtility = _L.Get {"Common", "Modules", "Utilities", "StatUtility"}
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	ClanEmblems = _L.Get {"Common", "Modules", "Databases", "ClanEmblems"}
	ClanEmblemUtility = _L.Get {"Common", "Modules", "Utilities", "ClanEmblemUtility"}
	ClanQuests = TableUtility.filter(_L.Get {"Common", "Modules", "Databases", "ClanQuests"}, function(i, v) return typeof(v) == "table" end)
	ClanQuestUtility = _L.Get {"Common", "Modules", "Utilities", "ClanQuestUtility"}
	TableTracker = _L.Get {"Common", "Library", "Classes", "Tracker", "TableTracker"}
	ClanShopItemUtility = _L.Get {"Common", "Modules", "Utilities", "ClanShopItemUtility"}
	
	self.is_open = Tracker.new(false)
	
	self._is_creating = {tracker = Tracker.new(false), trove = Trove.new()}
	self._is_editing = {tracker = Tracker.new(false), trove = Trove.new()}
	self._is_joining = {tracker = Tracker.new(false), trove = Trove.new()}
	
	self._view = {tracker = Tracker.new("MainView"), trove = Trove.new()}
	
	self._emblem = Tracker.new(1)
	self._type = Tracker.new("Public")
	
	self._create_request_pending = Tracker.new(false)
	self._leave_request_pending = Tracker.new(false)
	self._join_request_pending = Tracker.new(false)
end

function Clans:_start()
	Notifications = UI.Get("Notifications")

	self.object = _L.PlayerGui.Clans
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	self._instances = {}
	
	local data = Data.Await()
	
	if data then
		for _, clanShopItemInstance in pairs(self.object.Main.Pages.ShopView.Content.Main.Container:GetChildren()) do
			if clanShopItemInstance:IsA("Frame") then
				local clanShopItemId = tonumber(clanShopItemInstance.Name)
				local clanShopItemInfo = ClanShopItemUtility.getInfo(clanShopItemId)
				
				clanShopItemInstance.Main.CrownsBtn.MouseButton1Down:Connect(function()
					UI.Open({
						name = "Confirm",
						props = {
							text = "Are you sure you want to buy this item for "..NumberUtility.commas(clanShopItemInfo.price).." Crowns?",

							yes = function()
								local success = Network.Remote.Invoke("S_Clans_Shop_Buy", clanShopItemId)
							end,

							no = function()
							end,
						}
					})
				end)
			end
		end
		
		data:Bind({"stats", "Crowns"}, function(value)
			self.object.Main.Pages.ShopView.Content.Main.Crowns.Number.Text = NumberUtility.short(value)
		end)
		
		self.object.Main.Pages.MainView.CreateBtn.MouseButton1Down:Connect(function()
			if data:Get("clan") == nil and not self._create_request_pending:Get() then
				self._is_joining.tracker:Set(false)
				self._is_editing.tracker:Set(false)
				self._is_creating.tracker:Set(true)
			end
		end)
		
		self.object.Main.Pages.MainView.JoinBtn.MouseButton1Down:Connect(function()
			if data:Get("clan") == nil and not self._join_request_pending:Get() then
				self._is_editing.tracker:Set(false)
				self._is_creating.tracker:Set(false)
				self._is_joining.tracker:Set(true)
			end
		end)

		self.object.Main.Pages.MainView.Creating.BackBtn.MouseButton1Down:Connect(function()
			self._is_creating.tracker:Set(false)
		end)
		
		self.object.Main.Pages.MainView.Joining.BackBtn.MouseButton1Down:Connect(function()
			self._is_joining.tracker:Set(false)
		end)
		
		self.object.Main.Pages.ShopView.Content.Main.BackBtn.MouseButton1Down:Connect(function()
			self._view.tracker:Set("ClanView")
		end)
		
		self.object.Main.Pages.QuestsView.Content.Main.BackBtn.MouseButton1Down:Connect(function()
			self._view.tracker:Set("ClanView")
		end)
		
		self.object.Main.Pages.StatsView.Content.Main.BackBtn.MouseButton1Down:Connect(function()
			self._view.tracker:Set("ClanView")
		end)
		
		local clanNameTextBox = self.object.Main.Pages.MainView.Creating.Background.Main.ClanName.Main.TextBox
		local joinCodeTextBox = self.object.Main.Pages.MainView.Joining.Background.JoinCode.Main.TextBox
		--local clanDescriptionTextBox = self.object.Main.Pages.MainView.Creating.Background.Main.ClanDescription.Main.TextBox
		
		local createClanButton = self.object.Main.Pages.MainView.Creating.CreateBtn
		local joinClanButton = self.object.Main.Pages.MainView.Joining.JoinBtn
		local clanView = self.object.Main.Pages.ClanView
		local leaveClanButton = self.object.Main.Pages.ClanView.Content.Background.LeaveBtn 
		local shopButton = self.object.Main.Pages.ClanView.Content.Background.ShopBtn 
		local statsButton = self.object.Main.Pages.ClanView.Content.Background.StatsBtn
		local questsButton = self.object.Main.Pages.ClanView.Content.Background.QuestsBtn
		local settingsButton = self.object.Main.Pages.ClanView.Content.Background.SettingsBtn
		
		self.object.Main.Pages.MainView.Creating.Background.Main.ClanType.Main.StateBtn.MouseButton1Down:Connect(function()
			local currentType = self._type:Get()
			self._type:Set(if currentType == "Public" then "Private" else "Public")
		end)
		
		self.object.Main.Pages.MainView.Creating.Background.Main.ClanEmblem.Main.LeftBtn.MouseButton1Down:Connect(function()
			local currentEmblem = self._emblem:Get()
			self._emblem:Set(if currentEmblem == 1 then #ClanEmblems else currentEmblem - 1)
		end)
		
		self.object.Main.Pages.MainView.Creating.Background.Main.ClanEmblem.Main.RightBtn.MouseButton1Down:Connect(function()
			local currentEmblem = self._emblem:Get()
			self._emblem:Set(if currentEmblem == #ClanEmblems then 1 else currentEmblem + 1)
		end)
		
		self.object.Main.Pages.ClanView.Editing.Background.Main.ClanType.Main.StateBtn.MouseButton1Down:Connect(function()
			local currentType = self._type:Get()
			self._type:Set(if currentType == "Public" then "Private" else "Public")
		end)

		self.object.Main.Pages.ClanView.Editing.Background.Main.ClanEmblem.Main.LeftBtn.MouseButton1Down:Connect(function()
			local currentEmblem = self._emblem:Get()
			self._emblem:Set(if currentEmblem == 1 then #ClanEmblems else currentEmblem - 1)
		end)

		self.object.Main.Pages.ClanView.Editing.Background.Main.ClanEmblem.Main.RightBtn.MouseButton1Down:Connect(function()
			local currentEmblem = self._emblem:Get()
			self._emblem:Set(if currentEmblem == #ClanEmblems then 1 else currentEmblem + 1)
		end)
		
		self.object.Main.Pages.ClanView.Editing.DoneBtn.MouseButton1Down:Connect(function()
			self._is_editing.tracker:Set(false)
		end)
		
		self._emblem:Bind(function(value)
			local clanEmblemInfo = ClanEmblemUtility.getInfo(value)
			self.object.Main.Pages.MainView.Creating.Background.Main.ClanEmblem.Main.Emblem.Image = clanEmblemInfo.image
		end)
		
		self._type:Bind(function(value)
			self.object.Main.Pages.MainView.Creating.Background.Main.ClanType.Main.StateBtn.ImageColor3 = if value == "Public" then Color3.fromRGB(0, 255, 0) else Color3.fromRGB(255, 0, 0)
			self.object.Main.Pages.MainView.Creating.Background.Main.ClanType.Main.StateBtn.Number.Text = value
		end)
		
		createClanButton.MouseButton1Down:Connect(function()
			if self._create_request_pending:Get() then
				return
			end

			self._create_request_pending:Set(true)

			local clanName = clanNameTextBox.Text
			--local clanDescription = clanDescriptionTextBox.Text
			local clanEmblem = self._emblem:Get()
			
			local success, err, a = Network.Remote.Invoke("S_Clans_Create", {
				name = clanName,
				emblem = clanEmblem,
				--description = clanDescription
			})
			
			if not success then
				if err == "delay" then
					self:delay(a)
				elseif err == "enough" then
					Notifications:add({
						text = "❌ You need more gems to create a clan!",
						color = Color3.fromRGB(255, 0, 0),
						audio = {name = "Fail1"}
					})
				else
					Notifications:add({
						text = "Please try again later.",
						duration = 1
					})
				end
			end
			
			if success then
				self._is_creating.tracker:Set(false)
			end
			
			self._create_request_pending:Set(false)
		end)
		
		joinClanButton.MouseButton1Down:Connect(function()
			if self._join_request_pending:Get() then
				return
			end

			self._join_request_pending:Set(true)
			
			local clanCode = joinCodeTextBox.Text
			
			local success, err, a = Network.Remote.Invoke("S_Clans_Join", clanCode, true)

			if not success then
				if err == "delay" then
					self:delay(a)
				elseif err == "error" then
					Notifications:add({
						text = "An error occured, please try again.",
						duration = 1
					})
				elseif err == "invalid" then
					Notifications:add({
						text = "The join code you entered is invalid.",
						duration = 1
					})
				end
			end

			self._join_request_pending:Set(false)
		end)
		
		settingsButton.MouseButton1Down:Connect(function()
			self._is_creating.tracker:Set(false)
			self._is_joining.tracker:Set(false)
			self._is_editing.tracker:Set(true)
		end)
		
		shopButton.MouseButton1Down:Connect(function()
			self._view.tracker:Set("ShopView")
		end)
		
		questsButton.MouseButton1Down:Connect(function()
			self._view.tracker:Set("QuestsView")
		end)
		
		statsButton.MouseButton1Down:Connect(function()
			self._view.tracker:Set("StatsView")
		end)

		self._is_creating.tracker:Bind(function(value)
			self._is_creating.trove:Clean()
			clanNameTextBox.Text = ""
			--clanDescriptionTextBox.Text = ""
			self._emblem:Set(1)
			self._type:Set("Public")
		end)
		
		self._is_editing.tracker:Bind(function(value)
			self._is_editing.trove:Clean()
			joinCodeTextBox.Text = ""
		end)
		
		Tracker.Subscribe({self._is_creating.tracker, self._is_editing.tracker, self._is_joining.tracker}, function()
			local a = self._is_creating.tracker:Get()
			local b = self._is_editing.tracker:Get()
			local c = self._is_joining.tracker:Get()
			
			self.object.Main.Dark.Visible = a or b or c
			
			self.object.Main.Pages.MainView.Creating.Visible = a
			self.object.Main.Pages.ClanView.Editing.Visible = b
			self.object.Main.Pages.MainView.Joining.Visible = c
		end)
		
		self._view.tracker:Bind(function(value)
			self._view.trove:Clean()
			
			local pageInstance = self.object.Main.Pages:FindFirstChild(value)
			
			if pageInstance then
				if value ~= "MainView" and value ~= "ClanView" then
					for _, a in pairs(self.object.Main.Pages:GetChildren()) do
						if a:IsA("Frame") then
							if a.Name ~= "MainView" and a.Name ~= "ClanView" then
								a.LayoutOrder = if a.Name == value then 3 else 4
							end
						end
					end
				end
				
				self.object.Main.Pages.UIPageLayout:JumpTo(pageInstance)
			end
		end)
		
		local clan = {tracker = data:Track("clan"), trove = Trove.new()}
		
		clan.tracker:Bind(function(value)
			clan.trove:Clean()
			
			self._is_creating.tracker:Set(false)
			self._is_joining.tracker:Set(false)
			
			if value then
				clan.trove:Add(task.spawn(function()
					local newTrove = clan.trove:Add(Trove.new())
					local clanData = TableTracker.new({})
					
					local clanHolder = _L.Debris.Clans:WaitForChild(value)
					
					AttributeUtility.waitFor(clanHolder, "data")
					
					local playerObjects = {}
					local questObjects = {}
					local userInfosTracker = Tracker.new({})
					local clanPlayersTracker = Tracker.new({})
					
					clanPlayersTracker:Bind(function(value)
						local success, result
						
						if TableUtility.length(value) > 0 then
							success, result = pcall(function()
								return Services.UserService:GetUserInfosByUserIdsAsync(TableUtility.map(value, function(i, v)
									return i, v[1]
								end))
							end)
						end
						
						if success then
							userInfosTracker:Set(result or {})
						end
					end)
					
					local clanMetaData = clan.trove:Add(TrackerUtility.fromAttributeSignal(clanHolder, "data"))
					
					clan.trove:Add(Tracker.Subscribe({clanMetaData, data:Track("clan_quests"), userInfosTracker}, function()
						newTrove:Clean()

						local clanMetaDataValue = clanMetaData:Get()

						clanData:Set({}, clanMetaDataValue)

						local clanName = clanMetaDataValue.name[1]
						local clanEmblem = clanMetaDataValue.emblem[1]
						local clanUid = clanMetaDataValue.uid
						local clanPlayers = clanMetaDataValue.players
						local clanMaxPlayers = clanMetaDataValue.max_players
						local clanType = clanMetaDataValue._type[1]
						local joinCode = clanMetaDataValue.join_code
						--local clanDescription = clanMetaDataValue.description[1]
						
						clanPlayersTracker:Set(TableUtility.deep.clone(clanPlayers))
						
						local clanEmblemInfo = ClanEmblemUtility.getInfo(clanEmblem)

						local _, ownerPacket = TableUtility.match(clanPlayers, function(i, v)
							return v[3] == "Owner"
						end)

						local isOwner = if ownerPacket and ownerPacket[1] == _L.Player.UserId then true else false

						newTrove:Add(leaveClanButton.MouseButton1Down:Connect(function()
							UI.Open({
								name = "Confirm",
								props = {
									ignore_last = true,
									text = "Are you sure you want to leave this clan?",

									yes = function()
										if self._leave_request_pending:Get() then
											return
										end

										self._leave_request_pending:Set(true)

										local success, err, a = Network.Remote.Invoke("S_Clans_Leave")
										
										if not success and err == "delay" then
											self:delay(a)
										end
										
										self._leave_request_pending:Set(false)

										UI.Open({name = "Clans"})
									end,

									no = function()
										UI.Open({name = "Clans"})
									end,
								}
							})
						end))
						
						clanView.Background.Time.Text = clanName
						clanView.Background.Time.Time.Text = clanName
						clanView.Background.Emblem.Image = clanEmblemInfo.image
						--clanView.Background.Desc.Text = clanDescription
						--clanView.Editing.Background.Main.ClanDescription.Main.TextBox.Text = clanDescription
						
						clanView.Editing.Background.Main.ClanEmblem.Main.Emblem.Image = clanEmblemInfo.image
						clanView.Editing.Background.Main.ClanType.Main.StateBtn.ImageColor3 = if clanType == "Public" then Color3.fromRGB(0, 255, 0) else Color3.fromRGB(255, 0, 0)
						clanView.Editing.Background.Main.ClanType.Main.StateBtn.Number.Text = clanType
						clanView.Editing.Background.Main.ClanJoinCode.Main.TextBox.Text = joinCode or "?????"
						
						newTrove:Add(clanView.Editing.Background.Main.ClanType.Main.StateBtn.MouseButton1Down:Connect(function()
							Network.Remote.Invoke("S_Clans_Settings_Type", if clanType == "Public" then "Private" else "Public")
						end))

						newTrove:Add(clanView.Editing.Background.Main.ClanEmblem.Main.LeftBtn.MouseButton1Down:Connect(function()
							Network.Remote.Invoke("S_Clans_Settings_Emblem", if clanEmblem == 1 then #ClanEmblems else clanEmblem - 1)
						end))

						newTrove:Add(clanView.Editing.Background.Main.ClanEmblem.Main.RightBtn.MouseButton1Down:Connect(function()
							Network.Remote.Invoke("S_Clans_Settings_Emblem", if clanEmblem == #ClanEmblems then 1 else clanEmblem + 1)
						end))
						
						--newTrove:Add(clanView.Editing.Background.Main.ClanDescription.Main.TextBox.FocusLost:Connect(function(enterPressed)
						--	if enterPressed then
						--		Network.Remote.Invoke("S_Clans_Settings_Description", if clanEmblem == #ClanEmblems then 1 else clanEmblem + 1)
						--	end
						--end))
						
						self.object.Main.Pages.StatsView.Content.Main.Container.Kills.Main.Title.Text = "Total Kills: "..NumberUtility.commas(clanData:Get("kills"))
						self.object.Main.Pages.StatsView.Content.Main.Container.Deaths.Main.Title.Text = "Total Deaths: "..NumberUtility.commas(clanData:Get("deaths"))
						self.object.Main.Pages.StatsView.Content.Main.Container.Eggs_Opened.Main.Title.Text = "Total Eggs Opened: "..NumberUtility.commas(clanData:Get("eggs_opened"))
						self.object.Main.Pages.StatsView.Content.Main.Container.Strength.Main.Title.Text = "Total Coins: "..NumberUtility.short(clanData:Get("strength"))
						self.object.Main.Pages.StatsView.Content.Main.Container.Rebirths.Main.Title.Text = "Total Rebirths: "..NumberUtility.commas(clanData:Get("rebirths"))
						
						self.object.Main.Pages.ClanView.Content.Members.Count.Main.Time.Text = "Members "..#clanPlayers.."/"..clanMaxPlayers

						newTrove:Add(task.spawn(function()
							for userId, playerObject in pairs(playerObjects) do
								local playerIndex, _ = TableUtility.match(clanPlayers, function(i, v)
									return v[1] == userId
								end)

								if not playerIndex or playerObject.clan_uid ~= clanUid then
									playerObjects[userId] = nil
									playerObject.trove:Destroy()
								end
							end

							for _, playerPacket in pairs(clanPlayers) do
								local userId = playerPacket[1]
								local rank = playerPacket[3]
								
								local playerObject = playerObjects[userId]
								local _, userInfo = TableUtility.match(userInfosTracker:Get(), function(i, v)
									return v.Id == userId
								end)

								if not playerObject then
									local newPlayerTrove = clan.trove:Add(Trove.new())
									local newPlayerFrame = newPlayerTrove:Add(_L.Assets.UI.Clans.Member:Clone())

									newPlayerFrame.Main.BackgroundColor3 = if userId == _L.Player.UserId then Color3.fromRGB(255, 100, 0) else Color3.fromRGB(255, 255, 255)
									
									newPlayerFrame.Main.KickBtn.MouseButton1Down:Connect(function()
										UI.Open({
											name = "Confirm",
											props = {
												ignore_last = true,
												text = "Are you sure you want to kick "..(if userInfo then userInfo.Username else "this player").."?",

												yes = function()
													local success, err, a = Network.Remote.Invoke("S_Clans_Kick", userId)

													if not success and err == "delay" then
														self:delay(a)
													end
													
													UI.Open({name = "Clans"})
												end,

												no = function()
													UI.Open({name = "Clans"})
												end,
											}
										})
									end)
									
									newPlayerFrame.Parent = self.object.Main.Pages.ClanView.Content.Members.Main

									playerObject = {
										instance = newPlayerFrame,
										clan_uid = clanUid,
										trove = newPlayerTrove
									}

									playerObjects[userId] = playerObject
								end
								
								-- EHhhhh but whtvr --TODO
								if playerObject.instance:FindFirstChild("Main") then
									playerObject.instance.Main.KickBtn.Visible = ownerPacket and ownerPacket[1] == _L.Player.UserId and playerPacket ~= ownerPacket
									playerObject.instance.Main.Rank.Text = rank
									playerObject.instance.Main.Content.Owner.Visible = rank == "Owner"
									playerObject.instance.Main.Content.Time.Text = if userInfo then userInfo.Username else "???"
								end
							end
						end))
						
						for questId, questObject in pairs(questObjects) do
							local questIndex, _ = TableUtility.match(ClanQuests, function(i, v)
								return v.id == questId
							end)

							if not questIndex or questObject.clan_uid ~= clanUid then
								questObjects[questId] = nil
								questObject.trove:Destroy()
							end
						end

						for _, questInfo in pairs(ClanQuests) do
							local questObject = questObjects[questInfo.id]

							if not questObject then
								local newQuestTrove = clan.trove:Add(Trove.new())
								local newQuestFrame = newQuestTrove:Add(_L.Assets.UI.Clans.Quest:Clone())
								
								newQuestTrove:Add(newQuestFrame.Main.ClaimBtn.MouseButton1Down:Connect(function()
									local success = Network.Remote.Invoke("S_Clans_Quests_Claim", questInfo.id)
									
									if success then
										Notifications:add({text = "✅ Clan Quest completed!", color = Color3.fromRGB(0, 255, 0), audio = {name = "Success1"}})
									end
								end))
								
								newQuestFrame.Parent = self.object.Main.Pages.QuestsView.Content.Main.Container.Main

								questObject = {
									instance = newQuestFrame,
									clan_uid = clanUid,
									trove = newQuestTrove
								}

								questObjects[questInfo.id] = questObject
							end
							
							local canClaim, err = ClanQuestUtility.canClaimClient(questInfo.id, clanData, data)
							
							questObject.instance.Main.ClaimBtn.Image = if canClaim then Constants.POP_BUTTON_GREEN else Constants.POP_BUTTON_GRAY

							if err == "already" then
								questObject.instance.LayoutOrder = 2
								questObject.instance.Main.ClaimBtn.Visible = false
								questObject.instance.Main.Checkmark.Visible = true
							else
								questObject.instance.LayoutOrder = 1
								questObject.instance.Main.Checkmark.Visible = false
								questObject.instance.Main.ClaimBtn.Visible = true
							end
							
							questObject.instance.Main.TextLabel.Text = questInfo.description
							questObject.instance.Main.Icon.Icon.Image = questInfo.icon
							
							local rewardValue = unpack(questInfo.reward).props.value
							
							questObject.instance.Main.Number.Text = NumberUtility.commas(rewardValue) -- if we add more rewards make this support other stuff
							questObject.instance.Main.Number.Number.Text = NumberUtility.commas(rewardValue)
							
							local progress = questInfo.fetch_progress(clanData, data)
							local format = questInfo.fetch_format(clanData, data)
							
							local s = progress > 0
							
							questObject.instance.Main.Progress.Main.Visible = s
							questObject.instance.Main.Progress.TextLabel.Text = format
							questObject.instance.Main.Progress.Main.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
						end
					end))

					self._view.tracker:Set("ClanView")
				end))
			else
				self._view.tracker:Set("MainView")
			end
		end)
		
		self._create_request_pending:Bind(function(value)
			createClanButton.Image = if value then Constants.POP_BUTTON_GRAY else Constants.POP_BUTTON_GREEN
			createClanButton.TextLabel.Text = if value then "..." else "CREATE"
		end)
		
		self._leave_request_pending:Bind(function(value)
			leaveClanButton.Image = if value then Constants.POP_BUTTON_GRAY else Constants.POP_BUTTON_RED
			leaveClanButton.TextLabel.Text = if value then "..." else "LEAVE"
		end)
		
		self._join_request_pending:Bind(function(value)
			joinClanButton.Image = if value then Constants.POP_BUTTON_GRAY else Constants.POP_BUTTON_GREEN
			joinClanButton.TextLabel.Text = if value then "..." else "JOIN"
		end)
		
		local clans = Tracker.new(_L.Debris.Clans:GetChildren())
		
		_L.Debris.Clans.ChildAdded:Connect(function()
			clans:Set(_L.Debris.Clans:GetChildren())
		end)

		_L.Debris.Clans.ChildRemoved:Connect(function()
			clans:Set(_L.Debris.Clans:GetChildren())
		end)
		
		local clanObjects = {}
		
		clans:Bind(function(value)
			self.object.Main.Pages.MainView.Content.Background.Suggestions.Visible = #value <= 0
			
			for clanUid, clan in pairs(clanObjects) do
				local _, clanInstance = TableUtility.match(value, function(i, v)
					return v.Name == clanUid
				end)
				
				if not clanInstance then
					clanObjects[clanUid] = nil
					clan.trove:Destroy()
				end
			end

			for _, clanInstance in pairs(value) do
				local clanUid = clanInstance.Name
				
				if not clanObjects[clanUid] then
					local newClanTrove = Trove.new()
					local newClanFrame = newClanTrove:Add(_L.Assets.UI.Clans.Clan:Clone())
					local newClanDataTrove = newClanTrove:Add(Trove.new())
					
					newClanFrame.Main.StateBtn.MouseButton1Down:Connect(function()
						if self._join_request_pending:Get() then
							return
						end

						self._join_request_pending:Set(clanUid)

						local success, err, a = Network.Remote.Invoke("S_Clans_Join", clanUid)
						
						if not success then
							if err == "delay" then
								self:delay(a)
							elseif err == "error" then
								Notifications:add({
									text = "An error occured, please try again.",
									duration = 1
								})
							end
						end
						
						self._join_request_pending:Set(nil)
					end)
					
					newClanTrove:Add(self._join_request_pending:Bind(function(value)
						newClanFrame.Main.StateBtn.Image = if value == clanUid then Constants.POP_BUTTON_GRAY else Constants.POP_BUTTON_GREEN
						newClanFrame.Main.StateBtn.TextLabel.Text = if value == clanUid then "..." else "Join"
					end))
					
					clanObjects[clanUid] = {
						trove = newClanTrove
					}
					
					newClanTrove:Add(task.spawn(function()
						local clanHolder = _L.Debris.Clans:WaitForChild(clanUid)

						AttributeUtility.waitFor(clanHolder, "data")
						
						local playerObjects = {}
						
						newClanTrove:Add(newClanTrove:Add(TrackerUtility.fromAttributeSignal(clanHolder, "data")):Bind(function(value)
							newClanDataTrove:Clean()
							
							newClanDataTrove:Add(task.spawn(function()
								local clanName = value.name[1]
								local clanEmblem = value.emblem[1]
								local clanUid = value.uid
								local clanPlayers = value.players
								local clanMaxPlayers = value.max_players
								
								local clanEmblemInfo = ClanEmblemUtility.getInfo(clanEmblem)
								
								newClanFrame.Main.Members.Text = #clanPlayers.."/"..clanMaxPlayers
								newClanFrame.Main.Time.Text = clanName
								newClanFrame.Main.Emblem.Image = clanEmblemInfo.image

								newClanFrame.Parent = self.object.Main.Pages.MainView.Content.Join.Main
							end))
						end))
					end))
				end
			end
		end)
	end
end

function Clans:delay(a)
	local lastClanAction = _L.Player:GetAttribute("last_clan_action")
	local timeLeft

	if lastClanAction then
		timeLeft = Constants.CLAN_ACTION_DELAY - (a - lastClanAction)
	end

	Notifications:add({
		text = if timeLeft then "Please try again in "..math.round(timeLeft).."s" else "Please try again later.",
		duration = 1
	})
end

function Clans:Open()
	Spr.Stop(self.object.Main)
	
	self.object.Main.Visible = true
	self.object.Main.Position = UDim2.fromScale(0.5, 0.55)
	
	Spr.Target(self.object.Main, 1, 4, {
		Position = UDim2.fromScale(0.5, 0.5)
	})
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 80
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 20
	})
end

function Clans:Close()
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Clans