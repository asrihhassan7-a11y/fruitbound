return function(p1)
	local u2 = false;
	local function u3(p2)
		if u2 then
			return;
		end;
		for v1, v2 in pairs(p2) do
			if u2 then
				return;
			end;
			if type(v2) == "userdata" then
				u2 = true;
				return;
			end;
			if type(v1) == "userdata" then
				u2 = true;
				return;
			end;
			if type(v2) == "table" then
				u3(v2);
			end;
		end;
	end;
	u3(p1);
	return false;
end;
