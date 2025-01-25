-- URLs to the raw files on GitHub or Gist
local mainUrl = "https://raw.githubusercontent.com/NeowarOW/NeoSongBox/main/main.lua"
local audioUrl = "https://raw.githubusercontent.com/NeowarOW/NeoSongBox/main/audio.lua"

-- Download main.lua
local success = shell.run("wget", mainUrl, "main.lua")

-- Download audio.lua
local success2 = shell.run("wget", audioUrl, "audio.lua")

if success and success2 then
    print("C'est bon c'est DL mon pote !.")
else
    print("Euhh marche pas ton DL là !.")
end
