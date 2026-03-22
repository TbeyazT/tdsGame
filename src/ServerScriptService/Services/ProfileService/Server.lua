--[[
    ProfileServer
    Manages Player Data using ProfileStore and Zap for Replication.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Promise = require(Packages.Promise)
local Signal = require(Packages.Signal)
local TableUtil = require(Packages.TableUtil)
local ProfileStore = require(script.Parent.Parent.Parent.ProfileStore) 

local Net = require(ServerScriptService.Net)

-------------------------- Constants --------------------------
local STORE_NAME = "FullStarStudios"
local STORE_VERSION = 2

local DATA_TEMPLATE = {
	Cash = 350,
	LastLogin = 0,
	Daily = { Day = 1, LastClaimed = 0 }, 
	CurrentBow = "Normal",
	Towers = {},
	Badges = {},
}

if RunService:IsStudio() then
	STORE_NAME = "STUDIO_DATA"
end

local FinalStoreName = `{STORE_NAME}_v{STORE_VERSION}`
local PlayerStore = ProfileStore.New(FinalStoreName, DATA_TEMPLATE)

if RunService:IsStudio() and ServerStorage:GetAttribute("MOCK_DATA_STORE") then
	PlayerStore = PlayerStore.Mock
	warn("⚠️ ProfileServer: Using Mock DataStore")
end

-------------------------- Module Definition --------------------------
local ProfileServer = {
	PlayerLoaded = Signal.new(),
	PlayerRemoving = Signal.new(),

	_profiles = {},
	_loadedPlayers = {},
	_changedEvents = {},
	LoadOrder = 1,
}

-------------------------- Framework Init --------------------------
function ProfileServer:init()
	-- Connect Zap callbacks
	Net.ChangeSetting.SetCallback(function(player, key)
		return self:ChangeSetting(player, key)
	end)

	Net.EditTutorial.SetCallback(function(player, data)
		self:EditTutorial(player, data.Key, data.Value)
	end)

	-- Handle Players
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function() self:_onPlayerAdded(player) end)
	end

	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)
end

-------------------------- Public API --------------------------

function ProfileServer:IsLoaded(player: Player): boolean
	local profile = self._profiles[player]
	return profile ~= nil and profile:IsActive()
end

function ProfileServer:Get(player: Player, key: string): any
	local profile = self._profiles[player]
	if not profile then return nil end
	return profile.Data[key]
end

function ProfileServer:GetProfile(player: Player): table
	return self._profiles[player]
end

function ProfileServer:GetAllData(player: Player): table?
	local profile = self._profiles[player]
	if not profile then return nil end
	return TableUtil.Copy(profile.Data)
end

function ProfileServer:OnChanged(player: Player, key: string, callback: (any, any) -> nil)
	return self:_getKeyChangedSignal(player, key):Connect(callback)
end

function ProfileServer:Set(player: Player, key: string, value: any)
	return Promise.new(function(resolve, reject)
		local profile = self._profiles[player]
		if not profile then return reject("Player data not loaded") end

		local oldValue = profile.Data[key]
		profile.Data[key] = value

		self:_replicateAndFire(player, key, value, oldValue)
		resolve(value)
	end)
end

function ProfileServer:Increment(player: Player, key: string, amount: number)
	return Promise.new(function(resolve, reject)
		local profile = self._profiles[player]
		if not profile then return reject("Player data not loaded") end

		local currentVal = profile.Data[key] or 0
		if type(currentVal) ~= "number" then return reject(`Key '{key}' is not a number`) end

		local newVal = currentVal + amount
		profile.Data[key] = newVal

		self:_replicateAndFire(player, key, newVal, currentVal)
		resolve(newVal)
	end)
end

function ProfileServer:Update(player: Player, key: string, callback: (any) -> any)
	return Promise.new(function(resolve, reject)
		local profile = self._profiles[player]
		if not profile then return reject("Player data not loaded") end

		local currentVal = profile.Data[key]
		local newVal = callback(currentVal)

		profile.Data[key] = newVal

		self:_replicateAndFire(player, key, newVal, currentVal)
		resolve(newVal)
	end)
end

function ProfileServer:TableInsert(player: Player, key: string, valueToInsert: any)
	return Promise.new(function(resolve, reject)
		local profile = self._profiles[player]
		if not profile then return reject("Player data not loaded") end

		if type(profile.Data[key]) ~= "table" then return reject(`Key '{key}' is not a table`) end
		table.insert(profile.Data[key], valueToInsert)

		self:_replicateAndFire(player, key, profile.Data[key], nil)
		resolve()
	end)
end

function ProfileServer:TableRemove(player: Player, key: string, index: number)
	return Promise.new(function(resolve, reject)
		local profile = self._profiles[player]
		if not profile then return reject("Player data not loaded") end

		if type(profile.Data[key]) ~= "table" then return reject(`Key '{key}' is not a table`) end
		table.remove(profile.Data[key], index)

		self:_replicateAndFire(player, key, profile.Data[key], nil)
		resolve()
	end)
end

function ProfileServer:WipeData(player: Player)
	return Promise.new(function(resolve, reject)
		local profile = self._profiles[player]
		if not profile then return reject("Player data not loaded") end

		local newData = TableUtil.Copy(DATA_TEMPLATE, true)

		for key, value in pairs(newData) do
			profile.Data[key] = value
			self:_replicateAndFire(player, key, value, nil)
		end

		for key, _ in pairs(profile.Data) do
			if newData[key] == nil then
				profile.Data[key] = nil
				self:_replicateAndFire(player, key, nil, nil)
			end
		end

		resolve()
	end)
end

function ProfileServer:ObservePlayerAdded(observer)
	for _, player in ipairs(self._loadedPlayers) do
		local profile = self._profiles[player]
		if profile then
			task.spawn(observer, player, profile)
		end
	end

	return self.PlayerLoaded:Connect(observer)
end

-------------------------- Features --------------------------

function ProfileServer:ChangeSetting(player: Player, key: string)
	local Settings = self:Get(player, "Settings")
	if Settings and typeof(Settings[key]) ~= "nil" then
		Settings[key] = not Settings[key]
		self:Set(player, "Settings", Settings)
		return Settings[key]
	end
	return nil
end

function ProfileServer:EditTutorial(player: Player, dataToChange: string, value: any)
	local currentTutData = self:Get(player, "Tutorial")
	if currentTutData and typeof(currentTutData[dataToChange]) == typeof(value) then
		currentTutData[dataToChange] = value
		self:Set(player, "Tutorial", currentTutData)
	end
end

function ProfileServer:Save(player: Player)
	local profile = self._profiles[player]
	if profile then
		profile:Save()
	end
end

-------------------------- Internal Implementation --------------------------

function ProfileServer:_onPlayerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return not player:IsDescendantOf(Players)
		end,
	})

	if not profile then
		player:Kick("Profile load failed. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		self:_cleanupPlayer(player)
		player:Kick("Profile session ended. Please rejoin.")
	end)

	if not player:IsDescendantOf(Players) then
		profile:EndSession()
		return
	end

	self._profiles[player] = profile
	table.insert(self._loadedPlayers, player)
	player:SetAttribute("DATA_LOADED", true)

	-- Instead of ReplicaService, send data payload through Zap
	Net.DataLoaded.Fire(player, profile.Data)

	self.PlayerLoaded:Fire(player, profile)

	if not profile.Data.Tutorial.Finished then
		--self:WipeData(player)
	end
end

function ProfileServer:_onPlayerRemoving(player: Player)
	local profile = self._profiles[player]
	if profile then
		profile:EndSession()
	end
	self:_cleanupPlayer(player) 
end

function ProfileServer:_cleanupPlayer(player: Player)
	self._profiles[player] = nil

	local index = table.find(self._loadedPlayers, player)
	if index then
		table.remove(self._loadedPlayers, index)
	end

	if self._changedEvents[player] then
		for _, signal in pairs(self._changedEvents[player]) do
			signal:Destroy()
		end
		self._changedEvents[player] = nil
	end

	self.PlayerRemoving:Fire(player)
end

function ProfileServer:_getKeyChangedSignal(player: Player, key: string)
	if not self._changedEvents[player] then self._changedEvents[player] = {} end
	if not self._changedEvents[player][key] then self._changedEvents[player][key] = Signal.new() end
	return self._changedEvents[player][key]
end

function ProfileServer:_replicateAndFire(player: Player, key: string, newValue: any, oldValue: any)
	Net.DataUpdated.Fire(player, { Key = key, Value = newValue })

	local events = self._changedEvents[player]
	if events and events[key] then
		events[key]:Fire(newValue, oldValue)
	end
end

return ProfileServer