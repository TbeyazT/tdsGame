local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local GameVersion = "0.1.0"
local PREFIX = "[Framework-Client]"

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)

local Framework = require(Shared.Framework)

Framework.Boot({
	ReplicatedStorage.Shared.Services
})