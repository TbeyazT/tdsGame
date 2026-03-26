local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ServerScriptService.Net)

local NotificationService = {}

function NotificationService:Init()
end

function NotificationService:Notify(target: Player | {Player}, Data)
    local payload = {
        Text = Data.Text or "No Text",
        Duration = Data.Duration or 2,
        TextColor = Data.TextColor,
        FrameScale = Data.FrameScale,
        UseRichAnimation = Data.UseRichAnimation
    }

    if typeof(target) == "Instance" then
        Net.Notify.Fire(target, payload)
    elseif typeof(target) == "table" then
        for _, player in target do
            if typeof(player) == "Instance" and player:IsA("Player") then
                Net.Notify.Fire(player, payload)
            end
        end
    end
end

return NotificationService