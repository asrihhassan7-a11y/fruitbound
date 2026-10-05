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
local Purchases
local Icon
local _Settings
local Notifications

--> Constants

------------->
local Upgrades = {
	name = script.Name
}

function Upgrades:_init()
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
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
	Icon = _L.Get {"Client", "Modules", "Icon"}
	_Settings = _L.Get {"Common", "Modules", "Databases", "Settings"}
	UpgradeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeUtility"}

	self.is_open = Tracker.new(false)
end

function Upgrades:_start()
	Notifications = UI.Get("Notifications")

	self.object = _L.PlayerGui.Upgrades
	local function applyLayout()
		local viewport = workspace.CurrentCamera.ViewportSize
		self.object.Main.Size = UDim2.fromOffset(math.min(660, viewport.X - 32), math.min(560, viewport.Y - 24))
	end
	applyLayout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	
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
		for _, upgradeInstance in pairs(self.object.Main.Content.Background.List.Main:GetChildren()) do
			if upgradeInstance:IsA("Frame") then
				local upgradeId = upgradeInstance.Name
				local upgradeInfo = UpgradeUtility.getInfo(upgradeId)
				
				upgradeInstance.Main.GemsBtn.MouseButton1Down:Connect(function()
					if (data:Get({"upgrades", upgradeId}) or 1) >= upgradeInfo.max_stages then
						return
					end
					local success, err = Network.Remote.Invoke("S_Upgrade_Request", upgradeId)
					
					if success then
						Audio.Play({name = "Success2"})
					elseif err == "afford" then
						local upgradeCost = UpgradeUtility.getCost(upgradeId, data:Get({"upgrades", upgradeId}))
						
						Notifications:add({
							text = "❌ You need "..NumberUtility.short(upgradeCost - data:Get({"stats", "Gems"})).." more Gems to upgrade!",
							color = Color3.fromRGB(255, 0, 0),
							audio = {name = "Fail1"}
						})
					end
				end)
				
				self._instances[upgradeId] = {
					info = upgradeInfo,
					id = upgradeId,
					instance = upgradeInstance,
					stages = {}
				}
			end
		end
		
		data:Bind("upgrades", function(value)
			for upgradeId, upgradeStageValue in pairs(value) do
				local upgrade = self._instances[upgradeId]
				if not upgrade then
					continue
				end
				local maxed = upgradeStageValue >= upgrade.info.max_stages
				upgrade.instance.Main.Level.Text = "Level " .. upgradeStageValue .. " / " .. upgrade.info.max_stages
				local function valueAt(level)
					return if upgradeId == "1" then "+" .. level * 2 .. " speed" elseif upgradeId == "3" then "+" .. level .. " pet slots" else "x" .. level .. (if upgradeId == "2" then " Rebirth Gems" else " Harvest Coins")
				end
				upgrade.instance.Main.BeforeTxt.Text = "Now: " .. valueAt(upgradeStageValue)
				upgrade.instance.Main.AfterTxt.Text = if maxed then "Maximum level" else "Next: " .. valueAt(upgradeStageValue + 1)
				upgrade.instance.Main.GemsBtn.Active = not maxed
				upgrade.instance.Main.GemsBtn.AutoButtonColor = not maxed
				
				for i, upgradeStage in pairs(upgrade.stages) do
					if i > upgradeStageValue then
						upgradeStage.trove:Destroy()
						
						local ii, vv = TableUtility.match(upgrade.stages, function(iii, vvv)
							return upgradeStage == vvv
						end)
						
						if ii then
							table.remove(upgrade.stages, ii)
						end
					end
				end
				
				for i = 1, upgradeStageValue do
					if #upgrade.stages < i and not upgrade.stages[i] then
						local newTrove = Trove.new()
						local upgradeStageInstance = newTrove:Add(_L.Assets.UI.Upgrades.Fillers:FindFirstChild(upgrade.info.color):Clone())
						
						upgradeStageInstance.Size = UDim2.fromScale(1/upgrade.info.max_stages, 1)
						upgradeStageInstance.Parent = upgrade.instance.Progress
						
						table.insert(upgrade.stages, {
							instance = upgradeStageInstance,
							trove = newTrove
						})
					end
				end
				
				if upgradeStageValue == upgrade.info.max_stages then
					upgrade.instance.Main.GemsBtn.ImageLabel.Visible = false
					upgrade.instance.Main.GemsBtn.Number.Position = UDim2.fromScale(0.5, 0.542)
					upgrade.instance.Main.GemsBtn.Number.Text = "MAXED"
				else
					upgrade.instance.Main.GemsBtn.ImageLabel.Visible = true
					upgrade.instance.Main.GemsBtn.Number.Position = UDim2.fromScale(0.63, 0.542)
					upgrade.instance.Main.GemsBtn.Number.Text = NumberUtility.short(UpgradeUtility.getCost(upgradeId, upgradeStageValue))
				end
			end
		end)
	end
end

function Upgrades:Open()
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

function Upgrades:Close()
	
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
	
end

return Upgrades