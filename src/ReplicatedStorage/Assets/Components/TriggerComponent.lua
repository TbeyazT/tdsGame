local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages.Signal)

local HitPartComponent = {}
HitPartComponent.__index = HitPartComponent

HitPartComponent.TouchType = {
	Spatial = "Spatial", 
	Physics = "Physics"  
}

local activeComponents = {}
local runServiceConnection = nil

function HitPartComponent.new(part: BasePart, touchType: string?)
	pcall(function()
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			warn("HitPartComponent requires a BasePart")
		end
	end)

	local self = setmetatable({}, HitPartComponent)

	self.part = part
	self.touchType = touchType or HitPartComponent.TouchType.Spatial

	self.currentPlayers = setmetatable({}, {__mode = "k"}) 
	self.currentParts = setmetatable({}, {__mode = "k"})   

	self._foundPlayersCache = setmetatable({}, {__mode = "k"})
	self._foundPartsCache = setmetatable({}, {__mode = "k"})

	self.OnTouched = Signal.new()     
	self.OnTouchEnded = Signal.new()   
	self.OnPartTouched = Signal.new()   
	self.OnPartTouchEnded = Signal.new()

	self.overlapParams = OverlapParams.new()
	self.overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	self.overlapParams.FilterDescendantsInstances = {part}

	self._connections = {}
	self._isDestroyed = false

	table.insert(self._connections, part.Destroying:Connect(function()
		self:Destroy()
	end))

	if self.touchType == HitPartComponent.TouchType.Spatial then
		table.insert(activeComponents, self)
		if not runServiceConnection then
			runServiceConnection = RunService.Heartbeat:Connect(HitPartComponent.updateAll)
		end

	elseif self.touchType == HitPartComponent.TouchType.Physics then
		self:initPhysics()
	end

	return self
end

function HitPartComponent:initPhysics()
	if not self.part then return end

	local function handleHit(hit, isTouching)
		if self._isDestroyed then return end
		if hit.Name == "Terrain" then return end

		if table.find(self.overlapParams.FilterDescendantsInstances, hit) then return end

		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if player then
			if isTouching then
				self.OnTouched:Fire(player, hit)
			else
				self.OnTouchEnded:Fire(player, hit)
			end
		else
			if isTouching then
				self.OnPartTouched:Fire(hit)
			else
				self.OnPartTouchEnded:Fire(hit)
			end
		end
	end

	table.insert(self._connections, self.part.Touched:Connect(function(hit)
		handleHit(hit, true)
	end))

	table.insert(self._connections, self.part.TouchEnded:Connect(function(hit)
		handleHit(hit, false)
	end))
end

function HitPartComponent.updateAll()
	for i = #activeComponents, 1, -1 do
		activeComponents[i]:checkProximity()
	end
end

function HitPartComponent:checkProximity()
	if self._isDestroyed then return end

	if not self.part or not self.part.Parent then
		self:clearAllCurrent()
		return
	end

	table.clear(self._foundPlayersCache)
	table.clear(self._foundPartsCache)

	local foundPlayers = self._foundPlayersCache
	local foundParts = self._foundPartsCache

	local partsInPart = workspace:GetPartsInPart(self.part, self.overlapParams)

	for _, hitPart in ipairs(partsInPart) do
		if hitPart.Name == "Terrain" then continue end

		local character = hitPart.Parent
		local player = Players:GetPlayerFromCharacter(character)

		if player then
			foundPlayers[player] = true
		else
			foundParts[hitPart] = true
		end
	end

	for player, _ in pairs(foundPlayers) do
		if self._isDestroyed then return end
		if not self.currentPlayers[player] then
			self.currentPlayers[player] = true
			self.OnTouched:Fire(player)
		end
	end

	if self._isDestroyed then return end

	for player, _ in pairs(self.currentPlayers) do
		if self._isDestroyed then return end
		if not foundPlayers[player] or not player.Parent then
			self.currentPlayers[player] = nil
			self.OnTouchEnded:Fire(player)
		end
	end

	if self._isDestroyed then return end

	for part, _ in pairs(foundParts) do
		if self._isDestroyed then return end
		if not self.currentParts[part] then
			self.currentParts[part] = true
			self.OnPartTouched:Fire(part)
		end
	end

	if self._isDestroyed then return end

	for part, _ in pairs(self.currentParts) do
		if self._isDestroyed then return end
		if not foundParts[part] or not part.Parent then
			self.currentParts[part] = nil
			self.OnPartTouchEnded:Fire(part)
		end
	end
end

function HitPartComponent:clearAllCurrent()
	local playersToEnd = {}
	if self.currentPlayers then
		for player, _ in pairs(self.currentPlayers) do
			table.insert(playersToEnd, player)
		end
		table.clear(self.currentPlayers)
	end

	local partsToEnd = {}
	if self.currentParts then
		for part, _ in pairs(self.currentParts) do
			table.insert(partsToEnd, part)
		end
		table.clear(self.currentParts)
	end

	for _, player in ipairs(playersToEnd) do
		if self.OnTouchEnded then self.OnTouchEnded:Fire(player) end
	end

	for _, part in ipairs(partsToEnd) do
		if self.OnPartTouchEnded then self.OnPartTouchEnded:Fire(part) end
	end
end

function HitPartComponent:Destroy()
	if self._isDestroyed then return end
	self._isDestroyed = true

	if self.touchType == HitPartComponent.TouchType.Spatial then
		local index = table.find(activeComponents, self)
		if index then
			table.remove(activeComponents, index)
		end
	end

	if self._connections then
		for _, conn in ipairs(self._connections) do
			conn:Disconnect()
		end
		table.clear(self._connections)
	end
	
	self:clearAllCurrent()

	if self.OnTouched then self.OnTouched:Destroy() end
	if self.OnTouchEnded then self.OnTouchEnded:Destroy() end
	if self.OnPartTouched then self.OnPartTouched:Destroy() end
	if self.OnPartTouchEnded then self.OnPartTouchEnded:Destroy() end

	self.part = nil
	self.overlapParams = nil
	self.currentPlayers = nil
	self.currentParts = nil
	self._foundPlayersCache = nil
	self._foundPartsCache = nil

	setmetatable(self, nil)

	if #activeComponents == 0 and runServiceConnection then
		runServiceConnection:Disconnect()
		runServiceConnection = nil
	end
end

return HitPartComponent