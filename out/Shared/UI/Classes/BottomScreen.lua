--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local LocalPlayer = Players.LocalPlayer

local Dumpster = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Dumpster'))
local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local AnimationComponent = require(script.Parent.Parent:FindFirstChild('Components'):FindFirstChild('AnimationComponent'))

local BottomScreen = {
    Name = script.Name,
    _dump = nil,
}

function BottomScreen:Init()
    self.CharacterService = Framework.Get("CharacterService")
end

function BottomScreen:Mount(target: Instance)
    self._dump = Dumpster.new()
    
    local BottomScreen = Assets.UIs:FindFirstChild(self.Name)
    
    if not BottomScreen then 
        return function() end 
    end
    self.BottomScreen = BottomScreen:Clone()
    self.BottomScreen.Parent = target
    self._dump:Add(self.BottomScreen)

    local class = self._dump:Construct(AnimationComponent.new,self.BottomScreen.Play_Button)

    class:Init(nil,function()
        local teleportCFrame = workspace.Areas["2"]:FindFirstChild("LeaveLocation")
        if teleportCFrame then
            local character = self.CharacterService:GetPlayerData(LocalPlayer)
            if character.RootPart then
                character.RootPart.CFrame = teleportCFrame.CFrame
            end
        end
    end)

    return function()
        self:Destroy()
    end
end

function BottomScreen:Destroy()
    if self._dump then
        self._dump:Destroy()
        self._dump = nil::any
    end    
end

return BottomScreen