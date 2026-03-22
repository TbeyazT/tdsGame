--!strict
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Dumpster = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Dumpster'))
local AnimationComponent = require(script.Parent.Parent:FindFirstChild('Components'):FindFirstChild('AnimationComponent'))

local LeftScreenClass = {
    Name = script.Name,
    _dump = nil :: any,
    _currentFrameComponent = nil :: any,
    
    _target = nil :: Instance?, 
    _originalPositions = {} :: { [GuiObject]: UDim2 },
}

local function initXButton(self, frame: GuiObject, frameComponent: any)
    local xButton = frame:FindFirstChild("Close", true)

    if xButton and xButton:IsA("GuiButton") then
        local xAnim = self._dump:Construct(AnimationComponent, xButton)
        
        xAnim:Init(Enum.KeyCode.X, function()
            if frameComponent.IsOpen then
                frameComponent:Visible(false)
                
                if self._currentFrameComponent == frameComponent then
                    self._currentFrameComponent = nil
                    
                    self:OpenScreenFrames()
                end
            end
        end)
    end
end

function LeftScreenClass:GetOffscreenPosition(frame: GuiObject): UDim2
    local pos = frame.Position
    local size = frame.Size

    local centerX = pos.X.Scale + size.X.Scale / 2
    local centerY = pos.Y.Scale + size.Y.Scale / 2

    local sides: { [string]: number } = {
        Left = centerX, 
        Right = 1 - centerX, 
        Top = centerY, 
        Bottom = 1 - centerY 
    }

    local closestSide = "Left"
    for side, dist in pairs(sides) do
        if dist < sides[closestSide] then
            closestSide = side
        end
    end

    if closestSide == "Left" then
        return UDim2.new(-size.X.Scale - 0.1, 0, pos.Y.Scale, 0)
    elseif closestSide == "Right" then
        return UDim2.new(1 + size.X.Scale + 0.1, 0, pos.Y.Scale, 0)
    elseif closestSide == "Top" then
        return UDim2.new(pos.X.Scale, 0, -size.Y.Scale - 0.1, 0)
    elseif closestSide == "Bottom" then
        return UDim2.new(pos.X.Scale, 0, 1 + size.Y.Scale + 0.1, 0)
    end
    
    return UDim2.new(0, 0, 0, 0)
end

function LeftScreenClass:CacheOriginalPositions()
    if not self._target then return end
    
    for _, frame in pairs(CollectionService:GetTagged("ScreenFrames")) do
        if frame:IsA("GuiObject") and frame:IsDescendantOf(self._target) then
            if not self._originalPositions[frame] then
                self._originalPositions[frame] = frame.Position
            end
        end
    end
end

function LeftScreenClass:OpenScreenFrames()
    self:CacheOriginalPositions()
    
    for _, frame in pairs(CollectionService:GetTagged("ScreenFrames")) do
        if frame:IsA("GuiObject") and self._target and frame:IsDescendantOf(self._target) then
            local originalPos = self._originalPositions[frame]
            if originalPos then
                local tween = TweenService:Create(
                    frame, 
                    TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), 
                    {Position = originalPos}
                )
                tween:Play()
            end
        end
    end
end

function LeftScreenClass:CloseScreenFrames()
    self:CacheOriginalPositions()
    
    for _, frame in pairs(CollectionService:GetTagged("ScreenFrames")) do
        if frame:IsA("GuiObject") and self._target and frame:IsDescendantOf(self._target) then
            local offscreenPos = self:GetOffscreenPosition(frame)
            local tween = TweenService:Create(
                frame, 
                TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), 
                {Position = offscreenPos}
            )
            tween:Play()
        end
    end
end

function LeftScreenClass:Mount(target: Instance)
    self._dump = Dumpster.new()
    self._target = target 
    
    local LeftScreen = Assets.UIs:FindFirstChild(self.Name)
    
    if not LeftScreen then 
        return function() end 
    end

    local LeftScreenClone = LeftScreen:Clone() :: GuiObject
    LeftScreenClone.Parent = target
    self._dump:Add(LeftScreenClone)

    self:CacheOriginalPositions()

    for _, button in pairs(LeftScreenClone:GetChildren()) do
        if button:IsA("GuiButton") or button:IsA("Frame") then
            local targetValue = button:FindFirstChild("Type") or button:FindFirstChildWhichIsA("ObjectValue")
            
            if targetValue and targetValue:IsA("ObjectValue") and targetValue.Value then
                local originalTargetUI = targetValue.Value :: GuiObject
                
                local targetUIClone = originalTargetUI:Clone()
                targetUIClone.Parent = target
                targetUIClone.ZIndex = 3
                self._dump:Add(targetUIClone)

                local originalTargetPos = targetUIClone.Position
                local offscreenBottomPos = UDim2.new(originalTargetPos.X.Scale, originalTargetPos.X.Offset, 1.5, 0)
                
                targetUIClone.Position = offscreenBottomPos
                targetUIClone.Visible = false

                local frameComponent = {
                    IsOpen = false,
                    Visible = function(selfComponent, isVisible: boolean)
                        selfComponent.IsOpen = isVisible
                        if isVisible then
                            targetUIClone.Visible = true
                            TweenService:Create(targetUIClone, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
                                Position = originalTargetPos
                            }):Play()
                            if targetUIClone.Parent and targetUIClone.Parent:IsA("ScreenGui") then
                                local CenterFrame = targetUIClone.Parent:FindFirstChild("CenterScreen")
                                if CenterFrame and CenterFrame:IsA("GuiObject") then
                                    CenterFrame.Visible = true
                                end
                            end
                        else
                            local tween = TweenService:Create(targetUIClone, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
                                Position = offscreenBottomPos
                            })
                            tween:Play()
                            if targetUIClone.Parent and targetUIClone.Parent:IsA("ScreenGui") then
                                local CenterFrame = targetUIClone.Parent:FindFirstChild("CenterScreen")
                                if CenterFrame and CenterFrame:IsA("GuiObject") then
                                    CenterFrame.Visible = false
                                end
                            end
                            task.delay(0.4, function()
                                if not selfComponent.IsOpen then
                                    targetUIClone.Visible = false
                                end
                            end)
                        end
                    end
                }

                initXButton(self, targetUIClone, frameComponent)

                local animComponent = self._dump:Construct(AnimationComponent, button)
                local rotOptions = {10, -10}
                local rot = rotOptions[math.random(1, #rotOptions)]
                local display = button:FindFirstChild("Display")

                animComponent.OnHover = function()
                    if display then
                        TweenService:Create(display, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            Rotation = rot
                        }):Play()
                    end
                end

                animComponent.OnUnHover = function()
                    if display then
                        TweenService:Create(display, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            Rotation = 0
                        }):Play()
                    end
                end

                animComponent:Init(nil, function()
                    if self._currentFrameComponent == frameComponent then
                        local isNowVisible = not frameComponent.IsOpen
                        frameComponent:Visible(isNowVisible)
                        
                        if not isNowVisible then
                            self._currentFrameComponent = nil
                            self:OpenScreenFrames()
                        end
                    else
                        if self._currentFrameComponent then
                            self._currentFrameComponent:Visible(false)
                        else
                            self:CloseScreenFrames()
                        end

                        frameComponent:Visible(true)
                        self._currentFrameComponent = frameComponent::any
                    end
                end)
            end
        end
    end

    return function()
        self:Destroy()
    end
end

function LeftScreenClass:Destroy()
    if self._dump then
        self._dump:Destroy()
        self._dump = nil :: any
    end
    
    self._currentFrameComponent = nil 
    self._target = nil
    table.clear(self._originalPositions)
end

return LeftScreenClass