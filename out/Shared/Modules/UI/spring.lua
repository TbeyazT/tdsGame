--!strict
local RunService = game:GetService("RunService")

local Spring = {}
Spring.__index = Spring

export type Springable = number | Vector2 | Vector3 | Color3 | UDim2

export type SpringObject = {
	Target: Springable,
	Position: Springable,
	Velocity: Springable,
	Damping: number,
	Frequency: number,
	Stop: () -> (),
	
	_instance: Instance?,
	_property: string?,
	_connection: RBXScriptConnection?,
}

local ActiveSprings: { [number]: SpringObject } = {}
local NextId = 0

local function multiply(v: Springable, scalar: number): Springable
	if typeof(v) == "number" then return v * scalar end
	if typeof(v) == "Vector2" then return v * scalar end
	if typeof(v) == "Vector3" then return v * scalar end
	if typeof(v) == "Color3" then
		return Color3.new(v.R * scalar, v.G * scalar, v.B * scalar)
	end
	if typeof(v) == "UDim2" then
		return UDim2.new(v.X.Scale * scalar, v.X.Offset * scalar, v.Y.Scale * scalar, v.Y.Offset * scalar)
	end
	return v
end

local function add(a: Springable, b: Springable): Springable
	if typeof(a) == "number" and typeof(b) == "number" then return a + b end
	if typeof(a) == "Vector2" and typeof(b) == "Vector2" then return a + b end
	if typeof(a) == "Vector3" and typeof(b) == "Vector3" then return a + b end
	if typeof(a) == "Color3" and typeof(b) == "Color3" then
		return Color3.new(a.R + b.R, a.G + b.G, a.B + b.B)
	end
	if typeof(a) == "UDim2" and typeof(b) == "UDim2" then
		return UDim2.new(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
	end
	return a
end

local function subtract(a: Springable, b: Springable): Springable
	if typeof(a) == "number" and typeof(b) == "number" then return a - b end
	if typeof(a) == "Vector2" and typeof(b) == "Vector2" then return a - b end
	if typeof(a) == "Vector3" and typeof(b) == "Vector3" then return a - b end
	if typeof(a) == "Color3" and typeof(b) == "Color3" then
		return Color3.new(a.R - b.R, a.G - b.G, a.B - b.B)
	end
	if typeof(a) == "UDim2" and typeof(b) == "UDim2" then
		return UDim2.new(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
	end
	return a
end

function Spring.new(initialValue: Springable, damping: number?, frequency: number?): SpringObject
	local self = setmetatable({}, Spring)

	self.Target = initialValue
	self.Position = initialValue
	self.Velocity = multiply(initialValue, 0)
	self.Damping = damping or 1
	self.Frequency = frequency or 4
	
	return (self :: any) :: SpringObject
end

function Spring.Update(self: SpringObject, dt: number): Springable
	local d, f, g, p, v = self.Damping, self.Frequency * 2 * math.pi, self.Target, self.Position, self.Velocity
	local offset = subtract(p, g)
	local decay = math.exp(-d * f * dt)

	if d < 1 then
		local c = math.sqrt(1 - d * d)
		local i, j = math.cos(f * c * dt), math.sin(f * c * dt)
		self.Position = add(g, multiply(add(multiply(offset, i), multiply(add(v, multiply(offset, d * f)), j / (f * c))), decay))
		self.Velocity = multiply(subtract(multiply(v, i - j * (d / c)), multiply(offset, (f / c) * j)), decay)
	else
		local j = f * dt
		self.Position = add(g, multiply(add(multiply(offset, 1 + j), multiply(v, dt)), decay))
		self.Velocity = multiply(subtract(multiply(v, 1 - j), multiply(offset, f * j)), decay)
	end

	return self.Position
end

function Spring.Bind(self: SpringObject, instance: Instance, property: string)
	self:Stop() 
	
	self._instance = instance
	self._property = property
	
	local id = NextId
	NextId += 1
	ActiveSprings[id] = self
	
	self._connection = instance.Destroying:Connect(function()
		ActiveSprings[id] = nil
	end)
end

function Spring.Stop(self: SpringObject)
	if self._connection then self._connection:Disconnect() end
	for id, spring in pairs(ActiveSprings) do
		if spring == self then ActiveSprings[id] = nil break end
	end
end

function Spring.Impulse(self: SpringObject, velocity: Springable)
	self.Velocity = add(self.Velocity, velocity)
end

function Spring.SetTarget(self: SpringObject, target: Springable)
	self.Target = target
end

-- Global Heartbeat Loop
RunService.RenderStepped:Connect(function(dt: number)
	for id, spring in pairs(ActiveSprings) do
		if typeof(spring.Update) == "function" then
			local newValue = spring:Update(dt)
			if spring._instance and spring._property then
				-- Apply to UI
				(spring._instance :: any)[spring._property] = newValue
			end
		end
	end
end)

return Spring