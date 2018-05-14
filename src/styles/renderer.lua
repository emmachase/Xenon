local renderer = {}
renderer.model = {}

--#ignore
local xmlutils = require("xml")
--#require "src/styles/xml.lua" as xmlutils

-- Components
--#ignore
local components = require("components/index")
--#require "src/styles/components/index.lua" as components

function renderer.processStyles(styles)
  -- TODO
end

function renderer.inflateXML(xml)
  renderer.model = {}
  local model = xmlutils.parse(xml)

  if model.children and model.children[1] and model.children[1].name ~= "body" then
    error("Bad Layout Structure (No Body)")
  end

  local body = model.children[1]
  for i = 1, #body.children do
    local el = body.children[i]

    if components[el.name] then
      renderer.model[#renderer.model + 1] = components[el.name].new(el)
    else
      error("Unknown element " .. el.name)
    end
  end
end

return renderer