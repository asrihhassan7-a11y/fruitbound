-- Tiny UI kit: theme, constructors, juicy buttons, panels.
local TweenService = game:GetService("TweenService")
local Audio = require(script.Parent.Parent.Controllers.Audio)

local Lib = {}

Lib.Theme = {
	-- "brick toy" style: bright flat colors, thick black outlines, chunky 3D lips, studs
	Font = Enum.Font.FredokaOne,
	Title = Enum.Font.LuckiestGuy,
	Panel = Color3.fromRGB(255, 205, 40),
	PanelDark = Color3.fromRGB(60, 60, 72),
	Card = Color3.fromRGB(150, 152, 165),
	Stroke = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(240, 240, 245),
	Green = Color3.fromRGB(84, 214, 92),
	Yellow = Color3.fromRGB(255, 196, 42),
	Blue = Color3.fromRGB(64, 160, 255),
	Red = Color3.fromRGB(255, 84, 96),
	Pink = Color3.fromRGB(255, 102, 196),
	Orange = Color3.fromRGB(255, 140, 40),
	Purple = Color3.fromRGB(160, 92, 255),
	Grey = Color3.fromRGB(120, 115, 140),
}
local T = Lib.Theme

function Lib.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Lib.corner(parent: Instance, r: number?)
	-- blocky look: cap radii (keep true circles for round buttons)
	r = r or 8
	if r < 20 then
		r = math.min(r, 8)
	end
	return Lib.new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

function Lib.stroke(parent: Instance, color: Color3?, thick: number?)
	return Lib.new("UIStroke", { Color = color or T.Stroke, Thickness = thick or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function Lib.gradient(parent: Instance, c: Color3)
	local h, s, v = c:ToHSV()
	return Lib.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromHSV(h, s * 0.9, math.min(1, v * 1.08)), Color3.fromHSV(h, s, v * 0.92)),
		Rotation = 90,
		Parent = parent,
	})
end

function Lib.text(props: { [string]: any }): TextLabel
	local l = Lib.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	})
	for k, v in props do
		if k ~= "Parent" and k ~= "Stroke" and k ~= "StrokeThickness" then
			(l :: any)[k] = v
		end
	end
	if props.Stroke ~= false then
		Lib.new("UIStroke", { Color = T.Stroke, Thickness = props.StrokeThickness or 2, Parent = l })
	end
	l.Parent = props.Parent
	return l
end

function Lib.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Juicy button. opts: { Text, Color, Size, Position, AnchorPoint, Parent, OnClick, TextSize?, Name? }
function Lib.button(opts): TextButton
	local b = Lib.new("TextButton", {
		Name = opts.Name or "Button",
		Size = opts.Size or UDim2.fromOffset(120, 44),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = opts.LayoutOrder or 0,
	})
	Lib.corner(b, opts.Radius or 8)
	Lib.stroke(b, T.Stroke, 3)
	Lib.gradient(b, opts.Color or T.Green)
	-- darker bottom lip = chunky brick look
	local lip = Lib.new("Frame", { Name = "Lip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, math.clamp(math.floor((opts.Size and opts.Size.Y.Offset or 44) * 0.14), 4, 10)), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.72, BorderSizePixel = 0, Parent = b })
	Lib.corner(lip, opts.Radius or 8)
	local label = Lib.text({ Name = "Label", Text = opts.Text or "", Font = T.Title, StrokeThickness = 2.5, Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 3), Parent = b })
	local scale = Lib.new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function()
		Lib.tween(scale, 0.12, { Scale = 1.06 })
	end)
	b.MouseLeave:Connect(function()
		Lib.tween(scale, 0.12, { Scale = 1 })
	end)
	b.MouseButton1Down:Connect(function()
		Lib.tween(scale, 0.08, { Scale = 0.92 })
	end)
	b.MouseButton1Up:Connect(function()
		Lib.tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	b.Activated:Connect(function()
		Audio.play("Click")
		if opts.OnClick then
			opts.OnClick(b)
		end
	end)
	b.Parent = opts.Parent
	return b
end

function Lib.setButton(btn: TextButton, text: string?, color: Color3?)
	local l = btn:FindFirstChild("Label") :: TextLabel?
	if l and text then
		l.Text = text
	end
	local g = btn:FindFirstChildOfClass("UIGradient")
	if g and color then
		g:Destroy()
		Lib.gradient(btn, color)
	end
end

-- Rounded card frame
function Lib.card(props: { [string]: any }): Frame
	local f = Lib.new("Frame", { BackgroundColor3 = props.Color or T.Card, Size = props.Size or UDim2.fromOffset(140, 160), LayoutOrder = props.LayoutOrder or 0, Name = props.Name or "Card" })
	Lib.corner(f, 8)
	Lib.stroke(f, props.StrokeColor, props.StrokeThickness or 3)
	f.Parent = props.Parent
	return f
end

function Lib.bar(parent: Instance, pos: UDim2, size: UDim2, color: Color3): (Frame, Frame)
	local bg = Lib.new("Frame", { Position = pos, Size = size, BackgroundColor3 = T.PanelDark, Parent = parent })
	Lib.corner(bg, 8)
	Lib.stroke(bg, nil, 2)
	local fill = Lib.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = bg })
	Lib.corner(fill, 8)
	Lib.gradient(fill, color)
	return bg, fill
end

-- Row of toy-brick studs across a strip (decoration)
function Lib.studs(parent: GuiObject, color: Color3, count: number, size: number?)
	local holder = Lib.new("Frame", { Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = parent.ZIndex, Parent = parent })
	Lib.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, (size or 14) * 0.8), Parent = holder })
	local h, s, v = color:ToHSV()
	for _ = 1, count do
		local st = Lib.new("Frame", { Size = UDim2.fromOffset(size or 14, size or 14), BackgroundColor3 = Color3.fromHSV(h, s * 0.7, math.min(1, v * 1.15)), Parent = holder })
		Lib.corner(st, 100)
		Lib.new("UIStroke", { Color = Color3.fromHSV(h, s, v * 0.6), Thickness = 2, Parent = st })
	end
	return holder
end

function Lib.clear(container: Instance)
	for _, c in container:GetChildren() do
		if not c:IsA("UIGridStyleLayout") and not c:IsA("UIPadding") and not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

return Lib
