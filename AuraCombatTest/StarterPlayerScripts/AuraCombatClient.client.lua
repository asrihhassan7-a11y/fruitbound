-- LocalScript "AuraCombatClient" -> StarterPlayer > StarterPlayerScripts
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(RS:WaitForChild("AuraConfig"))
local remote = RS:WaitForChild("AuraRemote")
local plr = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "AuraHUD"; gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")

local function corner(p, r) Instance.new("UICorner", p).CornerRadius = UDim.new(0, r or 8) end
local function text(parent, t, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.TextSize = size or 14
	l.Text = t
	l.Parent = parent
	return l
end

-- ===== Sélecteur d'aura (dans le lobby) =====
local picker = Instance.new("Frame")
picker.Size = UDim2.new(0, 230, 0, 0)
picker.AutomaticSize = Enum.AutomaticSize.Y
picker.Position = UDim2.new(0, 16, 0.5, -180)
picker.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
picker.BackgroundTransparency = 0.15
picker.Parent = gui
corner(picker, 10)
local pad = Instance.new("UIPadding", picker)
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
local list = Instance.new("UIListLayout", picker)
list.Padding = UDim.new(0, 6)
list.SortOrder = Enum.SortOrder.LayoutOrder
local title = text(picker, "CHOISIS TON AURA", 16)
title.Size = UDim2.new(1, 0, 0, 22)
local desc = text(picker, "", 12)
desc.Size = UDim2.new(1, 0, 0, 34)
desc.TextWrapped = true
desc.LayoutOrder = 100

for i, a in ipairs(Config.Auras) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = a.Color
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 14
	b.TextColor3 = Color3.fromRGB(20, 20, 20)
	b.Text = a.Name
	b.Parent = picker
	corner(b, 6)
	b.MouseEnter:Connect(function() desc.Text = a.Desc end)
	b.Activated:Connect(function() remote:FireServer("Equip", a.Name) end)
end

-- ===== Infos bas d'écran =====
local info = text(gui, "", 16)
info.Size = UDim2.new(0, 400, 0, 24)
info.Position = UDim2.new(0.5, -200, 1, -110)
local help = text(gui, "Clic : frapper  |  E : capacité", 13)
help.Size = UDim2.new(0, 400, 0, 20)
help.Position = UDim2.new(0.5, -200, 1, -88)
local cdBar = Instance.new("Frame")
cdBar.Size = UDim2.new(0, 200, 0, 6)
cdBar.Position = UDim2.new(0.5, -100, 1, -64)
cdBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
cdBar.Parent = gui
corner(cdBar, 3)

local function refresh()
	local inArena = plr:GetAttribute("InArena")
	picker.Visible = not inArena
	info.Text = ("Aura : %s%s"):format(plr:GetAttribute("Aura") or "?", inArena and "" or "  —  entre dans le portail violet !")
end
plr:GetAttributeChangedSignal("Aura"):Connect(refresh)
plr:GetAttributeChangedSignal("InArena"):Connect(refresh)
refresh()

-- Kill feed
local feed = Instance.new("Frame")
feed.Size = UDim2.new(0, 320, 0, 120)
feed.Position = UDim2.new(1, -336, 0, 60)
feed.BackgroundTransparency = 1
feed.Parent = gui
local fl = Instance.new("UIListLayout", feed)
fl.HorizontalAlignment = Enum.HorizontalAlignment.Right

-- ===== Contrôles =====
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		remote:FireServer("Hit")
	elseif input.KeyCode == Enum.KeyCode.E then
		remote:FireServer("Ability")
	end
end)

-- ===== Effets =====
local function burst(pos, color, size)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.3), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.35)
end

remote.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Swing" then
		local r = a and a:FindFirstChild("HumanoidRootPart")
		if r then burst((r.CFrame * CFrame.new(0, 0, -3)).Position, b, 4) end
	elseif kind == "Impact" then
		burst(a, b, 9)
	elseif kind == "AbilityCd" then
		cdBar.Size = UDim2.new(0, 0, 0, 6)
		TweenService:Create(cdBar, TweenInfo.new(a, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 200, 0, 6) }):Play()
	elseif kind == "Feed" then
		local l = text(feed, ("%s a éjecté %s"):format(a, b), 14)
		l.Size = UDim2.new(1, 0, 0, 22)
		l.TextXAlignment = Enum.TextXAlignment.Right
		Debris:AddItem(l, 5)
	end
end)
