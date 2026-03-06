local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

-- Make sure this Signal class actually has a .Destroy method!
local Signal = require(Packages.Signal) 

local TweenComponent = {}
TweenComponent.__index = TweenComponent

export type Tween = {
	Connection: RBXScriptConnection?,
	Playing: boolean,
	Elapsed: number,
	Duration: number,
	Easing: (number) -> number,
	Step: (number) -> (),
	Completed: any, -- Changed to any to support Signal
	Play: (Tween) -> (),
	Stop: (Tween) -> (),
	Destroy: (Tween) -> (),
}

-- default easing (linear)
local function linear(t: number): number
	return t
end

function TweenComponent.new(duration: number, stepCallback: (alpha: number) -> (), easing: ((number) -> number)?): Tween
	local self = setmetatable({}, TweenComponent)

	self.Duration = duration
	self.Step = stepCallback
	self.Elapsed = 0
	self.Easing = easing or linear
	self.Playing = false
	self.Completed = Signal.new()

	return self
end

function TweenComponent:Play()
	if self.Playing then return end
	self.Playing = true
	self.Elapsed = 0
	
	local event = RunService:IsServer() and RunService.Heartbeat or RunService.RenderStepped

	self.Connection = event:Connect(function(dt)
		self.Elapsed += dt

		-- Optimization: Calculate alpha once
		local alpha = 1
		if self.Duration > 0 then
			alpha = math.clamp(self.Elapsed / self.Duration, 0, 1)
		end

		-- Safety check: Ensure Step still exists before calling
		if self.Step then
			self.Step(self.Easing(alpha))
		end

		if self.Elapsed >= self.Duration then
			self:Stop()
			-- Safety check: Ensure Completed still exists
			if self.Completed then
				self.Completed:Fire()
			end
		end
	end)
end

function TweenComponent:Stop()
	self.Playing = false
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

function TweenComponent:Destroy()
	self:Stop()

	if self.Completed then
		if self.Completed.Destroy then
			self.Completed:Destroy()
		elseif self.Completed.DisconnectAll then
			self.Completed:DisconnectAll()
		end
		self.Completed = nil
	end

	self.Step = nil 
	self.Easing = nil

	setmetatable(self, nil)
end

return TweenComponent