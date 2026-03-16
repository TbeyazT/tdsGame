local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages.Signal)

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local InputClass = {}
InputClass.__index = InputClass

function InputClass.new()
	local self = setmetatable({}, InputClass)

	self.OnClick = Signal.new()
	self.InputBegan = Signal.new()
	self.InputEnded = Signal.new()
	self.OnThumbstick = Signal.new()
	self.OnTouchMoved = Signal.new()
	self.OnHover = Signal.new()

	self.LastMobileClick = tick()
	self.MobileClickDebounce = 0.1
	self.HoveredInstance = nil

	self._connections = {}

	self:InitHoverDetection()
	self:InitKeybinds()

	return self
end

function InputClass:GetMousePosition2D()
	local mousePos = UserInputService:GetMouseLocation()
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local x = mousePos.X / viewportSize.X
	local y = mousePos.Y / viewportSize.Y
	return Vector2.new(x, y)
end

function InputClass:GetMouseWorldRay(BlackList)
	local screenMousePos = UserInputService:GetMouseLocation()
	local unitRay = Camera:ViewportPointToRay(screenMousePos.X, screenMousePos.Y)

	local filterTable = {}

	if LocalPlayer.Character then
		table.insert(filterTable, LocalPlayer.Character)
	end

	if BlackList then
		if typeof(BlackList) == "table" then
			for _, item in ipairs(BlackList) do
				table.insert(filterTable, item)
			end
		else
			table.insert(filterTable, BlackList)
		end
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = filterTable
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	return workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
end

function InputClass:IsMobile()
	return UserInputService.TouchEnabled 
end

function InputClass:IsPC()
	return not UserInputService.TouchEnabled
end

function InputClass:HasKeyboard()
	return UserInputService.KeyboardEnabled
end

function InputClass:InitHoverDetection()
	local conn = RunService.RenderStepped:Connect(function()
		local result = self:GetMouseWorldRay({})
		local hit = result and result.Instance or nil

		if hit ~= self.HoveredInstance then
			self.HoveredInstance = hit
			self.OnHover:Fire(hit)
		end
	end)
	
	table.insert(self._connections, conn)
end

function InputClass:InitKeybinds()
	local conn1 = UserInputService.InputBegan:Connect(function(input, gpe)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.OnClick:Fire("Mouse", input, gpe)
		end

		if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.Gamepad1 then
			self.InputBegan:Fire(input.KeyCode, gpe)
		end
	end)

	local conn2 = UserInputService.InputEnded:Connect(function(input, gpe)
		if gpe then return end

		if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.Gamepad1 then
			self.InputEnded:Fire(input.KeyCode, gpe)
		end
	end)

	local conn3 = UserInputService.TouchTap:Connect(function(touchPositions, gpe)
		if tick() - self.LastMobileClick > self.MobileClickDebounce then
			self.LastMobileClick = tick()
			self.OnClick:Fire("Touch", touchPositions, gpe)
		end
	end)

	local conn4 = UserInputService.InputChanged:Connect(function(input, gpe)
		if gpe then return end

		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.Thumbstick1 or input.KeyCode == Enum.KeyCode.Thumbstick2 then
				self.OnThumbstick:Fire(input.KeyCode, input.Position)
			end
		end

		if input.UserInputType == Enum.UserInputType.Touch then
			self.OnTouchMoved:Fire(input.Position)
		end
	end)
	
	table.insert(self._connections, conn1)
	table.insert(self._connections, conn2)
	table.insert(self._connections, conn3)
	table.insert(self._connections, conn4)
end

function InputClass:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	table.clear(self._connections)

	self.OnClick:Destroy()
	self.InputBegan:Destroy()
	self.InputEnded:Destroy()
	self.OnThumbstick:Destroy()
	self.OnTouchMoved:Destroy()
	self.OnHover:Destroy()
end

return InputClass