local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Net = require("@Shared/Net")
local Framework = require("@Shared/Framework")
local LabelComponent = require("@Shared/Components/LabelComponent")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MainGui = PlayerGui:WaitForChild("MainGui")
local notificationsFrame = MainGui.Notification
local TemplateNotification = notificationsFrame.Template

local TYPE_SPEED = 0.03
local LETTER_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FRAME_IN_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SCALE_IN_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SCALE_OUT_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local NotificationController = {
    Name = script.Name,
    ActiveNotifications = {},
    LayoutOrderCount = 0,
}

function NotificationController:Init()
    self.AudioController = Framework.Get("AudioService")
    self.ProfileService = Framework.Get("ProfileService")

    if not notificationsFrame:FindFirstChildWhichIsA("UIListLayout") then
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Padding = UDim.new(0, 5)
        layout.Parent = notificationsFrame
    end

    Net.Notify.On(function(data)
        self:SendNotification(data)
    end)
end

function NotificationController:SendNotification(Data)
    if not Data or not Data.Text then return end

    local notificationId = HttpService:GenerateGUID(false)
    local isCancelled = false
    local clone = TemplateNotification:Clone()

    self.LayoutOrderCount += 1
    clone.LayoutOrder = self.LayoutOrderCount
    clone.Parent = notificationsFrame
    clone.Visible = true
    clone.BackgroundTransparency = 1

    local textLabel = clone:FindFirstChild("TextLabel")
    if not textLabel then clone:Destroy() return end

    if Data.FrameScale then
        clone.Size = UDim2.fromScale(clone.Size.X.Scale * Data.FrameScale, clone.Size.Y.Scale * Data.FrameScale)
    end

    local uiScale = Instance.new("UIScale")
    uiScale.Scale = 0
    uiScale.Parent = clone

    local labelClass = nil
    local renderConnection = nil

    local function cleanup()
        if isCancelled then return end
        isCancelled = true
        self.ActiveNotifications[notificationId] = nil 
        
        if renderConnection then renderConnection:Disconnect() end
        if labelClass then labelClass:Destroy() end
        if clone then clone:Destroy() end
    end

    self.ActiveNotifications[notificationId] = cleanup

    task.spawn(function()
        TweenService:Create(clone, FRAME_IN_TWEEN, {BackgroundTransparency = 0}):Play()
        TweenService:Create(uiScale, SCALE_IN_TWEEN, {Scale = 1}):Play()

        task.wait(0.1)
        if isCancelled then return end

        if Data.UseRichAnimation then
            labelClass = LabelComponent.new(textLabel)
            labelClass.Changed:Connect(function()
                labelClass:InvisibleLetters()
            end)
            labelClass:SetText(Data.Text)

            if Data.UpdateCallback then
                renderConnection = RunService.RenderStepped:Connect(function(dt)
                    if isCancelled then return end
                    Data.UpdateCallback(labelClass, dt)
                end)
            end

            local letters = labelClass:GetLetters()
            for _, letterObj in ipairs(letters) do
                if isCancelled then return end

                local label = letterObj.Label
                local targetPosition = label.Position

                label.Position = targetPosition + UDim2.fromOffset(0, 10)
                label.Rotation = math.random(-15, 15)
                label.TextTransparency = 1

                if Data.TextColor then label.TextColor3 = Data.TextColor end

                TweenService:Create(label, LETTER_TWEEN, {
                    Position = targetPosition,
                    Rotation = 0,
                    TextTransparency = 0,
                }):Play()

                if self.AudioController then self.AudioController:PlaySound("Typewriter") end
                task.wait(TYPE_SPEED)
            end
        else
            textLabel.Text = Data.Text
            textLabel.MaxVisibleGraphemes = 0
            textLabel.TextTransparency = 0
            if Data.TextColor then textLabel.TextColor3 = Data.TextColor end

            for i = 1, utf8.len(Data.Text) do
                if isCancelled then return end
                textLabel.MaxVisibleGraphemes = i
                if self.AudioController then self.AudioController:PlaySound("Typewriter") end
                task.wait(TYPE_SPEED)
            end
        end

        task.wait(Data.Duration or 2)
        if isCancelled then return end

        local outInfo = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
        TweenService:Create(clone, outInfo, {BackgroundTransparency = 1}):Play()
        TweenService:Create(uiScale, SCALE_OUT_TWEEN, {Scale = 0}):Play()

        if labelClass then
            for _, letterObj in ipairs(labelClass:GetLetters()) do
                local label = letterObj.Label
                TweenService:Create(label, outInfo, {
                    TextTransparency = 1,
                    Position = label.Position - UDim2.fromOffset(0, 20)
                }):Play()
                task.wait(0.01)
            end
        else
            TweenService:Create(textLabel, outInfo, {
                TextTransparency = 1,
                Position = textLabel.Position - UDim2.fromOffset(0, 20)
            }):Play()
        end

        task.wait(0.4)
        cleanup()
    end)

    return notificationId
end

return NotificationController