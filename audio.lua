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

local function playAudioChunk(audio_chunk)
    for _, speaker in pairs(selected_speakers) do
        while not speaker.playAudio(audio_chunk) do
            sleep(0.05)
        end
    end
end

local function fetchAudioState()
    if fs.exists("audio_state.txt") then
        local file = fs.open("audio_state.txt", "r")
        local state = textutils.unserialise(file.readAll())
        file.close()
        print("Fetched Audio State: ", textutils.serialise(state)) -- Debug print
        return state
    end
    return {playing = false, now_playing = {}, queue = {}, looping = false}
end

local function playAudio()
    while true do
        local state = fetchAudioState()
        playing = state.playing
        now_playing = state.now_playing
        queue = state.queue
        looping = state.looping

        if playing and now_playing and now_playing.id then
            if playing_id ~= now_playing.id then
                playing_id = now_playing.id
                last_download_url = api_base_url .. "?id=" .. textutils.urlEncode(playing_id)
                playing_status = 0
                needs_next_chunk = 1

                http.request({url = last_download_url, binary = true})
            end
            if playing_status == 1 and needs_next_chunk == 1 then
                while true do
                    local chunk = player_handle.read(size)
                    if not chunk then
                        if looping then
                            playing_id = nil
                        else
                            if #queue > 0 then
                                now_playing = table.remove(queue, 1)
                                playing_id = nil
                            else
                                now_playing = nil
                                playing = false
                                playing_id = nil
                            end
                            break
                        end
                    else
                        if start then
                            chunk, start = start .. chunk, nil
                            size = size + 4
                        end
                        buffer = decoder(chunk)
                        playAudioChunk(buffer)
                        if needs_next_chunk == 2 then
                            needs_next_chunk = 1
                            break
                        end
                    end
                end
            end
        else
            -- Stop audio if not playing
            print("Playback stopped: ", now_playing and now_playing.name or "No track")
            for _, speaker in pairs(selected_speakers) do
                speaker.stop()
            end
            -- Clear current playback state
            playing_id = nil
            player_handle = nil
            start = nil
            size = nil
            decoder = nil
            needs_next_chunk = 0
            buffer = nil
        end
        sleep(0.1)  -- Prevent busy-waiting, check state often
    end
end

local function handleEvents()
    while true do
        local event, url, handle = os.pullEvent()
        if event == "http_success" and url == last_download_url then
            player_handle = handle
            start = player_handle.read(4)
            size = 16 * 1024 - 4
            if start == "RIFF" then
                error("WAV not supported!")
            end
            playing_status = 1
            decoder = require "cc.audio.dfpwm".make_decoder()
        elseif event == "http_failure" and url == last_download_url then
            print("Failed to fetch audio: ", url)
            if #queue > 0 then
                now_playing = table.remove(queue, 1)
                playing_id = nil
            else
                now_playing = nil
                playing = false
                playing_id = nil
            end
        elseif event == "speaker_audio_empty" then
            if needs_next_chunk == 2 then
                needs_next_chunk = 3
            end
        end
    end
end

-- Run both the audio playing loop and event handling in parallel
parallel.waitForAll(playAudio, handleEvents)
