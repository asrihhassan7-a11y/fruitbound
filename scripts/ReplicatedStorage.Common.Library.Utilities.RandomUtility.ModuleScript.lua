--> Variables
local _L = _G._L

--> Constants

---------->
local RandomUtility

RandomUtility = {
	chance = function(d)
		local tv, ti, c = 0, 0, {}

		for k, v in pairs(d) do
			tv, ti = tv + v, ti + 1
			c[ti] = {k, v}
		end

		for i, v in pairs(c) do
			local tz = 0

			for j = 1, i do
				tz += c[j][2]
			end

			c[i][3] = tz
		end

		local rn = Random.new():NextNumber(0, tv)

		for i, v in pairs(c) do
			if rn <= v[3] and (if (i-1) == 0 then 0 else c[i-1][3]) < rn then
				return v[1]
			end
		end
	end,
}

return RandomUtility