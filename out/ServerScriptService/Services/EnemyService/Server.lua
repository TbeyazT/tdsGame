local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local EnemyService = {}

function EnemyService:Init()
    self.Utils = require(script.Parent.Utils)
    self.EnemyClass = require(script.Parent.Enemy)

    self._enemies = {}
    self.SYNC_RATE = 0.1
    self.timeSinceLastSync = 0
    
    self.Waypoints = self:LoadWaypoints()

    RunService.Heartbeat:Connect(function(dt)
        self:OnHeartbeat(dt)
    end)

    task.spawn(function()
        task.wait(4)
        while task.wait(1) do
            for i = 1, 10 do
                self:SpawnEnemy("TbeyazT")
                task.wait(0.2)
            end
        end
    end)

    Net.DamageEnemy.On(function(player: Player, id: string)
        local enemy = self:GetEnemy(id)
        if enemy then
            enemy:TakeDamage(25)
        end
    end)
end

function EnemyService:GetEnemy(id)
    return self._enemies[id] or nil
end

function EnemyService:LoadWaypoints()
    local map = Workspace:FindFirstChild("Map")
    local pathway = map and map:FindFirstChild("Pathway")
    
    if not pathway then
        warn("EnemyService: Could not find workspace.Map.Pathway!")
        return {}
    end

    local parts = pathway:GetChildren()
    local waypoints = {}

    local pathParts = {}
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then
            table.insert(pathParts, part)
        end
    end

    table.sort(pathParts, function(a, b)
        local numA = tonumber(a.Name) or 0
        local numB = tonumber(b.Name) or 0
        return numA < numB
    end)

    for _, part in ipairs(pathParts) do
        table.insert(waypoints, part.Position)
    end

    return waypoints
end

function EnemyService:SpawnEnemy(Name)
    local properties = self.Utils:GetEnemyProperties(Name)
    if properties then
        local id = HttpService:GenerateGUID(false)
        
        local newEnemy = self.EnemyClass.new(id, Name, properties, self.Waypoints)
        self._enemies[id] = newEnemy
        
        Net.CreateEnemy.FireAll({
            ID = id,
            Name = Name,
            StartCFrame = newEnemy.CFrame
        })
    end
end

function EnemyService:OnHeartbeat(dt)
    local positionsToSync = {}
    local hasUpdates = false

    for id, enemy in pairs(self._enemies) do
        enemy:Update(dt)
        
        if enemy.Finished or enemy.Dead then
            self._enemies[id] = nil
            Net.DestroyEnemy.FireAll(id)
        else
            positionsToSync[id] = enemy.CFrame
            hasUpdates = true
        end
    end

    self.timeSinceLastSync += dt
    if self.timeSinceLastSync >= self.SYNC_RATE then
        self.timeSinceLastSync = 0
        if hasUpdates then
            Net.SyncEnemies.FireAll(positionsToSync)
        end
    end
end

return EnemyService