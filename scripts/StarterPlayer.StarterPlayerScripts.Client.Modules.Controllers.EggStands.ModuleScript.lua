--> EggStands (client)
-- Makes the hatching stands feel alive: the big fruit hanging on each fruit tree
-- sways softly like it's swinging on its branch. Only visual, only on your screen.

local _L = _G._L

local RunService = game:GetService("RunService")

local BOB_HEIGHT = 0.25
local BOB_SPEED = 1.6
local SWAY = math.rad(7)
local MAX_DISTANCE = 500 -- do not animate eggs far away

local EggStands = {}

function EggStands._start()
	task.spawn(function()
		local folder = _L.Map:WaitForChild("Eggs", 30)
		if not folder then
			return
		end
		local eggs = {}
		local function add(stand)
			local egg = stand:WaitForChild("Egg", 10)
			if egg and egg:IsA("Model") and egg.PrimaryPart then
				eggs[egg] = {base = egg:GetPivot(), phase = #folder:GetChildren() * 0.7 + math.random() * 3}
			end
		end
		for _, stand in ipairs(folder:GetChildren()) do
			task.spawn(add, stand)
		end
		folder.ChildAdded:Connect(add)

		RunService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera
			local t = os.clock()
			for egg, info in pairs(eggs) do
				if not egg.Parent then
					eggs[egg] = nil
				elseif (camera.CFrame.Position - info.base.Position).Magnitude < MAX_DISTANCE then
					local bob = math.sin(t * BOB_SPEED + info.phase) * BOB_HEIGHT
					local sway = math.sin(t * BOB_SPEED * 0.6 + info.phase) * SWAY
					local twist = math.sin(t * 0.7 + info.phase) * math.rad(12)
					egg:PivotTo(info.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, twist, sway))
				end
			end
		end)
	end)
end

return EggStands
