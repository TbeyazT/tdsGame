opt server_output = "ServerScriptService/Net.luau"
opt client_output = "Shared/Net.luau"

event DataLoaded = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: map { [string.utf8]: unknown }
}

event DataUpdated = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Key: string.utf8,
        Value: unknown
    }
}

event PlayAudio = {
    from: Server,
    call: SingleAsync,
    data: struct {
        SoundName: string.utf8,
        properties: struct {}
    }
}

event Notify = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Text: string.utf8,
        Duration: f32,
        TextColor: Color3?,
        FrameScale: f32?,
        UseRichAnimation: boolean?
    }
}

funct ChangeSetting = {
    call: Async,
    args: string.utf8,
    rets: boolean
}

funct EditTutorial = {
    call: Async,
    args: struct {
        Key: string.utf8,
        Value: unknown
    }
}

funct Rebirth = {
    call: Async,
    args: boolean,
    rets: unknown
}
-- Lobby stuff

event RequestJoin = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: u16,
}

event RequestLeave = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
}

event ChangeLobbySetting = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        MaxPlayers: u8,
        Map: string.utf8,
    }
}

event UpdateLobby = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Lobby: u16,
        MaxPlayers: u8,
        Map: string.utf8,
        Players: Instance[],
        Leader: Instance?,
        TimeLeft: u8?
    }
}

event StartLobby = {
    from: Client,
    type: Reliable,
    call: SingleAsync
}

funct EquipTower = {
    call: Async,
    args: string.utf8,
    rets: boolean
}

funct UnequipTower = {
    call: Async,
    args: string.utf8,
    rets: boolean
}