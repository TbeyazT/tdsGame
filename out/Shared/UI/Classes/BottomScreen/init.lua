--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local LocalPlayer = Players.LocalPlayer

local Dumpster = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Dumpster'))
local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local UIFramework = require(script.Parent.Parent:FindFirstChild('Init'))
local AnimationComponent = require(script.Parent.Parent:FindFirstChild('Components'):FindFirstChild('AnimationComponent'))

local BottomScreen = {
    Name = script.Name,
    _dump = nil,
}

function BottomScreen:Init()
    self.CharacterService = Framework.Get("CharacterService")
    self.ProfileService = Framework.Get("ProfileService")

    self.LeftScreen = UIFramework.Get("LeftScreen")
    self.CenterScreen = UIFramework.Get("CenterScreen")
    self.Utils = require(script.Utils)
end

function BottomScreen:Mount(target: Instance)
    self._dump = Dumpster.new()
    self.CleanUp = Dumpster.new()
    
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

    self.ProfileService:Observe("EquippedTowers", function(newLoadout)
        self:UpdateAllSlots(newLoadout)
    end)

    self.ProfileService:Get("EquippedTowers"):andThen(function(towers)
        self:UpdateAllSlots(towers)
    end)

    return function()
        self:Destroy()
    end
end

function BottomScreen:UpdateAllSlots(loadout)
    self.CleanUp:Destroy()
    for i = 1, 5 do
        local slotUI = self.BottomScreen.Slot_List:FindFirstChild(tostring(i))
        if slotUI then
            local towerName = loadout[i]
            self:RenderSlot(slotUI, towerName)
        end
    end
end

function BottomScreen:RenderSlot(slotUI, towerData)
    local images = slotUI:FindFirstChild("Images")
    local nameLabel = slotUI:FindFirstChild("Tower_Name")
    local priceLabel = slotUI:FindFirstChild("Ingame_Price")

    if towerData and towerData.Name then
        local properties = self.Utils:GetTowerProperties(towerData.Name) 
        
        slotUI.Visible = true
        nameLabel.Text = towerData.Name
        priceLabel.Text = "$" .. tostring(properties.Cost)
        images.Tower_Icon.Image = "rbxassetid://" .. properties.ImageID
        
        slotUI:SetAttribute("TowerID", towerData.ID)
        
        if images:FindFirstChild("Tower_Image") then
            images.Tower_Image.Visible = true
        end
    else
        nameLabel.Text = "Empty"
        priceLabel.Text = ""
        images.Tower_Icon.Image = ""
        slotUI:SetAttribute("TowerID", "")
        
        if images:FindFirstChild("Tower_Image") then
            images.Tower_Image.Visible = false
        end
    end

    local aniComp = self.CleanUp:Construct(AnimationComponent.new,slotUI)
    aniComp:Init(nil,function()
        self.LeftScreen:OpenFrame(self.CenterScreen.CenterScreen.Units) -- bad code
    end)
end

function BottomScreen:Destroy()
    if self._dump then
        self._dump:Destroy()
        self._dump = nil::any
    end    
end

return BottomScreen