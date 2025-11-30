-- Table to become compy.audio
local audio = { }

-- Add noises to the audio table
local names = {
  "beep",
  "blast",
  "boom",
  "correct",
  "gameover",
  "hyperjump",
  "jump",
  "knock",
  "lose",
  "pew",
  "ping",
  "punch",
  "rawr",
  "shot",
  "sword",
  "toggle",
  "win",
  "wow",
  "wrong"
}
for _,name in pairs(names) do
  local filename = "assets/sounds/"..name..".ogg"
  local source = love.audio.newSource(filename, "static")
  audio[name] = function()
    love.audio.play(source)
  end
end

return audio
