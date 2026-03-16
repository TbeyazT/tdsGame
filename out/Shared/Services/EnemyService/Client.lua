local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local EnemyController = {}

function EnemyController:Init()
    self.Utils = require(script.Parent.Utils)
    self.EnemyClass = require(script.Parent.Enemy)

    self._enemies = {}

    if not workspace:FindFirstChild("Enemies") then
        local folder = Instance.new("Folder")
        folder.Name = "Enemies"
        folder.Parent = workspace
    end

    Net.CreateEnemy.On(function(Data)
        self:SpawnEnemy(Data)
    end)

    Net.SyncEnemies.On(function(PositionsMap)
        self:SyncPositions(PositionsMap)
    end)

    Net.DestroyEnemy.On(function(ID)
        self:DestroyEnemy(ID)
    end)

    Net.DamageEnemyClient.On(function(data)
        local enemy = self:GetEnemy(data.ID)
        if enemy and typeof(enemy.TakeDamage) == "function" then
            enemy:TakeDamage(data)
        end
    end)
end

function EnemyController:GetEnemy(ID)
    return self._enemies[ID] or nil
end

function EnemyController:SpawnEnemy(Data)
    local newEnemy = self.EnemyClass.new(Data, self.Utils)
    self._enemies[Data.ID] = newEnemy
end

function EnemyController:SyncPositions(PositionsMap)
    for id, cframe in pairs(PositionsMap) do
        local enemy = self._enemies[id]
        if enemy then
            enemy:UpdateTargetCFrame(cframe)
        end
    end
end

function EnemyController:DestroyEnemy(ID)
    local enemy = self._enemies[ID]
    if enemy then
        enemy:Destroy()
        self._enemies[ID] = nil
    end
end

return EnemyController