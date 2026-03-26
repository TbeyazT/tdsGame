local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local LocalPlayer = Players.LocalPlayer

local Framework = require("@Shared/Framework")
local TableUtil = require("@Pckgs/TableUtil")

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

function Utils:GetTowerByID(ID,player)
    player = not player and LocalPlayer or player
    if player then
        local foundTower = nil
        self.ProfileService:Get("Towers",player):andThen(function(towers)  
            local found = TableUtil.Find(towers, function(tower): boolean 
                return tower.ID == ID
            end)
            if found then
                foundTower = found
            end
        end)
        return foundTower
    end
    return nil
end

function Utils:GetEquippedTowers(player)
    player = not player and LocalPlayer or player
    if player then
        local EquippedTowers = {}

        self.ProfileService:Get("EquippedTowers",player):andThen(function(towers)
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