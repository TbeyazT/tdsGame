local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Net = require("@SSS/Net")
local Framework = require("@Shared/Framework")

local TARGET_PLACE_ID = 83587105435922

local RoundService = {}

function RoundService:Init()
    self.CharacterService = Framework.Get("CharacterService")

    self.ActiveLobbys = {}

    Net.RequestJoin.SetCallback(function(Player: Player, Value: number) 
        self:RequestJoin(Player, Value)
    end)

    Net.RequestLeave.SetCallback(function(Player: Player) 
        self:RequestLeave(Player)
    end)

    Net.ChangeLobbySetting.SetCallback(function(Player: Player, Value: { MaxPlayers: number }) 
        self:ChangeSetting(Player, Value)
    end)

    Net.StartLobby.SetCallback(function(Player: Player)
        self:StartMatch(Player)
    end)

    Players.PlayerAdded:Connect(function(player)
        for lobbyNumber, _ in pairs(self.ActiveLobbys) do
            self:ReplicateLobby(lobbyNumber, player)
        end
    end)

    for _,lobby in pairs(workspace.Areas:GetChildren()) do
        self:InitLobby(lobby)    
    end
end

function RoundService:InitLobby(lobby: Folder)
    local lobbyNumber = tonumber(lobby.Name)

    if lobbyNumber then
        self.ActiveLobbys[lobbyNumber] = {
            Leader = nil,
            Players = {},
            MaxPlayers = 4,
            Map = "Normal",
            TimeLeft = nil,
            TimerTask = nil
        }
        self:ReplicateLobby(lobbyNumber)
    end
end

function RoundService:RequestJoin(player: Player, area: number)
    local lobby = self.ActiveLobbys[area]
    if lobby then
        local foundInLobbys = self:FindPlayerInLobbys(player)
        if foundInLobbys then return end
        
        if not lobby.Leader then
            lobby.Leader = player
        end
        
        table.insert(lobby.Players, player)
        
        local foundCharacter = self.CharacterService:GetCharacter(player)
        local lobbyFolder = workspace.Areas:FindFirstChild(tostring(area))
        
        if foundCharacter and foundCharacter.RootPart and lobbyFolder then
            local joinLocation = lobbyFolder:FindFirstChild("Trigger")
            if not joinLocation then return end
            foundCharacter.RootPart.CFrame = joinLocation.CFrame
        end
        
        self:HandleLobbyUpdates(area)
    end
end

function RoundService:RequestLeave(player: Player)
    local foundInLobbys = self:FindPlayerInLobbys(player)
    if foundInLobbys then
        local lobby = self.ActiveLobbys[foundInLobbys]
        if not lobby then return end
        
        local foundPlayerIndex = table.find(lobby.Players, player)
        if foundPlayerIndex then
            if lobby.Leader == player then
                self:ResetLobby(foundInLobbys)
            end
            
            table.remove(lobby.Players, foundPlayerIndex)
            
            local foundCharacter = self.CharacterService:GetCharacter(player)
            local lobbyFolder = workspace.Areas:FindFirstChild(tostring(foundInLobbys))
            if foundCharacter and foundCharacter.RootPart and lobbyFolder then
                local leaveLocation = lobbyFolder:FindFirstChild("LeaveLocation")
                if not leaveLocation then return end
                foundCharacter.RootPart.CFrame = leaveLocation.CFrame
            end
            
            self:HandleLobbyUpdates(foundInLobbys)
        end
    end
end

function RoundService:StartMatch(player: Player)
    local area = self:FindPlayerInLobbys(player)
    if not area then return end

    local lobby = self.ActiveLobbys[area]
    if not lobby then return end

    if lobby.Leader == player and not lobby.TimerTask then
        local isMaxPlayers = (#lobby.Players >= lobby.MaxPlayers)
        
        lobby.TimeLeft = isMaxPlayers and 5 or 15
        
        lobby.TimerTask = task.spawn(function()
            while lobby.TimeLeft > 0 do
                self:ReplicateLobby(area)
                task.wait(1)
                if not lobby or #lobby.Players == 0 then break end
                lobby.TimeLeft -= 1
            end
            
            if lobby and #lobby.Players > 0 and (lobby.TimeLeft or 0) <= 0 then
                self:ReplicateLobby(area)
                self:TeleportLobby(area)
            end
        end)
    end
end

function RoundService:HandleLobbyUpdates(area: number)
    local lobby = self.ActiveLobbys[area]
    if not lobby then return end

    if #lobby.Players == 0 then
        if lobby.TimerTask then
            task.cancel(lobby.TimerTask)
            lobby.TimerTask = nil
        end
        lobby.TimeLeft = nil
        self:ReplicateLobby(area)
    else
        if lobby.TimerTask then
            if #lobby.Players >= lobby.MaxPlayers and lobby.TimeLeft > 5 then
                lobby.TimeLeft = 5
            end
        end
        self:ReplicateLobby(area)
    end
end

function RoundService:TeleportLobby(area: number)
    local lobby = self.ActiveLobbys[area]
    if not lobby or #lobby.Players == 0 then return end
    
    local playersToTeleport = {}
    for _, p in pairs(lobby.Players) do
        table.insert(playersToTeleport, p)
    end
    
    local tpOptions = Instance.new("TeleportOptions")
    tpOptions:SetTeleportData({ Map = lobby.Map })

    if lobby.TimerTask and lobby.TimerTask ~= coroutine.running() then 
        task.cancel(lobby.TimerTask) 
    end
    
    lobby.TimerTask = nil
    lobby.TimeLeft = nil
    lobby.Leader = nil
    lobby.Players = {}
    self:ReplicateLobby(area)

    pcall(function()
        TeleportService:TeleportAsync(TARGET_PLACE_ID, playersToTeleport, tpOptions)
    end)
end

function RoundService:ResetLobby(area: number)
    local lobby = self.ActiveLobbys[area]
    if lobby then
        lobby.Leader = nil
        lobby.MaxPlayers = 4
        if #lobby.Players > 0 then
            lobby.Leader = lobby.Players[1]
        end
    end
end

function RoundService:ChangeSetting(player: Player, data)
    local playerLobbyIndex = self:FindPlayerInLobbys(player)
    if playerLobbyIndex and self.ActiveLobbys[playerLobbyIndex] then
        local playerLobby = self.ActiveLobbys[playerLobbyIndex]
        if playerLobby.Leader ~= player then return end
        
        for setting, value in pairs(data) do
            if playerLobby[setting] and typeof(playerLobby[setting]) == typeof(value) then
                playerLobby[setting] = value
            end
        end
        
        self:ReplicateLobby(playerLobbyIndex)
    end
end

function RoundService:FindPlayerInLobbys(player: Player)
    for index, lobby in pairs(self.ActiveLobbys) do
        if #lobby.Players <= 0 then continue end
        local foundPlayer = table.find(lobby.Players, player)
        if foundPlayer then
            return index
        end
    end
    return nil
end

function RoundService:ReplicateLobby(area: number, specificPlayer: Player?)
    local lobby = self.ActiveLobbys[area]
    if not lobby then return end
    
    local packet = {
        Lobby = area,
        MaxPlayers = lobby.MaxPlayers,
        Map = lobby.Map,
        Players = lobby.Players,
        Leader = lobby.Leader,
        TimeLeft = lobby.TimeLeft
    }
    
    if specificPlayer then
        Net.UpdateLobby.Fire(specificPlayer, packet)
    else
        Net.UpdateLobby.FireAll(packet)
    end
end

return RoundService