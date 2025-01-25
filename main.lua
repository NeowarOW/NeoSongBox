local api_base_url = "https://ipod-2to6magyna-uc.a.run.app/"

local width, height = term.getSize()

local tab = 1
local waiting_for_input = false
local last_search = nil
local last_search_url = nil
local search_results = nil
local search_error = false
local in_fullscreen = 0
local clicked_result = nil

local playing = false
local queue = {}
local now_playing = nil
local looping = false

local playing_id = nil
local last_download_url = nil
local playing_status = 0

local player_handle = nil
local start = nil
local pcm = nil
local size = nil
local decoder = nil
local needs_next_chunk = 0
local buffer

local speakers = { peripheral.find("speaker") }
if #speakers == 0 then
    error("No speakers attached", 0)
end

-- New: List to keep track of selected speakers, all selected by default
local selected_speakers = {}
for i = 1, #speakers do
    selected_speakers[i] = speakers[i]
end

-- New: Variable for volume control
local volume = 1.0

-- Function to toggle speaker selection
local function toggleSpeaker(speaker_index)
    if selected_speakers[speaker_index] then
        selected_speakers[speaker_index] = nil
    else
        selected_speakers[speaker_index] = speakers[speaker_index]
    end
end

-- Function to play audio on selected speakers with volume control
local function playOnSelectedSpeakers(audio_chunk)
    for _, speaker in pairs(selected_speakers) do
        while not speaker.playAudio(audio_chunk, volume) do
            sleep(0.05)  -- Small delay to prevent CPU overload
        end
    end
end

local function updateAudioState()
    local file = fs.open("audio_state.txt", "w")
    file.write(textutils.serialise({
        playing = playing,
        now_playing = now_playing or {},
        queue = queue,
        looping = looping,
        volume = volume
    }))
    file.close()
end

os.startTimer(1)

local function redrawScreen()
    if waiting_for_input == true then
        return
    end

    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Draw a border around the screen
    term.setBackgroundColor(colors.gray)
    for i = 1, height do
        term.setCursorPos(1, i)
        term.write(" ")
        term.setCursorPos(width, i)
        term.write(" ")
    end
    for i = 1, width do
        term.setCursorPos(i, 1)
        term.write(" ")
        term.setCursorPos(i, height)
        term.write(" ")
    end

    --tabs
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    
    tabs = {" Lecture en cours ", " Recherche ", " Haut-parleurs "}
    
    for i=1,3,1 do
        if tab == i then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.lightGray)
        else
            term.setTextColor(colors.lightGray)
            term.setBackgroundColor(colors.gray)
        end
        
        local tabWidth = #tabs[i]
        local xPosition = (math.floor((width/3)*(i-0.5)))-math.ceil(tabWidth/2)+1
        term.setCursorPos(xPosition, 1)
        term.write(tabs[i])
    end

    --now playing tab
    if tab == 1 then
        local center = math.floor(width/2)
        if now_playing ~= nil then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.setCursorPos(center - math.floor(#now_playing.name/2), 3)
            term.write(now_playing.name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(center - math.floor(#now_playing.artist/2), 4)
            term.write(now_playing.artist)
        else
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(center - 7, 3)
            term.write("Rien en cours")
        end

        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)

        local buttonStart = math.floor((width - (3 * 8 + 6)) / 2)  -- 8 is length of each button, 6 is space between buttons

        if playing then
            term.setCursorPos(buttonStart, 6)
            term.write("Arreter")
        else
            if now_playing ~= nil or #queue > 0 then
                term.setTextColor(colors.white)
            else
                term.setTextColor(colors.lightGray)
            end
            term.setCursorPos(buttonStart, 6)
            term.write("Lire")
        end

        if now_playing ~= nil or #queue > 0 then
            term.setTextColor(colors.white)
        else
            term.setTextColor(colors.lightGray)
        end
        term.setCursorPos(buttonStart + 8 + 3, 6)
        term.write("Suivant")

        if looping then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
        else
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.gray)
        end
        term.setCursorPos(buttonStart + 2*8 + 6, 6)
        term.write("Boucle")

        -- Volume control UI
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(2, 8)
        term.write("Volume: " .. string.format("%.2f", volume))
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        local volumeControlX = width - 3
        term.setCursorPos(volumeControlX, 8)
        term.write("-")
        term.setCursorPos(volumeControlX, 9)
        term.write("+")

        --search results
        if #queue > 0 then
            term.setBackgroundColor(colors.black)
            for i=1,#queue do
                term.setTextColor(colors.white)
                term.setCursorPos(2,10 + (i-1)*2)
                term.write(queue[i].name)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2,11 + (i-1)*2)
                term.write(queue[i].artist)
            end
        end
    end
    
    --search tab
    if tab == 2 then

        -- search bar
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.black)
        for a=3,5,1 do
            term.setCursorPos(2,a)
            for i=1,width-3,1 do
                term.write(" ")
            end
        end
        term.setCursorPos(3,4)
        term.write(last_search or "Recherche...")

        --search results
        if search_results ~= nil then
            term.setBackgroundColor(colors.black)
            for i=1,#search_results do
                term.setTextColor(colors.white)
                term.setCursorPos(2,7 + (i-1)*2)
                term.write(search_results[i].name)
                term.setTextColor(colors.lightGray)
                term.setCursorPos(2,8 + (i-1)*2)
                term.write(search_results[i].artist)
            end
        else
            term.setCursorPos(2,7)
            term.setBackgroundColor(colors.black)
            if search_error == true then
                term.setTextColor(colors.red)
                term.write("Erreur")
            else
                if last_search_url ~= nil then
                    term.setTextColor(colors.white)
                    term.write("Recherche...")
                else
                    term.setTextColor(colors.lightGray)
                    term.write("Aucun résultat")
                end
            end
        end

        --fullscreen song options
        if in_fullscreen == 1 then
            term.setBackgroundColor(colors.black)
            term.clear()
            local center = math.floor(width/2)
            term.setTextColor(colors.white)
            term.setCursorPos(center - math.floor(#search_results[clicked_result].name/2), 3)
            term.write(search_results[clicked_result].name)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(center - math.floor(#search_results[clicked_result].artist/2), 4)
            term.write(search_results[clicked_result].artist)

            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)

            local buttonStart = math.floor((width - 14) / 2)
            term.setCursorPos(buttonStart, 6)
            term.clearLine()
            term.write("Lire maintenant")
            term.setCursorPos(buttonStart, 8)
            term.clearLine()
            term.write("Lire ensuite")
            term.setCursorPos(buttonStart, 10)
            term.clearLine()
            term.write("Ajouter à la file")
            term.setCursorPos(buttonStart, 12)
            term.clearLine()
            term.write("Annuler")
        end
        
    end

    -- Speaker tab
    if tab == 3 then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        
        local start_y = 3
        for i, speaker in ipairs(speakers) do
            term.setCursorPos(2, start_y + i - 1)
            if selected_speakers[i] then
                term.setBackgroundColor(colors.green)
            else
                term.setBackgroundColor(colors.black)
            end
            term.write("Haut-parleur " .. i)
        end
    end
end

local function searchInput()
    while true do
        if waiting_for_input == true then
            for a=3,5,1 do
                term.setCursorPos(2,a)
                term.setTextColor(colors.white)
                term.setBackgroundColor(colors.white)
                for i=1,width-2,1 do
                    term.write(" ")
                end
            end
            term.setCursorPos(3,4)
            term.setTextColor(colors.black)
            local input = read()
            if string.len(input) > 0 then
                last_search = input
                last_search_url = api_base_url .. "?search=" .. textutils.urlEncode(input)
                http.request(last_search_url)
                search_results = nil
                search_error = false
            else
                last_search = nil
                last_search_url = nil
                search_results = nil
                search_error = false
            end
        
            waiting_for_input = false

            redrawScreen()
        end

        sleep(0.1)
    end
end

local function mainLoop()
    redrawScreen()

    while true do
        
        local event, param1, param2, param3 = os.pullEvent()    
 
        -- CLICK EVENTS
        if event == "mouse_click" and waiting_for_input == false then

            local button = param1
            local x = param2
            local y = param3

            -- tabs
            if button == 1 and in_fullscreen == 0 then
                if y == 1 then
                    if x < width/3 then
                        tab = 1
                    elseif x < 2*width/3 then
                        tab = 2
                    else
                        tab = 3
                    end
                    redrawScreen()
                end
            end

            -- Speaker selection tab
            if tab == 3 then
                local start_y = 3
                for i = 1, #speakers do
                    if y == start_y + i - 1 then
                        toggleSpeaker(i)
                        redrawScreen()
                    end
                end
            end

            -- Volume control in now playing tab
            if tab == 1 then
                if y == 8 or y == 9 then
                    if x == width - 3 then  -- decrease volume
                        volume = math.max(0, volume - 0.1)
                        for _, speaker in pairs(selected_speakers) do
                            speaker.setVolume(volume)
                        end
                    elseif x == width - 3 then  -- increase volume
                        volume = math.min(1, volume + 0.1)
                        for _, speaker in pairs(selected_speakers) do
                            speaker.setVolume(volume)
                        end
                    end
                    updateAudioState()
                    redrawScreen()
                end
            end

            --fullscreen windows
            if in_fullscreen == 1 then
                term.setBackgroundColor(colors.white)
                term.setTextColor(colors.black)

                if y == 6 then
                    term.setCursorPos(2,6)
                    term.clearLine()
                    term.write("Lire maintenant")
                    sleep(0.2)
                    in_fullscreen = 0
                    now_playing = search_results[clicked_result]
                    playing = true
                    playing_id = nil
                    updateAudioState()
                elseif y == 8 then
                    term.setCursorPos(2,8)
                    term.clearLine()
                    term.write("Lire ensuite")
                    sleep(0.2)
                    in_fullscreen = 0
                    table.insert(queue, 1, search_results[clicked_result])
                    updateAudioState()
                elseif y == 10 then
                    term.setCursorPos(2,10)
                    term.clearLine()
                    term.write("Ajouter à la file")
                    sleep(0.2)
                    in_fullscreen = 0
                    table.insert(queue, search_results[clicked_result])
                    updateAudioState()
                elseif y == 12 then
                    term.setCursorPos(2,12)
                    term.clearLine()
                    term.write("Annuler")
                    sleep(0.2)
                    in_fullscreen = 0
                end
            else

                -- now playing tab
                if tab == 1 and button == 1 then
                    local buttonStart = math.floor((width - (3 * 8 + 6)) / 2)
                    if y == 6 then
                        if x >= buttonStart and x < buttonStart + 8 then
                            local animate = false
                            local was_playing = playing
                            if playing then
                                playing = false
                                animate = true
                                for _, speaker in pairs(selected_speakers) do
                                    speaker.stop()
                                end
                                updateAudioState()
                            else
                                if now_playing ~= nil then
                                    playing = true
                                    animate = true
                                else
                                    if #queue > 0 then
                                        now_playing = queue[1]
                                        table.remove(queue, 1)
                                        playing = true
                                        animate = true
                                    end
                                end
                                updateAudioState()
                            end
                            if animate == true then
                                term.setBackgroundColor(colors.white)
                                term.setTextColor(colors.black)
                                term.setCursorPos(buttonStart, 6)
                                if was_playing then
                                    term.write("Arreter")
                                else 
                                    term.write("Lire")
                                end
                                sleep(0.2)
                            end
                        elseif x >= buttonStart + 8 + 3 and x < buttonStart + 8 + 3 + 8 then
                            local animate = false
                            if now_playing ~= nil or #queue > 0 then
                                if #queue > 0 then
                                    now_playing = queue[1]
                                    table.remove(queue, 1)
                                else
                                    now_playing = nil
                                    playing = false
                                end
                                animate = true
                                updateAudioState()
                            end
                            if animate == true then
                                term.setBackgroundColor(colors.white)
                                term.setTextColor(colors.black)
                                term.setCursorPos(buttonStart + 8 + 3, 6)
                                term.write("Suivant")
                                sleep(0.2)
                            end
                        elseif x >= buttonStart + 2*8 + 6 and x < buttonStart + 2*8 + 6 + 8 then
                            looping = not looping
                            updateAudioState()
                        end
                    end
                end

                -- search tab clicks
                if tab == 2 and button == 1 then
                    -- search box click
                    if y >= 3 and y <= 5 and x >= 1 and x <= width-1 then
                        waiting_for_input = true
                    end

                    -- search result click
                    if search_results then
                        for i=1,#search_results do
                            if y == 7 + (i-1)*2 or y == 8 + (i-1)*2 then
                                term.setBackgroundColor(colors.white)
                                term.setTextColor(colors.black)
                                term.setCursorPos(2,7 + (i-1)*2)
                                term.clearLine()
                                term.write(search_results[i].name)
                                term.setTextColor(colors.gray)
                                term.setCursorPos(2,8 + (i-1)*2)
                                term.clearLine()
                                term.write(search_results[i].artist)
                                sleep(0.2)
                                in_fullscreen = 1
                                clicked_result = i
                            end
                        end
                    end
                end
            end

            redrawScreen()

        end

        -- Handle window focus changes
        if event == "term_resize" or event == "monitor_touch" then
            redrawScreen()
        end

        -- HTTP EVENTS
        if event == "http_success" then
            local url = param1
            local handle = param2

            if url == last_search_url then
                search_results = textutils.unserialiseJSON(handle.readAll())
                redrawScreen()
            end
        end

        if event == "http_failure" then
            local url = param1

            if url == last_search_url then
                search_error = true
                redrawScreen()
            end
        end

        if event == "timer" then
            os.startTimer(1)
        end

    end

    sleep(0.1)
end

-- Write initial state before starting audio script
updateAudioState()

-- Instead of shell.run, we use shell.openTab for a new background tab
local audioHandle = shell.openTab("audio.lua", "bg")
if not audioHandle then
    error("Failed to start audio script")
end

-- Run the main loop
parallel.waitForAny(mainLoop, searchInput)
