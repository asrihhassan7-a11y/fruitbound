--!strict
-- Shared helpers: number formatting, tables, validation.
local Util = {}

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Util.fmt(n: number?): string
	local v = tonumber(n) or 0
	local neg = v < 0
	v = math.abs(v)
	if v < 1000 then
		return (neg and "-" or "") .. tostring(math.floor(v))
	end
	local i = 1
	while v >= 1000 and i < #SUFFIX do
		v /= 1000
		i += 1
	end
	local s
	if v >= 100 then
		s = string.format("%.0f", v)
	elseif v >= 10 then
		s = string.format("%.1f", v)
	else
		s = string.format("%.2f", v)
	end
	if string.find(s, "%.") then
		s = (string.gsub(s, "0+$", ""))
		s = (string.gsub(s, "%.$", ""))
	end
	return (neg and "-" or "") .. s .. SUFFIX[i]
end

function Util.time(sec: number): string
	sec = math.max(0, math.floor(sec))
	local h = sec // 3600
	local m = (sec % 3600) // 60
	local s = sec % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Util.deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = Util.deepCopy(v)
	end
	return c
end

-- Adds keys missing from `target` using `template` (never overwrites existing values).
function Util.reconcile(target: any, template: any)
	for k, v in template do
		if target[k] == nil then
			target[k] = Util.deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			Util.reconcile(target[k], v)
		end
	end
end

function Util.finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Util.finiteVector(v: any): boolean
	return typeof(v) == "Vector3" and Util.finite(v.X) and Util.finite(v.Y) and Util.finite(v.Z)
end

function Util.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- list of items, weightOf(item) -> number
function Util.weightedPick<T>(list: { T }, weightOf: (T) -> number, rng: Random?): T?
	local total = 0
	for _, item in list do
		total += math.max(0, weightOf(item))
	end
	if total <= 0 then
		return nil
	end
	local r = (rng and rng:NextNumber() or math.random()) * total
	for _, item in list do
		r -= math.max(0, weightOf(item))
		if r <= 0 then
			return item
		end
	end
	return list[#list]
end

return Util
