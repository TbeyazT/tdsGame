local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")


return function (context, text)
	if ServerStorage:FindFirstChild("DexGiver") then
		require(ServerStorage:FindFirstChild("DexGiver")):GiveDex(text.Name)	
	end
	return "Created Dex."
end