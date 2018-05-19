--== Monitor Rendering Endpoints ==--

local monW, monH = monPeriph.getSize()
local displaySurf = surface.create(monW, monH)

function repaintMonitor()
  for _, v in pairs(renderer.colorReference) do
    monPeriph.setPaletteColor(2^v[1], tonumber(v[2], 16))
  end

  renderer.renderToSurface(displaySurf)
  displaySurf:output(monPeriph)
end

local function drawStartup()
  monPeriph.setPaletteColor(2^0, 0x2F3542)
  monPeriph.setPaletteColor(2^1, 0x747D8C)

  monPeriph.setBackgroundColor(2^0)
  monPeriph.setTextColor(2^1)
  monPeriph.clear()

  local str = "Xenon is initializing..."
  monPeriph.setCursorPos(math.ceil((monW - #str) / 2), math.ceil(monH / 2))
  monPeriph.write(str)
end
