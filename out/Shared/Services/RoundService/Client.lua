local Players = game:GetService("Players")

local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))
local TriggerComponent = require(script.Parent.Parent.Parent:FindFirstChild('Components'):FindFirstChild('TriggerComponent'))

local LocalPlayer = Players.LocalPlayer

local RoundService = {}

function RoundService:Init()
    self.ProfileService = Framework.Get("ProfileService")
    self.LobbyUIs = {}
    
    Net.UpdateLobby.On(function(data)
        self:UpdateLobbyUI(data)
    end)
end

function RoundService:Start()
    repeat task.wait(0.5) until self.ProfileService:IsLoaded()

    for _, area in pairs(workspace.Areas:GetChildren()) do
        self:InitArea(area)
    end
end

function RoundService:InitArea(area: Folder)
    local triggerPart = area:FindFirstChild("Trigger")
    local billboardGui = area:FindFirstChildWhichIsA("BillboardGui", true)
    local areaNumber = tonumber(area.Name)

    if triggerPart and billboardGui and areaNumber then
        self.LobbyUIs[areaNumber] = billboardGui
        
        local triggerClass = TriggerComponent.new(triggerPart)
        triggerClass.touchType = triggerClass.TouchType.Physics

        triggerClass.OnTouched:Connect(function(player: Player, a1: { Name: any, Parent: Model }) 
            if player == LocalPlayer then
                Net.RequestJoin.Fire(areaNumber)
                task.wait(4)
                Net.StartLobby.Fire()
            end
        end)
    end
end

function RoundService:UpdateLobbyUI(data)
    local billboardGui = self.LobbyUIs[data.Lobby]
    if not billboardGui then return end
    
    local mapSelector = billboardGui:FindFirstChild("MapSelector")
    if not mapSelector then return end

    local isEmpty = (#data.Players == 0)

    local playerFrame = mapSelector:FindFirstChild("Player_Frame")
    if playerFrame then
        for i = 1, 4 do
            local slot = playerFrame:FindFirstChild("Player_" .. i)
            if slot then
                local playerIcon = slot:FindFirstChild("Player_Icon")
                local questionMark = slot:FindFirstChild("Question_Mark")
                
                local player = data.Players[i]
                
                if player then
                    if questionMark then questionMark.Visible = false end
                    if playerIcon then
                        playerIcon.Visible = true
                        
                        pcall(function()
                            local thumbnail = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                            playerIcon.Image = thumbnail
                        end)
                    end
                else
                    if questionMark then questionMark.Visible = true end
                    if playerIcon then 
                        playerIcon.Visible = false 
                        playerIcon.Image = ""
                    end
                end
            end
        end
    end

    local bottomFrame = mapSelector:FindFirstChild("Bottom_Frame")
    if bottomFrame then
        local playerCountFrame = bottomFrame:FindFirstChild("Player_Count")
        if playerCountFrame then
            local countText = playerCountFrame:FindFirstChild("Count_Text") or playerCountFrame:FindFirstChildWhichIsA("TextLabel", true)
            if countText then
                if isEmpty then
                    countText.Text = "???"
                else
                    countText.Text = string.format("%d/%d", #data.Players, data.MaxPlayers)
                end
            end
        end

        local timeCountFrame = bottomFrame:FindFirstChild("Time_Count")
        if timeCountFrame then
            local timeText = timeCountFrame:FindFirstChild("Count_Text") or timeCountFrame:FindFirstChildWhichIsA("TextLabel", true)
            if timeText then
                if isEmpty then
                    timeText.Text = "???"
                else
                    if data.TimeLeft ~= nil then
                        timeText.Text = tostring(data.TimeLeft) .. "s"
                    else
                        timeText.Text = "WAIT" 
                    end
                end
            end
        end
    end
    
    local topBar = mapSelector:FindFirstChild("Top_Bar")
    if topBar then
        local mapText = topBar:FindFirstChild("Map_Text")
        if mapText then
            if isEmpty then
                mapText.Text = "NO MAP SELECTED"
            else
                mapText.Text = data.Map and string.upper(data.Map) or "NO MAP SELECTED"
            end
        end
    end
end

return RoundService