local pproc = loadfile("pproc.lua")

local function processFile(fileName)
  return pproc(fileName, "--sout")
end

local out = processFile("src/main.lua")
local handle = io.open("xenon.lua", "w")
handle:write(out)
handle:close()

print("Built Xenon to ./xenon.lua")
