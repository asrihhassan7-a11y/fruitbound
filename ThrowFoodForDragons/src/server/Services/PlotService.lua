-- Assigns each player a farm plot, keeps them on it, and answers "is this point on their farm?".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Zones = require(Shared.Config.Zones)
local WorldBuilder = require(script.Parent.WorldBuilder)

local PlotService = {}
local owners: { [number]: Player } = {}
local plotOf: { [Player]: number } = {}

-- Farm pen area (relative to plot centre): behind the deck fence.
PlotService.FARM_MIN = Vector2.new(-Zones.PLOT_W / 2 + 4, -Zones.PLOT_D / 2 + 4) -- x, z offsets
PlotService.FARM_MAX = Vector2.new(Zones.PLOT_W / 2 - 4, Zones.PLOT_D / 2 - 16)

function PlotService.get(player: Player): number?
	return plotOf[player]
end

function PlotService.spawnCFrame(player: Player): CFrame
	return Zones.plotSpawn(plotOf[player] or 1)
end

-- Offsets (x, z) relative to the plot centre are what we store, so plots can change between sessions.
function PlotService.validFarmOffset(x: number, z: number): boolean
	return x >= PlotService.FARM_MIN.X and x <= PlotService.FARM_MAX.X and z >= PlotService.FARM_MIN.Y and z <= PlotService.FARM_MAX.Y
end

function PlotService.isOnPlot(player: Player, pos: Vector3): boolean
	local i = plotOf[player]
	if not i then
		return false
	end
	local c = Zones.plotCenter(i)
	return math.abs(pos.X - c.X) <= Zones.PLOT_W / 2 + 4 and math.abs(pos.Z - c.Z) <= Zones.PLOT_D / 2 + 4
end

local function setSign(i: number, text: string)
	local f = WorldBuilder.plotFolder(i)
	local sign = f and f:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChild("Owner") and sign.Owner:FindFirstChild("Text")
	if label then
		label.Text = text
	end
end

local function assign(player: Player)
	for i = 1, Zones.PLOTS do
		if not owners[i] then
			owners[i] = player
			plotOf[player] = i
			player:SetAttribute("Plot", i)
			setSign(i, player.DisplayName .. "'s Farm")
			return i
		end
	end
	return nil
end

function PlotService.start()
	local function added(player: Player)
		if not assign(player) then
			player:Kick("This server is full, please join another one.")
			return
		end
		local function onChar(char: Model)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if root then
				task.wait()
				char:PivotTo(PlotService.spawnCFrame(player))
			end
		end
		player.CharacterAdded:Connect(onChar)
		if player.Character then
			task.spawn(onChar, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		task.spawn(added, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local i = plotOf[player]
		if i then
			owners[i] = nil
			setSign(i, "Empty Farm")
		end
		plotOf[player] = nil
	end)
end

return PlotService
