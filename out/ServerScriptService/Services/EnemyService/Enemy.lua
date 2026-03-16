local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local ServerEnemy = {}
ServerEnemy.__index = ServerEnemy

local DEBUG_MODE = false 

function ServerEnemy.new(id, name, properties, waypoints)
    local self = setmetatable({}, ServerEnemy)

    self.ID = id
    self.Name = name
    self.Health = properties.Health or 100
    self.Speed = properties.Speed or 10
    
    self.Waypoints = waypoints
    self.CurrentNode = 1
    
    if #self.Waypoints > 0 then
        self.Position = self.Waypoints[1]
    else
        self.Position = Vector3.zero
    end
    
    self.CFrame = CFrame.new(self.Position)
    self.Finished = false
    self.Dead = false

    if DEBUG_MODE then
        local folder = workspace:FindFirstChild("ServerEnemyDebug")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "ServerEnemyDebug"
            folder.Parent = workspace
        end

        self.DebugPart = Instance.new("Part")
        self.DebugPart.Name = "Debug_" .. self.ID
        self.DebugPart.Size = Vector3.new(2, 2, 2)
        self.DebugPart.Shape = Enum.PartType.Ball
        self.DebugPart.Color = Color3.fromRGB(255, 0, 255) 
        self.DebugPart.Material = Enum.Material.Neon
        self.DebugPart.Anchored = true
        self.DebugPart.CanCollide = false
        self.DebugPart.CanTouch = false
        self.DebugPart.CanQuery = false
        self.DebugPart.CFrame = self.CFrame
        self.DebugPart.Parent = folder
    end

    return self
end

function ServerEnemy:TakeDamage(amount)
    amount = amount or 10
    self.Health -= amount
    Net.DamageEnemyClient.FireAll({
        CurrentHealth = self.Health,
        Damage = amount,
        ID = self.ID,
    })
    
    if self.Health <= 0 and not self.Dead then
        self:Destroy()
    end
end

function ServerEnemy:Update(dt)
    if self.Finished or self.Dead or #self.Waypoints == 0 then return end

    local targetPos = self.Waypoints[self.CurrentNode]
    local direction = (targetPos - self.Position)
    local distanceToNode = direction.Magnitude

    if distanceToNode < 0.1 then
        self.CurrentNode += 1
        if self.CurrentNode > #self.Waypoints then
            self.Finished = true
            return
        end
        targetPos = self.Waypoints[self.CurrentNode]
        direction = (targetPos - self.Position)
        distanceToNode = direction.Magnitude
    end

    local moveDir = direction.Unit
    local moveStep = self.Speed * dt

    if moveStep >= distanceToNode then
        self.Position = targetPos
    else
        self.Position += (moveDir * moveStep)
    end
    
    if moveDir.Magnitude > 0 then
        self.CFrame = CFrame.lookAt(self.Position, self.Position + moveDir)
    else
        self.CFrame = CFrame.new(self.Position)
    end

    -- Update debug part position
    if self.DebugPart then
        self.DebugPart.CFrame = self.CFrame
    end
end

function ServerEnemy:Destroy()
    self.Dead = true
    self.Waypoints = nil
    
    if self.DebugPart then
        self.DebugPart:Destroy()
        self.DebugPart = nil
    end
end

return ServerEnemy