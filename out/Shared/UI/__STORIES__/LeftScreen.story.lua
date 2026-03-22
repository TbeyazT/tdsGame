local LeftScreenClass = require(script.Parent.Parent:FindFirstChild('Classes'):FindFirstChild('LeftScreen'))::any

return function(target)
    local isUnmounted = false
    local cleanupFunc = nil

    task.spawn(function()
        cleanupFunc = LeftScreenClass:Mount(target)
        
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