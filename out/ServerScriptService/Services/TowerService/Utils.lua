local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Framework = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('Framework'))
local TableUtil = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('TableUtil'))

local Utils = {
    ProfileService = Framework.WaitFor("ProfileService")
}

function Utils:GetTowerProperties(Name)
    local foundModule = Assets.TowerProperties:FindFirstChild(Name)
    if foundModule then
        return require(foundModule)
    end
    return nil
end

function Utils:GetTowerModel(Name)
    local foundModule = Assets.TowerProperties:FindFirstChild(Name)
    if foundModule then
        local model = foundModule:FindFirstChildWhichIsA("Model")
        if model then
            return model
        end
    end
    return nil
end

function Utils:GetTowerByID(player,ID)
    if player then
        local foundTower,index = nil,nil
        local towers = self.ProfileService:Get(player,"Towers")
        print(player,towers)
        local found,Index = TableUtil.Find(towers, function(tower): boolean 
            return tower.ID == ID
        end)
        if found then
            foundTower = found
            index = Index
        end
        return foundTower,index
    end
    return nil
end

function Utils:GetEquippedTowers(player)
    if player then
        local EquippedTowers = {}

        self.ProfileService:Get(player,"EquippedTowers"):andThen(function(towers)
            for _,towerId in pairs(towers) do
                local foundTower = self:GetTowerByID(towerId,player)
                if foundTower then
                    table.insert(EquippedTowers,foundTower)
                end
            end
        end)
        return EquippedTowers
    end
    return nil
end

return Utils