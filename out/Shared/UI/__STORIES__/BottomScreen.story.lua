local BottomScreen = require(script.Parent.Parent:FindFirstChild('Classes'):FindFirstChild('BottomScreen'))::any

return function(target)
    local isUnmounted = false
    local cleanupFunc = nil

    task.spawn(function()
        cleanupFunc = BottomScreen:Mount(target)
        
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