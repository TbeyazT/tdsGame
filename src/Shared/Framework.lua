--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIInit = require("@Shared/UI/Init")

local Framework = {
	_modules = {} :: { [string]: any },
	_hasStarted = false,
	_uiInitDone = false,
}

local IS_SERVER = RunService:IsServer()
local PREFIX = IS_SERVER and "[Framework-Server]" or "[Framework-Client]"
local TARGET_NAME = IS_SERVER and "Server" or "Client"

-- Define where your services live so the lazy loader can find them
local SEARCH_DIRS = {
	Shared:WaitForChild("Services"),
	-- Shared:WaitForChild("Controllers"), -- Uncomment if you use controllers too
}

-- Internal helper to load just ONE specific module folder
local function _loadSingleModule(folder: Folder)
	local moduleName = folder.Name
	if Framework._modules[moduleName] then return Framework._modules[moduleName] end

	local foundModule = nil
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match(TARGET_NAME) then
			foundModule = child
			break
		end
	end

	if not foundModule then return nil end

	-- 1. Require
	local moduleData
	local success, err = xpcall(function()
		moduleData = require(foundModule)
	end, debug.traceback)

	if not (success and type(moduleData) == "table") then
		warn(string.format("%s ❌ Lazy Load Error in '%s':\n%s", PREFIX, moduleName, tostring(err)))
		return nil
	end

	Framework._modules[moduleName] = moduleData

	-- 2. Init
	local initFunc = moduleData.Init or moduleData.init
	if type(initFunc) == "function" then
		xpcall(function() initFunc(moduleData) end, function(e)
			warn(string.format("%s ❌ Lazy Init Error in %s:\n%s", PREFIX, moduleName, tostring(e)))
		end)
	end

	-- 3. Start
	local startFunc = moduleData.Start or moduleData.start
	if type(startFunc) == "function" then
		task.spawn(function()
			xpcall(function() startFunc(moduleData) end, function(e)
				warn(string.format("%s ❌ Lazy Start Error in %s:\n%s", PREFIX, moduleName, tostring(e)))
			end)
		end)
	end

	print(string.format("%s ⚡ Lazy Loaded: %s", PREFIX, moduleName))

	-- Run UI Init once if we are on the client
	if not IS_SERVER and not Framework._uiInitDone then
		Framework._uiInitDone = true
		UIInit:Init()
	end

	return moduleData
end

local function _lazyBoot(name: string)
	if Framework._hasStarted or Framework._modules[name] or not RunService:IsStudio() then
		return
	end

	for _, directory in ipairs(SEARCH_DIRS) do
		local folder = directory:FindFirstChild(name)
		if folder and folder:IsA("Folder") then
			_loadSingleModule(folder)
			break
		end
	end
end

function Framework.Get(name: string): any
	_lazyBoot(name) 

	local found = Framework._modules[name]
	if not found then
		warn(string.format("⚠️ %s: Could not find module named '%s'\n%s", PREFIX, name, debug.traceback()))
	end
	return found
end

function Framework.WaitFor(name: string): any
	_lazyBoot(name) 

	if Framework._modules[name] then return Framework._modules[name] end

	local startWait = os.clock()
	while not Framework._modules[name] do
		task.wait()
		if os.clock() - startWait > 5 then
			warn(PREFIX .. " Infinite yield waiting for module: " .. name)
			return nil
		end
	end
	return Framework._modules[name]
end

function Framework.GetUtil(name:string):any
	local foundService = IS_SERVER and ServerScriptService.Server.Services:FindFirstChild(name) or Shared.Services:FindFirstChild(name)
	if foundService then
		local utils = foundService:FindFirstChild("Utils")
		if utils then
			return require(utils)
		end
	end
	return nil
end

function Framework.IsStarted(): boolean
	return Framework._hasStarted
end

function Framework.Boot(directories: {Instance})
	if Framework._hasStarted then 
		warn(PREFIX .. " Framework has already booted!")
		return 
	end
	
	print(PREFIX .. " Booting...")
	local startTime = os.clock()
	local modulesToLoad = {}

	for _, directory in ipairs(directories) do
		for _, folder in ipairs(directory:GetChildren()) do
			if folder:IsA("Folder") then
				local foundModule = nil
				
				for _, child in ipairs(folder:GetChildren()) do
					if child:IsA("ModuleScript") and child.Name:match(TARGET_NAME) then
						foundModule = child
						break
					end
				end

				if foundModule then
					local moduleData
					local success, err = xpcall(function()
						moduleData = require(foundModule)
					end, debug.traceback)

					if success and type(moduleData) == "table" then
						local order = moduleData.LoadOrder or moduleData.loadOrder or 100
						
						Framework._modules[folder.Name] = moduleData
						table.insert(modulesToLoad, { 
							Name = folder.Name, 
							Module = moduleData, 
							Order = order 
						})
					else
						warn(string.format("%s ❌ Require Error in '%s':\n%s", PREFIX, folder.Name, tostring(err or "Module did not return a table")))
					end
				end
			end
		end
	end

	table.sort(modulesToLoad, function(a, b)
		return a.Order < b.Order
	end)

	for _, data in ipairs(modulesToLoad) do
		local initFunc = data.Module.Init or data.Module.init
		if type(initFunc) == "function" then
			local success, err = xpcall(function() 
				initFunc(data.Module) 
			end, debug.traceback)
			
			if not success then 
				warn(string.format("%s ❌ Init Error in %s (Order: %d):\n%s", PREFIX, data.Name, data.Order, tostring(err)))
			else 
				print(string.format("%s ✅ Init [%d]: %s", PREFIX, data.Order, data.Name)) 
			end
		end
	end

	for _, data in ipairs(modulesToLoad) do
		local startFunc = data.Module.Start or data.Module.start
		if type(startFunc) == "function" then
			task.spawn(function()
				local success, err = xpcall(function() 
					startFunc(data.Module) 
				end, debug.traceback)
				
				if not success then 
					warn(string.format("%s ❌ Start Error in %s:\n%s", PREFIX, data.Name, tostring(err)))
				end
			end)
		end
	end

	Framework._hasStarted = true
	local elapsed = math.round((os.clock() - startTime) * 1000)
	print(string.format("%s Boot complete: %d modules loaded (%dms)", PREFIX, #modulesToLoad, elapsed))
	
	if not IS_SERVER then
		Framework._uiInitDone = true
		UIInit:Init()
	end
end

return Framework