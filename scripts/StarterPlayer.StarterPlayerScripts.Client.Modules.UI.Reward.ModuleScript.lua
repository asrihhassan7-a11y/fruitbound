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
local PlayerRewardUtility
local Promise
local Eggs
local Module3D

--> Constants

------------->
local Reward = {
	name = script.Name
}

function Reward:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Network = _L.Get {"Common", "Library", "Network"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
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
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function Reward:_start()
	Eggs = UI.Get("Eggs")
	Module3D = _L.Get {"Common", "Library", "Classes", "Module3D"}
	
	self.object = _L.PlayerGui.Reward
	self.object.DisplayOrder = 5
	self._trove = Trove.new()
	
	self.is_open:Bind(function(value, props)
		if value and props then
			self:Open(props)
		else
			self:Close()
		end
	end)
	
	self.object.Main.MouseButton1Down:Connect(function()
		local lastUIName = UI.GetLast()
		
		if lastUIName and lastUIName ~= "Eggs" and lastUIName ~= "Confirm" and lastUIName ~= "Trade" then
			UI.Open({name = lastUIName})
		else
			UI.Close({name = self.name})
		end
	end)
	
	Network.Remote.Fired("C_Reward_Open", function(data)
		UI.Open({name = self.name, props = {
			data = data
		}})
	end)
end

function Reward:_reset()
	self._trove:Clean()
	
	Spr.Stop(self.object.Main)
	Spr.Stop(self.object.Main.Middle.YouReceived.UIScale)
	Spr.Stop(self.object.Main.Middle.ContinueTxt.UIScale)
	Spr.Stop(self.object.Main.Middle.Sunburst.UIScale)
	
	self.object.Main.BackgroundTransparency = 1
	self.object.Main.Middle.YouReceived.UIScale.Scale = 0
	self.object.Main.Middle.ContinueTxt.UIScale.Scale = 0
	self.object.Main.Middle.Sunburst.UIScale.Scale = 0
	
	self.object.Main.Visible = false
end

function Reward:Open(props)
	self:_reset()

	local data = props.data

	self.object.Main.Visible = true
	
	Spr.Target(self.object.Main, 1, 4, {
		BackgroundTransparency = 0.2
	})
	
	self._trove:Add(Services.RunService.Heartbeat:Connect(function()
		self.object.Main.Middle.Sunburst.Rotation += 0.2
	end))
	
	self._trove:Add(cancellableDelay(0.2, function()
		Spr.Target(self.object.Main.Middle.YouReceived.UIScale, 1, 4, {
			Scale = 1
		})
		
		Spr.Target(self.object.Main.Middle.ContinueTxt.UIScale, 1, 4, {
			Scale = 1
		})
		
		Spr.Target(self.object.Main.Middle.Sunburst.UIScale, 1, 4, {
			Scale = 1
		})
		
		Audio.Play({name = "Reward1"})
		
		for i, v in pairs(data) do
			self._trove:Add(cancellableDelay(0.1 * i, function()
				local newReward = _L.Assets.UI.Reward.Reward:Clone()
				
				self._trove:Add(newReward)
				
				local playerRewardInfo = PlayerRewardUtility.getInfo(v.reward_name).getInfo(v.name)
				
				newReward.ImageLabel.Quantity.Text = (if v.reward_name ~= "Stat" and v.value then ("x"..NumberUtility.short(v.value).." ") else "")
				newReward.ImageLabel.TextLabel.Text = (if v.reward_name == "Stat" and v.value then ("+"..NumberUtility.short(v.value).." ") else "")..(playerRewardInfo.display_name or playerRewardInfo.name)
				newReward.ImageLabel.ImageLabel.Image = playerRewardInfo.image or playerRewardInfo.icon or ""
				if (v.reward_name == "Fruit" or v.reward_name == "Seed" or v.reward_name == "SeedPack") and newReward.ImageLabel.ImageLabel.Image == "" then
					-- no icon: show the 3D model (Fruit, or the Seed / Seed Pack visual)
					local folder = if v.reward_name == "Fruit" then _L.Assets.Models.Fruits else _L.Assets.Models:FindFirstChild("Seeds")
					local modelName = if v.reward_name == "Fruit" then (playerRewardInfo.model or playerRewardInfo.name) else (playerRewardInfo.visual or playerRewardInfo.name)
					local model = folder and folder:FindFirstChild(modelName)
					if model then
						local fruitModel = model:Clone()
						for _, part in ipairs(fruitModel:GetDescendants()) do
							if part:IsA("BasePart") then
								part.PivotOffset = CFrame.new()
							end
						end
						self._trove:Add(fruitModel)
						local preview = Module3D:Attach3D(newReward.ImageLabel.ImageLabel, fruitModel)
						preview.LightColor = Color3.new(1, 1, 1)
						preview.Ambient = Color3.new(1, 1, 1)
						fruitModel:PivotTo(fruitModel:GetPivot() * CFrame.Angles(0, math.pi, 0))
						preview.ZIndex = newReward.ImageLabel.ImageLabel.ZIndex
						preview:Update()
						preview.Visible = true
						self._trove:Add(preview)
					end
				end
				newReward.UIScale.Scale = 0.5
				
				Spr.Target(newReward.UIScale, 1, 4, {
					Scale = 1
				})

				newReward.Parent = self.object.Main.Middle.Rewards
				
				self._trove:Add(cancellableDelay(0.1, function()
					Spr.Target(newReward.ImageLabel.TextLabel.UIScale, 1, 4, {
						Scale = 1.
					})
					
					Spr.Target(newReward.ImageLabel.ImageLabel.UIScale, 1, 4, {
						Scale = 1
					})
				end))
				
				Audio.Play({name = "Plop1"})
			end))
		end
	end))
end

function Reward:Close()	
	self:_reset()
end

return Reward