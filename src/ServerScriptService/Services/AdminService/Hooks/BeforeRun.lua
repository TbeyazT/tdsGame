local GROUP_ID = game.CreatorId
local REQUIRED_RANK = 200

local function isAdmin(player)
	return player:GetRankInGroup(GROUP_ID) >= REQUIRED_RANK or player.UserId == game.CreatorId
end

return function (registry)
	registry:RegisterHook("BeforeRun", function(context)
		if not isAdmin(context.Executor) then
			return "You don't have permission to run this command"
		end
	end)
end
