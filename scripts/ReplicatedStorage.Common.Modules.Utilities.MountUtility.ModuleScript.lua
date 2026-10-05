--> MountUtility
-- Ownership / equip of mounts (Databases.Mounts). Saved in data "mounts" = {owned = {[id] = true}, equipped = id}.
-- Only the SERVER calls give / equip / unequip (remotes check ownership there). The client only reads.

local _L = _G._L

local Mounts
local TableUtility

local MountUtility

MountUtility = {
	getInfo = function(id)
		if typeof(id) ~= "string" then
			return nil
		end
		return Mounts.getInfo(id)
	end,

	getAll = function()
		return Mounts.list
	end,

	owns = function(data, id)
		local owned = data:Get({"mounts", "owned"}) or {}
		return owned[id] == true
	end,

	getOwned = function(data)
		local result = {}
		for id in pairs(data:Get({"mounts", "owned"}) or {}) do
			local info = MountUtility.getInfo(id)
			if info then
				table.insert(result, info)
			end
		end
		table.sort(result, function(a, b) return a.order < b.order end)
		return result
	end,

	getEquipped = function(data)
		local id = data:Get({"mounts", "equipped"})
		if id and MountUtility.getInfo(id) and MountUtility.owns(data, id) then
			return id
		end
		return nil
	end,

	-- writes the whole table (safe even if the saved data had no "mounts" key yet)
	_write = function(data, fn)
		local mounts = TableUtility.deep.clone(data:Get("mounts") or {})
		mounts.owned = mounts.owned or {}
		fn(mounts)
		data:Set("mounts", mounts)
	end,

	-- server: returns true, info | false, "invalid" / "owned"
	give = function(client, props)
		local data = client and client.data
		local id = typeof(props) == "table" and (props.id or props.name) or props
		local info = MountUtility.getInfo(id)
		if not data or not info then
			return false, "invalid"
		end
		if MountUtility.owns(data, id) then
			return false, "owned"
		end
		MountUtility._write(data, function(m)
			m.owned[id] = true
		end)
		pcall(function()
			_L.Get {"Common", "Library", "Network"}.Remote.Fire("C_Mount_Unlocked", client.player, id)
		end)
		return true, info
	end,

	equip = function(data, id)
		if not MountUtility.getInfo(id) then
			return false, "invalid"
		end
		if not MountUtility.owns(data, id) then
			return false, "not_owned"
		end
		MountUtility._write(data, function(m)
			m.equipped = id
		end)
		return true
	end,

	unequip = function(data)
		MountUtility._write(data, function(m)
			m.equipped = nil
		end)
		return true
	end,

	_init = function()
		Mounts = _L.Get {"Common", "Modules", "Databases", "Mounts"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	end,
}

return MountUtility
