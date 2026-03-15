local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages.Signal)

local HitboxComponent = {}
HitboxComponent.__index = HitboxComponent

export type DebugConfig = {
	Enabled: boolean,
	Color: Color3?,
	Transparency: number?,
	ShowHitMarkers: boolean?,
	HitMarkerDuration: number?,
	ShowHitCount: boolean?,
}

export type Hitbox = {
	Connection: RBXScriptConnection?,
	Active: boolean,
	Source: BasePart,
	Size: Vector3,
	Offset: CFrame,
	OverlapParams: OverlapParams,
	HitDebounce: { [Instance]: number },
	DebounceTime: number,
	DebugConfig: DebugConfig,
	OnHit: any,
	HitCount: number,

	Start: (Hitbox) -> (),
	Stop: (Hitbox) -> (),
	SetDebug: (Hitbox, config: DebugConfig | boolean) -> (),
	ClearDebounce: (Hitbox, instance: Instance?) -> (),
	Destroy: (Hitbox) -> (),
}

local DEFAULT_DEBUG_CONFIG = {
	Enabled = false,
	Color = Color3.fromRGB(136, 17, 160),
	Transparency = 0.5,
	ShowHitMarkers = true,
	HitMarkerDuration = 0.5,
	ShowHitCount = true,
}

local IS_CLIENT = RunService:IsClient()
local HEARTBEAT_EVENT = IS_CLIENT and RunService.RenderStepped or RunService.Heartbeat

local HitMarkerPool = {}
local POOL_SIZE = 50 

local function CreateHitMarker(): Part
	local marker = Instance.new("Part")
	marker.Name = "HitMarker"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(0.5, 0.5, 0.5)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 0, 0)
	marker.Transparency = 0.3
	return marker
end

for i = 1, POOL_SIZE do
	table.insert(HitMarkerPool, CreateHitMarker())
end

local function GetHitMarker(): Part?
	local marker = table.remove(HitMarkerPool)
	if not marker then
		marker = CreateHitMarker()
	end
	return marker
end

local function ReturnHitMarker(marker: Part)
	marker.Parent = nil
	if #HitMarkerPool < POOL_SIZE then
		table.insert(HitMarkerPool, marker)
	else
		marker:Destroy()
	end
end

function HitboxComponent.new(
	sourcePart: BasePart, 
	size: Vector3, 
	overlapParams: OverlapParams?, 
	offset: CFrame?
): Hitbox
	local self = setmetatable({}, HitboxComponent)

	self.Source = sourcePart
	self.Size = size
	self.Offset = offset or CFrame.new()
	self.OverlapParams = overlapParams or OverlapParams.new()

	self.Active = false
	self.DebounceTime = 0

	self.HitDebounce = setmetatable({}, {__mode = "k"}) 

	self.HitCount = 0
	self.OnHit = Signal.new()

	self.DebugConfig = table.clone(DEFAULT_DEBUG_CONFIG)
	self._debugPart = nil
	self._debugBillboard = nil

	self._activeMarkers = {}

	self._lastDebounceCleanup = 0
	self._perFrameCache = {} 

	return self
end

function HitboxComponent:Start()
	if self.Active then return end
	self.Active = true

	table.clear(self.HitDebounce)
	self.HitCount = 0
	self._lastDebounceCleanup = 0

	local debugConfig = self.DebugConfig
	local useTimedDebounce = false 

	self.Connection = HEARTBEAT_EVENT:Connect(function(deltaTime)
		if not self.Source or not self.Source.Parent then
			self:Stop()
			return
		end

		local currentTime = os.clock()
		local debugEnabled = debugConfig.Enabled
		useTimedDebounce = self.DebounceTime > 0

		local centerCFrame = self.Source.CFrame * self.Offset

		if debugEnabled then
			self:_updateDebugVisuals(centerCFrame)

			if #self._activeMarkers > 0 then
				for i = #self._activeMarkers, 1, -1 do
					local data = self._activeMarkers[i]
					if currentTime >= data.Expiration then
						ReturnHitMarker(data.Part)
						table.remove(self._activeMarkers, i)
					end
				end
			end
		end

		if useTimedDebounce then
			if currentTime - self._lastDebounceCleanup >= 1 then
				self._lastDebounceCleanup = currentTime
				for instance, hitTime in pairs(self.HitDebounce) do
					if currentTime - hitTime >= self.DebounceTime then
						self.HitDebounce[instance] = nil
					end
				end
			end
		end

		local parts = Workspace:GetPartBoundsInBox(centerCFrame, self.Size, self.OverlapParams)
		table.clear(self._perFrameCache)

		for _, part in ipairs(parts) do
			local ancestor = part.Parent

			while ancestor do
				if ancestor:IsA("Model") then
					if self._perFrameCache[ancestor] then 
						break 
					end
					self._perFrameCache[ancestor] = true

					local humanoid = ancestor:FindFirstChildOfClass("Humanoid")

					if humanoid and humanoid.Health > 0 then
						local canHit = false

						if useTimedDebounce then
							local lastHit = self.HitDebounce[ancestor]
							if not lastHit or (currentTime - lastHit >= self.DebounceTime) then
								canHit = true
							end
						else
							if not self.HitDebounce[ancestor] then
								canHit = true
							end
						end

						if canHit then
							self.HitDebounce[ancestor] = useTimedDebounce and currentTime or true
							self.HitCount += 1

							if debugEnabled and debugConfig.ShowHitMarkers then
								self:_createHitMarker(part.Position, currentTime)
							end

							self.OnHit:Fire(part, humanoid, ancestor, part.Position)
						end
					end

					break 
				end
				ancestor = ancestor.Parent
				if ancestor == Workspace then break end 
			end
		end
	end)
end

function HitboxComponent:Stop()
	if not self.Active then return end
	self.Active = false

	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end

	self:_cleanupDebugVisuals()
end

function HitboxComponent:SetDebug(config: DebugConfig | boolean)
	if type(config) == "boolean" then
		self.DebugConfig.Enabled = config
	else
		for key, value in pairs(config) do
			self.DebugConfig[key] = value
		end
	end

	if not self.DebugConfig.Enabled then
		self:_cleanupDebugVisuals()
	end
end

function HitboxComponent:ClearDebounce(instance: Instance?)
	if instance then
		self.HitDebounce[instance] = nil
	else
		table.clear(self.HitDebounce)
	end
end

function HitboxComponent:Destroy()
	self:Stop()

	if self.OnHit then
		if self.OnHit.Destroy then
			self.OnHit:Destroy()
		elseif self.OnHit.DisconnectAll then
			self.OnHit:DisconnectAll()
		end
		self.OnHit = nil
	end

	self:_cleanupDebugVisuals()
	table.clear(self.HitDebounce)
	table.clear(self._perFrameCache)
	table.clear(self._activeMarkers)

	setmetatable(self, nil)
end

function HitboxComponent:_updateDebugVisuals(centerCFrame: CFrame)
	if not self._debugPart then
		local p = Instance.new("Part")
		p.Name = "HitboxVisualizer"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.ForceField
		p.Color = self.DebugConfig.Color
		p.Transparency = self.DebugConfig.Transparency
		p.Size = self.Size
		p.Parent = Workspace.CurrentCamera or Workspace
		self._debugPart = p

		local box = Instance.new("SelectionBox")
		box.LineThickness = 0.05
		box.Color3 = self.DebugConfig.Color
		box.Adornee = p
		box.Parent = p
	end

	self._debugPart.CFrame = centerCFrame

	if self.DebugConfig.ShowHitCount and IS_CLIENT then
		if not self._debugBillboard then
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.new(0, 100, 0, 50)
			billboard.StudsOffset = Vector3.new(0, self.Size.Y * 0.5 + 1, 0)
			billboard.AlwaysOnTop = true
			billboard.Adornee = self._debugPart
			billboard.Parent = self._debugPart

			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.5
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			label.Parent = billboard

			self._debugBillboard = label
		end
		self._debugBillboard.Text = "Hits: " .. tostring(self.HitCount)
	end
end

function HitboxComponent:_createHitMarker(position: Vector3, currentTime: number)
	local marker = GetHitMarker()
	if marker then 
		marker.Position = position
		marker.Parent = Workspace.CurrentCamera or Workspace

		table.insert(self._activeMarkers, {
			Part = marker,
			Expiration = currentTime + self.DebugConfig.HitMarkerDuration
		})
	end
end

function HitboxComponent:_cleanupDebugVisuals()
	if self._debugPart then
		self._debugPart:Destroy()
		self._debugPart = nil
		self._debugBillboard = nil
	end

	for _, data in ipairs(self._activeMarkers) do
		ReturnHitMarker(data.Part)
	end
	table.clear(self._activeMarkers)
end

return HitboxComponent