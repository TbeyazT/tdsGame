local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:FindFirstChild("Shared")
local Assets = ReplicatedStorage:FindFirstChild("Assets")

local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient"))

local AdminClient = {}

function AdminClient:Init()
    Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
end

return AdminClient