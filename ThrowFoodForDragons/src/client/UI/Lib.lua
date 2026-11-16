-- Tiny UI kit: theme, constructors, juicy buttons, panels.
local TweenService = game:GetService("TweenService")
local Audio = require(script.Parent.Parent.Controllers.Audio)

local Lib = {}

Lib.Theme = {
	Font = Enum.Font.FredokaOne,
	Panel = Color3.fromRGB(52, 38, 92),
	PanelDark = Color3.fromRGB(34, 24, 62),
	Card = Color3.fromRGB(78, 60, 132),
	Stroke = Color3.fromRGB(22, 14, 40),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(205, 195, 235),
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
	return Lib.new("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = parent })
end

function Lib.stroke(parent: Instance, color: Color3?, thick: number?)
	return Lib.new("UIStroke", { Color = color or T.Stroke, Thickness = thick or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function Lib.gradient(parent: Instance, c: Color3)
	local h, s, v = c:ToHSV()
	return Lib.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromHSV(h, s * 0.85, math.min(1, v * 1.15)), Color3.fromHSV(h, math.min(1, s * 1.1), v * 0.82)),
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
		if k ~= "Parent" and k ~= "Stroke" then
			(l :: any)[k] = v
		end
	end
	if props.Stroke ~= false then
		Lib.new("UIStroke", { Color = T.Stroke, Thickness = 2, Parent = l })
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
	Lib.corner(b, opts.Radius or 12)
	Lib.stroke(b)
	Lib.gradient(b, opts.Color or T.Green)
	local label = Lib.text({ Name = "Label", Text = opts.Text or "", Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Parent = b })
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
	Lib.corner(f, 14)
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

function Lib.clear(container: Instance)
	for _, c in container:GetChildren() do
		if not c:IsA("UIGridStyleLayout") and not c:IsA("UIPadding") and not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

return Lib
