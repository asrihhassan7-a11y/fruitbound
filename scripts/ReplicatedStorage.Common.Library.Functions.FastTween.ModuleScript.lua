return function(p1, p2, p3, p4)
	if type(p1) ~= "table" then
		p1 = { p1 }
	end
	local v1 = {}
	for v2, v3 in ipairs(p1) do
		if p3 == nil then
			p3 = { 1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out }
		else
			if p3[2] == nil then
				p3[2] = Enum.EasingStyle.Sine
			elseif type(p3[2]) == "string" then
				if string.lower(p3[2]) == "expo" then
					p3[2] = Enum.EasingStyle.Exponential
				else
					p3[2] = Enum.EasingStyle[p3[2]]
				end
			end
			if p3[3] == nil then
				p3[3] = Enum.EasingDirection.InOut
			elseif type(p3[3]) == "string" then
				p3[3] = Enum.EasingDirection[p3[3]]
			end
		end
		local u2 = game.TweenService:Create(v3, TweenInfo.new(unpack(p3)), p2)
		coroutine.wrap(function()
			if p4 then
				wait(p4)
			end
			u2:Play()
		end)()
		table.insert(v1, u2)
	end
	return unpack(v1)
end