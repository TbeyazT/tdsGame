--!nonstrict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Adjust these paths as necessary for your project structure
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Packages = ReplicatedStorage:WaitForChild("Packages")

-- Assuming Knit is used, otherwise remove
local Knit = require(Packages.Knit)

local ViewportComponent = {}
ViewportComponent.__index = ViewportComponent

export type ViewportComponent = {
	ViewportFrame: ViewportFrame?,
	WorldModel: WorldModel,
	Camera: Camera,
	Model: Model?,

	RotationY: number,
	IsDragging: boolean,
	LastMouseX: number,
	CurrentOptions: {[string]: any}?,
	CurrentOffset: CFrame,
	RotationEnabled: boolean,

	Connections: {RBXScriptConnection},
	ResizeConnection: RBXScriptConnection?,

	SetParent: (ViewportComponent, ViewportFrame?) -> (),
	SetModel: (ViewportComponent, Model, {[string]: any}?) -> Model,
	SetOffset: (ViewportComponent, CFrame) -> (),
	UpdateModelPosition: (ViewportComponent) -> (),
	EnableRotation: (ViewportComponent) -> (),
	Clear: (ViewportComponent) -> (),
	Destroy: (ViewportComponent) -> (),
}

local function getHumanoid(instance: Instance): Humanoid?
	if not instance then return nil end
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildWhichIsA("Humanoid")
			if humanoid then return humanoid end
		end
		current = current.Parent
	end
	return nil
end

local function isPointInFrame(viewport: ViewportFrame, pos: Vector2): boolean
	local absPos = viewport.AbsolutePosition
	local absSize = viewport.AbsoluteSize
	return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
		and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
end

function ViewportComponent.new(viewportFrame: ViewportFrame): ViewportComponent
	local self: ViewportComponent = setmetatable({}, ViewportComponent)

	self.ViewportFrame = viewportFrame
	
	self.WorldModel = viewportFrame:FindFirstChildOfClass("WorldModel") or Instance.new("WorldModel")
	self.WorldModel.Parent = viewportFrame

	self.Camera = Instance.new("Camera")
	self.Camera.FieldOfView = 70
	self.Camera.Parent = viewportFrame
	self.Camera.CFrame = CFrame.new()
	self.ViewportFrame.CurrentCamera = self.Camera

	self.Model = nil
	self.CurrentOptions = nil
	self.CurrentOffset = CFrame.identity

	self.RotationY = 0
	self.IsDragging = false
	self.LastMouseX = 0
	self.RotationEnabled = false

	self.Connections = {}
	self.ResizeConnection = nil

	return self
end

function ViewportComponent:SetParent(newParent: ViewportFrame?)
	if not newParent then
		self.ViewportFrame = nil
		self.WorldModel.Parent = nil
		self.Camera.Parent = nil
		return
	end

	self.ViewportFrame = newParent
	self.WorldModel.Parent = newParent
	self.Camera.Parent = newParent

	if newParent:IsA("ViewportFrame") then
		newParent.CurrentCamera = self.Camera
		self:UpdateModelPosition()
	end
end

function ViewportComponent:UpdateModelPosition()
	if not self.Model or not self.ViewportFrame then return end

	local boundingCFrame, size = self.Model:GetBoundingBox()
	
	local fov = self.Camera.FieldOfView
	local absSize = self.ViewportFrame.AbsoluteSize
	local aspectRatio = absSize.X / absSize.Y
	
	if absSize.X < 1 or absSize.Y < 1 then aspectRatio = 1 end

	local halfSize = size / 2
	local fitHeightDistance = halfSize.Y / math.tan(math.rad(fov) / 2)
	local fitWidthDistance = halfSize.X / (math.tan(math.rad(fov) / 2) * aspectRatio)
	
	local targetDistance = math.max(fitHeightDistance, fitWidthDistance) * 1.1 + halfSize.Z

	local targetCenterPos = CFrame.new(0, 0, -targetDistance) * self.CurrentOffset

	local rotation = CFrame.Angles(0, math.rad(self.RotationY), 0)

	local currentPivot = self.Model:GetPivot()
	local centerToPivot = boundingCFrame:Inverse() * currentPivot

	local finalCFrame = targetCenterPos * rotation * centerToPivot
	
	self.Model:PivotTo(finalCFrame)
end

function ViewportComponent:SetOffset(newOffset: CFrame)
	self.CurrentOffset = newOffset
	self:UpdateModelPosition()
end

function ViewportComponent:SetModel(model: Model, options: {[string]: any}?): Model
	self:Clear()
	self.CurrentOptions = options

	if options and options.Offset and typeof(options.Offset) == "CFrame" then
		self.CurrentOffset = options.Offset
	else
		self.CurrentOffset = CFrame.identity
	end

	local clone = model:Clone()

	-- Ensure PrimaryPart exists
	if not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChildWhichIsA("BasePart")
	end

	-- Rig setup for animation support
	local humanoid = getHumanoid(clone)
	clone.Parent = workspace -- Briefly parent to workspace for rigging if needed
	if humanoid then
		humanoid:BuildRigFromAttachments()
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- Hide names
	end

	clone.Parent = self.WorldModel
	self.Model = clone
	
	-- Reset Rotation
	self.RotationY = 0 
	-- If you want the model to face forward initially (180 deg)
	self.RotationY = 180 

	self:UpdateModelPosition()

	-- Connect resize listener to keep model centered if window changes size
	if self.ResizeConnection then self.ResizeConnection:Disconnect() end
	self.ResizeConnection = self.ViewportFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:UpdateModelPosition()
	end)

	return clone
end

function ViewportComponent:EnableRotation()
	if self.RotationEnabled then return end
	self.RotationEnabled = true

	for _, conn in ipairs(self.Connections) do conn:Disconnect() end
	table.clear(self.Connections)

	if not self.Model then return end

	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		local pos = input.Position or UserInputService:GetMouseLocation()
		
		local isValidInput = (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)

		if isValidInput and isPointInFrame(self.ViewportFrame, pos) then
			self.IsDragging = true
			self.LastMouseX = pos.X
		end
	end))

	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(input)
		if not self.IsDragging then return end
		local isMoveInput = (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)

		if isMoveInput then
			local pos = input.Position or UserInputService:GetMouseLocation()
			local deltaX = pos.X - self.LastMouseX
			self.LastMouseX = pos.X
			self.RotationY += deltaX * 0.4
			self:UpdateModelPosition()
		end
	end))

	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.IsDragging = false
		end
	end))
end

function ViewportComponent:Clear()
	if self.ResizeConnection then
		self.ResizeConnection:Disconnect()
		self.ResizeConnection = nil
	end

	if self.WorldModel then
		self.WorldModel:ClearAllChildren()
	end

	self.Model = nil
	self.CurrentOptions = nil
end

function ViewportComponent:Destroy()
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	table.clear(self.Connections)

	self:Clear()

	if self.Camera then self.Camera:Destroy() end
	if self.WorldModel then self.WorldModel:Destroy() end

	setmetatable(self, nil)
end

return ViewportComponent