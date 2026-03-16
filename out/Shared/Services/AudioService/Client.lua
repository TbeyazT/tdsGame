local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Trove = require(Packages.Trove)
local Framework = require(Shared.Framework)
local Net = require(Shared.Net)

local Audios = Assets.Sounds

local AudioController = {
    _trove = Trove.new(),
	
	_currentMusicName = nil,
	_musicTrack = nil,
	_musicPaused = false ,
	_savedVolume = 0.5   ,
	_playlist = {},
	_playlistIndex = 0,
	_isPlaylistActive = false,
	_activeLoops = {} ,
}

function AudioController:init()
end

function AudioController:Start()
	self.ProfileController = Framework.Get("ProfileService")

	local attempts = 0
	while not self.ProfileController:IsLoaded() do
		task.wait(0.5)
		attempts += 1
		if attempts > 20 then
			warn("ProfileController took too long to load!")
			break
		end
	end

    Net.PlayAudio.SetCallback(function(Value)
        self:PlaySound(Value.SoundName, Value.Properties)
    end)

	self.ProfileController:Get("Settings"):andThen(function(data)
		self:_HandleMusicState(true)
	end)

	-- Handle Changes (Observe)
	self.ProfileController:Observe("Settings", function(data)
		self:_HandleMusicState(true)
	end)
end

--[[ 
    NEW HELPER: Handles logic for turning music On/Off 
]]
function AudioController:_HandleMusicState(isEnabled)
	if isEnabled then
		-- 1. Make sure playlist contains songs
		self:_EnsurePlaylistLoaded()
		
		-- 2. If track exists but is paused, resume it
		if self._musicTrack and self._musicPaused then
			self:ResumeMusic(1)
		
		-- 3. If NO track exists (first time playing), start the playlist
		elseif not self._musicTrack then
			self._isPlaylistActive = true
			self:PlayNextInPlaylist()
		end
	else
		-- Setting is OFF, so pause
		self:PauseMusic(1)
	end
end

--[[ 
    NEW HELPER: Loads the folder into the table if it's empty 
]]
function AudioController:_EnsurePlaylistLoaded()
	-- Only load if the list is empty
	if #self._playlist == 0 then
		local playlistFolder = Audios:FindFirstChild("BackgoundMusics") or Audios:FindFirstChild("BackgroundMusic")
		
		if playlistFolder then
			self._playlist = playlistFolder:GetChildren()
		else
			warn("AudioController: BackgroundMusic folder missing.")
		end
	end
end

-- [EXISTING FUNCTIONS]

function AudioController:PauseMusic(fadeTime)
	if not self._musicTrack or self._musicPaused then return end
	
	fadeTime = fadeTime or 0.5
	self._musicPaused = true
	self._savedVolume = self._musicTrack.Volume
	
	local tween = TweenService:Create(self._musicTrack, TweenInfo.new(fadeTime), {Volume = 0})
	tween:Play()
	
	task.delay(fadeTime, function()
		if self._musicPaused and self._musicTrack then
			self._musicTrack:Pause()
		end
	end)
end

function AudioController:ResumeMusic(fadeTime)
	if not self._musicTrack or not self._musicPaused then return end
	
	fadeTime = fadeTime or 0.5
	self._musicPaused = false
	
	self._musicTrack:Resume()
	
	local tween = TweenService:Create(self._musicTrack, TweenInfo.new(fadeTime), {Volume = self._savedVolume})
	tween:Play()
end

function AudioController:PlayNextInPlaylist()
	-- Ensure playlist is loaded before trying to play
	self:_EnsurePlaylistLoaded()
	if not self._isPlaylistActive or #self._playlist == 0 then return end
	
	self._playlistIndex = self._playlistIndex + 1
	if self._playlistIndex > #self._playlist then
		self._playlistIndex = 1
	end
	
	local nextSoundObj = self._playlist[self._playlistIndex]
	if nextSoundObj then
		self:PlayMusic(nextSoundObj.Name, 2, false)
	end
end

function AudioController:PlayMusic(musicName, fadeTime, isLooped)
	fadeTime = fadeTime or 1
	if isLooped == nil then isLooped = true end 
	
	local soundTemplate = self:_GetSound(musicName)
	if not soundTemplate then return end

	-- If playing the same song and it's paused, just resume
	if self._currentMusicName == musicName then 
		if self._musicPaused then
			self:ResumeMusic(fadeTime)
		end
		return 
	end
	
	self._musicPaused = false 
	
	if self._musicTrack then
		local oldTrack = self._musicTrack
		if self._musicConnection then
			self._musicConnection:Disconnect()
			self._musicConnection = nil
		end
		
		local tween = TweenService:Create(oldTrack, TweenInfo.new(fadeTime), {Volume = 0})
		tween:Play()
		tween.Completed:Connect(function() oldTrack:Destroy() end)
	end

	local newTrack = soundTemplate:Clone()
	newTrack.Name = "Music_" .. musicName
	newTrack.Parent = SoundService
	newTrack.Looped = isLooped 
	
	local goalVolume = newTrack.Volume
	newTrack.Volume = 0
	newTrack:Play()
	
	TweenService:Create(newTrack, TweenInfo.new(fadeTime), {Volume = goalVolume}):Play()

	self._musicTrack = newTrack
	self._currentMusicName = musicName

	if not isLooped then
		self._musicConnection = newTrack.Ended:Connect(function()
			-- Only continue playlist if not paused
			if self._isPlaylistActive and not self._musicPaused then
				self:PlayNextInPlaylist()
			end
		end)
	else
		self._isPlaylistActive = false
	end
end

-- [STANDARD AUDIO FUNCTIONS]

function AudioController:PlaySound(soundName, properties)
	local soundTemplate = self:_GetSound(soundName)
	if not soundTemplate then return end
	local sound = soundTemplate:Clone()
	self:_ApplyProperties(sound, properties)
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
	return sound
end

function AudioController:PlaySound3D(soundName, target, properties)
	local soundTemplate = self:_GetSound(soundName)
	if not soundTemplate then return end
	local sound = soundTemplate:Clone()
	self:_ApplyProperties(sound, properties)
	local attachment = nil
	if typeof(target) == "Instance" and target:IsA("BasePart") then
		sound.Parent = target
	elseif typeof(target) == "Vector3" then
		attachment = Instance.new("Attachment")
		attachment.WorldPosition = target
		attachment.Parent = Workspace.Terrain
		sound.Parent = attachment
	else
		warn("AudioController: Invalid target for 3D sound", target)
		return
	end
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
		if attachment then attachment:Destroy() end
	end)
	return sound
end

function AudioController:StartLoop(soundName, properties)
	local soundTemplate = self:_GetSound(soundName)
	if not soundTemplate then return end
	local id = game:GetService("HttpService"):GenerateGUID(false)
	local sound = soundTemplate:Clone()
	self:_ApplyProperties(sound, properties)
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	self._activeLoops[id] = sound
	return id
end

function AudioController:StopLoop(loopId, fadeTime)
	local sound = self._activeLoops[loopId]
	if sound then
		self._activeLoops[loopId] = nil
		if fadeTime then
			local tween = TweenService:Create(sound, TweenInfo.new(fadeTime), {Volume = 0})
			tween:Play()
			tween.Completed:Connect(function() sound:Destroy() end)
		else
			sound:Destroy()
		end
	end
end

function AudioController:PlayRandom(soundName, properties, Position)
	properties = properties or {}
	if Position then
		local basePitch = properties.Pitch or 1
		local variance = 0.1
		properties.Pitch = basePitch + (math.random() * variance * 2 - variance)
		return self:PlaySound3D(soundName, Position, properties)
	else
		local basePitch = properties.Pitch or 1
		local variance = 0.1
		properties.Pitch = basePitch + (math.random() * variance * 2 - variance)
		return self:PlaySound(soundName, properties)
	end
end

function AudioController:BindButton(guiObject, hoverSoundName, clickSoundName)
	if not guiObject then return end
	local trove = Trove.new()
	if hoverSoundName then
		trove:Connect(guiObject.MouseEnter, function() self:PlaySound(hoverSoundName) end)
	end
	if clickSoundName then
		trove:Connect(guiObject.Activated, function() self:PlaySound(clickSoundName) end)
	end
	trove:AttachToInstance(guiObject)
end

function AudioController:_GetSound(name)
	local sound = Audios:FindFirstChild(name, true)
	if not sound then warn("AudioController: Sound not found:", name,debug.traceback()) return nil end
	return sound
end

function AudioController:_ApplyProperties(soundInstance, props)
	if props then for k, v in pairs(props) do soundInstance[k] = v end end
end

return AudioController