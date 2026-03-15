opt server_output = "ServerScriptService/Server/Net.luau"
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

-- enemy and stuff

event CreateEnemy = {
    from: Server,
    type:Reliable,
    call: SingleAsync,
    data: struct {
        Name: string.utf8,
        ID: string.utf8,
    }
}