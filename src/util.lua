local util = {}

function util.toListName(modid, damage, pred)
  return modid .. "::" .. damage .. "::" .. pred
end

function util.fromListName(lName)
  return lName:match("^(.-)::")
end

function util.wrappedWrite(surf, text, x, y, width, color, align, lineHeight)
  lineHeight = lineHeight or 1

  local lines = {""}

  text = tostring(text)

  local stX, stY = x, y + math.floor((lineHeight - 1) / 2)
  for word in text:gmatch("%S+") do
    if x + #word > stX + width and x ~= stX then
      x = stX
      y = y + lineHeight
      lines[#lines] = lines[#lines]:sub(1, -2)
      lines[#lines + 1] = ""
    end

    lines[#lines] = lines[#lines] .. word .. " "
    x = x + #word + 1
  end

  lines[#lines] = lines[#lines]:sub(1, -2)

  if surf then
    for i = 1, #lines do
      if align == "right" then
        surf:drawString(lines[i], stX + width - #lines[i], stY + (i - 1)*lineHeight, nil, color)
      elseif align == "center" then
        surf:drawString(lines[i], stX + math.floor((width - #lines[i]) / 2), stY + (i - 1)*lineHeight, nil, color)
      elseif align == "justify" and i ~= #lines then
        local lineStr = lines[i]
        local requiredExtra = width - #(lineStr:gsub("%s", ""))

        local finalStr = ""
        local _, wordCount = lineStr:gsub("%S+", "")

        if wordCount == 1 then
          finalStr = lineStr:gsub("%s", "")
        else
          local spacePerInstance = math.floor(requiredExtra / (wordCount - 1))
          local overflowAmount = requiredExtra - (spacePerInstance * (wordCount - 1))

          local wordI = 0
          for word in lineStr:gmatch("%S+") do
            wordI = wordI + 1

            local padding = spacePerInstance
            if wordI == wordCount then
              padding = 0
            elseif overflowAmount > 0 then
              padding = padding + 1
              overflowAmount = overflowAmount - 1
            end

            finalStr = finalStr .. word .. (" "):rep(padding)
          end
        end

        surf:drawString(finalStr, stX, stY + (i - 1)*lineHeight, nil, color)
      else -- left
        surf:drawString(lines[i], stX, stY + (i - 1)*lineHeight, nil, color)
      end
    end
  end

  return y + math.ceil((lineHeight - 1) / 2) + 1
end

function util.deepClone(table, cache)
  cache = cache or {}
  local t = {}

  cache[table] = t

  for k, v in pairs(table) do
    if type(v) == "table" then
      if cache[v] then
        t[k] = cache[v]
      else
        t[k] = util.deepClone(v, cache)
      end
    else
      t[k] = v
    end
  end

  return t
end

function util.round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

function util.matchPredicate(predicate, tab)
  if not tab then
    return false
  end

  for k, v in pairs(predicate) do
    local kType = type(k)
    if kType ~= "number" then
      if not tab[k] then
        return false
      end
    end

    if type(v) == "table" then
      return util.matchPredicate(v, tab[k])
    else
      if kType == "number" then
        local found = false
        for i = 1, #tab do
          if tab[k] == v then
            found = true
            break
          end
        end

        return found
      else
        if tab[k] ~= v then
          return false
        end
      end
    end
  end

  return true
end

function util.equals(val1, val2)
  local typeV = type(val1)
  
  if typeV ~= type(val2) then
    return false
  end

  if typeV ~= "table" then
    return val1 == val2
  end

  local lengthV1 = 0
  for k, v in pairs(val1) do
    lengthV1 = lengthV1 + 1

    if not util.equals(v, val2[k]) then
      return false
    end
  end

  local lengthV2 = 0
  for _ in pairs(val2) do
    lengthV2 = lengthV2 + 1
  end

  return lengthV1 == lengthV2
end

return util