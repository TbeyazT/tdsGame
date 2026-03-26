local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local Framework = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('Framework'))
local TableUtil = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('TableUtil'))
local WeightRandom = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('Modules'):FindFirstChild('Utils'):FindFirstChild('WeightRandom'))
local Net = require(game:GetService('ServerScriptService'):FindFirstChild('Net'))

local FIFTH_SLOT_GAMEPASS_ID = 123456789 

local TowerService = {}

function TowerService:Init()
    self.ProfileService = Framework.Get("ProfileService")
    self.NotificationService = Framework.Get("NotificationService")
    self.Utils = require(script.Parent.Utils)

    Net.EquipTower.SetCallback(function(player, towerID)
        return self:EquipTower(player, towerID)
    end)

    Net.UnequipTower.SetCallback(function(player, towerID)
        return self:UnequipTower(player, towerID)
    end)
end

function TowerService:EquipTower(player: Player, towerID: string, slotIndex: number?)
    local equipped = self.ProfileService:Get(player, "EquippedTowers") or {}
    local towerObj = self.Utils:GetTowerByID(player, towerID)

    if not towerObj then return false end
    
    for _, t in pairs(equipped) do
        if t and t.Name == towerObj.Name and t.ID ~= towerID then
            self.NotificationService:Notify(player, {
                Text = "You already have a " .. towerObj.Name .. " equipped!"
            })
            return false
        end
    end
    
    local _, existingSlot = TableUtil.Find(equipped, function(a0): boolean 
        return a0 and a0.ID == towerID 
    end)
    
    if existingSlot then
        equipped[existingSlot] = nil
    end

    local hasGamepass = false
    pcall(function()
        hasGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, FIFTH_SLOT_GAMEPASS_ID)
    end)
    
    local maxSlots = hasGamepass and 5 or 4

    if not slotIndex then
        for i = 1, maxSlots do
            if equipped[i] == nil then
                slotIndex = i
                break
            end
        end
    end

    if not slotIndex or slotIndex < 1 or slotIndex > maxSlots then
        if maxSlots == 4 then
            self.NotificationService:Notify(player,{
                Text = "Slot limit reached! Buy the 5th Slot gamepass to equip more."
            })
        else
            self.NotificationService:Notify(player,{
                Text = "All 5 slots are full!"
            })
        end
        return false 
    end

    equipped[slotIndex] = towerObj
    self.ProfileService:Set(player, "EquippedTowers", equipped)
    
    return true
end

function TowerService:UnequipTower(player: Player, towerID: string)
    local equipped = self.ProfileService:Get(player, "EquippedTowers") or {}
    
    local _, equipIndex = TableUtil.Find(equipped, function(a0): boolean 
        return a0 and a0.ID == towerID
    end)

    if equipIndex then
        equipped[equipIndex] = nil
        self.ProfileService:Set(player, "EquippedTowers", equipped)
        return true
    end
    
    return false
end

function TowerService:GiveTower(player: Player, towerName: string)
    local createdTower = self:CreateTower(towerName)
    if createdTower then
        self.ProfileService:TableInsert(player, "Towers", createdTower)
        return createdTower
    end
    return false
end

function TowerService:DeleteTower(player: Player, towerID: string)
    local _, index = self.Utils:GetTowerByID(player, towerID)
    
    if index then
        self.ProfileService:TableRemove(player, "Towers", index)
        
        local equipped = self.ProfileService:Get(player, "EquippedTowers") or {}
        local _, equipIndex = TableUtil.Find(equipped, function(a0): boolean 
            return a0 and a0.ID == towerID
        end)
        if equipIndex then
            equipped[equipIndex] = nil
            self.ProfileService:Set(player, "EquippedTowers", equipped)
        end
    end
end

function TowerService:CreateTower(name)
    local properties = self.Utils:GetTowerProperties(name)
    if properties then
        local createdTower = {
            Name = name,
            ID = HttpService:GenerateGUID(false),
        }
        return createdTower
    end
    return nil
end

return TowerService