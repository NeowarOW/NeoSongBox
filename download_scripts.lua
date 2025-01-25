-- URLs to the raw files on GitHub or Gist
local mainUrl = "https://github.com/NeowarOW/NeoSongBox/blob/main/main.lua"
local audioUrl = "https://github.com/NeowarOW/NeoSongBox/blob/main/audio.lua"

-- Download main.lua
shell.run("wget", mainUrl, "main.lua")

-- Download audio.lua
shell.run("wget", audioUrl, "audio.lua")

print("Scripts downloaded successfully.")



