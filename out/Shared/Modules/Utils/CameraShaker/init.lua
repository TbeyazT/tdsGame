local RunService = game:GetService("RunService")
local Physics = require(script.PhysicsModule)

local camera = {}
camera.__index = camera

local indexes = {}
local function update(v, dt)
	dt *= 100
	local x, y, z = v.recoil.x.p(), v.recoil.y.p(), v.recoil.z.p()
	x, y, z = x * dt, y * dt, z

	v.current.CFrame = v.current.CFrame * CFrame.Angles(x, y, z)
end

function camera.new(setting)
	local nCam = {}
	nCam.current = workspace.CurrentCamera
	nCam.angles = {}
	nCam.angles.x = 0
	nCam.angles.y = 0
	nCam.angles.z = 0
	nCam.recoil = {}
	nCam.recoil.x = Physics.spring.new{d=setting.RecoilDamper;s=setting.RecoilSpeed;}
	nCam.recoil.y = Physics.spring.new{d=setting.RecoilDamper;s=setting.RecoilSpeed;}
	nCam.recoil.z = Physics.spring.new{d=setting.RecoilDamper;s=setting.RecoilSpeed;}

	table.insert(indexes, nCam)
	return setmetatable(nCam,camera)
end

function camera:accelerate(x,y,z)
	self.recoil.x.impulse(x)
	self.recoil.y.impulse(y)
	self.recoil.z.impulse(z)
end

function camera:accelerateXY(x,y)
	self.recoil.x.impulse(x)
	self.recoil.y.impulse(y)
end

function camera:disconnect()
	for i,v in pairs(indexes) do
		if v == self then
			table.remove(indexes, i)
			self = nil
			
			break
		end
	end
end

RunService:BindToRenderStep("RecoilCam", 2000, function(dt)
	for _,v in pairs(indexes) do
		update(v, dt)
	end
end)

return camera