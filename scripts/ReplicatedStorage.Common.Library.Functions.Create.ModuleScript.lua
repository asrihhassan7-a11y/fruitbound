return function(p12, p13)
	local v13 = if typeof(p12) == "Instance" then p12 else Instance.new(p12)
	for v14, v15 in pairs(p13) do
		v13[v14] = v15
	end
	return v13
end