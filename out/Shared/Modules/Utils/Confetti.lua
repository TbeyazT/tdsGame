local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ConfettiComponent = {}

local TempRandom = Random.new()
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local MainUI = PlayerGui:WaitForChild("MainGui")

function ConfettiComponent:Spawn(ConfettiAmount)
	task.spawn(function()
		local ConfettiFrames = {}
		local connection

		local random = TempRandom

		for i = 1, ConfettiAmount do
			local ConfettiFrame = Instance.new("Frame")
			ConfettiFrame.Size = UDim2.new(0.02, 0, 0.02, 0) -- Adjusted size slightly
			ConfettiFrame.SizeConstraint = Enum.SizeConstraint.RelativeXX -- Keeps them square regardless of screen shape
			ConfettiFrame.BackgroundColor3 = Color3.fromHSV(random:NextNumber(0, 1), 0.85, 1)
			ConfettiFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			
			-- Initial Position is handled in the loop, but we set a default here
			ConfettiFrame.Position = UDim2.new(0.5, 0, -0.1, 0) 
			ConfettiFrame.Parent = MainUI.full
			ConfettiFrame.Transparency = 1
			ConfettiFrame.ZIndex = 10
			
			task.spawn(function()
				task.wait(random:NextNumber(0, 0.2)) -- Slight stagger in fade-in
				TweenService:Create(ConfettiFrame, TweenInfo.new(0.4), {
					Transparency = 0
				}):Play()
			end)

			local StartingPositionX = random:NextNumber(-0.5, 0.5)
			-- We will use this to offset the start so they don't look like a flat sheet
			local StartingPositionY = random:NextNumber(0, 0.5) 
			local StartingRotation = random:NextNumber(0, 360)

			table.insert(ConfettiFrames, {
				Frame = ConfettiFrame,
				StartPosX = StartingPositionX,
				StartPosY = StartingPositionY, 
				Rotation = StartingRotation,
				Speed = random:NextNumber(2, 6), -- Slowed down slightly for realism
				RotSpeed = random:NextNumber(15, 25),
				SwaySpeed = random:NextNumber(2, 5), -- How fast it moves left/right
				SwayDist = random:NextNumber(0.02, 0.05), -- How far it moves left/right
				IsDestroyed = false
			})
		end

		local function IsOutOfView(frame)
			local positionY = frame.Position.Y.Scale
			return positionY > 1.1 -- Wait until it's fully off screen
		end

		local StartTime = os.clock()
		
		connection = RunService.RenderStepped:Connect(function()
			local ElapsedTime = os.clock() - StartTime
			local AllDestroyed = true

			for _, Confetti in ipairs(ConfettiFrames) do
				if not Confetti.IsDestroyed then
					-- Calculate Base Fall (Time * Speed)
					-- Subtract StartPosY so they spawn at different heights (negative Y)
					local FallDistance = (ElapsedTime / 10) * Confetti.Speed * 5
					local CurrentY = -Confetti.StartPosY + FallDistance
					
					local RotationLevel = ElapsedTime * Confetti.RotSpeed
					
					-- SINE WAVE: Creates the left/right flutter
					local SwayMath = math.sin(ElapsedTime * Confetti.SwaySpeed + Confetti.StartPosX) * Confetti.SwayDist

					if IsOutOfView(Confetti.Frame) then
						Confetti.Frame:Destroy()
						Confetti.IsDestroyed = true
					else
						AllDestroyed = false
						-- Apply Position:
						-- X: Base Center (0.5) + Random Offset + Sway
						-- Y: Current Calculated Y
						Confetti.Frame.Position = UDim2.new(
							0.5 + Confetti.StartPosX + SwayMath, 0, 
							CurrentY, 0
						)
						Confetti.Frame.Rotation = Confetti.Rotation + RotationLevel
					end
				end
			end

			if AllDestroyed then
				connection:Disconnect()
				ConfettiFrames = {}
			end
		end)
	end)
end

return ConfettiComponent