-- URLs to the raw files on GitHub or Gist
local mainUrl = "https://raw.githubusercontent.com/NeowarOW/NeoSongBox/main/main.lua"
local audioUrl = "https://raw.githubusercontent.com/NeowarOW/NeoSongBox/main/audio.lua"

-- Download main.lua
shell.run("wget", mainUrl, "main.lua")

-- Download audio.lua
shell.run("wget", audioUrl, "audio.lua")

print("Scripts downloaded successfully.")



