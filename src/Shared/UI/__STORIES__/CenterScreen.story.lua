local HttpService = game:GetService("HttpService")
local CenterScreen = require("@UI/Classes/CenterScreen")::any
local Framework = require("@Shared/Framework")

return function(target)
    local ProfileService = Framework.Get("ProfileService")
    local isUnmounted = false
    local cleanupFunc = nil

    local MockData = {
        Towers = {
            [1] = {
                Name = "Tarret",
                ID = HttpService:GenerateGUID(false)
            }
        }
    }

    ProfileService:Mock(MockData)

    task.spawn(function()
        cleanupFunc = CenterScreen:Mount(target)
        
        if isUnmounted and cleanupFunc then
            cleanupFunc()
        end
    end)

    return function()
        isUnmounted = true
        if cleanupFunc then
            cleanupFunc()
        end
    end
end