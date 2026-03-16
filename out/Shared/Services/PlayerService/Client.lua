local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Bezier = require(script.Parent.Parent.Parent:FindFirstChild('Modules'):FindFirstChild('Math'):FindFirstChild('Bezier'))
local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local LocalPlayer = Players.LocalPlayer

local PlayerClient = {}

function PlayerClient:Init()
	self.EnemyService = Framework.Get("EnemyService")
	self.Utils = require(script.Parent.Utils)

	task.spawn(function()
		self:StartAttackLoop()
	end)
end

function PlayerClient:StartAttackLoop()
	while true do
		self:FireAttack()
		task.wait(0.3)
	end
end

function PlayerClient:FireAttack()
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then 
		return 
	end

	local p0 = character.HumanoidRootPart.Position

	local targetEnemyPart, targetEnemyID = self.Utils:GetNearestEnemy(p0)
	if not targetEnemyPart or not targetEnemyID then return end

	local expectedDamage = 25
	local clientEnemy = self.EnemyService:GetEnemy(targetEnemyID)
	if clientEnemy then
		clientEnemy:AddIncomingDamage(expectedDamage)
	end

	local midpoint = (p0 + targetEnemyPart.Position) / 2
	local p1 = midpoint + Vector3.new(0, math.random(15, 30), 0)

	local projectile = Assets.Models.ARROW:Clone()
	for _, value in projectile:GetDescendants() do
		if value:IsA("BasePart") then
			value.CanCollide = false
		end
	end
	projectile:PivotTo(CFrame.lookAt(p0, p1))
	projectile.Parent = workspace.Debris

	local duration = 0.5
	local elapsed = 0
	
	local targetPos = targetEnemyPart.Position 

	local connection
	connection = RunService.RenderStepped:Connect(function(deltaTime)
		elapsed += deltaTime
		local t = elapsed / duration

		if targetEnemyPart and targetEnemyPart.Parent then
			targetPos = targetEnemyPart.Position
		end

		if t >= 1 then
			t = 1
			connection:Disconnect()
			projectile:Destroy()
			
			Net.DamageEnemy.Fire(targetEnemyID)

			local enemy = self.EnemyService:GetEnemy(targetEnemyID)
			if enemy then
				enemy:RemoveIncomingDamage(expectedDamage) 
				
				local model = enemy.Model
				if model then
					local oldHighlight = model:FindFirstChild("DamageHighlight")
					if oldHighlight then
						oldHighlight:Destroy()
					end
					
					local highlight = Instance.new("Highlight")
					highlight.Name = "DamageHighlight"
					highlight.FillColor = Color3.new(1, 0, 0)
					highlight.FillTransparency = 0.7
					highlight.OutlineColor = Color3.new(1, 1, 1)
					highlight.OutlineTransparency = 0.2
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Parent = model
					
					local fadeTween = TweenService:Create(highlight, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
						FillTransparency = 1,
						OutlineTransparency = 1
					})
					
					fadeTween.Completed:Connect(function()
						highlight:Destroy()
					end)
					fadeTween:Play()
				end
			end
			
			return
		end

		local currentPos = Bezier.Quadratic(p0, p1, targetPos, t)
		local nextPos = Bezier.Quadratic(p0, p1, targetPos, math.min(t + 0.01, 1))

		if currentPos ~= nextPos then
			projectile:PivotTo(CFrame.lookAt(currentPos, nextPos))
		else
			projectile:PivotTo(CFrame.new(currentPos))
		end
	end)
end

return PlayerClient