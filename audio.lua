local api_base_url = "https://ipod-2to6magyna-uc.a.run.app/"

local playing = false
local now_playing = nil
local queue = {}
local looping = false

local playing_id = nil
local last_download_url = nil
local playing_status = 0

local player_handle = nil
local start = nil
local size = nil
local decoder = nil
local needs_next_chunk = 0
local buffer

local speakers = { peripheral.find("speaker") }
if #speakers == 0 then
    error("No speakers attached", 0)
end

local selected_speakers = {}
for i = 1, #speakers do
    selected_speakers[i] = speakers[i]
end

-- Define fetchAudioState before it's used
local function fetchAudioState()
    if fs.exists("audio_state.txt") then
        local file = fs.open("audio_state.txt", "r")
        local state = textutils.unserialise(file.readAll())
        file.close()
        print("Fetched Audio State: ", textutils.serialise(state)) -- Debug print
        return state
    end
    return {playing = false, now_playing = {}, queue = {}, looping = false, volume = 1.0}
end

-- Now you can define functions that use fetchAudioState
local function playAudioChunk(audio_chunk)
    for _, speaker in pairs(selected_speakers) do
        local state = fetchAudioState()
        speaker.setVolume(state.volume)
        while not speaker.playAudio(audio_chunk) do
            sleep(0.05)
        end
    end
end

-- ... rest of the script
