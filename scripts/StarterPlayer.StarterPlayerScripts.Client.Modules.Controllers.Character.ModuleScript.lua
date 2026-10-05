--> Variables
local _L = _G._L

local Services
local Maid
local Network
local Audio
local Shared
local RandomUtility
local Timer
local Create
local NumberUtility
local TableUtility
local DictionaryUtility
local cancellableDelay
local Tracker
local Promise
local AttributeUtility
local TrackerUtility
local Constants
local Pool
local EmojiMapUtility
local RankUtility
local PowerUtility
local PowerComponentUtility
local CharacterBillboardPool
local ProgressBar
local LevelUpPool
local RebirthPool
local Eggs
local Beam
local Spr

--> Constants

------------->
local Character = {_objects = {}}
Character.__index = Character

function Character._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Pool = _L.Get {"Common", "Library", "Classes", "Pool"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Shared = _L.Get {"Common", "Modules", "Shared"}
	RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	DictionaryUtility = _L.Get {"Common", "Library", "Utilities", "DictionaryUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	EmojiMapUtility = _L.Get {"Common", "Modules", "Utilities", "EmojiMapUtility"}
	RankUtility = _L.Get {"Common", "Modules", "Utilities", "RankUtility"}
	PowerComponentUtility = _L.Get {"Common", "Modules", "Utilities", "PowerComponentUtility"}
	PowerUtility = _L.Get {"Common", "Modules", "Utilities", "PowerUtility"}
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	UI = _L.Get {"Client", "Modules", "UI"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Beam = _L.Get {"Client", "Modules", "Beam"}
	TrainingAreaUtility = _L.Get {"Common", "Modules", "Utilities", "TrainingAreaUtility"}
end

function Character._start()
	Eggs = UI.Get("Eggs")
	LevelUpPool = Pool.new({name = "LevelUpPool", template = _L.Assets.Models.Other.LevelUp})
end

function Character.new(props)
	local self = setmetatable({}, Character)
	
	self._player_controller = props.player_controller
	self._instance = props.instance
	
	self._data = self._player_controller._data
	
	self._humanoid = nil
	self._root = nil
	
	self._health = nil
	
	self._trove = Trove.new()

	self:_construct()

	return self
end

function Character:_construct()
	Character._objects[self._instance] = self
	
	self._trove:Add(function()
		Character._objects[self._instance] = nil
	end)
	
	self._trove:AddPromise(Promise.new(function(resolve)
		self._humanoid = self._instance:WaitForChild("Humanoid")
		self._root = self._instance:WaitForChild("HumanoidRootPart")
		self._head = self._instance:WaitForChild("Head")
		self._left_foot = self._instance:WaitForChild("LeftFoot")
		self._left_upper_arm = self._instance:WaitForChild("LeftUpperArm")
		self._left_lower_arm = self._instance:WaitForChild("LeftLowerArm")
		self._right_upper_arm = self._instance:WaitForChild("RightUpperArm")
		self._right_lower_arm = self._instance:WaitForChild("RightLowerArm")
		self._left_upper_leg = self._instance:WaitForChild("LeftUpperLeg")
		self._left_lower_leg = self._instance:WaitForChild("LeftLowerLeg")
		self._right_upper_leg = self._instance:WaitForChild("RightUpperLeg")
		self._right_lower_leg = self._instance:WaitForChild("RightLowerLeg")
		
		self:_load_attributes()
		self:_create_billboard()
		self:_start_listeners()
		
		resolve()
	end)):catch(warn):expect()
end

function Character:_load_attributes()
	AttributeUtility.waitFor(self._player_controller._instance, "health")
	
	self._health = self._trove:Add(TrackerUtility.fromAttributeSignal(self._player_controller._instance, "health"))
end

function Character:_create_billboard()
	local newBillboardInstance = _L.Assets.UI.CharacterBillboard:Clone()
	
	local newProgressBar
	
	self._trove:Add(self._health:Bind(function(value)
		if not newProgressBar then
			newProgressBar = ProgressBar.new({instance = newBillboardInstance.Main.ProgressBar, format = function(n1, n2)
				return NumberUtility.short(math.floor(n1)).." / "..NumberUtility.short(math.floor(n2)).." HP"
			end, position = value})
			
			self._trove:Add(newProgressBar)
		else
			newProgressBar:Set(value)
		end
	end))
	
	self._trove:Add(function()
		newProgressBar:Destroy()
	end)
	
	self._trove:Add(Tracker.Subscribe({Eggs.is_opening, UI._current}, function()
		local isOpening = Eggs.is_opening:Get()
		local currentUi = UI._current:Get()
		newBillboardInstance.Enabled = not isOpening and currentUi == nil
	end))
	
	newBillboardInstance.Adornee = self._root
	newBillboardInstance.Parent = _L.PlayerGui
	
	self._trove:Add(newBillboardInstance)
	
	self._trove:Add(Tracker.Subscribe({self._data:Track({"stats", "Strength"}), self._data:Track({"stats", "Crops_Harvested"}), self._data:Track("crop_legacy")}, function(value)
		local currentStrength = self._data:Get({"stats", "Strength"})
		
		local emojiMapInfo = EmojiMapUtility.getInfo(currentStrength)
		-- rank from real crops harvested (+ the rank kept from before the crop counter migration)
		local rankInfo = RankUtility.getInfoFromData(self._data)
		
		newBillboardInstance.Main.Rank.Text = rankInfo.name.." "..emojiMapInfo[2]
		newBillboardInstance.Main.Strength.Text = NumberUtility.short(currentStrength).." Coins"
	end))
	
	-- Equipped title above the name
	local titleLabel = newBillboardInstance.Main:FindFirstChild("Title")
	if titleLabel then
		self._trove:Add(self._data:Bind("titles", function()
			local TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
			local info = TitleUtility.getEquipped(self._data)
			titleLabel.Visible = info ~= nil
			if info then
				titleLabel.Text = info.text
				titleLabel.TextColor3 = info.color or Color3.new(1, 1, 1)
			end
		end))
	end
	
	local protectionTrove = self._trove:Add(Trove.new())
	
	local newProtectionInstance
	
	self._trove:Add(self._data:Bind("boosts", function(value)
		local protectionData = value.Protection_Potion
		
		if protectionData then
			if protectionData and protectionData.time_left > 0 then
				if not newProtectionInstance then
					newProtectionInstance = _L.Assets.Models.Other.Protection:Clone()

					local originalSize = newProtectionInstance.Size

					newProtectionInstance.Size = Vector3.zero
					newProtectionInstance.Transparency = 1

					Spr.Target(newProtectionInstance, 1, 3, {
						Size = originalSize,
						Transparency = 0
					})

					newProtectionInstance.Parent = _L.Debris

					protectionTrove:Add(function()
						newProtectionInstance:Destroy()
						newProtectionInstance = nil
					end)

					protectionTrove:Add(Services.RunService.RenderStepped:Connect(function()
						newProtectionInstance.CFrame = self._root.CFrame
					end))
				end
			else
				protectionTrove:Clean()
			end
		end
	end))
	
	self._trove:Add(self._player_controller._flags:Bind({"protection"}, function(value)
		newBillboardInstance.Main.Shield.Visible = value ~= nil
	end))
end

function Character:_start_listeners()
	if self._player_controller._instance == _L.Player then
		self._trove:Add(task.spawn(function()
			AttributeUtility.waitFor(_L.Player, "visited_best_training_area")
			
			local a = {tracker = self._trove:Add(TrackerUtility.fromAttributeSignal(_L.Player, "visited_best_training_area")), trove = self._trove:Add(Trove.new())}
			
			self._trove:Add(a.tracker:Bind(function(value)
				a.trove:Clean()
				
				a.trove:Add(self._data:Bind({"stats", "Strength"}, function()
					local bestTrainingAreaInfo = TrainingAreaUtility.getBestInfo(self._data)

					if not value and bestTrainingAreaInfo then
						local bestTrainingAreaInstance = _L.Map.TrainingAreas:FindFirstChild(bestTrainingAreaInfo.id)

						if bestTrainingAreaInstance then
							Beam.Set({self._root, bestTrainingAreaInstance.Arrow})
							return
						end
					end
					
					Beam.Set()
				end))
			end))
		end))
		
		self._trove:Add(Network.Bindable.Fired("C_Character_LevelUp", function()
			local data = _G.Data
			
			if data and not data:Get({"settings", "Popups"}) then
				return
			end
			
			local newLevelUp = LevelUpPool:get()

			for i, v in pairs(newLevelUp.EmitPoint:GetChildren()) do
				v:Emit(v.Rate)
			end

			newLevelUp.Position = self._root.Position
			newLevelUp.Parent = _L.Debris

			task.delay(3, function()
				LevelUpPool:back(newLevelUp)
			end)
		end))
	end
	
	self._trove:Add(Network.Remote.Fired("C_Character_Rebirth", function(player)
		if player ~= self._player_controller._instance then
			return
		end
		
		local a = {}
		
		local newRebirth = _L.Assets.Models.Other.Rebirth:Clone()

		local bbbb = TableUtility.filter(newRebirth:GetDescendants(), function(a, b)
			return b:IsA("ParticleEmitter")
		end)
		
		local b = newRebirth.Torso["Body aura"]

		b.Torso.Part1 = self._root
		
		b.Parent = _L.Debris
		
		for i, v in pairs(newRebirth.Torso:GetChildren()) do
			if v:IsA("Attachment") then
				table.insert(a, v)
				v.Parent = self._root
			end
		end
		
		local dess = false
		
		local function des()
			if dess then
				return
			end
			
			dess = true
			
			for _, aaaaaa in pairs(a) do
				aaaaaa:Destroy()
			end

			newRebirth:Destroy()
			b:Destroy()
		end
		
		self._trove:Add(function()
			des()
		end)

		self._trove:Add(cancellableDelay(3, function()
			des()
		end))
	end))

end

function Character:get_height()
	local b1 = self._left_foot.Position - Vector3.new(0, self._left_foot.Size.Y / 2, 0)
	local b2 = self._head.Position + Vector3.new(0, self._head.Size.Y / 2, 0)
	return b2.Y - b1.Y
end

function Character:get_ratio()
	local b1 = self._left_foot.Position - Vector3.new(0, self._left_foot.Size.Y / 2, 0)
	local b2 = self._root.Position
	local height = self:get_height()
	return ((b2.Y - b1.Y) / height)
end

function Character:Destroy()
	self._trove:Destroy()
end

return Character