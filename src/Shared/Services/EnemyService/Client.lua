local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Framework = require("@Shared/Framework")
local Net = require("@Shared/Net")

local EnemyController = {}

function EnemyController:Init()
    self.Utils = require(script.Parent.Utils)
end

return EnemyController