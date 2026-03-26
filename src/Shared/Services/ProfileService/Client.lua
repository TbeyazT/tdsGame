debug.setmemorycategory(script.Name .. " Client")

--[[
    ProfileClient
    Client-side data cache and bridge. Interacts with the Server via Zap.
]]

-------------------------- Roblox Services --------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require("@Pckgs/Promise")
local Signal = require("@Pckgs/Signal")

local Net = require("@Shared/Net")

-------------------------- Controller Definition --------------------------
local ProfileClient = {
	_data = nil,
	_isLoaded = false,
	_dataLoadedSignal = Signal.new(),
	_changedSignals = {}, -- [key] = Signal
	LoadOrder = 1,
}

-------------------------- Framework Init --------------------------

function ProfileClient:init()
	-- 1. Listen for Initial Data Payload
	Net.DataLoaded.SetCallback(function(fullData)
		self._data = fullData
		self._isLoaded = true
		self._dataLoadedSignal:Fire()
		
		for key, signal in pairs(self._changedSignals) do
			if self._data[key] ~= nil then
				signal:Fire(self._data[key], nil)
			end
		end
	end)

	-- 2. Listen for Data Updates
	Net.DataUpdated.On(function(payload)
		if not self._isLoaded then return end

		local key = payload.Key
		local newValue = payload.Value
		local oldValue = self._data[key]

		self._data[key] = newValue

		-- Alert any active Observers
		if self._changedSignals[key] then
			self._changedSignals[key]:Fire(newValue, oldValue)
		end
	end)
end

-------------------------- Public API (Data Fetching) --------------------------

function ProfileClient:IsLoaded(): boolean
	return self._isLoaded
end

function ProfileClient:Get(key: string): "Promise"
	return Promise.new(function(resolve, reject)
		if self._isLoaded then
			resolve(self._data[key])
			return
		end

		local connection
		connection = self._dataLoadedSignal:Connect(function()
			connection:Disconnect()
			resolve(self._data[key])
		end)
		
		task.delay(15, function()
			if connection.Connected then
				connection:Disconnect()
				reject(`Timeout: Profile data never loaded for {key}.`)
			end
		end)
	end)
end

function ProfileClient:Observe(key: string, callback: (any, any) -> ())
	if not self._changedSignals[key] then
		self._changedSignals[key] = Signal.new()
	end
	
	local connection = self._changedSignals[key]:Connect(callback)

	if self._isLoaded and self._data[key] ~= nil then
		task.spawn(callback, self._data[key], nil)
	end

	return connection
end

function ProfileClient:ChangeSetting(key: string): "Promise"
	return Promise.new(function(resolve)
		resolve(Net.ChangeSetting.Call(key))
	end)
end

function ProfileClient:ClaimGroupReward(): "Promise"
	return Promise.new(function(resolve)
		resolve(Net.ClaimGroupReward.Call())
	end)
end

function ProfileClient:ClaimWelcomeReward(): "Promise"
	return Promise.new(function(resolve)
		resolve(Net.ClaimWelcomeReward.Call())
	end)
end

function ProfileClient:EditTutorial(key: string, value: any)
	Net.EditTutorial.Call({ Key = key, Value = value })
end

function ProfileClient:Rebirth(isSkipped: boolean): "Promise"
	return Promise.new(function(resolve)
		resolve(Net.Rebirth.Call(isSkipped))
	end)
end

function ProfileClient:Mock(mockData)
	self._data = mockData
	self._isLoaded = true
	
	self._dataLoadedSignal:Fire()

	for key, signal in pairs(self._changedSignals) do
		if self._data[key] ~= nil then
			signal:Fire(self._data[key], nil)
		end
	end
end

return ProfileClient