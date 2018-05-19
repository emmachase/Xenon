local basicTextComponent = {}

local function calcWidth(text)
  if #text == 0 then return 0 end

  local w = -1
  for i = 1, #text do
    w = w + font.widths[string.byte(text:sub(i, i)) - 31] + 1
  end

  return w
end

local function writeBig(surf, text, x, y, col, bg, align, width)
  local tempSurf = surface.create(math.ceil(calcWidth(text) / 2) * 2, math.ceil(font.height / 3) * 3, bg)

  tempSurf:drawText(text, font, 0, 0, col, bg, bg)
  surf:drawSurfaceSmall(tempSurf, x, y)
end

local function calcSizeBig(text)
  return math.ceil(calcWidth(text) / 2) * 2, math.ceil(font.height / 3) * 3
end

function basicTextComponent.new(node)
  return setmetatable({ node = node }, { __index = basicTextComponent })
end

function basicTextComponent:render(surf, position, styles, resolver)
  local bgc
  if styles["background-color"] then
    bgc = resolver({}, "color", styles["background-color"])
    if bgc > 0 then
      surf:fillRect(position.left, position.top, position.width, position.height, bgc)
    end
  end

  local pads = {}
  for pad in (styles.padding or "0"):gmatch("%S+") do
    pads[#pads + 1] = pad
  end

  local topPad = resolver({}, "number", pads[1])
  local rightPad = resolver({}, "number", pads[2] or pads[1])
  --  local bottomPad = resolver({}, "number", pads[3] or pads[1])
  local leftPad = resolver({}, "number", pads[4] or pads[2] or pads[1])

  if styles["line-height"] then
    local lh = resolver({}, "number", styles["line-height"])

    topPad = topPad + math.floor((lh - 1) / 2)
--    bottomPad = bottomPad + math.ceil((lh - 1) / 2)
  end

  local cY = position.top + topPad

  if styles["background"] then
    local path = styles["background"]:match("url(%b())"):sub(2, -2)
    local img = surface.load(path)

    local mw, mh = math.ceil(img.width / 2) * 2, math.ceil(img.height / 3) * 3
    if img.width ~= mw or img.height ~= mh then
      if bgc <= 0 then
        -- Gotta guess
        bgc = 0
      end

      local temp = surface.create(mw, mh, bgc)
      temp:drawSurface(img, 0, 0)

      img = temp
    end

    local pos = styles["background-position"] or "center"

    if pos == "left" then
      surf:drawSurfaceSmall(img, position.left + leftPad, cY)
    elseif pos == "right" then
      surf:drawSurfaceSmall(img, position.left + position.width - rightPad - img.width / 2, cY)
    elseif pos == "center" then
      surf:drawSurfaceSmall(img, position.left + math.floor((position.width - rightPad - img.width / 2) / 2), cY)
    end
  elseif styles.content then
    if styles["font-size"] == "2em" then
      if bgc <= 0 then
        error("'font-size: 2em' requires 'background-color' to be present")
      end

      writeBig(surf, resolver({}, "string", styles.content),
        position.left + leftPad, cY,
        resolver({}, "color", styles.color), bgc,
        styles["text-align"] or "left", position.width - leftPad - rightPad)
    else
      util.wrappedWrite(surf, resolver({}, "string", styles.content),
        position.left + leftPad, cY, position.width - leftPad - rightPad,
        resolver({}, "color", styles.color), styles["text-align"] or "left")
    end
  else
    if styles["font-size"] == "2em" then
      if bgc <= 0 then
        error("'font-size: 2em' requires 'background-color' to be present")
      end

      -- TODO Wrapping support?
      local text = self.node.children[1].content or ""
      writeBig(surf, text,
        position.left + leftPad, cY,
        resolver({}, "color", styles.color), bgc,
        styles["text-align"] or "left", position.width - leftPad - rightPad)
    else
      local children = self.node.children
      local acc = ""
      for i = 1, #children do
        if children[i].type == "text" then
          acc = acc .. children[i].content
        elseif children[i].name == "br" then
          cY = util.wrappedWrite(surf, acc,
            position.left + leftPad, cY, position.width - leftPad - rightPad,
            resolver({}, "color", styles.color), styles["text-align"] or "left")
          acc = ""
        elseif children[i].name == "span" then
          acc = acc .. children[i].children[1].content
        end
      end
      if #acc > 0 then
        util.wrappedWrite(surf, acc,
          position.left + leftPad, cY, position.width - leftPad - rightPad,
          resolver({}, "color", styles.color), styles["text-align"] or "left")
      end
    end
  end
end

function basicTextComponent:resolveHeight(styles, context, resolver)
  local pads = {}
  for pad in (styles.padding or "0"):gmatch("%S+") do
    pads[#pads + 1] = pad
  end

  local topPad = resolver({}, "number", pads[1])
  local rightPad = resolver({}, "number", pads[2] or pads[1])
  local bottomPad = resolver({}, "number", pads[3] or pads[1])
  local leftPad = resolver({}, "number", pads[4] or pads[2] or pads[1])

  local cY = 0

  if styles["line-height"] then
    local lh = resolver({}, "number", styles["line-height"])

    topPad = topPad + math.floor((lh - 1) / 2)
    bottomPad = bottomPad + math.ceil((lh - 1) / 2)
  end

  if styles["background"] then
    local path = styles["background"]:match("url(%b())"):sub(2, -2)
    local img = surface.load(path)

    cY = math.ceil(img.height / 3)
  elseif styles["font-size"] == "2em" then
    cY = math.ceil(font.height / 3)
  elseif styles.content then
    cY = util.wrappedWrite(nil, resolver({}, "string", styles.content),
      0, cY, context.width - leftPad - rightPad)
  else
    local children = self.node.children
    local acc = ""
    for i = 1, #children do
      if children[i].type == "text" then
        acc = acc .. children[i].content
      elseif children[i].name == "br" then
        cY = util.wrappedWrite(nil, acc,
          position.left + leftPad, cY, position.width - leftPad - rightPad)
        acc = ""
        cY = cY + 1
      elseif children[i].name == "span" then
        acc = acc .. children[i].children[1].content
      end
    end
    cY = cY + 1
  end

  return (topPad + bottomPad + cY) .. "px"
end

return basicTextComponent
