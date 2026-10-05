--> Variables
local _L = _G._L

--> Constants
local SUFFIXES = {"", "K", "M", "B", "T", "QD", "QN", "SX", "SP", "O", "N", "DE", "UD", "DD", "TDD",
	"QDD", "QND", "SXD", "SPD", "OCD", "NVD", "VGN", "UVG", "DVG", "TVG", "QTV",
	"QNV", "SEV", "SPG", "OVG", "NVG", "TGN", "UTG", "DTG", "TSTG", "QTTG", "QNTG",
	"SSTG", "SPTG", "OCTG", "NOTG", "QDDR", "UQDR", "DQDR", "TQDR", "QDQDR", "QNQDR",
	"SXQDR", "SPQDR", "OQDDR", "NQDDR", "QQGNT", "UQGNT", "DQGNT", "TQGNT", "QDQGNT",
	"QNQGNT", "SXQGNT", "SPQGNT", "OQQGNT", "NQQGNT", "SXGNTL", "USXGNTL", "DSXGNTL",
	"TSXGNTL", "QTSXGNTL", "QNSXGNTL", "SXSXGNTL", "SPSXGNTL", "OSXGNTL", "NVSXGNTL",
	"SPTGNTL", "USPTGNTL", "DSPTGNTL", "TSPTGNTL", "QTSPTGNTL", "QNSPTGNTL", "SXSPTGNTL",
	"SPSPTGNTL", "OSPTGNTL", "NVSPTGNTL", "OTGNTL", "UOTGNTL", "DOTGNTL", "TOTGNTL", "QTOTGNTL",
	"QNOTGNTL", "SXOTGNTL", "SPOTGNTL", "OTOTGNTL", "NVOTGNTL", "NONGNTL", "UNONGNTL", "DNONGNTL",
	"TNONGNTL", "QTNONGNTL", "QNNONGNTL", "SXNONGNTL", "SPNONGNTL", "OTNONGNTL", "NONONGNTL", "CENT", "UNCENT"
}

local ROMAN_MAP = { 
	I = 1,
	V = 5,
	X = 10,
	L = 50,
	C = 100, 
	D = 500, 
	M = 1000,
}
local ROMAN_NUMBERS = { 1, 5, 10, 50, 100, 500, 1000 }
local ROMAN_CHARS = { "I", "V", "X", "L", "C", "D", "M" }

---------->
local NumberUtility

NumberUtility = {
	decimal = function(x, z)
		local whole = math.floor(x)
		local decimal = x - whole

		local formatString = "%.1f"

		if z and z > 0 then
			formatString = "%." .. z .. "f"
		end

		if decimal == 0 then
			return string.format(formatString, x)
		else
			return string.format(formatString, whole + decimal)
		end
	end,
	
	short = function(x)
		if x == nil or x ~= x then
			return "0"
		end
		
		if x == math.huge then
			return "inf"
		end
		
		if x == -math.huge then
			return "-inf"
		end
		
		if x < 0 then
			return "-" .. NumberUtility.short(-x)
		end
		
		for i=1, #SUFFIXES do
			if tonumber(x) < 10^(i*3) then
				return math.floor(x/((10^((i-1)*3))/100))/(100)..SUFFIXES[i]
			end
		end
		
		-- Fallback for values beyond every suffix: never return nil or scientific notation
		return NumberUtility.commas(math.floor(x))
	end,
	
	timer = {
		colon = {
			auto = function(n)
				if n >= 86400 then
					return NumberUtility.timer.colon.days(n)
				elseif n >= 3600 then
					return NumberUtility.timer.colon.hours(n)
				elseif n >= 60 then
					return NumberUtility.timer.colon.minutes(n)
				else
					return NumberUtility.timer.colon.seconds(n)
				end
			end,

			seconds = function(n)
				return string.format("%02i", n)
			end,

			minutes = function(n)
				return string.format("%02i:%02i", n/60, n%60)
			end,

			hours = function(n)
				return string.format("%02i:%02i:%02i", n/60^2, n/60%60, n%60)
			end,

			days = function(n)
				return string.format("%02i:%02i:%02i:%02i", n/86400, n/60^2%24, n/60%60, n%60)
			end,
		},

		short = {
			auto = function(n)
				if n >= 86400 then
					return NumberUtility.timer.short.days(n)
				elseif n >= 3600 then
					return NumberUtility.timer.short.hours(n)
				elseif n >= 60 then
					return NumberUtility.timer.short.minutes(n)
				else
					return NumberUtility.timer.short.seconds(n)
				end
			end,

			seconds = function(n)
				return string.format("%is", n)
			end,

			minutes = function(n)
				return string.format("%im %is", n/60, n%60)
			end,

			hours = function(n)
				return string.format("%ih %im %is", n/60^2, n/60%60, n%60)
			end,

			days = function(n)
				return string.format("%id %ih %im %is", n/86400, n/60^2%24, n/60%60, n%60)
			end,
		},

		long = {
			auto = function(n)
				if n >= 86400 then
					return NumberUtility.timer.long.days(n)
				elseif n >= 3600 then
					return NumberUtility.timer.long.hours(n)
				elseif n >= 60 then
					return NumberUtility.timer.long.minutes(n)
				else
					return NumberUtility.timer.long.seconds(n)
				end
			end,

			seconds = function(n)
				return string.format("%i seconds", n)
			end,

			minutes = function(n)
				return string.format("%i minutes %i seconds", n/60, n%60)
			end,

			hours = function(n)
				return string.format("%i hours %i minutes %i seconds", n/60^2, n/60%60, n%60)
			end,

			days = function(n)
				return string.format("%i days %i hours %i minutes %i seconds", n/86400, n/60^2%24, n/60%60, n%60)
			end,
		}
	},
	
	commas = function(n)
		n = tostring(n)
		return n:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
	end,
	
	roman = {
		to = function(s)
			--s = tostring(s)
			s = tonumber(s)
			if not s or s ~= s then error"Unable to convert to number" end
			if s == math.huge then error"Unable to convert infinity" end
			s = math.floor(s)
			if s <= 0 then return s end
			local ret = ""
			for i = #ROMAN_NUMBERS, 1, -1 do
				local num = ROMAN_NUMBERS[i]
				while s - num >= 0 and s > 0 do
					ret = ret .. ROMAN_CHARS[i]
					s = s - num
				end
				--for j = i - 1, 1, -1 do
				for j = 1, i - 1 do
					local n2 = ROMAN_NUMBERS[j]
					if s - (num - n2) >= 0 and s < num and s > 0 and num - n2 ~= n2 then
						ret = ret .. ROMAN_CHARS[j] .. ROMAN_CHARS[i]
						s = s - (num - n2)
						break
					end
				end
			end
			return ret
		end,
		
		from = function(s)
			s = s:upper()
			local ret = 0
			local i = 1
			while i <= s:len() do
				--for i = 1, s:len() do
				local c = s:sub(i, i)
				if c ~= " " then -- allow spaces
					local m = ROMAN_MAP[c] or error("Unknown Roman Numeral '" .. c .. "'")

					local next = s:sub(i + 1, i + 1)
					local nextm = ROMAN_MAP[next]

					if next and nextm then
						if nextm > m then 
							-- if string[i] < string[i + 1] then result += string[i + 1] - string[i]
							-- This is used instead of programming in IV = 4, IX = 9, etc, because it is
							-- more flexible and possibly more efficient
							ret = ret + (nextm - m)
							i = i + 1
						else
							ret = ret + m
						end
					else
						ret = ret + m
					end
				end
				i = i + 1
			end
			return ret
		end,
	}
}

return NumberUtility