local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Packages = ReplicatedStorage:FindFirstChild("Packages")
local Shared = ReplicatedStorage:FindFirstChild("Shared")

local Dumpster = require(Packages.Dumpster)
local Signal = require(Packages.Signal)
local TableUtil = require(Packages.TableUtil)
local Net = require(ServerScriptService.Server.Net)

local AudioService = {}

function AudioService:init()
    self._dumpster = Dumpster.new()
    task.spawn(function()
        Players.PlayerAdded:Connect(function(player)
            task.wait(5)
            self:PlaySound(player, "StageComplete", {Volume = 0.5})
        end)
    end)
end

function AudioService:PlaySound(player, soundName, properties)
    Net.PlayAudio.Fire(player, {
        SoundName = soundName,
        Properties = properties
    })
end

function AudioService:PlaySoundAll(soundName, properties)
    Net.PlayAudio.FireAll({
        SoundName = soundName,
        Properties = properties
    })
end

return AudioService