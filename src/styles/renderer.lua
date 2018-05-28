local renderer = {}
renderer.model = {}
renderer.styles = { {}, {} }

--#ignore 2
local xmlutils = require("xml")
local css = require("css")

--#require "src/styles/xml.lua" as xmlutils
--#require "src/styles/css.lua" as css

-- Components
--#ignore
local components = require("components/index")
--#require "src/styles/components/index.lua" as components

renderer.components = components

local function deepMap(set, func, level)
  level = level or 1

  foreach(child, set.children) do
    func(child, level)
    if child.children then
      deepMap(child, func, level + 1)
    end
  end
end

local function queryMatch(el, selector)
  if el.type ~= "normal" then return false end

  if selector == "*" then
    return true
  else
    local namesToMatch = selector:match("^([^:]+):?")
    local psuedoSelector = selector:match(":(.+)")

    for nameToMatch in namesToMatch:gmatch("[%.%#]?[^%.%#]+") do
      if nameToMatch:match("^%#") then -- Matching an id
        if el.properties.id ~= nameToMatch:match("^%#(.+)") then
          return false
        end
      elseif nameToMatch:match("^%.") then -- Matching a class
        if el.properties.class then
          local good = false
          for class in el.properties.class:gmatch("%S+") do
            if class == nameToMatch:match("^%.(.+)") then
              good = true
              break
            end
          end

          if not good then
            return false
          end
        else
          return false
        end
      elseif el.name ~= nameToMatch then -- Matching an element
        return false
      end
    end

    if psuedoSelector then
      local pfunc = psuedoSelector:match("[^%(%)]+")
      local args = psuedoSelector:match("%b()"):sub(2, -2)

      if pfunc == "nth-child" then
        local nf = -1
        local op = "+"
        local ofs = 0
        for actor in args:gmatch("%S+") do
          local nn = actor:match("(%d+)n")
          if nn then nf = tonumber(nn) else
            local nop = actor:match("[%+%-]")
            if nop then op = nop else
              ofs = tonumber(actor)
            end
          end
        end

        local acn = 0
        for i = 1, #el.parent.children do
          if el.parent.children[i] == el then
            acn = i
            break
          end
        end

        local acndebug = acn -- TODO REMOVE ME

        if op == "+" then
          acn = acn - ofs
        else
          acn = acn + ofs
        end

        if nf ~= -1 then
          if acn / nf % 1 ~= 0 then
            return false
          end
        else
          if acn ~= 0 then
            return false
          end
        end
      end
    end

    return true
  end
end

local function querySelector(selector, startingNode)
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
  deepMap(startingNode or renderer.model, function(el, level)
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

local function parseHex(hexStr)
  if hexStr:sub(1, 1) ~= "#" then
    error("'" .. hexStr .. "' is not a hex string")
  end
  hexStr = hexStr:sub(2)

  local len = #hexStr
  local finalNums = {}

  if len == 3 then
    for c in hexStr:gmatch(".") do
      finalNums[#finalNums + 1] = tonumber(c, 16) / 15
    end
  elseif len % 2 == 0 then
    for c in hexStr:gmatch("..") do
      finalNums[#finalNums + 1] = tonumber(c, 16) / 255
    end
  else
    error("'#" .. hexStr .. "' is of invalid length")
  end

  return finalNums
end

local function parseOffset(numStr)
  if numStr == "0" then
    return { "pixel", 0 }
  elseif numStr:match("%d+px") then
    return { "pixel", tonumber(numStr:match("%d+")) }
  elseif numStr:match("%d+rem") then
    return { "remain", tonumber(numStr:match("%d+")) }
  elseif numStr:match("%d+%%") then
    return { "percent", tonumber(numStr:match("%d+")) }
  end
end

local function matchCalc(str)
  local op = str:match("[%+%-]")
  local v1 = str:match("%(%s*([^%+%-%s]+)")
  local v2 = str:match("([^%+%-%s]+)%s*%)")

  return op, v1, v2
end

local function resolveVal(context, extra, valStr)
  if valStr == "unset" then
    return nil
  end

  local type = type(extra) == "table" and extra.type or extra

  if type == "string" then
    local dq = valStr:match("\"([^\"]+)\"")
    if dq then return dq end

    local sq = valStr:match("'([^']+)'")
    if sq then return sq end

    return valStr
  end

  if type == "number" then
    local val = parseOffset(valStr)
    if val[1] == "pixel" then
      return val[2]
    else
      return 0
    end
  end

  if type == "left" then
    if valStr:match("^calc") then
      local op, v1, v2 = matchCalc(valStr)
      if op == "+" then
        return resolveVal(context, extra, v1) + resolveVal(context, extra, v2) - context.flowX
      else
        return resolveVal(context, extra, v1) - resolveVal(context, extra, v2) + context.flowX
      end
    end

    local val = parseOffset(valStr)
    if val[1] == "pixel" then
      return context.flowX + val[2]
    elseif val[1] == "percent" then
      return context.width * (val[2] / 100) + context.flowX
    elseif val[1] == "remain" then
      return context.flowW * (val[2] / 100) + context.flowX
    end
  elseif type == "right" then
    if valStr:match("^calc") then
      local op, v1, v2 = matchCalc(valStr)
      if op == "+" then
        return resolveVal(context, extra, v1) - parseOffset(v2)[2] -- TODO Will not work with types other than pixel
      else
        return resolveVal(context, extra, v1) + parseOffset(v2)[2] -- TODO Same here ^^^
      end
    end

    local val = parseOffset(valStr)
    if val[1] == "pixel" then
      return context.flowX + context.flowW
          - val[2]
          - extra.width
    else
      return context.flowX
    end
    --  TODO Implement other methods
  end

  if type == "top" then
    if valStr:match("^calc") then
      local op, v1, v2 = matchCalc(valStr)
      if op == "+" then
        return resolveVal(context, extra, v1) + resolveVal(context, extra, v2) - context.flowY
      else
        return resolveVal(context, extra, v1) - resolveVal(context, extra, v2) + context.flowY
      end
    end

    local val = parseOffset(valStr)
    if val[1] == "pixel" then
      return context.flowY + val[2]
    elseif val[1] == "percent" then
      return context.height * (val[2] / 100) + context.flowY
    elseif val[1] == "remain" then
      return context.flowY * (val[2] / 100) + context.flowY
    end
  elseif type == "bottom" then
    if valStr:match("^calc") then
      local op, v1, v2 = matchCalc(valStr)
      if op == "+" then
        return resolveVal(context, extra, v1) - parseOffset(v2)[2] -- TODO Will not work with types other than pixel
      else
        return resolveVal(context, extra, v1) + parseOffset(v2)[2] -- TODO Same here ^^^
      end
    end

    local val = parseOffset(valStr)
    if val[1] == "pixel" then
      return context.flowY + context.flowH
          - val[2]
          - extra.height
    else
      return context.flowY
    end
    --  TODO Implement other methods
  end

  if type == "width" then
    if valStr:match("^calc") then
      local op, v1, v2 = matchCalc(valStr)
      if op == "+" then
        return resolveVal(context, extra, v1) + resolveVal(context, extra, v2)
      else
        return resolveVal(context, extra, v1) - resolveVal(context, extra, v2)
      end
    end

    local val = parseOffset(valStr)
    if val[1] == "pixel" then
      return val[2]
    elseif val[1] == "percent" then
      return context.width * (val[2] / 100)
    elseif val[1] == "remain" then
      return context.flowW * (val[2] / 100)
    end
  elseif type == "height" then
    if valStr:match("^calc") then
      local op, v1, v2 = matchCalc(valStr)
      if op == "+" then
        return resolveVal(context, extra, v1) + resolveVal(context, extra, v2)
      else
        return resolveVal(context, extra, v1) - resolveVal(context, extra, v2)
      end
    end

    local val = parseOffset(valStr)
    if val[1] == "pixel" then
      return val[2]
    elseif val[1] == "percent" then
      return context.height * (val[2] / 100)
    elseif val[1] == "remain" then
      return context.flowH * (val[2] / 100)
    end
  end

  if type == "color" then
    if valStr == "transparent" then
      return -1
    elseif renderer.colorReference[valStr] then
      return 2 ^ renderer.colorReference[valStr][1]
    elseif not valStr then
      return 0
    else
      error("Color '" .. valStr .. "' was never defined")
    end
  end
end

function renderer.processStyles(styles)
  local rulesets

  if styles then
    rulesets = css(styles)
    renderer.styles = rulesets

    local colorI
    for i = 1, #rulesets do
      if rulesets[i][1] == "colors" then
        colorI = i
        break
      end
    end

    local colorSet
    if colorI then
      colorSet = rulesets[colorI][2]
    else
      -- ComputerCraft Default Palette
      colorSet = {
        { "white", "#F0F0F0" },
        { "orange", "#F2B233" },
        { "magenta", "#E57FD8" },
        { "lightBlue", "#99B2F2" },
        { "yellow", "#DEDE6C" },
        { "lime", "#7FCC19" },
        { "pink", "#F2B2CC" },
        { "gray", "#4C4C4C" },
        { "lightGray", "#999999" },
        { "cyan", "#4C99B2" },
        { "purple", "#B266E5" },
        { "blue", "#3366CC" },
        { "brown", "#7F664C" },
        { "green", "#57A64E" },
        { "red", "#CC4C4C" },
        { "black", "#191919" }
      }
    end

    local toTab = {}

    local ci = 0
    for i = 1, #colorSet do
      if ci == 16 then
        error("Too many colors")
      end

      local color, hex = colorSet[i][1], colorSet[i][2]

      toTab[color:match("^%-?%-?([^%-]+)$")] = { ci, hex:match("#(.+)") }
      ci = ci + 1
    end

    colorSet = toTab

    renderer.colorReference = colorSet
  else
    rulesets = renderer.styles
  end

  for rulesetI = 1, #rulesets do
    local k = rulesets[rulesetI][1]
    local v = rulesets[rulesetI][2]
    local matches = querySelector(k)

    foreach(matchedEl, matches) do
      matchedEl.styles = matchedEl.styles or {}

      for j = 1, #v do
        local prop = v[j][1]
        local val = v[j][2]
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
  foreach(el, body.children) do
    if components[el.name] then
      el.adapter = components[el.name].new(el, renderer, resolveVal)
    else
      error("Unknown element " .. el.name)
    end
  end
end

function renderer.renderToSurface(surf, node, context)
  node = node or renderer.model.children[1]

  context = context or {
    flowX = 0,
    flowY = 0,
    flowW = surf.width,
    flowH = surf.height,
    width = surf.width,
    height = surf.height
  }

  if node.styles and node.styles["background-color"] then
    local c = resolveVal({}, "color", node.styles["background-color"])
    surf:clear(c)
  end

  foreach(el, node.children) do
    if not el.styles then el.styles = {} end
    local s = el.styles

    if s.display ~= "none" then
      local px, py, pw, ph =
      context.flowX, context.flowY,
      context.flowW, context.flowH

      if s.position == "absolute" then
        context = {
          flowX = context.flowX,
          flowY = context.flowY,
          flowW = surf.width,
          flowH = surf.height,
          width = surf.width,
          height = surf.height
        }

        if s.left or s.right then
          context.flowX = 0
        end

        if s.top or s.bottom then
          context.flowY = 0
        end
      end

      print(surf.width)
      print(context.flowW)
      print(s.width or "100rem")

      local width, height
      width = resolveVal(context, "width", s.width or "100rem")
      print(width)
      read()

      if not s.height and el.adapter and el.adapter.resolveHeight then
        s.height = el.adapter:resolveHeight(s, { flow = context, width = width }, resolveVal)
      end
      height = resolveVal(context, "height", s.height or "100rem")

      local left
      if s.right then
        left = resolveVal(context, { type = "right", width = width }, s.right)
      else
        left = resolveVal(context, "left", s.left or "0")
      end

      local top
      if s.bottom then
        top = resolveVal(context, { type = "bottom", height = height }, s.bottom)
      else
        top = resolveVal(context, "top", s.top or "0")
      end

      if el.adapter then
        el.adapter:render(surf, {
          left = left,
          top = top,
          width = width,
          height = height
        }, s, resolveVal)

        context.flowY = context.flowY + height
        context.flowH = context.flowH - height
      end

      if s.position == "absolute" then
        context = {
          flowX = px,
          flowY = py,
          flowW = pw,
          flowH = ph,
          width = surf.width,
          height = surf.height
        }
      end
    end
  end
end

renderer.querySelector = querySelector

return renderer
