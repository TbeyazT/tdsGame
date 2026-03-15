local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local dexGiver = require(ServerStorage.DexGiver)

return function (context, text)
	dexGiver:GiveDex(text.Name)	
	return "Created Dex."
end