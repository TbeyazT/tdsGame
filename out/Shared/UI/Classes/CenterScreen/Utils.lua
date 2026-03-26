local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Utils = {}

function Utils:GetEnemyProperties(Name)
    local foundModule = Assets.EnemyProperties:FindFirstChild(Name)
    if foundModule then
        return require(foundModule)
    end
    return nil
end

function Utils:GetEnemyModel(Name)
    local foundModule = Assets.EnemyProperties:FindFirstChild(Name)
    if foundModule then
        local model = foundModule:FindFirstChildWhichIsA("Model")
        if model then
            return model
        end
    end
    return nil
end

return Utils