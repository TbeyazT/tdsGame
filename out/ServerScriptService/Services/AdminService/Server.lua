local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")

local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Packages = ReplicatedStorage:FindFirstChild("Packages")

local Dumpster = require(Packages.Dumpster)
local Signal = require(Packages.Signal)
local TableUtil = require(Packages.TableUtil)
local Cmdr = require(Packages.Cmdr)

local AdminService = {}

function AdminService:Init()
    Cmdr:RegisterHooksIn(script.Parent.Hooks)
    Cmdr:RegisterDefaultCommands()
    Cmdr:RegisterCommandsIn(script.Parent.Commands)
end

return AdminService