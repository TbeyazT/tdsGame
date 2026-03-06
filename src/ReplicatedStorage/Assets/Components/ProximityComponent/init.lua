local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local AnimationComponent = require(Assets.Components.AnimationComponent)

local Signal = require(Packages.Signal)
-- local Easing = require(Assets.Modules.Easing) -- Unused in this snippet

local MainGui = PlayerGui:WaitForChild("MainGui",30)

local ProximityComponent = {}
ProximityComponent.__index = ProximityComponent

local PromptUI = script.Prompt

-- // SINGLETON / MANAGER VARIABLES //
local ActivePrompts = {} 
local CurrentFocusedPrompt = nil 
local GlobalConnection = nil 
local GlobalInputBegan = nil
local GlobalInputEnded = nil

-- // CONSTANTS //
local BAR_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local UI_SCALE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local UI_CLOSE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

export type ProximityObject = BasePart | Vector3 | Model

export type Proximity = {
	Active: boolean,
	IsInRange: boolean,
	Range: number,
	Root: ProximityObject,
	Target: ProximityObject,
	
	Entered: Signal.Signal, 
	Left: Signal.Signal,    
	Updated: Signal.Signal, 
	Triggered: Signal.Signal,
	
	Start: (Proximity) -> (),
	Stop: (Proximity) -> (),
	Destroy: (Proximity) -> (),
}

local function getPosition(obj: ProximityObject): Vector3?
	if typeof(obj) == "Vector3" then
		return obj
	elseif typeof(obj) == "Instance" then
		if obj:IsA("BasePart") then
			return obj.Position
		elseif obj:IsA("Model") then
			if obj.PrimaryPart then
				return obj.PrimaryPart.Position
			else
				return obj:GetPivot().Position
			end
		end
	end
	return nil
end

local function UpdateAllPrompts()
	local closestPrompt = nil
	local closestDistance = math.huge
	
	for _, prompt in pairs(ActivePrompts) do
		local rootPos = getPosition(prompt.Root)
		local targetPos = getPosition(prompt.Target)

		if rootPos and targetPos then
			local dist = (rootPos - targetPos).Magnitude
			
			if dist <= prompt.Range and dist < closestDistance then
				closestDistance = dist
				closestPrompt = prompt
			end
			
			prompt.CurrentDistance = dist
		else
			prompt:Stop()
		end
	end
	
	CurrentFocusedPrompt = closestPrompt

	for _, prompt in pairs(ActivePrompts) do
		if prompt == closestPrompt then
			prompt:Update(true, prompt.CurrentDistance)
		else
			prompt:Update(false, prompt.CurrentDistance or math.huge)
		end
	end
end

local function SetupGlobalConnections()
	if GlobalConnection then return end
	
	GlobalConnection = RunService.Heartbeat:Connect(UpdateAllPrompts)
	
	GlobalInputBegan = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if CurrentFocusedPrompt then
			CurrentFocusedPrompt:HandleInput(input, true)
		end
	end)
	
	GlobalInputEnded = UserInputService.InputEnded:Connect(function(input, gpe)
		if CurrentFocusedPrompt then
			CurrentFocusedPrompt:HandleInput(input, false)
		end
	end)
end

local function CheckConnections()
	if #ActivePrompts == 0 then
		if GlobalConnection then GlobalConnection:Disconnect() GlobalConnection = nil end
		if GlobalInputBegan then GlobalInputBegan:Disconnect() GlobalInputBegan = nil end
		if GlobalInputEnded then GlobalInputEnded:Disconnect() GlobalInputEnded = nil end
	end
end

function ProximityComponent.new(Data): Proximity
	local self: Proximity = setmetatable({}, ProximityComponent)

	self.Data = Data
	self.Root = Data.Root
	self.Target = Data.Target
	self.Range = Data.Range
	self.KeyCode = Data.KeyCode or Enum.KeyCode.E
	self.ActionText = Data.ActionText
	self.HoldDuration = Data.HoldDuration or 0.5
	
	self.Active = false
	self.IsInRange = false
	self.CurrentDistance = math.huge
	
	self.Holding = false
	self.HoldStart = 0
	
	self.UI = PromptUI:Clone()
	self.UI.Parent = MainGui
	self.UI.Adornee = nil
	self.UI.Enabled = false

	self.Frame = self.UI:FindFirstChildWhichIsA("Frame")
	self.Button = self.Frame:FindFirstChildWhichIsA("GuiButton")
	self.Bar = self.Button:FindFirstChild("Bar")
	
	-- Pre-set bar to empty
	if self.Bar then
		self.Bar.Size = UDim2.fromScale(1, 0)
		self.Bar.Visible = true
	end
	
	self.oriSize = self.Frame.Size

	if self.Button then
		self.ButtonClass = AnimationComponent.new(self.Button)
		self.ButtonClass:Init(nil)
		
		self.ButtonClass.OnMouseDown = function()
			if CurrentFocusedPrompt == self then
				self:HandleInteraction(true)
			end
		end

		self.ButtonClass.OnMouseUp = function()
			self:HandleInteraction(false)
		end
	end
	
	self.Entered = Signal.new()
	self.Left = Signal.new()
	self.Updated = Signal.new()
	self.Triggered = Signal.new()

	return self
end

function ProximityComponent:HandleInput(input, isBegin)
	if input.KeyCode == self.KeyCode then
		self:HandleInteraction(isBegin)
	end
end

function ProximityComponent:HandleInteraction(isBegin)
	if not self.Active or not self.IsInRange then return end
	
	if isBegin then
		if self.HoldDuration <= 0 then
			self.Triggered:Fire()
		else
			self.Holding = true
			self.HoldStart = os.clock()
		end
	else
		self.Holding = false
	end
end

function ProximityComponent:OpenUI()
	if self.CloseTween then self.CloseTween:Cancel() end
	if self.ScaleTween then self.ScaleTween:Cancel() end

	self.UI.Adornee = self.Root
	self.UI.Enabled = true
	self.IsInRange = true

	if self.Frame then
		if self.Frame.Size.X.Scale == 0 then
			self.Frame.Size = UDim2.fromScale(0,0)
		end
		
		self.ScaleTween = TweenService:Create(self.Frame, UI_SCALE_INFO, {
			Size = self.oriSize
		})
		self.ScaleTween:Play()
	end
end

function ProximityComponent:CloseUI()
	if self.ScaleTween then self.ScaleTween:Cancel() end
	if self.CloseTween then self.CloseTween:Cancel() end
	
	self.IsInRange = false

	if self.Frame then
		self.CloseTween = TweenService:Create(self.Frame, UI_CLOSE_INFO, {
			Size = UDim2.fromScale(0,0)
		})
		
		self.CloseTween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed then
				self.UI.Enabled = false
				self.UI.Adornee = nil
			end
		end)
		
		self.CloseTween:Play()
	else
		self.UI.Enabled = false
		self.UI.Adornee = nil
	end
end

function ProximityComponent:Update(isFocused: boolean, distance: number)
	local holdProgress = 0
	
	if isFocused then
		
		if not self.IsInRange then
			self.Entered:Fire()
			self:OpenUI()
		end
		
		if self.Holding then
			if self.BarDownTween then self.BarDownTween:Cancel() end
			
			local timeElapsed = os.clock() - self.HoldStart
			holdProgress = math.clamp(timeElapsed / self.HoldDuration, 0, 1)
			
			if self.Bar then
				self.Bar.Size = UDim2.new(1, 0, holdProgress, 0)
			end
			
			if timeElapsed >= self.HoldDuration then
				self.Triggered:Fire()
				self.Holding = false
				holdProgress = 0
				
				if self.Bar then self.Bar.Size = UDim2.fromScale(1, 0) end
			end
		else
			if self.Bar and self.Bar.Size.Y.Scale > 0 then
				self.BarDownTween = TweenService:Create(self.Bar, BAR_TWEEN_INFO, {
					Size = UDim2.new(1, 0, 0, 0)
				})
				self.BarDownTween:Play()
			end
		end

		local alpha = math.clamp(1 - (distance / self.Range), 0, 1)
		self.Updated:Fire(distance, alpha, holdProgress)

	else
		self.Holding = false 
		
		if self.IsInRange then
			self.Left:Fire()
			self:CloseUI()
			
			if self.Bar then
				self.Bar.Size = UDim2.fromScale(1, 0)
			end
		end
	end
end

function ProximityComponent:Start()
	if self.Active then return end
	self.Active = true
	
	table.insert(ActivePrompts, self)
	SetupGlobalConnections()
end

function ProximityComponent:SetRange(newRange: number)
	self.Range = newRange
end

function ProximityComponent:Stop()
	if not self.Active then return end
	self.Active = false
	self.Holding = false
	self.IsInRange = false
	
	self.UI.Enabled = false
	
	local index = table.find(ActivePrompts, self)
	if index then
		table.remove(ActivePrompts, index)
	end
	
	CheckConnections()
end

function ProximityComponent:Destroy()
	self:Stop()
	
	if self.Entered then self.Entered:Destroy() end
	if self.Left then self.Left:Destroy() end
	if self.Updated then self.Updated:Destroy() end
	if self.Triggered then self.Triggered:Destroy() end
	
	if self.UI then self.UI:Destroy() end
	if self.ButtonClass then self.ButtonClass:Destroy() end
	
	self.Root = nil
	self.Target = nil
	setmetatable(self, nil)
end

return ProximityComponent