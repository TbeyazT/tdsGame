--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Dumpster = require("@Pckgs/Dumpster")

local CenterScreen = {
    Name = script.Name,
    _dump = nil,
    Order = 1
}

function CenterScreen:Init()
    self.Utils = require(script.Utils)
end

function CenterScreen:Mount(target: Instance)
    self._dump = Dumpster.new()
    
    local CenterScreen = Assets.UIs:FindFirstChild(self.Name)
    
    if not CenterScreen then 
        return function() end 
    end
    self.CenterScreen = CenterScreen:Clone()
    self.CenterScreen.Parent = target
    self._dump:Add(self.CenterScreen)

    for _,class in pairs(script.Frames:GetChildren()) do
        if class:IsA("ModuleScript") then
            local foundUI = self.CenterScreen:FindFirstChild(class.Name)
            if foundUI then
                local requiredClass = require(class)::any
                requiredClass:Init(foundUI)
            end
        end
    end

    return function()
        self:Destroy()
    end
end

function CenterScreen:Destroy()
    if self._dump then
        self._dump:Destroy()
        self._dump = nil::any
    end    
end

return CenterScreen