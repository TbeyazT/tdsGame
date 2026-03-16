local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:FindFirstChild("Shared")

local Framework = require(Shared.Framework)

Framework.Boot({
	ServerScriptService.Services
})