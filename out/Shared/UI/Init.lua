--!strict
local Players = game:GetService("Players")

local UI = {
    _screens = {} :: { [string]: any },
    _hasStarted = false,
}

local PREFIX = "[UI-System]"

function UI:Init()
    if self._hasStarted then return end
    
    local classesFolder = script.Parent:WaitForChild("Classes")
    local screensToLoad = {}

    print(PREFIX .. " Initializing UI...")

    for _, child in ipairs(classesFolder:GetChildren()) do
        if child:IsA("ModuleScript") then
            local success, moduleData = xpcall(function()
                return require(child)
            end, debug.traceback)

            if success and type(moduleData) == "table" then
                moduleData.Name = child.Name
                self._screens[child.Name] = moduleData
                table.insert(screensToLoad, moduleData)
                print(string.format("%s ✅ Loaded: %s", PREFIX, child.Name))
            else
                warn(string.format("%s ❌ Error requiring '%s': %s", PREFIX, child.Name, tostring(moduleData)))
            end
        end
    end

    for _, module in ipairs(screensToLoad) do
        if type(module.Init) == "function" then
            xpcall(function() module:Init() end, function(err)
                warn(string.format("%s ❌ Init Error in %s: %s", PREFIX, module.Name, err))
            end)
        end
    end

    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui",10):WaitForChild("MainGui",10)

    for _, module in ipairs(screensToLoad) do
        task.spawn(function()
            if type(module.Mount) == "function" then
                xpcall(function() module:Mount(PlayerGui) end, function(err)
                    warn(string.format("%s ❌ Mount Error in %s: %s", PREFIX, module.Name, err))
                end)
            end

            if type(module.Start) == "function" then
                xpcall(function() module:Start() end, function(err)
                    warn(string.format("%s ❌ Start Error in %s: %s", PREFIX, module.Name, err))
                end)
            end
        end)
    end

    self._hasStarted = true
    print(PREFIX .. " UI System Fully Booted.")
end

function UI:Get(name: string): any
    return self._screens[name]
end

return UI