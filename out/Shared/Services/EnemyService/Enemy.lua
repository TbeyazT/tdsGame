local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))

local ClientEnemy = {}
ClientEnemy.__index = ClientEnemy

function ClientEnemy.new(data, Utils)
    local self = setmetatable({}, ClientEnemy)

    self.EnemyService = Framework.Get("EnemyService")

    self.ID = data.ID
    self.Name = data.Name
    self.TargetCFrame = data.StartCFrame
    
    self.IncomingDamage = 0 
    
    local properties = Framework.GetUtil("EnemyService"):GetEnemyProperties(self.Name)
    if properties then
        self.Health = properties.Health
    end
    
    local modelTemplate = Utils:GetEnemyModel(self.Name)
    if modelTemplate then
        self.Model = modelTemplate:Clone()
        self.Model.Name = self.ID
        if self.TargetCFrame then
            self.Model:PivotTo(self.TargetCFrame)
        end
        self.Model.Parent = workspace:FindFirstChild("Enemies") or workspace
        
        local _, size = self.Model:GetBoundingBox()
        self.HeightOffset = size.Y / 2 
    end

    self.RaycastParams = RaycastParams.new()
    self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    self:UpdateRaycastFilter()

    self.RenderConnection = RunService.RenderStepped:Connect(function(dt)
        self:Render(dt)
    end)

    return self
end

function ClientEnemy:GetEffectiveHealth()
    return self.Health - self.IncomingDamage
end

function ClientEnemy:AddIncomingDamage(amount)
    self.IncomingDamage += amount
end

function ClientEnemy:RemoveIncomingDamage(amount)
    self.IncomingDamage = math.max(0, self.IncomingDamage - amount)
end

function ClientEnemy:UpdateTargetCFrame(cframe)
    self.TargetCFrame = cframe
end

function ClientEnemy:UpdateRaycastFilter()
    local filter = {self.Model}
    
    local enemiesFolder = workspace:FindFirstChild("Enemies")
    if enemiesFolder then
        table.insert(filter, enemiesFolder)
    end
    
    local debrisFolder = workspace:FindFirstChild("Debris")
    if debrisFolder then
        table.insert(filter, debrisFolder)
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(filter, player.Character)
        end
    end
    
    self.RaycastParams.FilterDescendantsInstances = filter
end

function ClientEnemy:Render(dt)
    if not self.Model or not self.Model.PrimaryPart or not self.TargetCFrame then return end
    
    self:UpdateRaycastFilter()
    
    local currentCFrame = self.Model:GetPivot()
    local nextCFrame = currentCFrame:Lerp(self.TargetCFrame, dt * 10)
    
    local rayOrigin = nextCFrame.Position + Vector3.new(0, 5, 0)
    local rayDirection = Vector3.new(0, -10, 0) 
    
    local hitResult = workspace:Raycast(rayOrigin, rayDirection, self.RaycastParams)
    
    if hitResult then
        local groundY = hitResult.Position.Y + self.HeightOffset
        local newPosition = Vector3.new(nextCFrame.Position.X, groundY, nextCFrame.Position.Z)
        
        nextCFrame = nextCFrame.Rotation + newPosition
    end
    
    self.Model:PivotTo(nextCFrame)
end

function ClientEnemy:TakeDamage(data)
    self.Health = data.CurrentHealth
end

function ClientEnemy:Destroy()
    if self.RenderConnection then
        self.RenderConnection:Disconnect()
    end
    if self.Model then
        self.Model:Destroy()
    end
end

return ClientEnemy