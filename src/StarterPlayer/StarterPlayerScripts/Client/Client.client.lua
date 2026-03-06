local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local GameVersion = "0.1.0"
local PREFIX = "[Framework-Client]"

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)

local Loaded = false

local function Load()
	if Loaded then return end
	
	if not Shared then
		warn(PREFIX .. " ❌ CRITICAL: 'Shared' folder not found in ReplicatedStorage! Framework halted.")
		return
	end

	print(PREFIX .. " Booting framework (v" .. GameVersion .. ")...")
	local totalStartTime = os.clock()
	local successCount, failCount = 0, 0

	local ClientFolders = Shared.Services:GetChildren()
	local modulesToInit = {}

	for _, Folder in ipairs(ClientFolders) do
		if Folder:IsA("Folder") then
			local foundModule = nil
			
			for _, child in ipairs(Folder:GetChildren()) do
				if child:IsA("ModuleScript") and string.find(child.Name, "Client") then
					foundModule = child
					break
				end
			end

			if foundModule then
				local requireSuccess, moduleData = pcall(require, foundModule)

				if requireSuccess then
					if type(moduleData) == "table" and type(moduleData.init) == "function" then
						local order = type(moduleData.LoadOrder) == "number" and moduleData.LoadOrder or 50
						
						table.insert(modulesToInit, {
							Name = Folder.Name,
							Module = moduleData,
							Order = order
						})
					else
						warn(PREFIX .. " ⚠️ Module '" .. Folder.Name .. "' does not have an init() function.")
					end
				else
					warn(PREFIX .. " ❌ Require Error in '" .. Folder.Name .. "':\n" .. tostring(moduleData))
					failCount += 1
				end
			else
				warn(PREFIX .. " ⚠️ No Client module found in folder: " .. Folder:GetFullName())
			end
		end
	end

	table.sort(modulesToInit, function(a, b)
		return a.Order < b.Order
	end)

	for _, data in ipairs(modulesToInit) do
		local initStartTime = os.clock()
		
		local initSuccess, initError = pcall(function()
			data.Module:init()
		end)

		if initSuccess then
			local elapsed = math.round((os.clock() - initStartTime) * 1000)
			print(PREFIX .. " ✔️ Initialized '" .. data.Name .. "' [Order: " .. data.Order .. "] (" .. elapsed .. "ms)")
			successCount += 1
		else
			warn(PREFIX .. " ❌ Runtime Error in init() of '" .. data.Name .. "':\n" .. tostring(initError))
			failCount += 1
		end
	end
	
	Loaded = true
	local totalElapsed = math.round((os.clock() - totalStartTime) * 1000)
	print(string.format("%s Boot complete: %d loaded, %d failed (%dms)", PREFIX, successCount, failCount, totalElapsed))
end

Load()