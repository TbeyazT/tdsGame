local PointerModule = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages", 20)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

-- Configuration Constants
local CONFIG = {
	TweenTime = 0.8,
	TweenStyle = Enum.EasingStyle.Quint,
	TweenDirection = Enum.EasingDirection.Out,
	
	-- Spotlight specific configurations
	OverlayColor = Color3.fromRGB(0, 0, 0),
	OverlayTransparency = 0.5,
	SpotlightPadding = 12, -- Adds a bit of space around the highlighted UI
}

--=========================================
-- Helper Math Functions
--=========================================
local function getExactProperties(parent, target, anchor)
	local parentPos = parent.AbsolutePosition
	local targetPos = target.AbsolutePosition
	local targetSize = target.AbsoluteSize
	
	local padding = CONFIG.SpotlightPadding

	-- Calculate precise pixel size
	local sizeX = targetSize.X + padding
	local sizeY = targetSize.Y + padding
	local finalSize = UDim2.fromOffset(sizeX, sizeY)

	-- Calculate precise position relative to the parent frame
	local relativeTopLeftX = (targetPos.X - parentPos.X) - (padding / 2)
	local relativeTopLeftY = (targetPos.Y - parentPos.Y) - (padding / 2)

	-- Shift position based on the Pointer's AnchorPoint to perfectly center it
	local finalX = relativeTopLeftX + (anchor.X * sizeX)
	local finalY = relativeTopLeftY + (anchor.Y * sizeY)
	local finalPosition = UDim2.fromOffset(finalX, finalY)

	return finalPosition, finalSize
end

local function shortestRotation(current, target)
	local diff = (target - current) % 360
	if diff > 180 then diff -= 360 end
	return current + diff
end

--=========================================
-- React Component
--=========================================
local function PointerComponent(props)
	local frameRef = React.useRef(nil)
	local strokeRef = React.useRef(nil)
	
	local tweenRef = React.useRef(nil)
	local strokeTweenRef = React.useRef(nil)

	React.useEffect(function()
		local frame = frameRef.current
		local stroke = strokeRef.current
		local target = props.target
		if not frame or not stroke then return end

		local function updatePointer()
			local frameGoal = {}
			local strokeGoal = {}
			local parent = frame.Parent

			if target and parent then
				local newPos, newSize = getExactProperties(parent, target, frame.AnchorPoint)
				
				frameGoal = {
					Position = newPos,
					Size = newSize,
					Rotation = shortestRotation(frame.Rotation, target.AbsoluteRotation)
				}
				strokeGoal = { Transparency = CONFIG.OverlayTransparency }
			else
				frameGoal = {
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(5, 5), 
					Rotation = math.floor((frame.Rotation / 180) + 0.5) * 180
				}
				strokeGoal = { Transparency = 1 }
			end

			local tweenInfo = TweenInfo.new(CONFIG.TweenTime, CONFIG.TweenStyle, CONFIG.TweenDirection)

			if tweenRef.current then tweenRef.current:Cancel() end
			if strokeTweenRef.current then strokeTweenRef.current:Cancel() end

			tweenRef.current = TweenService:Create(frame, tweenInfo, frameGoal)
			tweenRef.current:Play()
			
			strokeTweenRef.current = TweenService:Create(stroke, tweenInfo, strokeGoal)
			strokeTweenRef.current:Play()
		end

		local connections = {}
		if target then
			table.insert(connections, target:GetPropertyChangedSignal("AbsolutePosition"):Connect(updatePointer))
			table.insert(connections, target:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePointer))
			table.insert(connections, target:GetPropertyChangedSignal("AbsoluteRotation"):Connect(updatePointer))
			
			if frame.Parent then
				table.insert(connections, frame.Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePointer))
				table.insert(connections, frame.Parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(updatePointer))
			end
		end

		updatePointer()

		return function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
			if tweenRef.current then tweenRef.current:Cancel() end
			if strokeTweenRef.current then strokeTweenRef.current:Cancel() end
		end
	end, {props.target})

	return React.createElement("Frame", {
		ref = frameRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(5, 5),
		Active = false,
	}, {
		UICorner = React.createElement("UICorner", { 
			CornerRadius = UDim.new(0, 8),
		}),
		
		UIStroke = React.createElement("UIStroke", {
			ref = strokeRef,
			Color = CONFIG.OverlayColor,
			Transparency = 1,
			Thickness = 5000,
			-- Ensures the stroke explicitly draws outward so it never squishes the hole!
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border, 
		})
	})
end

--=========================================
-- Module API & Initialization
--=========================================
local player = Players.LocalPlayer

-- Fix: We create a brand new ScreenGui specifically to ignore the Mobile Notch Safe Areas
local pointerGui = Instance.new("ScreenGui")
pointerGui.Name = "PointerOverlayGui"
pointerGui.IgnoreGuiInset = true -- Ignore the top bar
pointerGui.ScreenInsets = Enum.ScreenInsets.None -- Ignore the mobile notch to fix the black edges!
pointerGui.DisplayOrder = 100 -- Force it to render above literally everything else
pointerGui.Parent = player.PlayerGui

local rootFrame = Instance.new("Frame")
rootFrame.Name = "PointerRoot"
rootFrame.Size = UDim2.new(1, 0, 1, 0)
rootFrame.Position = UDim2.new(0, 0, 0, 0)
rootFrame.BackgroundTransparency = 1
rootFrame.Parent = pointerGui

-- Create a React Root inside our new full-screen GUI
local root = ReactRoblox.createRoot(rootFrame)

function PointerModule:MoveIt(targetFrame)
	root:render(
		React.createElement(PointerComponent, {
			target = targetFrame
		})
	)
end

function PointerModule:Hide()
	root:render(
		React.createElement(PointerComponent, {
			target = nil
		})
	)
end

return PointerModule