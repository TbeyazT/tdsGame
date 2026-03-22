--!strict
local RunService = game:GetService("RunService")

export type SpringType = number | Vector2 | Vector3 | Color3 | UDim2

export type SpringOptions = {
	Mass: number?,
	Tension: number?,
	Friction: number?
}

export type Spring = {
	Target: SpringType,
	Position: SpringType,
	Velocity: SpringType,
	Mass: number,
	Tension: number,
	Friction: number,

	SetDamper: (self: Spring, frequency: number, dampingRatio: number) -> (),
	Update: (self: Spring, dt: number) -> SpringType,
	Impulse: (self: Spring, velocity: SpringType) -> (),
	Attach: (self: Spring, instance: Instance, property: string) -> RBXScriptConnection,
	Detach: (self: Spring, instance: Instance) -> (),
	Destroy: (self: Spring) -> ()
}

local SpringModule = {}

local DEFAULT_MASS = 1
local DEFAULT_TENSION = 150
local DEFAULT_FRICTION = 15

local UPDATE_EVENT = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat

local function toInternal(val: any, typeName: string): any
	if typeName == "Color3" then
		return Vector3.new(val.R, val.G, val.B)
	elseif typeName == "UDim2" then
		return {val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset}
	end
	return val
end

local function toExternal(val: any, typeName: string): any
	if typeName == "Color3" then
		return Color3.new(math.clamp(val.X, 0, 1), math.clamp(val.Y, 0, 1), math.clamp(val.Z, 0, 1))
	elseif typeName == "UDim2" then
		return UDim2.new(val[1], val[2], val[3], val[4])
	end
	return val
end

local function getZero(typeName: string): any
	if typeName == "number" then return 0
	elseif typeName == "Vector2" then return Vector2.zero
	elseif typeName == "Vector3" then return Vector3.zero
	elseif typeName == "Color3" then return Vector3.zero
	elseif typeName == "UDim2" then return {0, 0, 0, 0}
	end
	error("Unsupported spring type: " .. typeName)
end

local SpringClass = {}

function SpringClass:SetDamper(frequency: number, dampingRatio: number)
	self.Tension = (frequency * 2 * math.pi)^2 * self.Mass
	self.Friction = dampingRatio * 2 * math.sqrt(self.Tension * self.Mass)
end

function SpringClass:Impulse(velocity: SpringType)
	local vel = toInternal(velocity, self.Type)
	if self.Type == "UDim2" then
		for i = 1, 4 do
			self._velocity[i] += vel[i]
		end
	else
		self._velocity += vel
	end
end

function SpringClass:Update(dt: number): SpringType
	local steps = math.ceil(dt / 0.016)
	local subDt = dt / steps

	local typeName = self.Type
	local pos = self._position
	local vel = self._velocity
	local target = self._target
	local m, t, f = self.Mass, self.Tension, self.Friction

	if typeName == "number" or typeName == "Vector2" or typeName == "Vector3" or typeName == "Color3" then
		for _ = 1, steps do
			local force = (target - pos) * t - vel * f
			vel += (force / m) * subDt
			pos += vel * subDt
		end
	elseif typeName == "UDim2" then
		for _ = 1, steps do
			for i = 1, 4 do
				local force = (target[i] - pos[i]) * t - vel[i] * f
				vel[i] += (force / m) * subDt
				pos[i] += vel[i] * subDt
			end
		end
	end

	self._position = pos
	self._velocity = vel

	return toExternal(pos, typeName)
end

function SpringClass:Attach(instance: Instance, property: string): RBXScriptConnection
	self:Detach(instance)

	local connection
	connection = UPDATE_EVENT:Connect(function(dt)
		if not instance or not instance.Parent then
			self:Detach(instance)
			return
		end

		local newPosition = self:Update(dt)
		
		local success = pcall(function()
			(instance :: any)[property] = newPosition
		end)
		
		if not success then
			self:Detach(instance)
		end
	end)

	self._connections[instance] = connection
	return connection
end

function SpringClass:Detach(instance: Instance)
	if self._connections[instance] then
		self._connections[instance]:Disconnect()
		self._connections[instance] = nil
	end
end

function SpringClass:Destroy()
	for inst, conn in pairs(self._connections) do
		conn:Disconnect()
	end
	table.clear(self._connections)
end

function SpringModule.new(initialValue: SpringType, options: SpringOptions?): Spring
	local typeName = typeof(initialValue)

	local state = {
		Type = typeName,
		Mass = options and options.Mass or DEFAULT_MASS,
		Tension = options and options.Tension or DEFAULT_TENSION,
		Friction = options and options.Friction or DEFAULT_FRICTION,
		
		_target = toInternal(initialValue, typeName),
		_position = toInternal(initialValue, typeName),
		_velocity = getZero(typeName),
		_connections = {},
	}

	return setmetatable(state, {
		__index = function(self, key)
			if key == "Target" then
				return toExternal(self._target, self.Type)
			elseif key == "Position" then
				return toExternal(self._position, self.Type)
			elseif key == "Velocity" then
				return toExternal(self._velocity, self.Type)
			else
				return SpringClass[key]
			end
		end,
		__newindex = function(self, key, value)
			if key == "Target" then
				self._target = toInternal(value, self.Type)
			elseif key == "Position" then
				self._position = toInternal(value, self.Type)
			elseif key == "Velocity" then
				self._velocity = toInternal(value, self.Type)
			elseif key == "Mass" or key == "Tension" or key == "Friction" then
				rawset(self, key, value)
			else
				error("Cannot set unknown property '" .. tostring(key) .. "' on Spring")
			end
		end
	}) :: any
end

return SpringModule