--!strict
local Players = game:GetService("Players")

export type UIModule = {
	Name: string,
	Order: number,
	Init: ((self: UIModule) -> ())?,
	Mount: ((self: UIModule, parent: Instance) -> ())?,
	Start: ((self: UIModule) -> ())?,
	[string]: any
}

local _screens: { [string]: UIModule } = {}

local UI = {
	_hasStarted = false,
}

local PREFIX = "[UI-System]"

function UI:Init()
	if self._hasStarted then return end

	local classesFolder = script.Parent:WaitForChild("Classes")
	local screensToLoad: { UIModule } = {}

	print(PREFIX .. " Initializing UI...")

	for _, child in ipairs(classesFolder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local success: boolean, moduleData: any = xpcall(function()
				return require(child :: ModuleScript)
			end, debug.traceback)

			if success and type(moduleData) == "table" then
				local rawModule: any = moduleData 
				rawModule.Name = child.Name
				rawModule.Order = if type(rawModule.Order) == "number" then rawModule.Order else 999 
				
				local uiModule = rawModule :: UIModule
				_screens[child.Name] = uiModule
				table.insert(screensToLoad, uiModule)
			else
				warn(string.format("%s ❌ Error requiring '%s': %s", PREFIX, child.Name, tostring(moduleData)))
			end
		end
	end

	table.sort(screensToLoad, function(a: UIModule, b: UIModule): boolean
		return a.Order < b.Order
	end)

	print(string.format("%s ✅ Loaded %d modules. Running Lifecycle...", PREFIX, #screensToLoad))

	for _, uiModule in ipairs(screensToLoad) do
		local initFunc = uiModule.Init
		if type(initFunc) == "function" then
			xpcall(function() 
				initFunc(uiModule)
			end, function(err: any)
				warn(string.format("%s ❌ Init Error in %s: %s", PREFIX, uiModule.Name, tostring(err)))
			end)
		end
	end

	local localPlayer = Players.LocalPlayer
	assert(localPlayer, "LocalPlayer is nil")
	
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	assert(playerGui, "PlayerGui was not found")
	
	local mainGui = playerGui:WaitForChild("MainGui", 10)
	assert(mainGui, "MainGui was not found")

	for _, uiModule in ipairs(screensToLoad) do
		local mountFunc = uiModule.Mount
		if type(mountFunc) == "function" then
			xpcall(function() 
				mountFunc(uiModule, mainGui)
			end, function(err: any)
				warn(string.format("%s ❌ Mount Error in %s: %s", PREFIX, uiModule.Name, tostring(err)))
			end)
		end
	end

	for _, uiModule in ipairs(screensToLoad) do
		local startFunc = uiModule.Start
		if type(startFunc) == "function" then
			task.spawn(function()
				xpcall(function() 
					startFunc(uiModule)
				end, function(err: any)
					warn(string.format("%s ❌ Start Error in %s: %s", PREFIX, uiModule.Name, tostring(err)))
				end)
			end)
		end
	end

	self._hasStarted = true
	print(PREFIX .. " UI System Fully Booted.")
end

function UI.Get(name: string): UIModule?
	return _screens[name]
end

return UI