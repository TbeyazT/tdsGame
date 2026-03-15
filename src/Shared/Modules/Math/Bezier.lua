--!strict
-- Shared/Modules/Math/Bezier.lua

local Bezier = {}

-- Quadratic Bezier (3 Points: Start, Control, End)
-- 't' is the alpha/percentage along the line (0 to 1)
function Bezier.Quadratic(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	-- Formula: (1-t)^2 * p0 + 2(1-t)t * p1 + t^2 * p2
	-- Alternatively, using Roblox's built in Lerp for readability:
	local l1 = p0:Lerp(p1, t)
	local l2 = p1:Lerp(p2, t)
	return l1:Lerp(l2, t)
end

-- Cubic Bezier (4 Points: Start, Control 1, Control 2, End)
function Bezier.Cubic(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local l1 = Bezier.Quadratic(p0, p1, p2, t)
	local l2 = Bezier.Quadratic(p1, p2, p3, t)
	return l1:Lerp(l2, t)
end

-- Optional: Function to get a derivative (useful for finding the direction the curve is pointing)
function Bezier.GetQuadraticDerivative(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	return 2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)
end

return Bezier