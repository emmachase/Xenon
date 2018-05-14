local renderer = {}
renderer.model = {}

--#ignore 2
local xmlutils = require("xml")
local css = require("css")

--#require "src/styles/xml.lua" as xmlutils
--#require "src/styles/css.lua" as css

-- Components
--#ignore
local components = require("components/index")
--#require "src/styles/components/index.lua" as components

local function deepMap(set, func, level)
  level = level or 1

  for i = 1, #set.children do
    func(set.children[i], level)
    if set.children[i].children then
      deepMap(set.children[i], func, level + 1)
    end
  end
end

local function queryMatch(el, selector)
  if el.type ~= "normal" then return false end

  if selector == "*" then
    return true
  elseif selector:match("^%.") then
    -- Matching a class
    -- TODO
  else
    -- Matching element
    local nameToMatch = selector:match("^([^:]+):?")
    local psuedoSelector = selector:match(":(.+)")

    if el.name == nameToMatch then
      -- TODO psuedoSelectors
      return true
    else
      return false
    end
  end
end

local function querySelector(selector)
  local steps = {}
  local step = ""
  local brace = 0
  for c in selector:gmatch(".") do
    if c:match("%s") and brace == 0 then
      steps[#steps + 1] = step
      step = ""
    else
      step = step .. c
      if c:match("[%(%{]") then
        brace = brace + 1
      elseif c:match("[%)%}]") then
        brace = brace - 1
      end
    end
  end
  steps[#steps + 1] = step

  local matches = {}
  deepMap(renderer.model, function(el, level)
    if #steps > level then return end -- Cannot possibly match the selector so optimize a bit

    local stillMatches = true
    local activeEl = el
    for outLev = #steps, 1, -1 do
      if not queryMatch(activeEl, steps[outLev]) then
        stillMatches = false
        break
      end

      activeEl = el.parent
    end

    if stillMatches then
      matches[#matches + 1] = el
    end
  end)

  return matches
end

function renderer.processStyles(styles)
  local rulesets, order = css(styles)

  for rulesetI = 1, #order do
    local k = order[rulesetI]
    local v = rulesets[order[rulesetI]]
    local matches = querySelector(k)

    for i = 1, #matches do
      local matchedEl = matches[i]
      matchedEl.styles = matchedEl.styles or {}

      for prop, val in pairs(v) do
        matchedEl.styles[prop] = val
      end
    end
  end
end

function renderer.inflateXML(xml)
  renderer.model = xmlutils.parse(xml)
  local model = renderer.model

  if model.children and model.children[1] and model.children[1].name ~= "body" then
    error("Bad Layout Structure (No Body)")
  end

  local body = model.children[1]
  for i = 1, #body.children do
    local el = body.children[i]

    if components[el.name] then
      el.adapter = components[el.name].new(el)
    else
      error("Unknown element " .. el.name)
    end
  end
end

function renderer.renderToSurface(surf)
  local flowX = 0
  local flowY = 0

  for i = 1, #renderer.model do

  end
end

return renderer
