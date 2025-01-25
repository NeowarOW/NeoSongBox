-- URLs to the raw files on GitHub or Gist
local mainUrl = "URL_TO_MAIN_LUA"
local audioUrl = "URL_TO_AUDIO_LUA"

-- Download main.lua
shell.run("wget", mainUrl, "main.lua")

-- Download audio.lua
shell.run("wget", audioUrl, "audio.lua")

print("Scripts downloaded successfully.")
