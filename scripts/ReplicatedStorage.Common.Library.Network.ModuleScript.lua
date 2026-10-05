--> Variables
local _L = _G._L

local Services
local Signal

local IsServer

--> Constants

---------->
local Network = {Remote = {}, Bindable = {}}

Network._remote = {
	Event = {instance = script.RemoteEvent, connections = {}},
	Function = {instance = script.RemoteFunction, connections = {}}
}

function Network._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	BindableEvent = _L.Get {"Common", "Library", "Bindables", "BindableEvent"}
	BindableFunction = _L.Get {"Common", "Library", "Bindables", "BindableFunction"}
end

function Network._start()
	Network._bindable = {
		Event = {instance = BindableEvent.new(), connections = {}},
		Function = {instance = BindableFunction.new(), connections = {}}
	}
	
	IsServer = Services.RunService:IsServer()
	
	if IsServer then
		Network._remote.Event.instance.OnServerEvent:Connect(function(player, connectionName, args)
			if not Network._remote.Event.connections[connectionName] then
				return
			end

			for _, connectionFunc in pairs(Network._remote.Event.connections[connectionName]) do
				task.spawn(function()
					connectionFunc(player, unpack(args))
				end)
			end
		end)

		Network._remote.Function.instance.OnServerInvoke = function(player, connectionName, args)
			if not Network._remote.Function.connections[connectionName] then
				return
			end

			local connectionFunc = Network._remote.Function.connections[connectionName][1]
			
			if connectionFunc then
				return connectionFunc(player, unpack(args))
			end
		end
	else
		Network._remote.Event.instance.OnClientEvent:Connect(function(connectionName, args)
			if not Network._remote.Event.connections[connectionName] then
				return
			end

			for _, connectionFunc in pairs(Network._remote.Event.connections[connectionName]) do
				task.spawn(function()
					connectionFunc(unpack(args))
				end)
			end
		end)

		Network._remote.Function.instance.OnClientInvoke = function(connectionName, args)
			if not Network._remote.Function.connections[connectionName] then
				return
			end
			
			local results = {}

			for i, connectionFunc in pairs(Network._remote.Function.connections[connectionName]) do
				local result = connectionFunc(unpack(args))

				if result then
					table.insert(results, result)
				end
			end

			return unpack(results)
		end
	end
	
	Network._bindable.Event.instance:Connect(function(connectionName, args)
		if not Network._bindable.Event.connections[connectionName] then
			return
		end

		for _, connectionFunc in pairs(Network._bindable.Event.connections[connectionName]) do
			task.spawn(function()
				connectionFunc(unpack(args))
			end)
		end
	end)

	Network._bindable.Function.instance:Connect(function(connectionName, args)
		if not Network._bindable.Function.connections[connectionName] then
			return
		end

		local results = {}

		for i, connectionFunc in pairs(Network._bindable.Function.connections[connectionName]) do
			local result = connectionFunc(unpack(args))
			
			if result then
				table.insert(results, result)
			end
		end

		return unpack(results)
	end)
end

local function connectConfig(tbl, connectionName, connectionFunc)
	tbl.connections[connectionName] = tbl.connections[connectionName] or {}

	table.insert(tbl.connections[connectionName], connectionFunc)

	return function()
		if table.find(tbl.connections[connectionName], connectionFunc) then
			table.remove(tbl.connections[connectionName], table.find(tbl.connections[connectionName], connectionFunc))
		end

		if #tbl.connections[connectionName] == 0 then
			tbl.connections[connectionName] = nil
		end
	end
end

function Network.Remote.Fired(...)
	return connectConfig(Network._remote.Event, ...)
end

function Network.Remote.Invoked(...)
	return connectConfig(Network._remote.Function, ...)
end

function Network.Remote.Fire(connectionName, player, ...)
	if IsServer then
		return Network._remote.Event.instance:FireClient(player, connectionName, {...})
	else
		return Network._remote.Event.instance:FireServer(connectionName, {player, ...})
	end
end

function Network.Remote.Invoke(connectionName, player, ...)
	local args = {...}

	if IsServer then
		return Network._remote.Function.instance:InvokeClient(player, connectionName, {...})
	else
		return Network._remote.Function.instance:InvokeServer(connectionName, {player, ...})
	end
end

function Network.Bindable.Fired(...)
	return connectConfig(Network._bindable.Event, ...)
end

function Network.Bindable.Invoked(...)
	return connectConfig(Network._bindable.Function, ...)
end

function Network.Bindable.Fire(connectionName, ...)
	return Network._bindable.Event.instance:Fire(connectionName, {...})
end

function Network.Bindable.Invoke(connectionName, ...)
	return Network._bindable.Function.instance:Invoke(connectionName, {...})
end

function Network.Remote.FireAll(connectionName, ...)
	if not IsServer then
		return warn('FireAll can only be used on the server')
	end
	
	return Network._remote.Event.instance:FireAllClients(connectionName, {...})
end

return Network