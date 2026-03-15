debug.setmemorycategory(script.Name.." OHA")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PhysicsService    = game:GetService("PhysicsService")
local Players           = game:GetService("Players")
local TweenService	  = game:GetService("TweenService") 

local Packages = ReplicatedStorage:FindFirstChild("Packages")
local Shared = ReplicatedStorage:FindFirstChild("Shared")

local Framework = require(Shared.Framework)
local Dumpster = require(Packages.Dumpster)
local Signal = require(Packages.Signal)

local NPC_TAG = "NPC"
local COLLISION_GROUP_NAME = "NpcCollideable"
local PROJECTILE_GROUP_NAME = "Balls"

export type CharacterData = {
	Model: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	Animator: Animator?,
	Player: Player?,
	IsPlayer: boolean,
	Dumpster: any
}

local CharacterService = {}

function CharacterService:Init()
	self.ProfileService = Framework.Get("ProfileService")
	
	self._registry = {}

	self.CharacterAdded = Signal.new()
	self.CharacterRemoved = Signal.new()

	self:_setupCollisionGroups()
end

function CharacterService:Start()
	self.ProfileService:ObservePlayerAdded(function(player)
		player.CharacterAdded:Connect(function(character)
			self:RegisterCharacter(character, player)
		end)

		if player.Character then
			self:RegisterCharacter(player.Character, player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			self:UnregisterCharacter(player.Character)
		end
	end)

	CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(function(npc)
		self:RegisterCharacter(npc, nil) 
	end)

	for _, npc in ipairs(CollectionService:GetTagged(NPC_TAG)) do
		self:RegisterCharacter(npc, nil)
	end

	for _, Tower in pairs(ReplicatedStorage:GetDescendants()) do
		if Tower:FindFirstChild("Humanoid") then
			self:_applyCollisionGroup(Tower)
		end
	end
end

function CharacterService:_setupCollisionGroups()
	local success, err = pcall(function()
		PhysicsService:RegisterCollisionGroup(PROJECTILE_GROUP_NAME)
		PhysicsService:RegisterCollisionGroup(COLLISION_GROUP_NAME)
		
		PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP_NAME, COLLISION_GROUP_NAME, false)
		PhysicsService:CollisionGroupSetCollidable(PROJECTILE_GROUP_NAME, COLLISION_GROUP_NAME, false)
	end)
	
	if not success then
		warn("Collision Group Setup Error:", err)
	end
end

function CharacterService:_applyCollisionGroup(model)
	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = COLLISION_GROUP_NAME
		end
	end
end

function CharacterService:RegisterCharacter(model, player):CharacterData
	if self._registry[model] then return end

	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	local rootPart = model:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then
		return 
	end

	local dumpster = Dumpster.new()

	self:_applyCollisionGroup(model)

	dumpster:Connect(model.DescendantAdded, function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = COLLISION_GROUP_NAME
		end
	end)

	local container = {
		Model = model,
		Humanoid = humanoid,
		RootPart = rootPart,
		Animator = humanoid:FindFirstChild("Animator") or humanoid:WaitForChild("Animator", 5),
		Player = player,
		IsPlayer = (player ~= nil),
		Dumpster = dumpster
	}

	self._registry[model] = container
	
	dumpster:Connect(model.AncestryChanged, function(_, parent)
		if parent == nil then
			self:UnregisterCharacter(model)
		end
	end)

	dumpster:Connect(humanoid.Died, function()
	end)
	
	local healthScript = model:FindFirstChild("Health")
	if healthScript then
		healthScript:Destroy()
	end

	self.CharacterAdded:Fire(container)

	return container
end

function CharacterService:UnregisterCharacter(model)
	local container = self._registry[model]
	if container then
		container.Dumpster:Destroy()
		self._registry[model] = nil
		self.CharacterRemoved:Fire(model)
	end
end

function CharacterService:GetCharacter(target):CharacterData
	if not target then return nil end

	local model

	if target:IsA("Player") then
		model = target.Character
	elseif target:IsA("Model") then
		model = target
	elseif target:IsA("BasePart") then
		model = target.Parent
	end

	while model and not model:IsA("Model") and model.Parent ~= game do
		model = model.Parent
	end

	if model then
		return self._registry[model]
	end

	return nil
end

function CharacterService:PushCharacter(target, direction, speed, duration)
	local charData = self:GetCharacter(target)
	if not charData then return end

	local rootPart = charData.RootPart
	local humanoid = charData.Humanoid

	local attachment = Instance.new("Attachment")
	attachment.Name = "PushAttachment"
	attachment.Parent = rootPart

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "PushVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(100000, 0, 100000) 

	local flatVel = Vector3.new(direction.X, 0, direction.Z).Unit * speed
	velocity.VectorVelocity = flatVel

	rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity + Vector3.new(0, 25, 0) 

	velocity.Parent = attachment

	local oldAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local tweenInfo = TweenInfo.new(duration or 0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	
	local tween = TweenService:Create(velocity, tweenInfo, {
		VectorVelocity = Vector3.new(0, 0, 0)
	})
	
	tween:Play()

	task.delay(duration or 0.4, function()
		if attachment then attachment:Destroy() end
		if tween then tween:Destroy() end
		
		if humanoid and humanoid.Parent then
			humanoid.AutoRotate = oldAutoRotate
		end
	end)
end

return CharacterService