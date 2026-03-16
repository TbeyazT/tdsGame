local Framework = require("@Shared/Framework")

local Utils = {
    EnemyService = Framework.Get("EnemyService")
}

function Utils:GetNearestEnemy(originPos)
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if not enemiesFolder then return nil, nil end

	local nearestEnemy = nil
	local nearestID = nil
	local shortestDistance = 30

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		local enemyID = enemy.Name
		local clientEnemy = self.EnemyService:GetEnemy(enemyID)
		
		if clientEnemy and clientEnemy:GetEffectiveHealth() > 0 then
			local enemyPart = enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart")
			if enemyPart then
				local distance = (enemyPart.Position - originPos).Magnitude
				
				if distance <= shortestDistance then
					shortestDistance = distance
					nearestEnemy = enemyPart
					nearestID = enemyID
				end
			end
		end
	end

	return nearestEnemy, nearestID
end

return Utils