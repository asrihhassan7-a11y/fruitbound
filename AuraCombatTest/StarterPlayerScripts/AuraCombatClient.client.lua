-- LocalScript "AuraCombatClient" -> StarterPlayer > StarterPlayerScripts
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(RS:WaitForChild("AuraConfig"))
local remote = RS:WaitForChild("AuraRemote")
local plr = Players.LocalPlayer
local mouse = plr:GetMouse()

-- HUD : barre d'aura + palier
local gui = Instance.new("ScreenGui")
gui.Name = "AuraHUD"; gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")
local back = Instance.new("Frame")
back.Size = UDim2.new(0, 300, 0, 18)
back.Position = UDim2.new(0.5, -150, 1, -90)
back.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
back.Parent = gui
Instance.new("UICorner", back).CornerRadius = UDim.new(0, 9)
local fill = Instance.new("Frame")
fill.Size = UDim2.new(0, 0, 1, 0)
fill.Parent = back
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 9)
local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 20)
label.Position = UDim2.new(0, 0, 0, -22)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextSize = 14
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0.5
label.Parent = back
local help = label:Clone()
help.Position = UDim2.new(0, 0, 1, 4)
help.TextSize = 12
help.Text = "Clic: Coup | C (maintenir): Charger | Q: Blast (30) | E: Burst (70)"
help.Parent = back

local function refresh()
	local aura = plr:GetAttribute("Aura") or 0
	local tier = Config.Tiers[1]
	for _, t in ipairs(Config.Tiers) do if aura >= t.Min then tier = t end end
	fill.Size = UDim2.new(aura / Config.MaxAura, 0, 1, 0)
	fill.BackgroundColor3 = tier.Color
	label.Text = ("AURA %d — %s (x%.2f)"):format(aura, tier.Name, tier.Mult)
end
plr:GetAttributeChangedSignal("Aura"):Connect(refresh)
refresh()

-- Contrôles
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		remote:FireServer("Punch")
	elseif input.KeyCode == Enum.KeyCode.C then
		remote:FireServer("Charge", true)
	elseif input.KeyCode == Enum.KeyCode.Q then
		remote:FireServer("Blast", mouse.Hit.Position)
	elseif input.KeyCode == Enum.KeyCode.E then
		remote:FireServer("Burst")
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.C then remote:FireServer("Charge", false) end
end)

-- Effets
remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Hit" and a and a:FindFirstChild("Head") then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 80, 0, 30)
		bb.StudsOffset = Vector3.new(math.random(-2, 2), 2, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = a.Head
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = tostring(math.floor(b))
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 230, 80)
		t.TextStrokeTransparency = 0
		t.Parent = bb
		bb.Parent = gui
		TweenService:Create(bb, TweenInfo.new(0.7), { StudsOffset = bb.StudsOffset + Vector3.new(0, 3, 0) }):Play()
		TweenService:Create(t, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(bb, 0.8)
	elseif kind == "BurstFx" then
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Ball
		ring.Anchored, ring.CanCollide, ring.CastShadow = true, false, false
		ring.Material = Enum.Material.ForceField
		ring.Color = b
		ring.Size = Vector3.one * 2
		ring.Position = a
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = Vector3.one * c * 2, Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.5)
	end
end)
