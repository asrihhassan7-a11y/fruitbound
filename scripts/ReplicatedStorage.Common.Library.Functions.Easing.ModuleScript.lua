local u2 = {}
function u2.QuadIn(p4)
	p4 = p4 / 1
	return 1 * math.pow(p4, 2) + 0
end
function u2.QuadOut(p5)
	p5 = p5 / 1
	return -1 * p5 * (p5 - 2) + 0
end
function u2.QuadInOut(p6)
	p6 = p6 / 1 * 2
	if p6 < 1 then
		return 0.5 * math.pow(p6, 2) + 0
	end
	return -0.5 * ((p6 - 1) * (p6 - 3) - 1) + 0
end
function u2.QuadOutIn(p7)
	if p7 < 0.5 then
		return u2.QuadOut(p7 * 2)
	end
	return u2.QuadIn(p7 * 2 - 1)
end
function u2.CubicIn(p8)
	p8 = p8 / 1
	return 1 * math.pow(p8, 3) + 0
end
function u2.CubicOut(p9)
	p9 = p9 / 1 - 1
	return 1 * (math.pow(p9, 3) + 1) + 0
end
function u2.CubicInOut(p10)
	p10 = p10 / 1 * 2
	if p10 < 1 then
		return 0.5 * p10 * p10 * p10 + 0
	end
	p10 = p10 - 2
	return 0.5 * (p10 * p10 * p10 + 2) + 0
end
function u2.CubicOutIn(p11)
	if p11 < 0.5 then
		return u2.CubicOut(p11 * 2)
	end
	return u2.CubicIn(p11 * 2 - 1)
end
function u2.QuartIn(p12)
	p12 = p12 / 1
	return 1 * math.pow(p12, 4) + 0
end
function u2.QuartOut(p13)
	p13 = p13 / 1 - 1
	return -1 * (math.pow(p13, 4) - 1) + 0
end
function u2.QuartInOut(p14)
	p14 = p14 / 1 * 2
	if p14 < 1 then
		return 0.5 * math.pow(p14, 4) + 0
	end
	p14 = p14 - 2
	return -0.5 * (math.pow(p14, 4) - 2) + 0
end
function u2.QuartOutIn(p15)
	if p15 < 0.5 then
		return u2.QuartOut(p15 * 2)
	end
	return u2.QuartIn(p15 * 2 - 1)
end
function u2.QuintIn(p16)
	p16 = p16 / 1
	return 1 * math.pow(p16, 5) + 0
end
function u2.QuintOut(p17)
	p17 = p17 / 1 - 1
	return 1 * (math.pow(p17, 5) + 1) + 0
end
function u2.QuintInOut(p18)
	p18 = p18 / 1 * 2
	if p18 < 1 then
		return 0.5 * math.pow(p18, 5) + 0
	end
	p18 = p18 - 2
	return 0.5 * (math.pow(p18, 5) + 2) + 0
end
function u2.QuintOutIn(p19)
	if p19 < 0.5 then
		return u2.QuintOut(p19 * 2)
	end
	return u2.QuintIn(p19 * 2 - 1)
end
function u2.SineIn(p20)
	return -1 * math.cos(p20 / 1 * (math.pi / 2)) + 1 + 0
end
function u2.SineOut(p21)
	return 1 * math.sin(p21 / 1 * (math.pi / 2)) + 0
end
function u2.SineInOut(p22)
	return -0.5 * (math.cos(math.pi * p22 / 1) - 1) + 0
end
function u2.SineOutIn(p23)
	if p23 < 0.5 then
		return u2.SineOut(p23 * 2)
	end
	return u2.SineIn(p23 * 2)
end
function u2.ExpoIn(p24)
	if p24 == 0 then
		return 0
	end
	return 1 * math.pow(2, 10 * (p24 / 1 - 1)) + 0 - 0.001
end
function u2.ExpoOut(p25)
	if p25 == 1 then
		return 1
	end
	return 1.001 * (-math.pow(2, -10 * p25 / 1) + 1) + 0
end
function u2.ExpoInOut(p26)
	if p26 == 0 then
		return 0
	end
	if p26 == 1 then
		return 1
	end
	p26 = p26 / 1 * 2
	if p26 < 1 then
		return 0.5 * math.pow(2, 10 * (p26 - 1)) + 0 - 0.0005
	end
	p26 = p26 - 1
	return 0.50025 * (-math.pow(2, -10 * p26) + 2) + 0
end
function u2.ExpoOutIn(p27)
	if p27 < 0.5 then
		return u2.ExpoOut(p27 * 2)
	end
	return u2.ExpoIn(p27 * 2 - 1)
end
function u2.CircIn(p28)
	p28 = p28 / 1
	return -1 * (math.sqrt(1 - math.pow(p28, 2)) - 1) + 0
end
function u2.CircOut(p29)
	p29 = p29 / 1 - 1
	return 1 * math.sqrt(1 - math.pow(p29, 2)) + 0
end
function u2.CircInOut(p30)
	p30 = p30 / 1 * 2
	if p30 < 1 then
		return -0.5 * (math.sqrt(1 - p30 * p30) - 1) + 0
	end
	p30 = p30 - 2
	return 0.5 * (math.sqrt(1 - p30 * p30) + 1) + 0
end
function u2.CircOutIn(p31)
	if p31 < 0.5 then
		return u2.CircOut(p31 * 2)
	end
	return u2.CircIn(p31 * 2 - 1)
end
function u2.ElasticIn(p32)
	if p32 == 0 then
		return 0
	end
	p32 = p32 / 1
	if p32 == 1 then
		return 1
	end
	local v1 = nil
	local v2 = nil
	if not v1 then
		v1 = 0.3
	end
	local v3
	if not v2 or v2 < math.abs(1) then
		v2 = 1
		v3 = v1 / 4
	else
		v3 = v1 / (2 * math.pi) * math.asin(1 / v2)
	end
	p32 = p32 - 1
	return -(v2 * math.pow(2, 10 * p32) * math.sin((p32 * 1 - v3) * (2 * math.pi) / v1)) + 0
end
function u2.ElasticOut(p33)
	if p33 == 0 then
		return 0
	end
	p33 = p33 / 1
	if p33 == 1 then
		return 1
	end
	local v4 = nil
	local v5 = nil
	if not v4 then
		v4 = 0.3
	end
	local v6
	if not v5 or v5 < math.abs(1) then
		v5 = 1
		v6 = v4 / 4
	else
		v6 = v4 / (2 * math.pi) * math.asin(1 / v5)
	end
	return v5 * math.pow(2, -10 * p33) * math.sin((p33 * 1 - v6) * (2 * math.pi) / v4) + 1 + 0
end
function u2.ElasticInOut(p34)
	if p34 == 0 then
		return 0
	end
	p34 = p34 / 1 * 2
	if p34 == 2 then
		return 1
	end
	local v7 = nil
	local v8 = nil
	if not v7 then
		v7 = 0.44999999999999996
	end
	if not v8 then
		v8 = 0
	end
	local v9
	if not v8 or v8 < math.abs(1) then
		v8 = 1
		v9 = v7 / 4
	else
		v9 = v7 / (2 * math.pi) * math.asin(1 / v8)
	end
	if p34 < 1 then
		p34 = p34 - 1
		return -0.5 * (v8 * math.pow(2, 10 * p34) * math.sin((p34 * 1 - v9) * (2 * math.pi) / v7)) + 0
	end
	p34 = p34 - 1
	return v8 * math.pow(2, -10 * p34) * math.sin((p34 * 1 - v9) * (2 * math.pi) / v7) * 0.5 + 1 + 0
end
function u2.ElasticOutIn(p35)
	if p35 < 0.5 then
		return u2.ElasticOut(p35 * 2)
	end
	return u2.ElasticIn(p35 * 2 - 1)
end
function u2.BackIn(p36)
	p36 = p36 / 1
	return 1 * p36 * p36 * (2.70158 * p36 - 1.70158) + 0
end
function u2.BackOut(p37)
	p37 = p37 / 1 - 1
	return 1 * (p37 * p37 * (2.70158 * p37 + 1.70158) + 1) + 0
end
function u2.BackInOut(p38)
	local v10 = nil
	v10 = 1.70158 * 1.525
	p38 = p38 / 1 * 2
	if p38 < 1 then
		return 0.5 * (p38 * p38 * ((v10 + 1) * p38 - v10)) + 0
	end
	p38 = p38 - 2
	return 0.5 * (p38 * p38 * ((v10 + 1) * p38 + v10) + 2) + 0
end
function u2.BackOutIn(p39)
	if p39 < 0.5 then
		return u2.BackOut(p39 * 2)
	end
	return u2.BackIn(p39 * 2 - 1)
end
function u2.BounceOut(p40)
	p40 = p40 / 1
	if p40 < 0.36363636363636365 then
		return 1 * (7.5625 * p40 * p40) + 0
	end
	if p40 < 0.7272727272727273 then
		p40 = p40 - 0.5454545454545454
		return 1 * (7.5625 * p40 * p40 + 0.75) + 0
	end
	if p40 < 0.9090909090909091 then
		p40 = p40 - 0.8181818181818182
		return 1 * (7.5625 * p40 * p40 + 0.9375) + 0
	end
	p40 = p40 - 0.9545454545454546
	return 1 * (7.5625 * p40 * p40 + 0.984375) + 0
end
function u2.BounceIn(p41)
	return 1 - u2.BounceOut(1 - p41) + 0
end
function u2.BounceInOut(p42)
	if p42 < 0.5 then
		return u2.BounceIn(p42 * 2) * 0.5 + 0
	end
	return u2.BounceOut(p42 * 2 - 1) * 0.5 + 0.5 + 0
end
function u2.BounceOutIn(p43)
	if p43 < 0.5 then
		return u2.BounceOut(p43 * 2)
	end
	return u2.BounceIn(p43 * 2 - 1)
end
return u2