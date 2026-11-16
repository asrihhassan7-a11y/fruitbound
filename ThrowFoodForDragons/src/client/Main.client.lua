-- Throw Food for Dragons — client entry point.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Net = require(Shared.Net)
local Foods = require(Shared.Config.Foods)
local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local State = require(Controllers.State)
local Audio = require(Controllers.Audio)
local FX = require(Controllers.FX)
local DragonAnimator = require(Controllers.DragonAnimator)
local ThrowController = require(Controllers.ThrowController)
local CompanionController = require(Controllers.Companions)
local ZoneController = require(Controllers.ZoneController)
local HUD = require(UI.HUD)
local Panels = require(UI.Panels)

local player = Players.LocalPlayer

State.start()
Audio.start()
FX.start()
DragonAnimator.start()
ThrowController.start()
CompanionController.start()
ZoneController.start()
local gui = HUD.build(Panels)
Panels.start(gui)

-- settings side effects
State.Changed:Connect(function(d)
	Audio.applySettings(d.Settings)
	FX.lowGfx = d.Settings.LowGfx == true
	DragonAnimator.setLowGfx(FX.lowGfx)
	CompanionController.setLowGfx(FX.lowGfx)
end)

-- feeding feedback
local GOLD = Color3.fromRGB(255, 214, 60)
local CRIT = Color3.fromRGB(255, 90, 200)
Net.get("Fed").OnClientEvent:Connect(function(dragonId, userId, coins, crit, foodId)
	local head = DragonAnimator.headPosition(dragonId)
	if not head then
		return
	end
	local food = Foods.ById[foodId]
	FX.burst(head, food and food.color or GOLD, crit and 24 or 12)
	local mine = userId == player.UserId
	if mine then
		FX.floating(FX.fmtReward(coins, crit), head + Vector3.new(0, 2, 0), crit and CRIT or GOLD, crit)
		FX.coinFly(head, crit and 6 or 3)
		Audio.play("Eat", 0.9 + math.random() * 0.3)
		Audio.play("Coin", crit and 1.4 or 1.1)
	elseif State.data and State.data.Settings.ShowOthers ~= false then
		FX.floating("+" .. require(Shared.Util).fmt(coins), head + Vector3.new(0, 2, 0), Color3.new(1, 1, 1), false)
	end
end)

Net.get("Discover").OnClientEvent:Connect(function(defId)
	HUD.discover(defId)
end)

print("[TFFD] Client ready")
