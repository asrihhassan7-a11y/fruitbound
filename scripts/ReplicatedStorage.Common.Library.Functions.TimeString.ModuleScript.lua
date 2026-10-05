return function(p1, p2)
	local v1 = nil;
	local v2 = nil;
	local v3 = nil;
	local v4 = nil;
	v1 = math.round(p1 / 60 / 60 / 24 - 0.5);
	v2 = math.round(p1 / 60 / 60 % 24 - 0.5);
	v3 = math.round(p1 / 60 % 60 - 0.5);
	v4 = math.round(p1 % 60);
	if p2 then
		if v1 >= 1 then
			return v1 .. "d";
		elseif v2 >= 1 then
			return v2 .. "hr";
		elseif v3 >= 1 then
			return v3 .. "m";
		else
			return v4 .. "s";
		end;
	end;
	if v1 >= 1 then
		local v5 = ' Day'
		if v1 > 1 then
			v5 = " Days";
		else
			v5 = " Day";
		end;
		return v1 .. v5;
	end;
	if v2 >= 1 then
		local v6
		if v2 > 1 then
			v6 = " Hours";
		else
			v6 = " Hour";
		end;
		return v2 .. v6;
	end;
	if v3 >= 1 then
		local v7
		if v3 > 1 then
			v7 = " Minutes";
		else
			v7 = " Minute";
		end;
		return v3 .. v7;
	end;
	local v8
	if v4 > 1 then
		v8 = " Seconds";
	else
		v8 = " Second";
	end;
	return v4 .. v8;
end;
