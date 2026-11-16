-- Client mirror of the server state + action helper + toast signal.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Net = require(Shared.Net)

local State = {}
State.data = nil :: any
local changed = Instance.new("BindableEvent")
local toast = Instance.new("BindableEvent")
State.Changed = changed.Event -- (data)
State.Toast = toast.Event -- (text, kind)
local receivedAt = os.clock()

local ActionRemote = Net.get("Action")

function State.serverNow(): number
	if not State.data then
		return os.time()
	end
	return State.data.ServerTime + (os.clock() - receivedAt)
end

function State.toast(text: string, kind: string?)
	toast:Fire(text, kind or "info")
end

-- Calls a server action; shows its message. Returns the result table.
function State.action(name: string, arg: any?)
	local ok, result = pcall(ActionRemote.InvokeServer, ActionRemote, name, arg)
	if not ok or type(result) ~= "table" then
		State.toast("Connection hiccup, try again", "error")
		return { ok = false }
	end
	if result.msg then
		State.toast(result.msg, result.ok and "success" or "error")
	end
	return result
end

function State.start()
	Net.get("State").OnClientEvent:Connect(function(view)
		State.data = view
		receivedAt = os.clock()
		changed:Fire(view)
	end)
	Net.get("Notify").OnClientEvent:Connect(function(text, kind)
		State.toast(text, kind)
	end)
end

return State
