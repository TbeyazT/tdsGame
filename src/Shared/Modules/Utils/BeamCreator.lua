--!strict
--!native
local BeamModule = {}

--// Services
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

--// Constants
local TERRAIN = Workspace.Terrain
local CAM = Workspace.CurrentCamera
local FLAT_VEC = Vector3.new(1, 1, 0) -- Pre-allocated for optimization
local EPSILON = 1e-5 -- Small number for floating point comparisons

--// Cache System (Object Pooling)
-- This prevents the game from creating/destroying Instances constantly
local Cache = {
	Beams = {} :: {Beam},
	Attachments = {} :: {Attachment},
}

local function GetFromCache(): (Beam, Attachment, Attachment)
	local beam = table.remove(Cache.Beams)
	local att0 = table.remove(Cache.Attachments)
	local att1 = table.remove(Cache.Attachments)

	if not beam then
		beam = Instance.new("Beam")
		beam.Segments = 16
		beam.TextureSpeed = 0
		beam.FaceCamera = true
		beam.Enabled = false -- Keep disabled until ready
	end
	
	if not att0 then att0 = Instance.new("Attachment") end
	if not att1 then att1 = Instance.new("Attachment") end

	beam.Attachment0 = att0
	beam.Attachment1 = att1
	
	-- Parent to Terrain (fastest rendering parent)
	att0.Parent = TERRAIN
	att1.Parent = TERRAIN
	beam.Parent = TERRAIN
	
	return beam, att0, att1
end

local function ReturnToCache(beam: Beam, att0: Attachment, att1: Attachment)
	beam.Enabled = false
	beam.Parent = nil
	att0.Parent = nil
	att1.Parent = nil
	
	table.insert(Cache.Beams, beam)
	table.insert(Cache.Attachments, att0)
	table.insert(Cache.Attachments, att1)
end

--// Math Helper
-- Returns point in Object Space relative to Camera
local function GetPointToObjectSpace(cf: CFrame, v3: Vector3): Vector3
	return cf:PointToObjectSpace(v3)
end

--// Main Logic
local function createBeamHandler(startPos: Vector3)
	-- Get instances from pool
	local beam, attach0, attach1 = GetFromCache()
	
	-- State variables
	local t0: number?
	local p0: Vector3?
	local v0: Vector3?
	
	local t1 = os.clock()
	local p1 = GetPointToObjectSpace(CAM.CFrame, startPos)
	local v1: Vector3? = nil

	beam.Transparency = NumberSequence.new(0)
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.Width0 = 0
	beam.Width1 = 0
	beam.Enabled = true

	local function update(w2: Vector3, size: number, bloom: number, brightness: number)
		local t2 = os.clock()
		local p2 = GetPointToObjectSpace(CAM.CFrame, w2)
		local v2: Vector3

		local dt = t2 - t1
		
		-- Avoid division by zero or extremely small updates
		if dt < EPSILON then return end 

		if t0 and p0 then
			-- Hermite spline acceleration approximation
			-- (p2 - p1) is deltaPos, (t2-t1) is deltaTime
			local term1 = (2 / dt) * (p2 - p1)
			local term2 = (p2 - p0 :: Vector3) / (t2 - t0 :: number)
			v2 = term1 - term2
		else
			-- First frame velocity approximation
			v2 = (p2 - p1) / dt
			v1 = v2
		end

		-- Cycle states
		t0, v0, p0 = t1, v1, p1
		t1, v1, p1 = t2, v2, p2

		-- Calculate Tangents for Beam Curve
		-- This smooths the jagged movement caused by network latency
		local vm0 = (v0 :: Vector3).Magnitude
		local vm1 = (v1 :: Vector3).Magnitude

		beam.CurveSize0 = (dt / 3) * vm0
		beam.CurveSize1 = (dt / 3) * vm1

		-- Update Attachment Positions (World Space)
		local camCF = CAM.CFrame
		attach0.Position = camCF * (p0 :: Vector3)
		attach1.Position = camCF * p1

		-- Align Attachments to Velocity (Tangent)
		if vm0 > EPSILON then
			attach0.Axis = camCF:VectorToWorldSpace((v0 :: Vector3) / vm0)
		end
		if vm1 > EPSILON then
			attach1.Axis = camCF:VectorToWorldSpace((v1 :: Vector3) / vm1)
		end

		-- Visual Calculations (Bloom/Glow)
		local dist0 = math.max(0, -(p0 :: Vector3).Z)
		local dist1 = math.max(0, -p1.Z)

		local width0 = size + bloom * dist0
		local width1 = size + bloom * dist1

		-- Calculate perceived length for brightness falloff
		local len = ((p1 - (p0 :: Vector3)) * FLAT_VEC).Magnitude
		local combinedWidth = width0 + width1
		
		-- Brightness math (avoids NaN if width is 0)
		local tr = 1
		if combinedWidth > EPSILON then
			tr = 1 - (4 * size * size) / (combinedWidth * (2 * len + combinedWidth)) * brightness
		end
		
		beam.Width0 = width0
		beam.Width1 = width1
		
		-- Optimization: Only create new NumberSequence if transparency changed significantly
		-- (Optional, but creating UserData every frame is expensive. 
		-- However, this specific math changes TR almost every frame, so we keep it simple).
		beam.Transparency = NumberSequence.new(math.clamp(tr, 0, 1))
	end

	local function remove()
		ReturnToCache(beam, attach0, attach1)
	end

	return beam, update, remove
end

--// Module Interface
type BeamConfig = {
	position: Vector3?,
	texture: string?,
	color: ColorSequence?,
	size: number?,
	bloom: number?,
	brightness: number?
}

function BeamModule.CreateBeam(config: BeamConfig)
	local settings = config or {}
	local startPos = settings.position or Vector3.zero
	
	local texture = settings.texture or "rbxassetid://2650195052"
	local color = settings.color or ColorSequence.new(Color3.fromRGB(255, 149, 78))
	local size = settings.size or 0.25
	local bloom = settings.bloom or 0.005
	local brightness = settings.brightness or 400

	local beam, updateBeam, removeBeam = createBeamHandler(startPos)
	
	beam.Texture = texture
	beam.Color = color
	beam.LightEmission = 1

	local controller = {}

	function controller.Stop()
		removeBeam()
	end

	function controller.Update(newPosition: Vector3, newSize: number?, newBloom: number?, newBrightness: number?)
		updateBeam(
			newPosition, 
			newSize or size, 
			newBloom or bloom, 
			newBrightness or brightness
		)
	end

	return controller
end

return BeamModule