--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local UIAnimationController

--> Constants

------------->
local UI = {_loaded = false, _objects = {}, _current = nil, _instantCloses = {}}

function UI.Await()
	if not UI._loaded then
		UI.Loaded:Wait()
	end
end

function UI.Get(uiName)
	return UI._objects[uiName]
end

function UI.Open(props)
	local uiName = props.name
	local uiProps = props.props
	
	if UI._closingFrame then
		UI._closingFrame.Visible = false
		UI._closingFrame = nil
	end
	local travel = _L.PlayerGui:FindFirstChild("TravelMenu")
	if travel then
		travel.Enabled = false
	end
	local currentUiName = UI._current:Get()
	
	if currentUiName then
		UI.Close({name = currentUiName}, true)
	end
	
	if uiName then
		local ui = UI.Get(uiName)
		
		UI._current:Set(uiName)
		ui.is_open:Set(true, {
			props = props.props
		})
	end
end

function UI.Close(props, dont)
	local uiName = props.name
	local uiProps = props.props
	
	local currentUiName = UI._current:Get()
	
	if uiName and uiName == currentUiName then
		local ui = UI.Get(uiName)
		
		if not dont then
			UI._current:Set(nil)
		end
		
		UI._instantCloses[uiName] = dont == true
		UI._switching = dont == true
		ui.is_open:Set(false, {
			props = props.props
		})
		UI._switching = false
	end
end

function UI.Toggle(props)
	local uiName = props.name
	
	local ui = UI.Get(uiName)
	
	local uiState = props.state or ui.is_open:Get()
	
	if uiState then
		UI.Close(props)
	else
		UI.Open(props)
	end
end

function UI.GetLast()
	return UI._current:GetLast()
end

function UI._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	
	UIAnimationController = _L.Get {"Client", "Modules", "Controllers", "UIAnimationController"}
	UI.Loaded = Signal.new()
	UI._current = Tracker.new(nil)
end

function UI._start()
	_L.Storage:WaitForChild("UI")
	
	for _, instance in pairs(_L.Storage.UI:GetChildren()) do
		instance.Parent = _L.PlayerGui
	end
	
	for _, uiModule in pairs(script:GetChildren()) do
		if uiModule:IsA("ModuleScript") then
			local ui = require(uiModule)
			local uiName = ui.name
			
			UI._objects[uiName] = ui
		end
	end
	
	for uiName, ui in pairs(UI._objects) do
		if typeof(ui) == "table" and typeof(rawget(ui, "_init")) == "function" then
			ui:_init()
		end
	end

	for uiName, ui in pairs(UI._objects) do
		if typeof(ui) == "table" and typeof(rawget(ui, "_start")) == "function" then
			if type(ui.Open) == "function" and type(ui.Close) == "function" then
				local originalOpen = ui.Open
				local originalClose = ui.Close
				ui.Open = function(self, ...)
					originalOpen(self, ...)
					local frame = self.object and self.object:FindFirstChild("Main")
					if frame and frame:IsA("GuiObject") then
						UIAnimationController.OpenFrame(frame)
					end
				end
				ui.Close = function(self, ...)
					local frame = self.object and self.object:FindFirstChild("Main")
					local wasVisible = frame and frame:IsA("GuiObject") and frame.Visible
					local instant = UI._instantCloses[self.name]
					UI._instantCloses[self.name] = nil
					originalClose(self, ...)
					if wasVisible and not instant and not UI._switching and UI._current:Get() == nil then
						UI._closingFrame = frame
						frame.Visible = true
						UIAnimationController.CloseFrame(frame)
					end
				end
			end
			task.spawn(function()
				ui:_start()
			end)
		end
	end
	
	_L.Player.CharacterRemoving:Connect(function()
		local current = UI._current:Get()
		if current then
			UI.Close({name = current}, true)
			UI._current:Set(nil)
		end
		local travel = _L.PlayerGui:FindFirstChild("TravelMenu")
		if travel then
			travel.Enabled = false
		end
	end)
	UI._loaded = true
	UI.Loaded:Fire()
end

return UI