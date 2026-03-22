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

-- Checks if local player's data is loaded on the client
function ProfileClient:IsLoaded(): boolean
	return self._isLoaded
end

-- Returns a Promise resolving with the value of the key.
function ProfileClient:Get(key: string): "Promise"
	return Promise.new(function(resolve, reject)
		-- If data is already loaded, resolve instantly
		if self._isLoaded then
			resolve(self._data[key])
			return
		end

		-- Otherwise, wait for the data to arrive from the server
		local connection
		connection = self._dataLoadedSignal:Connect(function()
			connection:Disconnect()
			resolve(self._data[key])
		end)
		
		-- Optional 15s timeout
		task.delay(15, function()
			if connection.Connected then
				connection:Disconnect()
				reject(`Timeout: Profile data never loaded for {key}.`)
			end
		end)
	end)
end

-- Observes a key and fires a callback on change (and immediately)
function ProfileClient:Observe(key: string, callback: (any, any) -> ())
	-- Make sure we have the Signal setup
	if not self._changedSignals[key] then
		self._changedSignals[key] = Signal.new()
	end
	
	local connection = self._changedSignals[key]:Connect(callback)

	-- Fire immediately if data is loaded, otherwise it will fire when DataLoaded occurs
	if self._isLoaded and self._data[key] ~= nil then
		task.spawn(callback, self._data[key], nil)
	end

	return connection
end

-------------------------- Features (Network Bridges) --------------------------

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

return ProfileClient