--[[
	// FileName: MobileButtonComponent.lua
	// Updated for React Integration + Visuals + Images
	// @TbeyazT 2025
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 5)

local ScreenGui = PlayerGui:WaitForChild("MainGui", 10) or Instance.new("ScreenGui")
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Name = "MainGui"
if not PlayerGui:FindFirstChild("MainGui") then
	ScreenGui.Parent = PlayerGui
end

local ParentFrame = ScreenGui:WaitForChild("MobileButtons", 10) or Instance.new("Frame")
ParentFrame.Size = UDim2.fromScale(1, 1)
ParentFrame.BackgroundTransparency = 1
ParentFrame.Name = "MobileButtons"
if not ScreenGui:FindFirstChild("MobileButtons") then
	ParentFrame.Parent = ScreenGui
end

local function FrameComponent(props)
	local isPressed, setIsPressed = React.useState(false)

	local currentScale = isPressed and 0.9 or 1.0
	
	local hasImage = props.Image and props.Image ~= ""
	
	return React.createElement("Frame", {
		Position = props.Position or UDim2.new(0.94, 0, 0.60, 0),
		Size = props.Size or UDim2.new(0.046, 0, 0.088, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30), 
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Name = props.Name or "Frame",
		ZIndex = 10,
	}, {
		React.createElement("UICorner", {
			CornerRadius = UDim.new(1, 0), 
		}),
		
		React.createElement("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 2,
			Transparency = 0.5, 
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		React.createElement("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 80, 80)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 10)),
			})
		}),
		
		React.createElement("UIScale", {
			Scale = currentScale,
		}),
		
		React.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1.0, 
		}),

		hasImage and React.createElement("ImageLabel", {
			Size = UDim2.fromScale(0.65, 0.65),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.Image,
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 12,
		}),

		(not hasImage) and React.createElement("TextLabel", {
			Text = props.Text or "",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 18,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			TextWrapped = true,
			TextScaled = true,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 12,
		}),
		
		React.createElement("ImageButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Name = "TouchTarget",
			ZIndex = 15,
			
			[React.Event.InputBegan] = function(rbx, input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					setIsPressed(true)
					if props.OnClick then
						props.OnClick()
					end
				end
			end,
			
			[React.Event.InputEnded] = function(rbx, input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					setIsPressed(false)
				end
			end,
			
			[React.Event.MouseLeave] = function()
				setIsPressed(false)
			end
		}, {
			React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
	})
end

local updateReactState = nil 

local function ButtonContainer()
	local buttons, setButtons = React.useState({})

	React.useEffect(function()
		updateReactState = setButtons
		return function()
			updateReactState = nil
		end
	end, {})

	local children = {}
	
	for actionName, data in pairs(buttons) do
		children[actionName] = React.createElement(FrameComponent, {
			Name = actionName,
			Position = data.Position,
			Size = data.Size,
			Text = data.Text,
			Image = data.Image,
			OnClick = data.Callback
		})
	end

	return React.createElement(React.Fragment, {}, children)
end

local root = ReactRoblox.createRoot(ParentFrame)
root:render(React.createElement(ButtonContainer))

--// Module Logic
local MobileButtonComponent = {}
MobileButtonComponent.__index = MobileButtonComponent

local ActiveButtonData = {} 

local function RefreshReact()
	if updateReactState then
		local newData = table.clone(ActiveButtonData)
		updateReactState(newData)
	end
end

export type MobileButton = {
	ActionName: string,
	SetText: (string) -> (),
	SetImage: (string) -> (),
	Destroy: (MobileButton) -> (),
}

function MobileButtonComponent.CreateActionButton(
	actionName: string,
	callback: () -> (),
	position: UDim2?,
	size: UDim2?,
	text: string?,
	image: string?
): MobileButton
	
	local self = setmetatable({}, MobileButtonComponent)
	self.ActionName = actionName
	
	if image and tonumber(image) then
		image = "rbxassetid://" .. tostring(image)
	end

	ActiveButtonData[actionName] = {
		Position = position or UDim2.new(0.72, 0, 0.494, 0),
		Size = size or UDim2.new(0.15, 0, 0.15, 0),
		Text = text or "",
		Image = image or nil,
		Callback = callback
	}

	RefreshReact()
	return self
end

function MobileButtonComponent:SetText(text: string)
	if ActiveButtonData[self.ActionName] then
		local oldData = ActiveButtonData[self.ActionName]
		ActiveButtonData[self.ActionName] = {
			Position = oldData.Position,
			Size = oldData.Size,
			Callback = oldData.Callback,
			Image = oldData.Image,
			Text = text 
		}
		RefreshReact()
	end
end

function MobileButtonComponent:SetImage(imageId: string)
	if ActiveButtonData[self.ActionName] then
		local oldData = ActiveButtonData[self.ActionName]
		
		if imageId and tonumber(imageId) then
			imageId = "rbxassetid://" .. tostring(imageId)
		end
		
		ActiveButtonData[self.ActionName] = {
			Position = oldData.Position,
			Size = oldData.Size,
			Callback = oldData.Callback,
			Text = oldData.Text,
			Image = imageId
		}
		RefreshReact()
	end
end

function MobileButtonComponent:Destroy()
	if ActiveButtonData[self.ActionName] then
		ActiveButtonData[self.ActionName] = nil
		RefreshReact()
	end
end

function MobileButtonComponent.DestroyActionButton(actionName: string)
	if ActiveButtonData[actionName] then
		ActiveButtonData[actionName] = nil
		RefreshReact()
	end
end

function MobileButtonComponent.DestroyAllActionButtons()
	table.clear(ActiveButtonData)
	RefreshReact()
end

return MobileButtonComponent