local Framework = require(game:GetService('ReplicatedStorage'):FindFirstChild('Shared'):FindFirstChild('Framework'))

return function (context, Player,towerName)
    local TowerService = Framework.WaitFor("TowerService")
    if TowerService then
        TowerService:GiveTower(Player,towerName)
    end
end