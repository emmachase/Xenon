-- vim: syntax=lua
-- luacheck: globals loadRemote getRemote fs loadstring peripheral


local versionTag = "v3.0.1"

local args = {...}
local layoutMode = args[1] == "--layout" or args[1] == "-l"

local successTools = {}

local function xenon()
local util = (function()
  if util then return util end
local util = {}

function util.toListName(modid, pred)
  return modid .. "::" .. pred
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

function util.parseOrdinalStyle(resolver, styles, styleName)
  local ordinals = {}
  for ordinal in (styles[styleName] or "0"):gmatch("%S+") do
    ordinals[#ordinals + 1] = ordinal
  end

  if styles[styleName .. "-top"]    then ordinals[1] = styles[styleName .. "-top"] end
  if styles[styleName .. "-right"]  then ordinals[2] = styles[styleName .. "-right"] end
  if styles[styleName .. "-bottom"] then ordinals[3] = styles[styleName .. "-bottom"] end
  if styles[styleName .. "-left"]   then ordinals[4] = styles[styleName .. "-left"] end

  local top = resolver({}, "number", ordinals[1])
  local right = resolver({}, "number", ordinals[2] or ordinals[1])
  local bottom = resolver({}, "number", ordinals[3] or ordinals[1])
  local left = resolver({}, "number", ordinals[4] or ordinals[2] or ordinals[1])

  return top, right, bottom, left
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

return util end)()

  -- Load local config
  local configHandle = fs.open(fs.combine(shell.dir(), "config.lua"), "r")
  if not configHandle then
    configHandle = fs.open(fs.combine(shell.dir(), ".config"), "r")

    if not configHandle then
      error("No config file found at '.config', please create one")
    end
  end

  local config
  local configData = configHandle.readAll()
  if not configData:match("^return") then
    configData = "return " .. configData
  end
  local configFunc, err = loadstring(configData)
  if not configFunc then
    error("Invalid config: Line " .. (err:match(":(%d+:.+)") or err))
  else
    config = configFunc()
  end

  configHandle.close()
  
  if not (turtle or layoutMode) then -- or config.outChest) then
    error("Xenon must run on a turtle")
  end


local transformedItems = {}

local predicateCache = {}
local predicateIDCounter = 0
for i = 1, #config.items do local item = config.items[i] -- do
  if item.predicate then
    for predicateID = 1, #predicateCache do
      local predicate = predicateCache[predicateID]
      if util.equals(predicate, item.predicate) then
        item.predicateID = predicateID
      end
    end

    if not item.predicateID then
      predicateIDCounter = predicateIDCounter + 1

      item.predicateID = predicateIDCounter
      predicateCache[predicateIDCounter] = item.predicate
    end
  end

  transformedItems[util.toListName(item.modid, item.predicateID or 0)] = item
end


--== Load required libs / files ==--


local surface = (function()
  if surface then return surface end
local surface = { } do
    --[[
    Surface 2

    The MIT License (MIT)
    Copyright (c) 2017 CrazedProgrammer

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction,
    including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
    so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or
    substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
    PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
    AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]]
    local surf = { }
    surface.surf = surf

    local table_concat, math_floor, math_atan2 = table.concat, math.floor, math.atan2

    local _cc_color_to_hex, _cc_hex_to_color = { }, { }
    for i = 0, 15 do
        _cc_color_to_hex[2 ^ i] = string.format("%01x", i)
        _cc_hex_to_color[string.format("%01x", i)] = 2 ^ i
    end

    local _chars = { }
    for i = 0, 255 do
        _chars[i] = string.char(i)
    end
    local _numstr = { }
    for i = 0, 1023 do
        _numstr[i] = tostring(i)
    end

    local _eprc, _esin, _ecos = 20, { }, { }
    for i = 0, _eprc - 1 do
        _esin[i + 1] = (1 - math.sin(i / _eprc * math.pi * 2)) / 2
        _ecos[i + 1] = (1 + math.cos(i / _eprc * math.pi * 2)) / 2
    end

    local _steps, _palette, _rgbpal, _palr, _palg, _palb = 16

    local function calcStack(stack, width, height)
        local ox, oy, cx, cy, cwidth, cheight = 0, 0, 0, 0, width, height
        for i = 1, #stack do
            ox = ox + stack[i].ox
            oy = oy + stack[i].oy
            cx = cx + stack[i].x
            cy = cy + stack[i].y
            cwidth = stack[i].width
            cheight = stack[i].height
        end
        return ox, oy, cx, cy, cwidth, cheight
    end

    local function clipRect(x, y, width, height, cx, cy, cwidth, cheight)
        if x < cx then
            width = width + x - cx
            x = cx
        end
        if y < cy then
            height = height + y - cy
            y = cy
        end
        if x + width > cx + cwidth then
            width = cwidth + cx - x
        end
        if y + height > cy + cheight then
            height = cheight + cy - y
        end
        return x, y, width, height
    end



    function surface.create(width, height, b, t, c)
        local surface = setmetatable({ }, {__index = surface.surf})
        surface.width = width
        surface.height = height
        surface.buffer = { }
        surface.overwrite = false
        surface.stack = { }
        surface.ox, surface.oy, surface.cx, surface.cy, surface.cwidth, surface.cheight = calcStack(surface.stack, width, height)
        -- force array indeces instead of hashed indices

        local buffer = surface.buffer
        for i = 1, width * height * 3, 3 do
            buffer[i] = b or false
            buffer[i + 1] = t or false
            buffer[i + 2] = c or false
        end
        buffer[width * height * 3 + 1] = false
        if not b then
            for i = 1, width * height * 3, 3 do
                buffer[i] = b
            end
        end
        if not t then
            for i = 2, width * height * 3, 3 do
                buffer[i] = t
            end
        end
        if not c then
            for i = 3, width * height * 3, 3 do
                buffer[i] = c
            end
        end

        return surface
    end

    function surface.getPlatformOutput(output)
        output = output or (term or gpu or (love and love.graphics) or io)

        if output.blit and output.setCursorPos then
            return "cc", output, output.getSize()
        elseif output.write and output.setCursorPos and output.setTextColor and output.setBackgroundColor then
            return "cc-old", output, output.getSize()
        elseif output.blitPixels then
            return "riko-4", output, 320, 200
        elseif output.points and output.setColor then
            return "love2d", output, output.getWidth(), output.getHeight()
        elseif output.drawPixel then
            return "redirection", output, 64, 64
        elseif output.setForeground and output.setBackground and output.set then
            return "oc", output, output.getResolution()
        elseif output.write then
            return "ansi", output, (os.getenv and (os.getenv("COLUMNS"))) or 80, (os.getenv and (os.getenv("LINES"))) or 43
        else
            error("unsupported platform/output object")
        end
    end

    function surf:output(output, x, y, sx, sy, swidth, sheight)
        local platform, output, owidth, oheight = surface.getPlatformOutput(output)

        x = x or 0
        y = y or 0
        sx = sx or 0
        sy = sy or 0
        swidth = swidth or self.width
        sheight = sheight or self.height
        sx, sy, swidth, sheight = clipRect(sx, sy, swidth, sheight, 0, 0, self.width, self.height)

        local buffer = self.buffer
        local bwidth = self.width
        local xoffset, yoffset, idx

        if platform == "cc" then
            -- CC
            local str, text, back = { }, { }, { }
            for j = 0, sheight - 1 do
                yoffset = (j + sy) * bwidth + sx
                for i = 0, swidth - 1 do
                    xoffset = (yoffset + i) * 3
                    idx = i + 1
                    str[idx] = buffer[xoffset + 3] or " "
                    text[idx] = _cc_color_to_hex[buffer[xoffset + 2] or 1]
                    back[idx] = _cc_color_to_hex[buffer[xoffset + 1] or 32768]
                end
                output.setCursorPos(x + 1, y + j + 1)
                output.blit(table_concat(str), table_concat(text), table_concat(back))
            end

        elseif platform == "cc-old" then
            -- CC pre-1.76
            local str, b, t, pb, pt = { }
            for j = 0, sheight - 1 do
                output.setCursorPos(x + 1, y + j + 1)
                yoffset = (j + sy) * bwidth + sx
                for i = 0, swidth - 1 do
                    xoffset = (yoffset + i) * 3
                    pb = buffer[xoffset + 1] or 32768
                    pt = buffer[xoffset + 2] or 1
                    if pb ~= b then
                        if #str ~= 0 then
                            output.write(table_concat(str))
                            str = { }
                        end
                        b = pb
                        output.setBackgroundColor(b)
                    end
                    if pt ~= t then
                        if #str ~= 0 then
                            output.write(table_concat(str))
                            str = { }
                        end
                        t = pt
                        output.setTextColor(t)
                    end
                    str[#str + 1] = buffer[xoffset + 3] or " "
                end
                output.write(table_concat(str))
                str = { }
            end

        elseif platform == "riko-4" then
            -- Riko 4
            local pixels = { }
            for j = 0, sheight - 1 do
                yoffset = (j + sy) * bwidth + sx
                for i = 0, swidth - 1 do
                    pixels[j * swidth + i + 1] = buffer[(yoffset + i) * 3 + 1] or 0
                end
            end
            output.blitPixels(x, y, swidth, sheight, pixels)

        elseif platform == "love2d" then
            -- Love2D
            local pos, r, g, b, pr, pg, pb = { }
            for j = 0, sheight - 1 do
                yoffset = (j + sy) * bwidth + sx
                for i = 0, swidth - 1 do
                    xoffset = (yoffset + i) * 3
                    pr = buffer[xoffset + 1]
                    pg = buffer[xoffset + 2]
                    pb = buffer[xoffset + 3]
                    if pr ~= r or pg ~= g or pb ~= b then
                        if #pos ~= 0 then
                            output.setColor((r or 0) * 255, (g or 0) * 255, (b or 0) * 255, (r or g or b) and 255 or 0)
                            output.points(pos)
                        end
                        r, g, b = pr, pg, pb
                        pos = { }
                    end
                    pos[#pos + 1] = i + x + 1
                    pos[#pos + 1] = j + y + 1
                end
            end
            output.setColor((r or 0) * 255, (g or 0) * 255, (b or 0) * 255, (r or g or b) and 255 or 0)
            output.points(pos)

        elseif platform == "redirection" then
            -- Redirection arcade (gpu)
            -- todo: add image:write support for extra performance
            local px = output.drawPixel
            for j = 0, sheight - 1 do
                for i = 0, swidth - 1 do
                    px(x + i, y + j, buffer[((j + sy) * bwidth + (i + sx)) * 3 + 1] or 0)
                end
            end

        elseif platform == "oc" then
            -- OpenComputers
            local str, lx, b, t, pb, pt = { }
            for j = 0, sheight - 1 do
                lx = x
                yoffset = (j + sy) * bwidth + sx
                for i = 0, swidth - 1 do
                    xoffset = (yoffset + i) * 3
                    pb = buffer[xoffset + 1] or 0x000000
                    pt = buffer[xoffset + 2] or 0xFFFFFF
                    if pb ~= b then
                        if #str ~= 0 then
                            output.set(lx + 1, j + y + 1, table_concat(str))
                            lx = i + x
                            str = { }
                        end
                        b = pb
                        output.setBackground(b)
                    end
                    if pt ~= t then
                        if #str ~= 0 then
                            output.set(lx + 1, j + y + 1, table_concat(str))
                            lx = i + x
                            str = { }
                        end
                        t = pt
                        output.setForeground(t)
                    end
                    str[#str + 1] = buffer[xoffset + 3] or " "
                end
                output.set(lx + 1, j + y + 1, table_concat(str))
                str = { }
            end

        elseif platform == "ansi" then
            -- ANSI terminal
            local str, b, t, pb, pt = { }
            for j = 0, sheight - 1 do
                str[#str + 1] = "\x1b[".._numstr[y + j + 1]..";".._numstr[x + 1].."H"
                yoffset = (j + sy) * bwidth + sx
                for i = 0, swidth - 1 do
                    xoffset = (yoffset + i) * 3
                    pb = buffer[xoffset + 1] or 0
                    pt = buffer[xoffset + 2] or 7
                    if pb ~= b then
                        b = pb
                        if b < 8 then
                            str[#str + 1] = "\x1b[".._numstr[40 + b].."m"
                        elseif b < 16 then
                            str[#str + 1] = "\x1b[".._numstr[92 + b].."m"
                        elseif b < 232 then
                            str[#str + 1] = "\x1b[48;2;".._numstr[math_floor((b - 16) / 36 * 85 / 2)]..";".._numstr[math_floor((b - 16) / 6 % 6 * 85 / 2)]..";".._numstr[math_floor((b - 16) % 6 * 85 / 2)].."m"
                        else
                            local gr = _numstr[b * 10 - 2312]
                            str[#str + 1] = "\x1b[48;2;"..gr..";"..gr..";"..gr.."m"
                        end
                    end
                    if pt ~= t then
                        t = pt
                        if t < 8 then
                            str[#str + 1] = "\x1b[".._numstr[30 + t].."m"
                        elseif t < 16 then
                            str[#str + 1] = "\x1b[".._numstr[82 + t].."m"
                        elseif t < 232 then
                            str[#str + 1] = "\x1b[38;2;".._numstr[math_floor((t - 16) / 36 * 85 / 2)]..";".._numstr[math_floor((t - 16) / 6 % 6 * 85 / 2)]..";".._numstr[math_floor((t - 16) % 6 * 85 / 2)].."m"
                        else
                            local gr = _numstr[t * 10 - 2312]
                            str[#str + 1] = "\x1b[38;2;"..gr..";"..gr..";"..gr.."m"
                        end
                    end
                    str[#str + 1] = buffer[xoffset + 3] or " "
                end
            end
            output.write(table_concat(str))
        end
    end

    function surf:push(x, y, width, height, nooffset)
        x, y = x + self.ox, y + self.oy

        local ox, oy = nooffset and self.ox or x, nooffset and self.oy or y
        x, y, width, height = clipRect(x, y, width, height, self.cx, self.cy, self.cwidth, self.cheight)
        self.stack[#self.stack + 1] = {ox = ox - self.ox, oy = oy - self.oy, x = x - self.cx, y = y - self.cy, width = width, height = height}

        self.ox, self.oy, self.cx, self.cy, self.cwidth, self.cheight = calcStack(self.stack, self.width, self.height)
    end

    function surf:pop()
        if #self.stack == 0 then
            error("no stencil to pop")
        end
        self.stack[#self.stack] = nil
        self.ox, self.oy, self.cx, self.cy, self.cwidth, self.cheight = calcStack(self.stack, self.width, self.height)
    end

    function surf:copy()
        local surface = setmetatable({ }, {__index = surface.surf})

        for k, v in pairs(self) do
            surface[k] = v
        end

        surface.buffer = { }
        for i = 1, self.width * self.height * 3 + 1 do
            surface.buffer[i] = false
        end
        for i = 1, self.width * self.height * 3 do
            surface.buffer[i] = self.buffer[i]
        end

        surface.stack = { }
        for i = 1, #self.stack do
            surface.stack[i] = self.stack[i]
        end

        return surface
    end

    function surf:clear(b, t, c)
        local xoffset, yoffset

        for j = 0, self.cheight - 1 do
            yoffset = (j + self.cy) * self.width + self.cx
            for i = 0, self.cwidth - 1 do
                xoffset = (yoffset + i) * 3
                self.buffer[xoffset + 1] = b
                self.buffer[xoffset + 2] = t
                self.buffer[xoffset + 3] = c
            end
        end
    end

    function surf:drawPixel(x, y, b, t, c)
        x, y = x + self.ox, y + self.oy

        local idx
        if x >= self.cx and x < self.cx + self.cwidth and y >= self.cy and y < self.cy + self.cheight then
            idx = (y * self.width + x) * 3
            if b or self.overwrite then
                self.buffer[idx + 1] = b
            end
            if t or self.overwrite then
                self.buffer[idx + 2] = t
            end
            if c or self.overwrite then
                self.buffer[idx + 3] = c
            end
        end
    end

    function surf:drawString(str, x, y, b, t)
        x, y = x + self.ox, y + self.oy

        local sx = x
        local insidey = y >= self.cy and y < self.cy + self.cheight
        local idx
        local lowerxlim = self.cx
        local upperxlim = self.cx + self.cwidth
        local writeb = b or self.overwrite
        local writet = t or self.overwrite

        for i = 1, #str do
            local c = str:sub(i, i)
            if c == "\n" then
                x = sx
                y = y + 1
                if insidey then
                    if y >= self.cy + self.cheight then
                        return
                    end
                else
                    insidey = y >= self.cy
                end
            else
                idx = (y * self.width + x) * 3
                if x >= lowerxlim and x < upperxlim and insidey then
                    if writeb then
                        self.buffer[idx + 1] = b
                    end
                    if writet then
                        self.buffer[idx + 2] = t
                    end
                    self.buffer[idx + 3] = c
                end
                x = x + 1
            end
        end
    end

    -- You can remove any of these components
    function surface.load(strpath, isstr)
        local data = strpath
        if not isstr then
            local handle = io.open(strpath, "rb")
            if not handle then return end
            local chars = { }
            local byte = handle:read(1)
            if type(byte) == "number" then -- cc doesn't conform to standards
                while byte do
                    chars[#chars + 1] = _chars[byte]
                    byte = handle:read(1)
                end
            else
                while byte do
                    chars[#chars + 1] = byte
                    byte = handle:read(1)
                end
            end
            handle:close()
            data = table_concat(chars)
        end

        if data:sub(1, 3) == "RIF" then
            -- Riko 4 image format
            local width, height = data:byte(4) * 256 + data:byte(5), data:byte(6) * 256 + data:byte(7)
            local surf = surface.create(width, height)
            local buffer = surf.buffer
            local upper, byte = 8, false
            local byte = data:byte(index)

            for j = 0, height - 1 do
                for i = 0, height - 1 do
                    if not upper then
                        buffer[(j * width + i) * 3 + 1] = math_floor(byte / 16)
                    else
                        buffer[(j * width + i) * 3 + 1] = byte % 16
                        index = index + 1
                        data = data:byte(index)
                    end
                    upper = not upper
                end
            end
            return surf

        elseif data:sub(1, 2) == "BM" then
            -- BMP format
            local width = data:byte(0x13) + data:byte(0x14) * 256
            local height = data:byte(0x17) + data:byte(0x18) * 256
            if data:byte(0xF) ~= 0x28 or data:byte(0x1B) ~= 1 or data:byte(0x1D) ~= 0x18 then
                error("unsupported bmp format, only uncompressed 24-bit rgb is supported.")
            end
            local offset, linesize = 0x36, math.ceil((width * 3) / 4) * 4

            local surf = surface.create(width, height)
            local buffer = surf.buffer
            for j = 0, height - 1 do
                for i = 0, width - 1 do
                    buffer[(j * width + i) * 3 + 1] = data:byte((height - j - 1) * linesize + i * 3 + offset + 3) / 255
                    buffer[(j * width + i) * 3 + 2] = data:byte((height - j - 1) * linesize + i * 3 + offset + 2) / 255
                    buffer[(j * width + i) * 3 + 3] = data:byte((height - j - 1) * linesize + i * 3 + offset + 1) / 255
                end
            end
            return surf

        elseif data:find("\30") then
            -- NFT format
            local width, height, lwidth = 0, 1, 0
            for i = 1, #data do
                if data:byte(i) == 10 then -- newline
                    height = height + 1
                    if lwidth > width then
                        width = lwidth
                    end
                    lwidth = 0
                elseif data:byte(i) == 30 or data:byte(i) == 31 then -- color control
                    lwidth = lwidth - 1
                elseif data:byte(i) ~= 13 then -- not carriage return
                    lwidth = lwidth + 1
                end
            end
            if data:byte(#data) == 10 then
                height = height - 1
            end

            local surf = surface.create(width, height)
            local buffer = surf.buffer
            local index, x, y, b, t = 1, 0, 0

            while index <= #data do
                if data:byte(index) == 10 then
                    x, y = 0, y + 1
                elseif data:byte(index) == 30 then
                    index = index + 1
                    b = _cc_hex_to_color[data:sub(index, index)]
                elseif data:byte(index) == 31 then
                    index = index + 1
                    t = _cc_hex_to_color[data:sub(index, index)]
                elseif data:byte(index) ~= 13 then
                    buffer[(y * width + x) * 3 + 1] = b
                    buffer[(y * width + x) * 3 + 2] = t
                    if b or t then
                        buffer[(y * width + x) * 3 + 3] = data:sub(index, index)
                    elseif data:sub(index, index) ~= " " then
                        buffer[(y * width + x) * 3 + 3] = data:sub(index, index)
                    end
                    x = x + 1
                end
                index = index + 1
            end

            return surf
        else
            -- NFP format
            local width, height, lwidth = 0, 1, 0
            for i = 1, #data do
                if data:byte(i) == 10 then -- newline
                    height = height + 1
                    if lwidth > width then
                        width = lwidth
                    end
                    lwidth = 0
                elseif data:byte(i) ~= 13 then -- not carriage return
                    lwidth = lwidth + 1
                end
            end
            if data:byte(#data) == 10 then
                height = height - 1
            end

            local surf = surface.create(width, height)
            local buffer = surf.buffer
            local x, y = 0, 0
            for i = 1, #data do
                if data:byte(i) == 10 then
                    x, y = 0, y + 1
                elseif data:byte(i) ~= 13 then
                    buffer[(y * width + x) * 3 + 1] = _cc_hex_to_color[data:sub(i, i)]
                    x = x + 1
                end
            end

            return surf
        end
    end

    function surf:save(file, format)
        format = format or "nfp"
        local data = { }
        if format == "nfp" then
            for j = 0, self.height - 1 do
                for i = 0, self.width - 1 do
                    data[#data + 1] = _cc_color_to_hex[self.buffer[(j * self.width + i) * 3 + 1]] or " "
                end
                data[#data + 1] = "\n"
            end

        elseif format == "nft" then
            for j = 0, self.height - 1 do
                local b, t, pb, pt
                for i = 0, self.width - 1 do
                    pb = self.buffer[(j * self.width + i) * 3 + 1]
                    pt = self.buffer[(j * self.width + i) * 3 + 2]
                    if pb ~= b then
                        data[#data + 1] = "\30"..(_cc_color_to_hex[pb] or " ")
                        b = pb
                    end
                    if pt ~= t then
                        data[#data + 1] = "\31"..(_cc_color_to_hex[pt] or " ")
                        t = pt
                    end
                    data[#data + 1] = self.buffer[(j * self.width + i) * 3 + 3] or " "
                end
                data[#data + 1] = "\n"
            end

        elseif format == "rif" then
            data[1] = "RIF"
            data[2] = string.char(math_floor(self.width / 256), self.width % 256)
            data[3] = string.char(math_floor(self.height / 256), self.height % 256)
            local byte, upper, c = 0, false
            for j = 0, self.width - 1 do
                for i = 0, self.height - 1 do
                    c = self.buffer[(j * self.width + i) * 3 + 1] or 0
                    if not upper then
                        byte = c * 16
                    else
                        byte = byte + c
                        data[#data + 1] = string.char(byte)
                    end
                    upper = not upper
                end
            end
            if upper then
                data[#data + 1] = string.char(byte)
            end

        elseif format == "bmp" then
            data[1] = "BM"
            data[2] = string.char(0, 0, 0, 0) -- file size, change later
            data[3] = string.char(0, 0, 0, 0, 0x36, 0, 0, 0, 0x28, 0, 0, 0)
            data[4] = string.char(self.width % 256, math_floor(self.width / 256), 0, 0)
            data[5] = string.char(self.height % 256, math_floor(self.height / 256), 0, 0)
            data[6] = string.char(1, 0, 0x18, 0, 0, 0, 0, 0)
            data[7] = string.char(0, 0, 0, 0) -- pixel data size, change later
            data[8] = string.char(0x13, 0x0B, 0, 0, 0x13, 0x0B, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

            local padchars = math.ceil((self.width * 3) / 4) * 4 - self.width * 3
            for j = self.height - 1, 0, -1 do
                for i = 0, self.width - 1 do
                    data[#data + 1] = string.char((self.buffer[(j * self.width + i) * 3 + 1] or 0) * 255)
                    data[#data + 1] = string.char((self.buffer[(j * self.width + i) * 3 + 2] or 0) * 255)
                    data[#data + 1] = string.char((self.buffer[(j * self.width + i) * 3 + 3] or 0) * 255)
                end
                data[#data + 1] = ("\0"):rep(padchars)
            end
            local size = #table_concat(data)
            data[2] = string.char(size % 256, math_floor(size / 256) % 256, math_floor(size / 65536), 0)
            size = size - 54
            data[7] = string.char(size % 256, math_floor(size / 256) % 256, math_floor(size / 65536), 0)

        else
            error("format not supported")
        end

        data = table_concat(data)
        if file then
            local handle = io.open(file, "wb")
            for i = 1, #data do
                handle:write(data:byte(i))
            end
            handle:close()
        end
        return data
    end
    function surf:drawLine(x1, y1, x2, y2, b, t, c)
        if x1 == x2 then
            x1, y1, x2, y2 = x1 + self.ox, y1 + self.oy, x2 + self.ox, y2 + self.oy
            if x1 < self.cx or x1 >= self.cx + self.cwidth then return end
            if y2 < y1 then
                local temp = y1
                y1 = y2
                y2 = temp
            end
            if y1 < self.cy then y1 = self.cy end
            if y2 >= self.cy + self.cheight then y2 = self.cy + self.cheight - 1 end
            if b or self.overwrite then
                for j = y1, y2 do
                    self.buffer[(j * self.width + x1) * 3 + 1] = b
                end
            end
            if t or self.overwrite then
                for j = y1, y2 do
                    self.buffer[(j * self.width + x1) * 3 + 2] = t
                end
            end
            if c or self.overwrite then
                for j = y1, y2 do
                    self.buffer[(j * self.width + x1) * 3 + 3] = c
                end
            end
        elseif y1 == y2 then
            x1, y1, x2, y2 = x1 + self.ox, y1 + self.oy, x2 + self.ox, y2 + self.oy
            if y1 < self.cy or y1 >= self.cy + self.cheight then return end
            if x2 < x1 then
                local temp = x1
                x1 = x2
                x2 = temp
            end
            if x1 < self.cx then x1 = self.cx end
            if x2 >= self.cx + self.cwidth then x2 = self.cx + self.cwidth - 1 end
            if b or self.overwrite then
                for i = x1, x2 do
                    self.buffer[(y1 * self.width + i) * 3 + 1] = b
                end
            end
            if t or self.overwrite then
                for i = x1, x2 do
                    self.buffer[(y1 * self.width + i) * 3 + 2] = t
                end
            end
            if c or self.overwrite then
                for i = x1, x2 do
                    self.buffer[(y1 * self.width + i) * 3 + 3] = c
                end
            end
        else
            local delta_x = x2 - x1
            local ix = delta_x > 0 and 1 or -1
            delta_x = 2 * math.abs(delta_x)
            local delta_y = y2 - y1
            local iy = delta_y > 0 and 1 or -1
            delta_y = 2 * math.abs(delta_y)
            self:drawPixel(x1, y1, b, t, c)
            if delta_x >= delta_y then
                local error = delta_y - delta_x / 2
                while x1 ~= x2 do
                    if (error >= 0) and ((error ~= 0) or (ix > 0)) then
                        error = error - delta_x
                        y1 = y1 + iy
                    end
                    error = error + delta_y
                    x1 = x1 + ix
                    self:drawPixel(x1, y1, b, t, c)
                end
            else
                local error = delta_x - delta_y / 2
                while y1 ~= y2 do
                    if (error >= 0) and ((error ~= 0) or (iy > 0)) then
                        error = error - delta_y
                        x1 = x1 + ix
                    end
                    error = error + delta_x
                    y1 = y1 + iy
                    self:drawPixel(x1, y1, b, t, c)
                end
            end
        end
    end

    function surf:drawRect(x, y, width, height, b, t, c)
        self:drawLine(x, y, x + width - 1, y, b, t, c)
        self:drawLine(x, y, x, y + height - 1, b, t, c)
        self:drawLine(x + width - 1, y, x + width - 1, y + height - 1, b, t, c)
        self:drawLine(x, y + height - 1, x + width - 1, y + height - 1, b, t, c)
    end

    function surf:fillRect(x, y, width, height, b, t, c)
        x, y, width, height = clipRect(x + self.ox, y + self.oy, width, height, self.cx, self.cy, self.cwidth, self.cheight)

        if b or self.overwrite then
            for j = 0, height - 1 do
                for i = 0, width - 1 do
                    self.buffer[((j + y) * self.width + i + x) * 3 + 1] = b
                end
            end
        end
        if t or self.overwrite then
            for j = 0, height - 1 do
                for i = 0, width - 1 do
                    self.buffer[((j + y) * self.width + i + x) * 3 + 2] = t
                end
            end
        end
        if c or self.overwrite then
            for j = 0, height - 1 do
                for i = 0, width - 1 do
                    self.buffer[((j + y) * self.width + i + x) * 3 + 3] = c
                end
            end
        end
    end

    function surf:drawTriangle(x1, y1, x2, y2, x3, y3, b, t, c)
        self:drawLine(x1, y1, x2, y2, b, t, c)
        self:drawLine(x2, y2, x3, y3, b, t, c)
        self:drawLine(x3, y3, x1, y1, b, t, c)
    end

    function surf:fillTriangle(x1, y1, x2, y2, x3, y3, b, t, c)
        if y1 > y2 then
            local tempx, tempy = x1, y1
            x1, y1 = x2, y2
            x2, y2 = tempx, tempy
        end
        if y1 > y3 then
            local tempx, tempy = x1, y1
            x1, y1 = x3, y3
            x3, y3 = tempx, tempy
        end
        if y2 > y3 then
            local tempx, tempy = x2, y2
            x2, y2 = x3, y3
            x3, y3 = tempx, tempy
        end
        if y1 == y2 and x1 > x2 then
            local temp = x1
            x1 = x2
            x2 = temp
        end
        if y2 == y3 and x2 > x3 then
            local temp = x2
            x2 = x3
            x3 = temp
        end

        local x4, y4
        if x1 <= x2 then
            x4 = x1 + (y2 - y1) / (y3 - y1) * (x3 - x1)
            y4 = y2
            local tempx, tempy = x2, y2
            x2, y2 = x4, y4
            x4, y4 = tempx, tempy
        else
            x4 = x1 + (y2 - y1) / (y3 - y1) * (x3 - x1)
            y4 = y2
        end

        local finvslope1 = (x2 - x1) / (y2 - y1)
        local finvslope2 = (x4 - x1) / (y4 - y1)
        local linvslope1 = (x3 - x2) / (y3 - y2)
        local linvslope2 = (x3 - x4) / (y3 - y4)

        local xstart, xend, dxstart, dxend
        for y = math.ceil(y1 + 0.5) - 0.5, math.floor(y3 - 0.5) + 0.5, 1 do
            if y <= y2 then -- first half
                xstart = x1 + finvslope1 * (y - y1)
                xend = x1 + finvslope2 * (y - y1)
            else -- second half
                xstart = x3 - linvslope1 * (y3 - y)
                xend = x3 - linvslope2 * (y3 - y)
            end

            dxstart, dxend = math.ceil(xstart - 0.5), math.floor(xend - 0.5)
            if dxstart <= dxend then
                self:drawLine(dxstart, y - 0.5, dxend, y - 0.5, b, t, c)
            end
        end
    end

    function surf:drawEllipse(x, y, width, height, b, t, c)
        for i = 0, _eprc - 1 do
            self:drawLine(math_floor(x + _ecos[i + 1] * (width - 1) + 0.5), math_floor(y + _esin[i + 1] * (height - 1) + 0.5), math_floor(x + _ecos[(i + 1) % _eprc + 1] * (width - 1) + 0.5), math_floor(y + _esin[(i + 1) % _eprc + 1] * (height - 1) + 0.5), b, t, c)
        end
    end

    function surf:fillEllipse(x, y, width, height, b, t, c)
        x, y = x + self.ox, y + self.oy

        local sx, sy
        for j = 0, height - 1 do
            for i = 0, width - 1 do
                sx, sy = i + x, j + y
                if ((i + 0.5) / width * 2 - 1) ^ 2 + ((j + 0.5) / height * 2 - 1) ^ 2 <= 1 and sx >= self.cx and sx < self.cx + self.cwidth and sy >= self.cy and sy < self.cy + self.cheight then
                    if b or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 1] = b
                    end
                    if t or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 2] = t
                    end
                    if c or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 3] = c
                    end
                end
            end
        end
    end

    function surf:drawArc(x, y, width, height, fromangle, toangle, b, t, c)
        if fromangle > toangle then
            local temp = fromangle
            fromangle = toangle
            temp = toangle
        end
        fromangle = math_floor(fromangle / math.pi / 2 * _eprc + 0.5)
        toangle = math_floor(toangle / math.pi / 2 * _eprc + 0.5) - 1

        for j = fromangle, toangle do
            local i = j % _eprc
            self:drawLine(math_floor(x + _ecos[i + 1] * (width - 1) + 0.5), math_floor(y + _esin[i + 1] * (height - 1) + 0.5), math_floor(x + _ecos[(i + 1) % _eprc + 1] * (width - 1) + 0.5), math_floor(y + _esin[(i + 1) % _eprc + 1] * (height - 1) + 0.5), b, t, c)
        end
    end

    function surf:fillArc(x, y, width, height, fromangle, toangle, b, t, c)
        x, y = x + self.ox, y + self.oy

        if fromangle > toangle then
            local temp = fromangle
            fromangle = toangle
            temp = toangle
        end
        local diff = toangle - fromangle
        fromangle = fromangle % (math.pi * 2)

        local fx, fy, sx, sy, dir
        for j = 0, height - 1 do
            for i = 0, width - 1 do
                fx, fy = (i + 0.5) / width * 2 - 1, (j + 0.5) / height * 2 - 1
                sx, sy = i + x, j + y
                dir = math_atan2(-fy, fx) % (math.pi * 2)
                if fx ^ 2 + fy ^ 2 <= 1 and ((dir >= fromangle and dir - fromangle <= diff) or (dir <= (fromangle + diff) % (math.pi * 2))) and sx >= self.cx and sx < self.cx + self.cwidth and sy >= self.cy and sy < self.cy + self.cheight then
                    if b or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 1] = b
                    end
                    if t or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 2] = t
                    end
                    if c or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 3] = c
                    end
                end
            end
        end
    end
    function surf:drawSurface(surf2, x, y, width, height, sx, sy, swidth, sheight)
        x, y, width, height, sx, sy, swidth, sheight = x + self.ox, y + self.oy, width or surf2.width, height or surf2.height, sx or 0, sy or 0, swidth or surf2.width, sheight or surf2.height

        if width == swidth and height == sheight then
            local nx, ny
            nx, ny, width, height = clipRect(x, y, width, height, self.cx, self.cy, self.cwidth, self.cheight)
            swidth, sheight = width, height
            if nx > x then
                sx = sx + nx - x
                x = nx
            end
            if ny > y then
                sy = sy + ny - y
                y = ny
            end
            nx, ny, swidth, sheight = clipRect(sx, sy, swidth, sheight, 0, 0, surf2.width, surf2.height)
            width, height = swidth, sheight
            if nx > sx then
                x = x + nx - sx
                sx = nx
            end
            if ny > sy then
                y = y + ny - sy
                sy = ny
            end

            local b, t, c
            for j = 0, height - 1 do
                for i = 0, width - 1 do
                    b = surf2.buffer[((j + sy) * surf2.width + i + sx) * 3 + 1]
                    t = surf2.buffer[((j + sy) * surf2.width + i + sx) * 3 + 2]
                    c = surf2.buffer[((j + sy) * surf2.width + i + sx) * 3 + 3]
                    if b or self.overwrite then
                        self.buffer[((j + y) * self.width + i + x) * 3 + 1] = b
                    end
                    if t or self.overwrite then
                        self.buffer[((j + y) * self.width + i + x) * 3 + 2] = t
                    end
                    if c or self.overwrite then
                        self.buffer[((j + y) * self.width + i + x) * 3 + 3] = c
                    end
                end
            end
        else
            local hmirror, vmirror = false, false
            if width < 0 then
                hmirror = true
                x = x + width
            end
            if height < 0 then
                vmirror = true
                y = y + height
            end
            if swidth < 0 then
                hmirror = not hmirror
                sx = sx + swidth
            end
            if sheight < 0 then
                vmirror = not vmirror
                sy = sy + sheight
            end
            width, height, swidth, sheight = math.abs(width), math.abs(height), math.abs(swidth), math.abs(sheight)

            local xscale, yscale, px, py, ssx, ssy, b, t, c = swidth / width, sheight / height
            for j = 0, height - 1 do
                for i = 0, width - 1 do
                    px, py = math_floor((i + 0.5) * xscale), math_floor((j + 0.5) * yscale)
                    if hmirror then
                        ssx = x + width - i - 1
                    else
                        ssx = i + x
                    end
                    if vmirror then
                        ssy = y + height - j - 1
                    else
                        ssy = j + y
                    end

                    if ssx >= self.cx and ssx < self.cx + self.cwidth and ssy >= self.cy and ssy < self.cy + self.cheight and px >= 0 and px < surf2.width and py >= 0 and py < surf2.height then
                        b = surf2.buffer[(py * surf2.width + px) * 3 + 1]
                        t = surf2.buffer[(py * surf2.width + px) * 3 + 2]
                        c = surf2.buffer[(py * surf2.width + px) * 3 + 3]
                        if b or self.overwrite then
                            self.buffer[(ssy * self.width + ssx) * 3 + 1] = b
                        end
                        if t or self.overwrite then
                            self.buffer[(ssy * self.width + ssx) * 3 + 2] = t
                        end
                        if c or self.overwrite then
                            self.buffer[(ssy * self.width + ssx) * 3 + 3] = c
                        end
                    end
                end
            end
        end
    end

    function surf:drawSurfaceRotated(surf2, x, y, ox, oy, angle)
        local sin, cos, sx, sy, px, py = math.sin(angle), math.cos(angle)
        for j = math.floor(-surf2.height * 0.75), math.ceil(surf2.height * 0.75) do
            for i = math.floor(-surf2.width * 0.75), math.ceil(surf2.width * 0.75) do
                sx, sy, px, py = x + i, y + j, math_floor(cos * (i + 0.5) - sin * (j + 0.5) + ox), math_floor(sin * (i + 0.5) + cos * (j + 0.5) + oy)
                if sx >= self.cx and sx < self.cx + self.cwidth and sy >= self.cy and sy < self.cy + self.cheight and px >= 0 and px < surf2.width and py >= 0 and py < surf2.height then
                    b = surf2.buffer[(py * surf2.width + px) * 3 + 1]
                    t = surf2.buffer[(py * surf2.width + px) * 3 + 2]
                    c = surf2.buffer[(py * surf2.width + px) * 3 + 3]
                    if b or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 1] = b
                    end
                    if t or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 2] = t
                    end
                    if c or self.overwrite then
                        self.buffer[(sy * self.width + sx) * 3 + 3] = c
                    end
                end
            end
        end
    end

    function surf:drawSurfacesInterlaced(surfs, x, y, step)
        x, y, step = x + self.ox, y + self.oy, step or 0
        local width, height = surfs[1].width, surfs[1].height
        for i = 2, #surfs do
            if surfs[i].width ~= width or surfs[i].height ~= height then
                error("surfaces should be the same size")
            end
        end

        local sx, sy, swidth, sheight, index, b, t, c = clipRect(x, y, width, height, self.cx, self.cy, self.cwidth, self.cheight)
        for j = sy, sy + sheight - 1 do
            for i = sx, sx + swidth - 1 do
                index = (i + j + step) % #surfs + 1
                b = surfs[index].buffer[((j - sy) * surfs[index].width + i - sx) * 3 + 1]
                t = surfs[index].buffer[((j - sy) * surfs[index].width + i - sx) * 3 + 2]
                c = surfs[index].buffer[((j - sy) * surfs[index].width + i - sx) * 3 + 3]
                if b or self.overwrite then
                    self.buffer[(j * self.width + i) * 3 + 1] = b
                end
                if t or self.overwrite then
                    self.buffer[(j * self.width + i) * 3 + 2] = t
                end
                if c or self.overwrite then
                    self.buffer[(j * self.width + i) * 3 + 3] = c
                end
            end
        end
    end

    function surf:drawSurfaceSmall(surf2, x, y)
        x, y = x + self.ox, y + self.oy
        if surf2.width % 2 ~= 0 or surf2.height % 3 ~= 0 then
            error("surface width must be a multiple of 2 and surface height a multiple of 3")
        end

        local sub, char, c1, c2, c3, c4, c5, c6 = 32768
        for j = 0, surf2.height / 3 - 1 do
            for i = 0, surf2.width / 2 - 1 do
                if i + x >= self.cx and i + x < self.cx + self.cwidth and j + y >= self.cy and j + y < self.cy + self.cheight then
                    char, c1, c2, c3, c4, c5, c6 = 0,
                    surf2.buffer[((j * 3) * surf2.width + i * 2) * 3 + 1],
                    surf2.buffer[((j * 3) * surf2.width + i * 2 + 1) * 3 + 1],
                    surf2.buffer[((j * 3 + 1) * surf2.width + i * 2) * 3 + 1],
                    surf2.buffer[((j * 3 + 1) * surf2.width + i * 2 + 1) * 3 + 1],
                    surf2.buffer[((j * 3 + 2) * surf2.width + i * 2) * 3 + 1],
                    surf2.buffer[((j * 3 + 2) * surf2.width + i * 2 + 1) * 3 + 1]
                    if c1 ~= c6 then
                        sub = c1
                        char = 1
                    end
                    if c2 ~= c6 then
                        sub = c2
                        char = char + 2
                    end
                    if c3 ~= c6 then
                        sub = c3
                        char = char + 4
                    end
                    if c4 ~= c6 then
                        sub = c4
                        char = char + 8
                    end
                    if c5 ~= c6 then
                        sub = c5
                        char = char + 16
                    end
                    self.buffer[((j + y) * self.width + i + x) * 3 + 1] = c6
                    self.buffer[((j + y) * self.width + i + x) * 3 + 2] = sub
                    self.buffer[((j + y) * self.width + i + x) * 3 + 3] = _chars[128 + char]
                end
            end
        end
    end
    function surf:flip(horizontal, vertical)
        local ox, oy, nx, ny, tb, tt, tc
        if horizontal then
            for i = 0, math.ceil(self.cwidth / 2) - 1 do
                for j = 0, self.cheight - 1 do
                    ox, oy, nx, ny = i + self.cx, j + self.cy, self.cx + self.cwidth - i - 1, j + self.cy
                    tb = self.buffer[(oy * self.width + ox) * 3 + 1]
                    tt = self.buffer[(oy * self.width + ox) * 3 + 2]
                    tc = self.buffer[(oy * self.width + ox) * 3 + 3]
                    self.buffer[(oy * self.width + ox) * 3 + 1] = self.buffer[(ny * self.width + nx) * 3 + 1]
                    self.buffer[(oy * self.width + ox) * 3 + 2] = self.buffer[(ny * self.width + nx) * 3 + 2]
                    self.buffer[(oy * self.width + ox) * 3 + 3] = self.buffer[(ny * self.width + nx) * 3 + 3]
                    self.buffer[(ny * self.width + nx) * 3 + 1] = tb
                    self.buffer[(ny * self.width + nx) * 3 + 2] = tt
                    self.buffer[(ny * self.width + nx) * 3 + 3] = tc
                end
            end
        end
        if vertical then
            for j = 0, math.ceil(self.cheight / 2) - 1 do
                for i = 0, self.cwidth - 1 do
                    ox, oy, nx, ny = i + self.cx, j + self.cy, i + self.cx, self.cy + self.cheight - j - 1
                    tb = self.buffer[(oy * self.width + ox) * 3 + 1]
                    tt = self.buffer[(oy * self.width + ox) * 3 + 2]
                    tc = self.buffer[(oy * self.width + ox) * 3 + 3]
                    self.buffer[(oy * self.width + ox) * 3 + 1] = self.buffer[(ny * self.width + nx) * 3 + 1]
                    self.buffer[(oy * self.width + ox) * 3 + 2] = self.buffer[(ny * self.width + nx) * 3 + 2]
                    self.buffer[(oy * self.width + ox) * 3 + 3] = self.buffer[(ny * self.width + nx) * 3 + 3]
                    self.buffer[(ny * self.width + nx) * 3 + 1] = tb
                    self.buffer[(ny * self.width + nx) * 3 + 2] = tt
                    self.buffer[(ny * self.width + nx) * 3 + 3] = tc
                end
            end
        end
    end

    function surf:shift(x, y, b, t, c)
        local hdir, vdir = x < 0, y < 0
        local xstart, xend = self.cx, self.cx + self.cwidth - 1
        local ystart, yend = self.cy, self.cy + self.cheight - 1
        local nx, ny
        for j = vdir and ystart or yend, vdir and yend or ystart, vdir and 1 or -1 do
            for i = hdir and xstart or xend, hdir and xend or xstart, hdir and 1 or -1 do
                nx, ny = i - x, j - y
                if nx >= 0 and nx < self.width and ny >= 0 and ny < self.height then
                    self.buffer[(j * self.width + i) * 3 + 1] = self.buffer[(ny * self.width + nx) * 3 + 1]
                    self.buffer[(j * self.width + i) * 3 + 2] = self.buffer[(ny * self.width + nx) * 3 + 2]
                    self.buffer[(j * self.width + i) * 3 + 3] = self.buffer[(ny * self.width + nx) * 3 + 3]
                else
                    self.buffer[(j * self.width + i) * 3 + 1] = b
                    self.buffer[(j * self.width + i) * 3 + 2] = t
                    self.buffer[(j * self.width + i) * 3 + 3] = c
                end
            end
        end
    end

    function surf:map(colors)
        local c
        for j = self.cy, self.cy + self.cheight - 1 do
            for i = self.cx, self.cx + self.cwidth - 1 do
                c = colors[self.buffer[(j * self.width + i) * 3 + 1]]
                if c or self.overwrite then
                    self.buffer[(j * self.width + i) * 3 + 1] = c
                end
            end
        end
    end
    surface.palette = { }
    surface.palette.cc = {[1]="F0F0F0",[2]="F2B233",[4]="E57FD8",[8]="99B2F2",[16]="DEDE6C",[32]="7FCC19",[64]="F2B2CC",[128]="4C4C4C",[256]="999999",[512]="4C99B2",[1024]="B266E5",[2048]="3366CC",[4096]="7F664C",[8192]="57A64E",[16384]="CC4C4C",[32768]="191919"}
    surface.palette.riko4 = {"181818","1D2B52","7E2553","008651","AB5136","5F564F","7D7F82","FF004C","FFA300","FFF023","00E755","29ADFF","82769C","FF77A9","FECCA9","ECECEC"}
    surface.palette.redirection = {[0]="040404",[1]="FFFFFF"}

    local function setPalette(palette)
        if palette == _palette then return end
        _palette = palette
        _rgbpal, _palr, _palg, _palb = { }, { }, { }, { }

        local indices = { }
        for k, v in pairs(_palette) do
            if type(v) == "string" then
                _palr[k] = tonumber(v:sub(1, 2), 16) / 255
                _palg[k] = tonumber(v:sub(3, 4), 16) / 255
                _palb[k] = tonumber(v:sub(5, 6), 16) / 255
            elseif type(v) == "number" then
                _palr[k] = math.floor(v / 65536) / 255
                _palg[k] = (math.floor(v / 256) % 256) / 255
                _palb[k] = (v % 256) / 255
            end
            indices[#indices + 1] = k
        end

        local pr, pg, pb, dist, d, id
        for i = 0, _steps - 1 do
            for j = 0, _steps - 1 do
                for k = 0, _steps - 1 do
                    pr = (i + 0.5) / _steps
                    pg = (j + 0.5) / _steps
                    pb = (k + 0.5) / _steps

                    dist = 1e10
                    for l = 1, #indices do
                        d = (pr - _palr[indices[l]]) ^ 2 + (pg - _palg[indices[l]]) ^ 2 + (pb - _palb[indices[l]]) ^ 2
                        if d < dist then
                            dist = d
                            id = l
                        end
                    end
                    _rgbpal[i * _steps * _steps + j * _steps + k + 1] = indices[id]
                end
            end
        end
    end



    function surf:toRGB(palette)
        setPalette(palette)
        local c
        for j = 0, self.height - 1 do
            for i = 0, self.width - 1 do
                c = self.buffer[(j * self.width + i) * 3 + 1]
                self.buffer[(j * self.width + i) * 3 + 1] = _palr[c]
                self.buffer[(j * self.width + i) * 3 + 2] = _palg[c]
                self.buffer[(j * self.width + i) * 3 + 3] = _palb[c]
            end
        end
    end

    function surf:toPalette(palette, dither)
        setPalette(palette)
        local scale, r, g, b, nr, ng, nb, c, dr, dg, db = _steps - 1
        for j = 0, self.height - 1 do
            for i = 0, self.width - 1 do
                r = self.buffer[(j * self.width + i) * 3 + 1]
                g = self.buffer[(j * self.width + i) * 3 + 2]
                b = self.buffer[(j * self.width + i) * 3 + 3]
                r = (r > 1) and 1 or r
                r = (r < 0) and 0 or r
                g = (g > 1) and 1 or g
                g = (g < 0) and 0 or g
                b = (b > 1) and 1 or b
                b = (b < 0) and 0 or b

                nr = (r == 1) and scale or math_floor(r * _steps)
                ng = (g == 1) and scale or math_floor(g * _steps)
                nb = (b == 1) and scale or math_floor(b * _steps)
                c = _rgbpal[nr * _steps * _steps + ng * _steps + nb + 1]
                if dither then
                    dr = (r - _palr[c]) / 16
                    dg = (g - _palg[c]) / 16
                    db = (b - _palb[c]) / 16

                    if i < self.width - 1 then
                        self.buffer[(j * self.width + i + 1) * 3 + 1] = self.buffer[(j * self.width + i + 1) * 3 + 1] + dr * 7
                        self.buffer[(j * self.width + i + 1) * 3 + 2] = self.buffer[(j * self.width + i + 1) * 3 + 2] + dg * 7
                        self.buffer[(j * self.width + i + 1) * 3 + 3] = self.buffer[(j * self.width + i + 1) * 3 + 3] + db * 7
                    end
                    if j < self.height - 1 then
                        if i > 0 then
                            self.buffer[((j + 1) * self.width + i - 1) * 3 + 1] = self.buffer[((j + 1) * self.width + i - 1) * 3 + 1] + dr * 3
                            self.buffer[((j + 1) * self.width + i - 1) * 3 + 2] = self.buffer[((j + 1) * self.width + i - 1) * 3 + 2] + dg * 3
                            self.buffer[((j + 1) * self.width + i - 1) * 3 + 3] = self.buffer[((j + 1) * self.width + i - 1) * 3 + 3] + db * 3
                        end
                        self.buffer[((j + 1) * self.width + i) * 3 + 1] = self.buffer[((j + 1) * self.width + i) * 3 + 1] + dr * 5
                        self.buffer[((j + 1) * self.width + i) * 3 + 2] = self.buffer[((j + 1) * self.width + i) * 3 + 2] + dg * 5
                        self.buffer[((j + 1) * self.width + i) * 3 + 3] = self.buffer[((j + 1) * self.width + i) * 3 + 3] + db * 5
                        if i < self.width - 1 then
                            self.buffer[((j + 1) * self.width + i + 1) * 3 + 1] = self.buffer[((j + 1) * self.width + i + 1) * 3 + 1] + dr * 1
                            self.buffer[((j + 1) * self.width + i + 1) * 3 + 2] = self.buffer[((j + 1) * self.width + i + 1) * 3 + 2] + dg * 1
                            self.buffer[((j + 1) * self.width + i + 1) * 3 + 3] = self.buffer[((j + 1) * self.width + i + 1) * 3 + 3] + db * 1
                        end
                    end
                end
                self.buffer[(j * self.width + i) * 3 + 1] = c
                self.buffer[(j * self.width + i) * 3 + 2] = nil
                self.buffer[(j * self.width + i) * 3 + 3] = nil
            end
        end
    end
    function surface.loadFont(surf)
        local font = {width = surf.width, height = surf.height - 1}
        font.buffer =  { }
        font.indices = {0}
        font.widths = { }

        local startc, hitc, curc = surf.buffer[((surf.height - 1) * surf.width) * 3 + 1]
        for i = 0, surf.width - 1 do
            curc = surf.buffer[((surf.height - 1) * surf.width + i) * 3 + 1]
            if curc ~= startc then
                hitc = curc
                break
            end
        end

        for j = 0, surf.height - 2 do
            for i = 0, surf.width - 1 do
                font.buffer[j * font.width + i + 1] = surf.buffer[(j * surf.width + i) * 3 + 1] == hitc
            end
        end

        local curchar = 1
        for i = 0, surf.width - 1 do
            if surf.buffer[((surf.height - 1) * surf.width + i) * 3 + 1] == hitc then
                font.widths[curchar] = i - font.indices[curchar]
                curchar = curchar + 1
                font.indices[curchar] = i + 1
            end
        end
        font.widths[curchar] = font.width - font.indices[curchar]

        return font
    end

    function surface.getTextSize(str, font)
        local cx, cy, maxx = 0, 0, 0
        local ox, char = cx

        for i = 1, #str do
            char = str:byte(i) - 31

            if char + 31 == 10 then -- newline
                cx = ox
                cy = cy + font.height + 1
            elseif font.indices[char] then
                cx = cx + font.widths[char] + 1
            else
                cx = cx + font.widths[1]
            end
            if cx > maxx then
                maxx = cx
            end
        end

        return maxx - 1, cy + font.height
    end

    function surf:drawText(str, font, x, y, b, t, c)
        local cx, cy = x + self.ox, y + self.oy
        local ox, char, idx = cx

        for i = 1, #str do
            char = str:byte(i) - 31

            if char + 31 == 10 then -- newline
                cx = ox
                cy = cy + font.height + 1
            elseif font.indices[char] then
                for i = 0, font.widths[char] - 1 do
                    for j = 0, font.height - 1 do
                        x, y = cx + i, cy + j
                        if font.buffer[j * font.width + i + font.indices[char] + 1] then
                            if x >= self.cx and x < self.cx + self.cwidth and y >= self.cy and y < self.cy + self.cheight then
                                idx = (y * self.width + x) * 3
                                if b or self.overwrite then
                                    self.buffer[idx + 1] = b
                                end
                                if t or self.overwrite then
                                    self.buffer[idx + 2] = t
                                end
                                if c or self.overwrite then
                                    self.buffer[idx + 3] = c
                                end
                            end
                        end
                    end
                end
                cx = cx + font.widths[char] + 1
            else
                cx = cx + font.widths[1]
            end
        end
    end
    local smap = { }
    surface.smap = smap

    function surface.loadSpriteMap(surf, spwidth, spheight, sprites)
        if surf.width % spwidth ~= 0 or surf.height % spheight ~= 0 then
            error("sprite width/height does not match smap width/height")
        end

        local smap = setmetatable({ }, {__index = surface.smap})
        smap.surf = surf
        smap.spwidth = spwidth
        smap.spheight = spheight
        smap.sprites = sprites or ((surf.width / spwidth) * (surf.height / spheight))
        smap.perline = surf.width / spwidth

        return smap
    end

    function smap:pos(index, scale)
        if index < 0 or index >= self.sprites then
            error("sprite index out of bounds")
        end

        return (index % self.perline) * self.spwidth, math.floor(index / self.perline) * self.spheight
    end

    function smap:sprite(index, x, y, width, height)
        local sx, sy = self:pos(index)
        return self.surf, x, y, width or self.spwidth, height or self.spheight, sx, sy, self.spwidth, self.spheight
    end
end return surface
 end)()
local fontData = (function()
  if fontData then return fontData end
return [[
    0 0 0   0 0  0000 00  0  00   0  0 0  0 0                0  00   0   00   00    0  0000  000 0000  00   00                    00   000  00  000   00  000  0000 0000  000 0  0 000 000 0  0 0    00 0  0  0  00  000   00  000   000 00000 0  0 0  0 0   0 0  0 0  0 0000 000 0   000  0       0       0            0        00      0    0   0 0    00                                       0                                  00 0 00
    0 0 0 00000 0 0   0  0  0  0  0 0   0  0   0             0 0  0 00  0  0 0  0  00  0    0       0 0  0 0  0 0  0  00 000 00  0  0 0 00 0  0 0  0 0  0 0  0 0    0    0    0  0  0    0 0 0  0    0 0 0 00 0 0  0 0  0 0  0 0  0 0      0   0  0 0  0 0 0 0 0  0 0  0    0 0   0     0 0 0       0  00  000   000  000  00   0    00  0          0 00  0  00 0  000   00  000   000 0 00  000 000 0  0 0  0 0   0 0  0 0  0 0000  0  0  0   0 0
    0      0 0   000    0    00 0   0   0 0 0 000    000    0  0  0  0    0    0  0 0  000  000    0   00   000      0         0   0  00 0 0000 000  0    0  0 000  000  0 00 0000  0    0 00   0    0 0 0 0 00 0  0 000  0  0 000   00    0   0  0 0  0 0 0 0  00   000  00  0    0    0             0  0 0  0 0    0  0 0  0 000  0  0 000  0   0 00    0  0 0 0 0  0 0  0 0  0 0  0 00   00    0  0  0 0  0 0 0 0  00  0  0   0  0   0   0 0 0
          00000   0 0  0  0 0  0    0   0      0           0   0  0  0   0   0  0 0000    0 0  0  0   0  0    0 0  0  00 000 00       0 00 0  0 0  0 0  0 0  0 0    0    0  0 0  0  0    0 0 0  0    0   0 0 00 0  0 0    0 0  0  0    0   0   0  0  00   0 0  0  0    0 0    0     0   0             0  0 0  0 0    0  0 000   0    000 0  0 0   0 0 0   0  0 0 0 0  0 0  0 0  0 0  0 0      00  0  0  0 0000 0 0 0  00   00   0    0  0  0
    0     0 0   0000  0  00  00 0    0 0           0     0 0    00  000 0000  00    0  000   00   0    00  000    0               0    00  0  0 000   00  000  0000 0     00  0  0 000 00  0  0 0000 0   0 0  0  00  0     0 0 0  0 000    0    00   00   0 0  0  0 000  0000 000   0 000     0000     000 000   000  000  000  0      0 0  0 0   0 0  0   0 0   0 0  0  00  000   000 0    000    0  000  00   0 0  0  0  0   0000  00 0 00
                                                  0                                                                                                                                                                                                                                                                                 000         00                           0       0                                    0
   0 0   0     0     0     0     0 0  0  0   0   0  0   0 0   0    0   0    0    0    0    0    0    0    0    0 0  0   0   0   0    0    0    0    0    0    0    0    0    0    0   0   0    0    0     0    0    0    0    0    0    0     0    0    0     0    0    0    0   0   0   0   0    0  0    0    0    0    0    0    0    0    0 0   0    0   0     0    0    0    0    0    0    0   0    0    0     0    0    0    0   0 0   0]] end)()

local font = surface.loadFont(surface.load(fontData, true))


local wapi = (function()
  if wapi then return wapi end
local jua = nil
local idPatt = "#R%d+"

if not ((socket and socket.websocket) or http.websocketAsync) then
    error("You do not have CC:Tweaked/CCTweaks installed or you are not on the latest version.")
end

local newws = socket and socket.websocket or http.websocketAsync
local async
if socket and socket.websocket then
    async = false
else
    async = true
end

local callbackRegistry = {}
wsRegistry = {}

local function gfind(str, patt)
    local t = {}
    for found in str:gmatch(patt) do
        table.insert(t, found)
    end

    if #t > 0 then
        return t
    else
        return nil
    end
end

local function findID(url)
    local found = gfind(url, idPatt)
    return tonumber(found[#found]:sub(found[#found]:find("%d+")))
end

local function newID()
    return #callbackRegistry + 1
end

local function trimID(url)
    local found = gfind(url, idPatt)
    local s, e = url:find(found[#found])
    return url:sub(1, s-1)
end

function open(callback, url, headers)
    local id
    if async then
        id = newID()
    end
    local newUrl
    if async then
        newUrl = url .. "#R" .. id
        newws(newUrl, headers)
    else
        if headers then
            error("Websocket headers not supported under CCTweaks")
        end
        local ws = newws(url)
        ws.send = ws.write
        id = ws.id()
        wsRegistry[id] = ws
    end
    callbackRegistry[id] = callback
    return id
end

function init(jua)
    jua = jua
    if async then
        jua.on("websocket_success", function(event, url, handle)
            local id = findID(url)
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].success then
                callbackRegistry[id].success(findID(url), handle)
            end
        end)

        jua.on("websocket_failure", function(event, url)
            local id = findID(url)
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].failure then
                callbackRegistry[id].failure(findID(url))
            end
            table.remove(callbackRegistry, id)
        end)

        jua.on("websocket_message", function(event, url, data)
            local id = findID(url)
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].message then
                callbackRegistry[id].message(findID(url), data)
            end
        end)

        jua.on("websocket_closed", function(event, url)
            local id = findID(url)
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].closed then
                callbackRegistry[id].closed(findID(url))
            end
            table.remove(callbackRegistry, id)
        end)
    else
        jua.on("socket_connect", function(event, id)
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].success then
                callbackRegistry[id].success(id, wsRegistry[id])
            end
        end)

        jua.on("socket_error", function(event, id, msg)
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].failure then
                callbackRegistry[id].failure(id, msg)
            end
            table.remove(callbackRegistry, id)
        end)

        jua.on("socket_message", function(event, id)
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].message then
                local data = wsRegistry[id].read()
                callbackRegistry[id].message(id, data)
            end
        end)

        jua.on("socket_closed", function(event, id)
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].closed then
                callbackRegistry[id].closed(id)
            end
            table.remove(callbackRegistry, id)
        end)
    end
end

return {
    open = open,
    init = init
}
 end)()
local rapi = (function()
  if rapi then return rapi end
local jua = nil
local idPatt = "#R%d+"

local callbackRegistry = {}

local function gfind(str, patt)
    local t = {}
    for found in str:gmatch(patt) do
        table.insert(t, found)
    end

    if #t > 0 then
        return t
    else
        return nil
    end
end

local function findID(url)
    local found = gfind(url, idPatt)
    if not found then
        return -1
    end
    return tonumber(found[#found]:sub(found[#found]:find("%d+")))
end

local function newID()
    for i = 1, math.huge do
        if not callbackRegistry[i] then
            return i
        end
    end
end

local function trimID(url)
    local found = gfind(url, idPatt)
    local s, e = url:find(found[#found])
    return url:sub(1, s-1)
end

function request(callback, url, headers, postData)
    local id = newID()
    local newUrl = url .. "#R" .. id
    callbackRegistry[id] = callback
    http.request(newUrl, postData, headers)
end

function init(jua)
    jua = jua
    jua.on("http_success", function(event, url, handle)
        local id = findID(url)
        if callbackRegistry[id] then
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].success then
                callbackRegistry[id].success(true, trimID(url), handle)
            else
                callbackRegistry[id](true, trimID(url), handle)
            end
            callbackRegistry[id] = nil
        end
    end)

    jua.on("http_failure", function(event, url, handle)
        local id = findID(url)
        if callbackRegistry[id] then
            if type(callbackRegistry[id]) == "table" and callbackRegistry[id].failure then
                callbackRegistry[id].failure(false, trimID(url), handle)
            else
                callbackRegistry[id](false, trimID(url), handle)
            end
            callbackRegistry[id] = nil
        end
    end)
end

return {
    request = request,
    init = init
}
 end)()
local kapi = (function()
  if kapi then return kapi end
local w
local r
local jua
local json
local await

local endpoint = "krist.dev"
local wsEndpoint = "wss://"..endpoint
local httpEndpoint = "https://"..endpoint

local function asserttype(var, name, vartype, optional)
  if not (type(var) == vartype or optional and type(var) == "nil") then
    error(name..": expected "..vartype.." got "..type(var), 3)
  end
end

function init(juai, jsoni, wi, ri)
  asserttype(juai, "jua", "table")
  asserttype(jsoni, "json", "table")
  asserttype(wi, "w", "table", true)
  asserttype(ri, "r", "table")

  jua = juai
  await = juai.await
  json = jsoni
  w = wi
  r = ri
end

local function prints(...)
  local objs = {...}
  for i, obj in ipairs(objs) do
    print(textutils.serialize(obj))
  end
end

local function url(call)
  return httpEndpoint..call
end

local function api_request(cb, api, data)
  local success, _url, handle = await(r.request, url(api) .. (api:find("%%?") and "?cc" or "&cc"), {["Content-Type"]="application/json"}, data and json.encode(data))
  if success then
    cb(success, json.decode(handle.readAll()))
    handle.close()
  else
    cb(success)
  end
end

local function authorize_websocket(cb, privatekey)
  asserttype(cb, "callback", "function")
  asserttype(privatekey, "privatekey", "string", true)

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.url and data.url or data)
  end, "/ws/start", {
    privatekey = privatekey
  })
end

function address(cb, address)
  asserttype(cb, "callback", "function")
  asserttype(address, "address", "string")

  api_request(function(success, data)
    if data.address then
      data.address.address = address
    end
    cb(success and data and data.ok, data and data.address or data)
  end, "/addresses/"..address)
end

function addressTransactions(cb, address, limit, offset)
  asserttype(cb, "callback", "function")
  asserttype(address, "address", "string")
  asserttype(limit, "limit", "number", true)
  asserttype(offset, "offset", "number", true)

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.transactions or data)
  end, "/addresses/"..address.."/transactions?limit="..(limit or 50).."&offset="..(offset or 0))
end

function addressNames(cb, address)
  asserttype(cb, "callback", "function")
  asserttype(address, "address", "string")

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.names or data)
  end, "/addresses/"..address.."/names")
end

function addresses(cb, limit, offset)
  asserttype(cb, "callback", "function")
  asserttype(limit, "limit", "number", true)
  asserttype(offset, "offset", "number", true)

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.addresses or data)
  end, "/addresses?limit="..(limit or 50).."&offset="..(offset or 0))
end

function name(cb, name)
  asserttype(cb, "callback", "function")
  asserttype(name, "name", "string")

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.name or data)
  end, "/names/"..name)
end

function rich(cb, limit, offset)
  asserttype(cb, "callback", "function")
  asserttype(limit, "limit", "number", true)
  asserttype(offset, "offset", "number", true)

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.addresses or data)
  end, "/addresses/rich?limit="..(limit or 50).."&offset="..(offset or 0))
end

function transactions(cb, limit, offset)
  asserttype(cb, "callback", "function")
  asserttype(limit, "limit", "number", true)
  asserttype(offset, "offset", "number", true)

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.transactions or data)
  end, "/transactions?limit="..(limit or 50).."&offset="..(offset or 0))
end

function latestTransactions(cb, limit, offset)
  asserttype(cb, "callback", "function")
  asserttype(limit, "limit", "number", true)
  asserttype(offset, "offset", "number", true)

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.transactions or data)
  end, "/transactions/latest?limit="..(limit or 50).."&offset="..(offset or 0))
end

function transaction(cb, txid)
  asserttype(cb, "callback", "function")
  asserttype(txid, "txid", "number")

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.transaction or data)
  end, "/transactions/"..txid)
end

function makeTransaction(cb, privatekey, to, amount, metadata)
  asserttype(cb, "callback", "function")
  asserttype(privatekey, "privatekey", "string")
  asserttype(to, "to", "string")
  asserttype(amount, "amount", "number")
  asserttype(metadata, "metadata", "string", true)

  api_request(function(success, data)
    cb(success and data and data.ok, data and data.transaction or data)
  end, "/transactions", {
    privatekey = privatekey,
    to = to,
    amount = amount,
    metadata = metadata
  })
end

local wsEventNameLookup = {
  blocks = "block",
  ownBlocks = "block",
  transactions = "transaction",
  ownTransactions = "transaction",
  names = "name",
  ownNames = "name",
  ownWebhooks = "webhook",
  motd = "motd",
  keepalive = "keepalive"
}

local wsEvents = {}

local wsReqID = 0
local wsReqRegistry = {}
local wsEvtRegistry = {}
local wsHandleRegistry = {}

local function newWsID()
  local id = wsReqID
  wsReqID = wsReqID + 1
  return id
end

local function registerEvent(id, event, callback)
  if wsEvtRegistry[id] == nil then
    wsEvtRegistry[id] = {}
  end

  if wsEvtRegistry[id][event] == nil then
    wsEvtRegistry[id][event] = {}
  end

  table.insert(wsEvtRegistry[id][event], callback)
end

local function registerRequest(id, reqid, callback)
  if wsReqRegistry[id] == nil then
    wsReqRegistry[id] = {}
  end

  wsReqRegistry[id][reqid] = callback
end

local function discoverEvents(id, event)
    local evs = {}
    for k,v in pairs(wsEvtRegistry[id]) do
        if k == event or string.match(k, event) or event == "*" then
            for i,v2 in ipairs(v) do
                table.insert(evs, v2)
            end
        end
    end

    return evs
end

wsEvents.success = function(id, handle)
  -- fire success event
  wsHandleRegistry[id] = handle
  if wsEvtRegistry[id] then
    local evs = discoverEvents(id, "success")
    for i, v in ipairs(evs) do
      v(id, handle)
    end
  end
end

wsEvents.failure = function(id)
  -- fire failure event
  if wsEvtRegistry[id] then
    local evs = discoverEvents(id, "failure")
    for i, v in ipairs(evs) do
      v(id)
    end
  end
end

wsEvents.message = function(id, data)
  local data = json.decode(data)
  --print("msg:"..tostring(data.ok)..":"..tostring(data.type)..":"..tostring(data.id))
  --prints(data)
  -- handle events and responses
  if wsReqRegistry[id] and wsReqRegistry[id][tonumber(data.id)] then
    wsReqRegistry[id][tonumber(data.id)](data)
  elseif wsEvtRegistry[id] then
    local evs = discoverEvents(id, data.type)
    for i, v in ipairs(evs) do
      v(data)
    end

    if data.event then
      local evs = discoverEvents(id, data.event)
      for i, v in ipairs(evs) do
        v(data)
      end
    end

    local evs2 = discoverEvents(id, "message")
    for i, v in ipairs(evs2) do
      v(id, data)
    end
  end
end

wsEvents.closed = function(id)
  -- fire closed event
  if wsEvtRegistry[id] then
    local evs = discoverEvents(id, "closed")
    for i, v in ipairs(evs) do
      v(id)
    end
  end
end

local function wsRequest(cb, id, type, data)
  local reqID = newWsID()
  registerRequest(id, reqID, function(data)
    cb(data)
  end)
  data.id = tostring(reqID)
  data.type = type
  wsHandleRegistry[id].send(json.encode(data))
end

local function barebonesMixinHandle(id, handle)
  handle.on = function(event, cb)
    registerEvent(id, event, cb)
  end

  return handle
end

local function mixinHandle(id, handle)
  handle.subscribe = function(cb, event, eventcb)
    local data = await(wsRequest, id, "subscribe", {
      event = event
    })
    registerEvent(id, wsEventNameLookup[event], eventcb)
    cb(data.ok, data)
  end

  return barebonesMixinHandle(id, handle)
end

function connect(cb, privatekey, preconnect)
  asserttype(cb, "callback", "function")
  asserttype(privatekey, "privatekey", "string", true)
  asserttype(preconnect, "preconnect", "function", true)
  local url
  if privatekey then
    local success, auth = await(authorize_websocket, privatekey)
    url = success and auth or wsEndpoint
  end
  local id = w.open(wsEvents, url)
  if preconnect then
    preconnect(id, barebonesMixinHandle(id, {}))
  end
  registerEvent(id, "success", function(id, handle)
    cb(true, mixinHandle(id, handle))
  end)
  registerEvent(id, "failure", function(id)
    cb(false)
  end)
end

local domainMatch = "^([%l%d-_]*)@?([%l%d-]+).kst$"
local commonMetaMatch = "^(.+)=(.+)$"

function parseMeta(meta)
  asserttype(meta, "meta", "string")
  local tbl = {meta={}}

  for m in meta:gmatch("[^;]+") do
    if m:match(domainMatch) then
      -- print("Matched domain")

      local p1, p2 = m:match("([%l%d-_]*)@"), m:match("@?([%l%d-]+).kst")
      tbl.name = p1
      tbl.domain = p2

    elseif m:match(commonMetaMatch) then
      -- print("Matched common meta")

      local p1, p2 = m:match(commonMetaMatch)

      tbl.meta[p1] = p2

    else
      -- print("Unmatched standard meta")

      table.insert(tbl.meta, m)
    end
    -- print(m)
  end
  -- print(textutils.serialize(tbl))
  return tbl
end

local g = string.gsub
sha256 = loadstring(g(g(g(g(g(g(g(g('Sa=XbandSb=XbxWSc=XlshiftSd=unpackSe=2^32SYf(g,h)Si=g/2^hSj=i%1Ui-j+j*eVSYk(l,m)Sn=l/2^mUn-n%1VSo={0x6a09e667Tbb67ae85T3c6ef372Ta54ff53aT510e527fT9b05688cT1f83d9abT5be0cd19}Sp={0x428a2f98T71374491Tb5c0fbcfTe9b5dba5T3956c25bT59f111f1T923f82a4Tab1c5ed5Td807aa98T12835b01T243185beT550c7dc3T72be5d74T80deb1feT9bdc06a7Tc19bf174Te49b69c1Tefbe4786T0fc19dc6T240ca1ccT2de92c6fT4a7484aaT5cb0a9dcT76f988daT983e5152Ta831c66dTb00327c8Tbf597fc7Tc6e00bf3Td5a79147T06ca6351T14292967T27b70a85T2e1b2138T4d2c6dfcT53380d13T650a7354T766a0abbT81c2c92eT92722c85Ta2bfe8a1Ta81a664bTc24b8b70Tc76c51a3Td192e819Td6990624Tf40e3585T106aa070T19a4c116T1e376c08T2748774cT34b0bcb5T391c0cb3T4ed8aa4aT5b9cca4fT682e6ff3T748f82eeT78a5636fT84c87814T8cc70208T90befffaTa4506cebTbef9a3f7Tc67178f2}SYq(r,q)if e-1-r[1]<q then r[2]=r[2]+1;r[1]=q-(e-1-r[1])-1 else r[1]=r[1]+qVUrVSYs(t)Su=#t;t[#t+1]=0x80;while#t%64~=56Zt[#t+1]=0VSv=q({0,0},u*8)fWw=2,1,-1Zt[#t+1]=a(k(a(v[w]TFF000000),24)TFF)t[#t+1]=a(k(a(v[w]TFF0000),16)TFF)t[#t+1]=a(k(a(v[w]TFF00),8)TFF)t[#t+1]=a(v[w]TFF)VUtVSYx(y,w)Uc(y[w]W0,24)+c(y[w+1]W0,16)+c(y[w+2]W0,8)+(y[w+3]W0)VSYz(t,w,A)SB={}fWC=1,16ZB[C]=x(t,w+(C-1)*4)VfWC=17,64ZSD=B[C-15]SE=b(b(f(B[C-15],7),f(B[C-15],18)),k(B[C-15],3))SF=b(b(f(B[C-2],17),f(B[C-2],19)),k(B[C-2],10))B[C]=(B[C-16]+E+B[C-7]+F)%eVSG,h,H,I,J,j,K,L=d(A)fWC=1,64ZSM=b(b(f(J,6),f(J,11)),f(J,25))SN=b(a(J,j),a(Xbnot(J),K))SO=(L+M+N+p[C]+B[C])%eSP=b(b(f(G,2),f(G,13)),f(G,22))SQ=b(b(a(G,h),a(G,H)),a(h,H))SR=(P+Q)%e;L,K,j,J,I,H,h,G=K,j,J,(I+O)%e,H,h,G,(O+R)%eVA[1]=(A[1]+G)%e;A[2]=(A[2]+h)%e;A[3]=(A[3]+H)%e;A[4]=(A[4]+I)%e;A[5]=(A[5]+J)%e;A[6]=(A[6]+j)%e;A[7]=(A[7]+K)%e;A[8]=(A[8]+L)%eUAVUY(t)t=t W""t=type(t)=="string"and{t:byte(1,-1)}Wt;t=s(t)SA={d(o)}fWw=1,#t,64ZA=z(t,w,A)VU("%08x"):rep(8):format(d(A))V',"S"," local "),"T",",0x"),"U"," return "),"V"," end "),"W","or "),"X","bit32."),"Y","function "),"Z"," do "))()

function makeaddressbyte(byte)
  local byte = 48 + math.floor(byte / 7)
  return string.char(byte + 39 > 122 and 101 or byte > 57 and byte + 39 or byte)
end

function makev2address(key)
  local protein = {}
  local stick = sha256(sha256(key))
  local n = 0
  local link = 0
  local v2 = "k"
  repeat
    if n < 9 then protein[n] = string.sub(stick,0,2)
    stick = sha256(sha256(stick)) end
    n = n + 1
  until n == 9
  n = 0
  repeat
    link = tonumber(string.sub(stick,1+(2*n),2+(2*n)),16) % 9
    if string.len(protein[link]) ~= 0 then
      v2 = v2 .. makeaddressbyte(tonumber(protein[link],16))
      protein[link] = ''
      n = n + 1
    else
      stick = sha256(stick)
    end
  until n == 9
  return v2
end

function toKristWalletFormat(passphrase)
  return sha256("KRISTWALLET"..passphrase).."-000"
end

return {
  init = init,
  address = address,
  addressTransactions = addressTransactions,
  addressNames = addressNames,
  addresses = addresses,
  name = name,
  rich = rich,
  transactions = transactions,
  latestTransactions = latestTransactions,
  transaction = transaction,
  makeTransaction = makeTransaction,
  connect = connect,
  parseMeta = parseMeta,
  sha256 = sha256,
  makeaddressbyte = makeaddressbyte,
  makev2address = makev2address,
  toKristWalletFormat = toKristWalletFormat
}
 end)()
local jua = (function()
  if jua then return jua end
local juaVersion = "0.0"

juaRunning = false
eventRegistry = {}
timedRegistry = {}

local function registerEvent(event, callback)
    if eventRegistry[event] == nil then
        eventRegistry[event] = {}
    end

    table.insert(eventRegistry[event], callback)
end

local function registerTimed(time, repeating, callback)
    if repeating then
        callback(true)
    end

    table.insert(timedRegistry, {
        time = time,
        repeating = repeating,
        callback = callback,
        timer = os.startTimer(time)
    })
end

local function discoverEvents(event)
    local evs = {}
    for k,v in pairs(eventRegistry) do
        if k == event or string.match(k, event) or event == "*" then
            for i,v2 in ipairs(v) do
                table.insert(evs, v2)
            end
        end
    end

    return evs
end

function on(event, callback)
    registerEvent(event, callback)
end

function setInterval(callback, time)
    registerTimed(time, true, callback)
end

function setTimeout(callback, time)
    registerTimed(time, false, callback)
end

function tick()
    local eargs = {os.pullEventRaw()}
    local event = eargs[1]

    if eventRegistry[event] == nil then
        eventRegistry[event] = {}
    else
        local evs = discoverEvents(event)
        for i, v in ipairs(evs) do
            v(unpack(eargs))
        end
    end

    if event == "timer" then
        local timer = eargs[2]

        for i = #timedRegistry, 1, -1 do
            local v = timedRegistry[i]
            if v.timer == timer then
                v.callback(not v.repeating or nil)

                if v.repeating then
                    v.timer = os.startTimer(v.time)
                else
                    table.remove(timedRegistry, i)
                end
            end
        end
    end
end

function run()
    os.queueEvent("init")
    juaRunning = true
    while juaRunning do
        tick()
    end
end

function go(func)
    on("init", func)
    run()
end

function stop()
    juaRunning = false
end

function await(func, ...)
    local args = {...}
    local out
    local finished
    func(function(...)
        out = {...}
        finished = true
    end, unpack(args))
    while not finished do tick() end
    return unpack(out)
end

return {
    on = on,
    setInterval = setInterval,
    setTimeout = setTimeout,
    tick = tick,
    run = run,
    go = go,
    stop = stop,
    await = await
}
 end)()

local logger = (function()
  if logger then return logger end

local logger = {}
local slackURL = config.slackURL
local discordURL = config.discordURL
local slackName = config.slackName
local discordName = config.discordName
local externName

local webhookHeaders = {["Content-Type"] = "application/json", ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:61.0) Gecko/20100101 Firefox/61.0"}

local function time()
  return os.epoch("utc")
end

function logger.init(prints, tExternName, noColor)
  logger.printf = prints and print or function() end
  logger.handle = fs.open(fs.combine(shell.dir(), "/log"), "a")
  logger.color = not noColor

  externName = tExternName or os.getComputerLabel() or "Computer - " .. os.getComputerID()
end

function logger.log(text)
  if logger.color then
    term.setTextColor(colors.white)
  end
  logger.printf(text)
  logger.handle.write(text .. "\n")
  logger.handle.flush()
end

function logger.info(text, externRelay, quiet)
  if logger.color then
    term.setTextColor(colors.gray)
  end
  logger.printf("[" .. time() .. "] [INFO] " .. text)

  if not quiet then
    logger.handle.write("[" .. time() .. "] [INFO] " .. text .. "\n")
    logger.handle.flush()
  end

  if externRelay == "important" then
    logger.externMention(text)
  elseif externRelay then
    logger.externInfo(text)
  end
end

function logger.warn(text, externRelay, quiet)
  if logger.color then
    term.setTextColor(colors.yellow)
  end
  logger.printf("[" .. time() .. "] [WARN] " .. text)

  if not quiet then
    logger.handle.write("[" .. time() .. "] [WARN] " .. text .. "\n")
    logger.handle.flush()
  end

  if externRelay then
    logger.externMention(text)
  end
end

function logger.error(text, externRelay, quiet)
  if logger.color then
    term.setTextColor(colors.red)
  end
  logger.printf("[" .. time() .. "] [ERROR] " .. text)

  if not quiet then
    logger.handle.write("[" .. time() .. "] [ERROR] " .. text .. "\n")
    logger.handle.flush()
  end

  if externRelay then
    logger.externMention(text)
  end
end

function logger.externInfo(text)
  if slackURL then
    http.post(slackURL,  textutils.serializeJSON({username = externName, text = text}), webhookHeaders)
  end

  if discordURL then
    http.post(discordURL, textutils.serializeJSON({username = externName, content = text}), webhookHeaders)
  end
end

function logger.externMention(text)
  if slackURL then
    if slackName then
      http.post(slackURL, textutils.serializeJSON({username = externName, text = "<@" .. slackName .. "> " .. text}), webhookHeaders)
    else
      http.post(slackURL, textutils.serializeJSON({username = externName, text = "<@" .. slackName .. "> " .. text}), webhookHeaders)
    end
  end

  if discordURL then
    if discordName then
      http.post(discordURL, textutils.serializeJSON({username = externName, content = "<@" .. discordName .. "> " .. text}), webhookHeaders)
    else
      http.post(discordURL, textutils.serializeJSON({username = externName, content = text}), webhookHeaders)
    end
  end
end

function logger.close()
  logger.handle.close()
end

return logger
 end)()
logger.init(true, config.title, not term.isColor())
successTools.logger = logger

local json = (function()
  if json then return json end
local json = {}

------------------------------------------------------------------ utils
local controls = {["\n"]="\\n", ["\r"]="\\r", ["\t"]="\\t", ["\b"]="\\b", ["\f"]="\\f", ["\""]="\\\"", ["\\"]="\\\\"}

local function isArray(t)
    local max = 0
    for k,v in pairs(t) do
        if type(k) ~= "number" then
            return false
        elseif k > max then
            max = k
        end
    end
    return max == #t
end

local whites = {['\n']=true; ['\r']=true; ['\t']=true; [' ']=true; [',']=true; [':']=true}
local function removeWhite(str)
    while whites[str:sub(1, 1)] do
        str = str:sub(2)
    end
    return str
end

------------------------------------------------------------------ encoding

local function encodeCommon(val, pretty, tabLevel, tTracking)
    local str = ""

    -- Tabbing util
    local function tab(s)
        str = str .. ("\t"):rep(tabLevel) .. s
    end

    local function arrEncoding(val, bracket, closeBracket, iterator, loopFunc)
        str = str .. bracket
        if pretty then
            str = str .. "\n"
            tabLevel = tabLevel + 1
        end
        for k,v in iterator(val) do
            tab("")
            loopFunc(k,v)
            str = str .. ","
            if pretty then str = str .. "\n" end
        end
        if pretty then
            tabLevel = tabLevel - 1
        end
        if str:sub(-2) == ",\n" then
            str = str:sub(1, -3) .. "\n"
        elseif str:sub(-1) == "," then
            str = str:sub(1, -2)
        end
        tab(closeBracket)
    end

    -- Table encoding
    if type(val) == "table" then
        assert(not tTracking[val], "Cannot encode a table holding itself recursively")
        tTracking[val] = true
        if isArray(val) then
            arrEncoding(val, "[", "]", ipairs, function(k,v)
                str = str .. encodeCommon(v, pretty, tabLevel, tTracking)
            end)
        else
            arrEncoding(val, "{", "}", pairs, function(k,v)
                assert(type(k) == "string", "JSON object keys must be strings", 2)
                str = str .. encodeCommon(k, pretty, tabLevel, tTracking)
                str = str .. (pretty and ": " or ":") .. encodeCommon(v, pretty, tabLevel, tTracking)
            end)
        end
        -- String encoding
    elseif type(val) == "string" then
        str = '"' .. val:gsub("[%c\"\\]", controls) .. '"'
        -- Number encoding
    elseif type(val) == "number" or type(val) == "boolean" then
        str = tostring(val)
    else
        error("JSON only supports arrays, objects, numbers, booleans, and strings", 2)
    end
    return str
end

function json.encode(val)
    return encodeCommon(val, false, 0, {})
end

function json.encodePretty(val)
    return encodeCommon(val, true, 0, {})
end

------------------------------------------------------------------ decoding

local decodeControls = {}
for k,v in pairs(controls) do
    decodeControls[v] = k
end

function json.parseBoolean(str)
    if str:sub(1, 4) == "true" then
        return true, removeWhite(str:sub(5))
    else
        return false, removeWhite(str:sub(6))
    end
end

function json.parseNull(str)
    return nil, removeWhite(str:sub(5))
end

local numChars = {['e']=true; ['E']=true; ['+']=true; ['-']=true; ['.']=true}
function json.parseNumber(str)
    local i = 1
    while numChars[str:sub(i, i)] or tonumber(str:sub(i, i)) do
        i = i + 1
    end
    local val = tonumber(str:sub(1, i - 1))
    str = removeWhite(str:sub(i))
    return val, str
end

function json.parseString(str)
    str = str:sub(2)
    local s = ""
    while str:sub(1,1) ~= "\"" do
        local next = str:sub(1,1)
        str = str:sub(2)
        assert(next ~= "\n", "Unclosed string")

        if next == "\\" then
            local escape = str:sub(1,1)
            str = str:sub(2)

            next = assert(decodeControls[next..escape], "Invalid escape character")
        end

        s = s .. next
    end
    return s, removeWhite(str:sub(2))
end

function json.parseArray(str)
    str = removeWhite(str:sub(2))

    local val = {}
    local i = 1
    while str:sub(1, 1) ~= "]" do
        local v = nil
        v, str = json.parseValue(str)
        val[i] = v
        i = i + 1
        str = removeWhite(str)
    end
    str = removeWhite(str:sub(2))
    return val, str
end

function json.parseObject(str)
    str = removeWhite(str:sub(2))

    local val = {}
    while str:sub(1, 1) ~= "}" do
        local k, v = nil, nil
        k, v, str = json.parseMember(str)
        val[k] = v
        str = removeWhite(str)
    end
    str = removeWhite(str:sub(2))
    return val, str
end

function json.parseMember(str)
    local k = nil
    k, str = json.parseValue(str)
    local val = nil
    val, str = json.parseValue(str)
    return k, val, str
end

function json.parseValue(str)
    local fchar = str:sub(1, 1)
    if fchar == "{" then
        return json.parseObject(str)
    elseif fchar == "[" then
        return json.parseArray(str)
    elseif tonumber(fchar) ~= nil or numChars[fchar] then
        return json.parseNumber(str)
    elseif str:sub(1, 4) == "true" or str:sub(1, 5) == "false" then
        return json.parseBoolean(str)
    elseif fchar == "\"" then
        return json.parseString(str)
    elseif str:sub(1, 4) == "null" then
        return json.parseNull(str)
    end
    return nil
end

function json.decode(str)
    str = removeWhite(str)
    t = json.parseValue(str)
    return t
end

function json.decodeFromFile(path)
    local file = assert(fs.open(path, "r"))
    local decoded = json.decode(file.readAll())
    file.close()
    return decoded
end

return json
 end)()


local versionURL = "http://xenon.its-em.ma/version"

if config.checkForUpdates ~= false then
  rapi.request(function(success, url, handle)
    if success then
      if url == versionURL then
        local release = handle.readAll()
        handle.close()

        if release ~= versionTag then
          logger.warn("Version mismatch, latest release is "
            .. release .. ", but running version is " .. versionTag)

          if release:match("v(%d+)") ~= versionTag:match("v(%d+)") then
            logger.warn("Latest version has a major version seperation gap, it may not be safe to update. Review the changelog for more details.")
          end
        end
      end
    else
      if url == versionURL then
        logger.warn("Unable to fetch release data")
      end
    end
  end, versionURL)
end


--== Initialize Renderer ==--

local defaultLayout =
[[
<body>
    <header>My Shop</header>
    <aside>Welcome! To make a purchase, use /pay to send the exact amount
        of Krist to the respective address. Excess Krist will be refunded.</aside>
    <table class="stock-table">
        <thead>
            <tr>
                <th class="stock">Stock</th>
                <th class="name">Item Name</th>
                <th class="price">Price</th>
                <th class="addy">Address</th>
            </tr>
        </thead>
        <tbody>
            <tr id="row-template">
                <td id="stock"></td>
                <td id="name"></td>
                <td class="price-container"><span id="price"></span>kst/i</td>
           <!-- <td id="price-per-stack"></td> -->
           <!-- <td id="addy"></td> -->
                <td id="addy-full"></td>
            </tr>
        </tbody>
    </table>
    <details>By @Emma</details>
</body>
]]
local defaultStyles =
[[
/* Think of this file as your reference:
    Everything that can be customized is in here
    And everything that is not in here, cannot be customized */

colors {
    --white:     #F0F0F0;
    --orange:    #F2B233;
    --magenta:   #E57FD8;
    --lightBlue: #99B2F2;
    --yellow:    #DEDE6C;
    --lime:      #7FCC19;
    --pink:      #F2B2CC;
    --gray:      #4C4C4C;
    --lightGray: #999999;
    --cyan:      #4C99B2;
    --purple:    #B266E5;
    --blue:      #3366CC;
    --brown:     #7F664C;
    --green:     #57A64E;
    --red:       #CC4C4C;
    --black:     #191919;
}

* {
    display: block;
}

body {
    background-color: lightBlue;
}

header {
    position: relative;

    /* content: "My Shop"; */
    /* background: url(myLogo.nfp); */
    /* background-position: center; */
    /* Content and Background (Images) are mutually exclusive, with content taking precedence if both are present */

    background-color: blue;

    width: 100%;
    padding: 1px;

    color: white;
    text-align: left;

    font-size: 2em; /* Either 1em or 2em, no other sizes are currently supported */
}

aside {
    position: absolute;
    right: 0;

    /* Since `top` (and bottom) are omitted here, it will be positioned relative to the last positioned element,
        which is exactly where we want it to be.. */

    width: 30px;
    height: 100rem; /* In Xenon CSS, rem doesn't stand for Root Em, it stands for Remaining space, so this is 100% of the remaining space */

    text-align: left;
    padding: 1px;
    
    background-color: cyan;
    color: white;
}

table {
    position: relative;

    background-color: lightBlue;

    width: calc(100% - 30px);
    height: calc(100rem - 2px); /* See note under aside height */
}

td {
    color: white;
    padding: 0 1px 0 0;
}

.stock {
    color: white;
    text-align: right;
    width: 7px;
}

.stock.low {
    color: yellow;
}

.stock.critical {
    color: red;
}

.name {
    flex: 1; /* tr elements implicitly have flex-box like behavior, it is the only element that (currently) supports this feature */
}

.price-container, .price {
    text-align: right;
    width: 10px;
}

.addy-full, .addy {
    color: white;
    width: 15px;
}

th {
    color: blue;
    padding: 1px 1px 1px 0;
}

/* This is a pretty unreliable rule, just saves a few chars */
/* If you plan on changing the structure, you will most likely need to change this */
th:nth-child(2n + 1) {
    text-align: right;
}

details {
    position: absolute;
    left: 0;
    bottom: 0;

    background-color: transparent;
    color: white;

    width: calc(100% - 30px);
    height: 1px;
}
]]
local userLayout = fs.open(fs.combine(shell.dir(), config.layout or "layout.html"), "r")
local userStyles = fs.open(fs.combine(shell.dir(), config.styles or "styles.css"), "r")

local layout, styles = defaultLayout, defaultStyles
if userLayout then
  layout = userLayout.readAll()
  userLayout.close()
end

if userStyles then
  styles = userStyles.readAll()
  userStyles.close()
end

local renderer = (function()
  if renderer then return renderer end
local renderer = {}
renderer.model = {}
renderer.styles = { {}, {} }


local xmlutils = (function()
  if xmlutils then return xmlutils end
local xmlutils = {}

local INVERSE_ESCAPE_MAP = {
  ["\\a"] = "\a", ["\\b"] = "\b", ["\\f"] = "\f", ["\\n"] = "\n", ["\\r"] = "\r",
  ["\\t"] = "\t", ["\\v"] = "\v", ["\\\\"] = "\\",
}

local specialEscapes = {
  nbsp = " ", amp = "&", krist = "\164"
}

local function consumeWhitespace(wBuffer)
  local nPos = wBuffer:find("%S")
  return wBuffer:sub(nPos or #wBuffer + 1)
end

function xmlutils.parse(buffer)
  local tagStack = {children = {}}

  local parsePoint = tagStack

  local next = buffer:find("%<%!%-%-")
  while next do
    local endComment = buffer:find("%-%-%>", next + 4)
    buffer = buffer:sub(1, next - 1) .. buffer:sub(endComment + 3)

    next = buffer:find("%<%!%-%-")
  end

  local ntWhite = buffer:find("%S")

  while ntWhite do
    buffer = buffer:sub(ntWhite)

    local nxtLoc, _, capt = buffer:find("(%<%/?)%s*[a-zA-Z0-9_%:]+")
    if nxtLoc ~= 1 and buffer:sub(1,3) ~= "<![" then
      --Text node probably
      if nxtLoc ~= buffer:find("%<") then
        -- Syntax error
        error("Unexpected character")
      end

      local cnt = buffer:sub(1, nxtLoc - 1)

      local replaceSearch = 1
      while true do
        local esBegin, esEnd, code = cnt:find("%&([%w#]%w-)%;", replaceSearch)
        if not esBegin then break end

        local replacement = specialEscapes[code]
        if not replacement then
          if code:match("^#%d+$") then
            replacement = string.char(tonumber(code:sub(2)))
          else
            error("Unknown replacement '" .. code .. "' in xml")
          end
        end

        cnt = cnt:sub(1, esBegin - 1) .. replacement .. cnt:sub(esEnd + 1)
        replaceSearch = esBegin + 1
      end

      parsePoint.children[#parsePoint.children + 1] = {type = "text", content = cnt, parent = parsePoint}
      buffer = buffer:sub(nxtLoc)
    elseif nxtLoc == 1 and capt == "</" then
      -- Closing tag
      local _, endC, closingName = buffer:find("%<%/%s*([a-zA-Z0-9%_%-%:]+)")
      if closingName == parsePoint.name then
        -- All good!
        parsePoint = parsePoint.parent

        local _, endTagPos = buffer:find("%s*>")
        if not endTagPos then
          -- Improperly terminated terminating tag... how?
          error("Improperly terminated terminating tag...")
        end

        buffer = buffer:sub(endTagPos + 1)
      else
        -- BAD! Someone forgot to close their tag, gonna be strict and throw
        -- TODO?: Add stack unwind to attempt to still parse?
        error("Unterminated '" .. tostring(parsePoint.name) .. "' tag")
      end
    else
      -- Proper node

      if buffer:sub(1, 9) == "<![CDATA[" then
        parsePoint.children[#parsePoint.children + 1] = {type = "cdata", parent = parsePoint}

        local ctepos = buffer:find("%]%]%>")
        if not ctepos then
          -- Syntax error
          error("Unterminated CDATA")
        end

        parsePoint.children[#parsePoint.children].content = buffer:sub(10, ctepos - 1)

        buffer = buffer:sub(ctepos + 3)
      else

        parsePoint.children[#parsePoint.children + 1] = {type = "normal", children = {}, properties = {}, parent = parsePoint}
        parsePoint = parsePoint.children[#parsePoint.children]

        local _, eTp, tagName = buffer:find("%<%s*([a-zA-Z0-9%_%-%:]+)")
        parsePoint.name = tagName

        buffer = buffer:sub(eTp + 1)

        local sp, ep
        repeat
          buffer = consumeWhitespace(buffer)

          local nChar, eChar, propName = buffer:find("([a-zA-Z0-9%_%-%:]+)")
          if nChar == 1 then
            local nextNtWhite, propMatch = (buffer:find("%S", eChar + 1))
            if not nextNtWhite then
              error("Unexpected EOF")
            end
            buffer = buffer:sub(nextNtWhite)

            buffer = consumeWhitespace(buffer)

            local eqP = buffer:find("%=")
            if eqP ~= 1 then
              error("Expected '='")
            end

            buffer = buffer:sub(eqP + 1)

            nextNtWhite, _, propMatch = buffer:find("(%S)")

            if tonumber(propMatch) then
              -- Gon be a num
              local _, endNP, wholeNum = buffer:find("([0-9%.]+)")

              if tonumber(wholeNum) then
                parsePoint.properties[propName] = tonumber(wholeNum)
              else
                error("Unfinished number")
              end

              buffer = buffer:sub(endNP + 1)
            elseif propMatch == "\"" or propMatch == "'" then
              -- Gon be a string

              buffer = buffer:sub(nextNtWhite)

              local terminationPt = buffer:find("[^%\\]%" .. propMatch) + 1

              local buildStr = buffer:sub(2, terminationPt - 1)

              local repPl, _, repMatch = buildStr:find("(%\\.)")
              while repMatch do
                local replS = INVERSE_ESCAPE_MAP[repMatch] or repMatch:sub(2)
                buildStr = buildStr:sub(1, repPl - 1) .. replS .. buildStr:sub(repPl + 2)
                repPl, _, repMatch = buildStr:find("(%\\.)")
              end

              parsePoint.properties[propName] = buildStr

              buffer = buffer:sub(terminationPt + 1)
            else
              error("Unexpected property, expected number or string")
            end
          end

          sp, ep = buffer:find("%s*%/?>")
          if not sp then
            error("Unterminated tag")
          end
        until sp == 1

        local selfTerm = buffer:sub(ep - 1, ep - 1)
        if selfTerm == "/" then
          -- Self terminating tag
          parsePoint = parsePoint.parent
        end

        buffer = buffer:sub(ep + 1)
      end
    end

    ntWhite = buffer:find("%S")
  end

  return tagStack
end

local prettyXML
do
  local ESCAPE_MAP = {
    ["\a"] = "\\a", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r",
    ["\t"] = "\\t", ["\v"] = "\\v", ["\\"] = "\\\\",
  }

  local function escape(s)
    s = s:gsub("([%c\\])", ESCAPE_MAP)
    local dq = s:find("\"")
    if dq then
      return s:gsub("\"", "\\\"")
    else
      return s
    end
  end

  local root = false
  prettyXML = function(parsedXML, spPos)
    spPos = spPos or 0

    local amRoot
    if root then
      amRoot = false
    else
      amRoot = true
      root = true
    end

    local str = ""
    local newFlag = false
    for i = 1, #parsedXML.children do
      local elm = parsedXML.children[i]

      if elm.type == "normal" then
        str = str .. (" "):rep(spPos) .. "<" .. elm.name

        for k, v in pairs(elm.properties) do
          str = str .. " " .. k .. "="
          if type(v) == "number" then
            str = str .. v
          else
            str = str .. "\"" .. escape(v) .. "\""
          end
        end

        if elm.children and #elm.children ~= 0 then
          str = str .. ">\n"

          local ret, fl = prettyXML(elm, spPos + 2)
          if fl then
            str = str:sub(1, #str - 1) .. ret
          else
            str = str .. ret
          end

          str = str .. (fl and "" or (" "):rep(spPos)) .. "</" .. elm.name .. ">\n"
        else
          str = str .. "></" .. elm.name .. ">\n"
        end
      elseif elm.type == "cdata" then
        str = str .. (" "):rep(spPos) .. "<![CDATA[" .. elm.content .. "]]>\n"
      elseif elm.type == "text" then
        if #parsedXML.children == 1 then
          str = elm.content
          newFlag = true
        else
          str = str .. (" "):rep(spPos) .. elm.content .. "\n"
        end
      end
    end

    if amRoot then
      root = false
      return str
    else
      return str, newFlag
    end
  end
end

xmlutils.pretty = prettyXML

return xmlutils
 end)()
local css = (function()
  if css then return css end
-- CSS Parser

local function trim(str)
  return str:match("%s*(.+)"):reverse():match("%s*(.+)"):reverse()
end

return function(toParse)
  local ruleset = {}
  local order = {}

  local next = toParse:find("%/%*")
  while next do
    local endComment = toParse:find("%*%/", next + 2)
    toParse = toParse:sub(1, next - 1) .. toParse:sub(endComment + 2)

    next = toParse:find("%/%*")
  end

  for IRules in toParse:gmatch("%s*([^{}]+%s-%b{})") do
    local applicatorStr = IRules:match("^[^{}]+")
    local applicators = {}

    for applicator in applicatorStr:gmatch("[^,]+") do
      applicators[#applicators + 1] = #ruleset + 1
      ruleset[#ruleset + 1] = {trim(applicator), {}}
    end

    local contents = IRules:match("%b{}"):sub(2, -2)

    for rule in contents:gmatch("[^%;]+") do
      local name = rule:match("^%s-([^%s%:]+)")
      if name then
        local rest = rule:match("%:%s*(.+)"):reverse():match("%s*(.+)"):reverse()

        for i = 1, #applicators do local applicator = applicators[i] -- do
          ruleset[applicator][2][#ruleset[applicator][2] + 1] = {name, rest}
        end
      end
    end
  end

  return ruleset
end
 end)()

-- Components
local components = (function()
  if components then return components end

local tableComponent = (function()
  if tableComponent then return tableComponent end
local tableComponent = {}

local function makeTextEl(content, parent)
  return {
    type = "text",
    content = (parent.properties.prepend or "")
              .. content ..
              (parent.properties.append or ""),
    parent = parent
  }
end

local function addClass(node, class)
  local prop = node.properties
  local cc = prop.class or ""

  if #cc > 0 then
    local stM, enM = cc:find(class)
    if (not stM) or cc:sub(stM - 1, enM + 1):match("%S+") ~= class then
      prop.class = cc .. " " .. class
    end
  else
    prop.class = class
  end
end

function tableComponent.new(node, renderer)
  local t = { node = node, renderer = renderer }

  local rtemp = renderer.querySelector("#row-template")
  if #rtemp > 0 then
    local row = rtemp[1]

    for i = 1, #row.parent.children do
      if row.parent.children[i] == row then
        row.parent.children[i] = nil
      end
    end

    row.properties.id = nil
    t.rowTemplate = row
  end

  local tel = renderer.querySelector("th", node)
  for i = 1, #tel do local th = tel[i] -- do
    th.adapter = renderer.components.text.new(th)
  end

  return setmetatable(t, { __index = tableComponent })
end

function tableComponent:render(surf, position, styles, resolver)
  if styles["background-color"] then
    local c = resolver({}, "color", styles["background-color"])
    if c > 0 then
      surf:fillRect(position.left, position.top, position.width, position.height, c)
    end
  end

  local rows = self.renderer.querySelector("tr", self.node)

  local flowY = position.top
  for i = 1, #rows do local row = rows[i] -- do
    local flowX = position.left
    local maxH = 0

    local flexTot = 0
    local remWidth = position.width
    local widths = {}

    local topRowMargin,
          rightRowMargin,
          bottomRowMargin,
          leftRowMargin = util.parseOrdinalStyle(resolver, row.styles, "margin")

    flowX = flowX + leftRowMargin
    remWidth = remWidth - rightRowMargin

    flowY = flowY + topRowMargin

    for j = 1, #row.children do
      local td = row.children[j]
      if td.styles.width then
        local w = resolver({width = position.width, flowW = remWidth}, "width", td.styles.width)
        remWidth = remWidth - w
        widths[j] = w
      else
        flexTot = flexTot + (tonumber(td.styles.flex) or 1)
      end
    end

    for j = 1, #row.children do
      local td = row.children[j]
      if row.styles["line-height"] and not td.styles["line-height"] then
        td.styles["line-height"] = row.styles["line-height"]
      end

      local height = tonumber(td.adapter:resolveHeight(td.styles, { width = 10 }, resolver):sub(1, -3))

      local width
      if widths[j] then
        width = math.floor(widths[j])
      else
        width = math.floor(remWidth * ((tonumber(td.styles.flex) or 1) / flexTot))
      end

      local topMargin,
            rightMargin,
            bottomMargin,
            leftMargin = util.parseOrdinalStyle(resolver, td.styles, "margin")

      flowX = flowX + leftMargin
      flowY = flowY + topMargin

      td.adapter:render(surf, {
        left = flowX,
        top = flowY,
        width = width,
        height = height
      }, td.styles, resolver)

      maxH = math.max(maxH, height + bottomMargin)

      flowX = flowX + width + rightMargin
    end

    if row.styles["background-color"] then
      local c = resolver({}, "color", row.styles["background-color"])
      if c > 0 then
        surf:fillRect(position.left, flowY, position.width, maxH, c)
      end
    end

    flowY = flowY + maxH + bottomRowMargin
  end
end

function tableComponent:updateData(data)
  self.data = data

  -- New data so create and restyle it
  local body = self.renderer.querySelector("tbody", self.node)[1]
  if self.rowTemplate then
    local newChildren = {}

    local sortedList = {}
    for k, _ in pairs(data) do
      sortedList[#sortedList + 1] = k
    end

    table.sort(sortedList, function(str1, str2)
      local cOrder1 = transformedItems[str1].order
      local cOrder2 = transformedItems[str2].order

      if (cOrder1 or cOrder2) and (cOrder1 ~= cOrder2) then
        return (cOrder1 or math.huge) < (cOrder2 or math.huge)
      end

      str1 = transformedItems[str1].disp
      str2 = transformedItems[str2].disp

      local i = 0
      local c1, c2
      repeat
        i = i + 1
        c1 = str1:sub(i, i):lower()
        c2 = str2:sub(i, i):lower()
      until i == #str1 or i == #str2 or c1 ~= c2

      return c1:byte() < c2:byte()
    end)

    for sI = 1, #sortedList do
      local k = sortedList[sI]
      local v = tostring(data[sortedList[sI]])

      local skeleton = util.deepClone(self.rowTemplate)
      skeleton.parent = body

      local tel = self.renderer.querySelector("td", skeleton)
      for i = 1, #tel do local td = tel[i] -- do
        td.adapter = self.renderer.components.text.new(td)
      end

      local stock = self.renderer.querySelector("#stock", skeleton)[1]
      local name = self.renderer.querySelector("#name", skeleton)[1]
      local price = self.renderer.querySelector("#price", skeleton)[1]
      local pricePerStack = self.renderer.querySelector("#price-per-stack", skeleton)[1]
      local addy = self.renderer.querySelector("#addy", skeleton)[1]
      local addyFull = self.renderer.querySelector("#addy-full", skeleton)[1]

      if stock then
        stock.children = { makeTextEl(v, stock) }
        addClass(stock, "stock")

        v = tonumber(v)
        if v < (transformedItems[k].critical or config.criticalStock or 10) then
          addClass(stock, "critical")
        elseif v < (transformedItems[k].low or config.lowStock or 50) then
          addClass(stock, "low")
        end
      end

      if name then
        name.children = { makeTextEl(transformedItems[k].disp or k, name) }
        addClass(name, "name")
      end

      if price then
        price.children = { makeTextEl(transformedItems[k].price, price) }
        addClass(price, "price")
      end

      if pricePerStack then
        pricePerStack.children = { makeTextEl(util.round(60 / transformedItems[k].price, 2), pricePerStack) }
        addClass(pricePerStack, "price-per-stack")
      end

      if addy then
        addy.children = { makeTextEl(transformedItems[k].addy, addy) }
        addClass(addy, "addy")
      end

      if addyFull then
        addyFull.children = { makeTextEl(transformedItems[k].addy .. "@" .. config.name .. ".kst", addyFull) }
        addClass(addyFull, "addy-full")
      end

      newChildren[#newChildren + 1] = skeleton
    end

    body.children = newChildren
  end

  self.renderer.processStyles()
end

return tableComponent end)()
local basicComponent = (function()
  if basicComponent then return basicComponent end
local basicTextComponent = {}

local function calcWidth(text)
  if #text == 0 then return 0 end

  local w = -1
  for i = 1, #text do
    w = w + font.widths[string.byte(text:sub(i, i)) - 31] + 1
  end

  return w
end

local function calcSizeBig(text)
  return math.ceil(calcWidth(text) / 2) * 2, math.ceil(font.height / 3) * 3
end

local function writeBig(surf, text, x, y, col, bg, align, width)
  local sw, sh = calcSizeBig(text)
  local tempSurf = surface.create(sw, sh, bg)

  tempSurf:drawText(text, font, 0, 0, col, bg, bg)
  if align == "left" then
    surf:drawSurfaceSmall(tempSurf, x, y)
  elseif align == "center" then
    surf:drawSurfaceSmall(tempSurf, math.floor(x + (width - sw / 2) / 2), y)
  else
    surf:drawSurfaceSmall(tempSurf, width + x - sw / 2, y)
  end
end

local function transformText(text, styles)
  local style = styles["text-transform"]
  if style == "uppercase" then
    return text:upper()
  elseif style == "lowercase" then
    return text:lower()
  elseif style == "capitalize" then
    return text:gsub("%f[%a]%w", function(c) return c:upper() end)
  end

  return text
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

  local topPad,
        rightPad,
        _, -- bottomPad is unused
        leftPad = util.parseOrdinalStyle(resolver, styles, "padding")

  local lineHeight = 1
  if styles["line-height"] then
    lineHeight = resolver({}, "number", styles["line-height"])
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
    local text = resolver({}, "string", styles.content)
    text = transformText(text, styles)

    if styles["font-size"] == "2em" then
      if bgc <= 0 then
        error("'font-size: 2em' requires 'background-color' to be present")
      end

      writeBig(surf, text,
        position.left + leftPad, cY,
        resolver({}, "color", styles.color), bgc,
        styles["text-align"] or "left", position.width - leftPad - rightPad)
    else
      util.wrappedWrite(surf, text,
        position.left + leftPad, cY, position.width - leftPad - rightPad,
        resolver({}, "color", styles.color), styles["text-align"] or "left", lineHeight)
    end
  else
    if styles["font-size"] == "2em" then
      if bgc <= 0 then
        error("'font-size: 2em' requires 'background-color' to be present")
      end

      -- TODO Wrapping support?
      local text = self.node.children[1].content or ""
      text = transformText(text, styles)
      writeBig(surf, text,
        position.left + leftPad, cY,
        resolver({}, "color", styles.color), bgc,
        styles["text-align"] or "left", position.width - leftPad - rightPad)
    else
      local children = self.node.children
      local acc = ""

      for i = 1, #children do local child = children[i] -- do
        if child.type == "text" then
          acc = acc .. child.content
        elseif child.name == "br" then
          acc = transformText(acc, styles)

          cY = util.wrappedWrite(surf, acc,
            position.left + leftPad, cY, position.width - leftPad - rightPad,
            resolver({}, "color", styles.color), styles["text-align"] or "left", lineHeight)
          acc = ""
        elseif child.name == "span" then
          acc = acc .. child.children[1].content
        end
      end
      if #acc > 0 then
        acc = transformText(acc, styles)

        util.wrappedWrite(surf, acc,
          position.left + leftPad, cY, position.width - leftPad - rightPad,
          resolver({}, "color", styles.color), styles["text-align"] or "left", lineHeight)
      end
    end
  end
end

function basicTextComponent:resolveHeight(styles, context, resolver)
  local topPad,
        rightPad,
        bottomPad,
        leftPad = util.parseOrdinalStyle(resolver, styles, "padding")

  local cY = 0

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
    for i = 1, #children do local child = children[i] -- do
      if child.type == "text" then
        acc = acc .. child.content
      elseif child.name == "br" then
        cY = util.wrappedWrite(nil, acc,
          position.left + leftPad, cY, position.width - leftPad - rightPad)
        acc = ""
        cY = cY + 1
      elseif child.name == "span" then
        acc = acc .. child.children[1].content
      end
    end
    cY = cY + 1
  end

  if styles["line-height"] then
    cY = cY * resolver({}, "number", styles["line-height"])
  end

  return (topPad + bottomPad + cY) .. "px"
end

return basicTextComponent
 end)()

return {
  table = tableComponent,
  header = basicComponent,
  aside = basicComponent,
  details = basicComponent,
  text = basicComponent
}
 end)()

renderer.components = components

local function deepMap(set, func, level)
  level = level or 1

  for i = 1, #set.children do local child = set.children[i] -- do
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
      return math.floor(context.width * (val[2] / 100) + context.flowX)
    elseif val[1] == "remain" then
      return math.floor(context.flowW * (val[2] / 100) + context.flowX)
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
      return math.floor(context.height * (val[2] / 100) + context.flowY)
    elseif val[1] == "remain" then
      return math.floor(context.flowY * (val[2] / 100) + context.flowY)
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

    for i = 1, #matches do local matchedEl = matches[i] -- do
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
  for i = 1, #body.children do local el = body.children[i] -- do
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

  for i = 1, #node.children do local el = node.children[i] -- do
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

      local width, height
      width = resolveVal(context, "width", s.width or "100rem")

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

      local topMargin,
            _, -- rightMargin currently unused as there is no way (currently) to have inline elements
            bottomMargin,
            leftMargin = util.parseOrdinalStyle(resolveVal, s, "margin")

      left = left + leftMargin
      top = top + topMargin

      if el.adapter then
        el.adapter:render(surf, {
          left = left,
          top = top,
          width = width,
          height = height
        }, s, resolveVal)

        context.flowY = context.flowY + height + bottomMargin
        context.flowH = context.flowH - height - bottomMargin
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
 end)()
renderer.inflateXML(layout)
renderer.processStyles(styles)


  if layoutMode then
    local exampleData = config.example or {
      ["minecraft:gold_ingot::0::0"] = 412,
      ["minecraft:iron_ingot::0::0"] = 4,
      ["minecraft:diamond::0::0"] = 27
    }

    local rmList = {}
    for item in pairs(exampleData) do
      if not transformedItems[item] then
        rmList[#rmList + 1] = item
      end
    end

    for i = 1, #rmList do local item = rmList[i] -- do
      exampleData[item] = nil
    end

    local els = renderer.querySelector("table.stock-table")
    for i = 1, #els do
      els[i].adapter:updateData(exampleData)
    end

    for _, v in pairs(renderer.colorReference) do
      term.setPaletteColor(2^v[1], tonumber(v[2], 16))
    end

    local testSurf = surface.create(term.getSize())

    renderer.renderToSurface(testSurf)
    testSurf:output()

    os.pullEvent("mouse_click")
  else
    local repaintMonitor -- Forward declaration

--== Chests ==--

if config.chest then
  config.chests = { config.chest }
end

-- Wrap the peripherals
if not config.chests then
  local periphs = peripheral.getNames()
  local chest
  for i = 1, #periphs do local periph = periphs[i] -- do
    if periph:match("chest") or periph:match("shulker_box") then
      chest = periph
    end
  end

  if not chest then
    error("No configured chest(s), and none could be found")
  else
    config.chests = { chest }
  end
end

local modems = { peripheral.find("modem") }
local peripheralNameToSelf = {}
for i = 1, #modems do local modem = modems[i] -- do
  local self = modem.getNameLocal()
  local names = modem.getNamesRemote()
  for i = 1, #names do local name = names[i] -- do
    peripheralNameToSelf[name] = self
  end
end

local chestPeriphs = {}
local chestToSelf = {}
for i = 1, #config.chests do local chest = config.chests[i] -- do
  local wrapper = peripheral.wrap(chest)
  chestPeriphs[#chestPeriphs + 1] = wrapper
  chestToSelf[wrapper] = peripheralNameToSelf[chest]

  if not chestPeriphs[#chestPeriphs] then
    chestPeriphs[#chestPeriphs] = nil
    logger.error("No chest by name '" .. chest .. "'")
  end
end

if #chestPeriphs == 0 then
  error("No valid chest(s) could be found")
end

-- if not config.self and not config.outChest then
--   -- Attempt to find by chestPeriph reverse search
--   local cp = chestPeriphs[1]
--   local list = cp.getTransferLocations()
--   for i = 1, #list do local loc = list[i] -- do
--     if loc:match("^turtle") then
--       config.self = loc
--       logger.warn("config.self not specified, assuming turtle connection '" .. config.self .. "'")

--       break
--     end
--   end

--   if not config.self then
--     error("config.self not specified, and was unable to infer self, please add to config")
--   end
-- end

-- Wrap the output chest
-- local outChest = nil
-- if config.outChest then
--   outChest = peripheral.wrap(config.outChest)
-- end

--== Monitors ==--

local monPeriph
if not config.monitor then
  local mon = peripheral.find("monitor")

  if mon then
    monPeriph = mon
  else
    error("No configured monitor(s), and none could be found")
  end
else
  monPeriph = peripheral.wrap(config.monitor)

  if not (monPeriph and monPeriph.setPaletteColor) then
    error("No monitor by name '" .. monPeriph .. "' could be found")
  end
end

--== RS Integrators ==--

local rsIntegrators = {}
if config.redstoneIntegrator then
  local toWrap = {}
  if type(config.redstoneIntegrator[1]) == "table" then
    for i = 1, #config.redstoneIntegrator do local integrator = config.redstoneIntegrator[i] -- do
      toWrap[#toWrap + 1] = integrator
    end
  else
    toWrap = {config.redstoneIntegrator}
  end
  
  for i = 1, #toWrap do local integrator = toWrap[i] -- do
    local pHandle = peripheral.wrap(integrator[1])
    rsIntegrators[#rsIntegrators + 1] = {pHandle, integrator[2]}
  end
end

monPeriph.setTextScale(config.textScale or 0.5)
successTools.monitor = monPeriph

--== Various Helper Functions ==--

local function anyFree()
  local c = 0
  for i = 1, 16 do
    c = c + turtle.getItemSpace(i)
  end

  return c > 0
end

local function getFreeSlot()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then
      return i
    end
  end
end

--== Inventory Management Functions ==--

local drawRefresh

local function processChest(chestPeriph, list, slotList, hasPredCache)
  local cTable = chestPeriph.list()
  if not cTable then
    logger.error("Unable to list chest '" .. chestPeriph .. "'")
  else
    for k, v in pairs(cTable) do -- For each item..
      local bName = util.toListName(v.name, 0) -- Simplified name to check if deep predicate matching is required

      local predicateID = 0
      if hasPredCache[bName] then
        -- This item has known predicates, find which one

        -- First see if we can match the predicate without making expensive meta calls
        for chkPredicateID = 1, #predicateCache do
          if util.matchPredicate(predicateCache[chkPredicateID], v) then
            predicateID = chkPredicateID
            break
          end
        end

        -- Check detailed metadata
        if predicateID == 0 then
          -- This may take a while, so make sure to alert potential customers while shop is unavaliable
          -- TODO: ^^^^^ but only when sleep is required

          local cachedMeta = chestPeriph.getItemDetail(k)
          for chkPredicateID = 1, #predicateCache do
            if util.matchPredicate(predicateCache[chkPredicateID], cachedMeta) then
              predicateID = chkPredicateID
              break
            end
          end
        end
      end


      local lName = util.toListName(v.name, predicateID)

      if transformedItems[lName] then
        if not list[lName] then
          list[lName] = v.count
          slotList[lName] = { { k, v.count, chestPeriph } }
        else
          list[lName] = list[lName] + v.count
          slotList[lName][#slotList[lName] + 1] = { k, v.count, chestPeriph }
        end
      end
    end
  end
end

local list -- Item count list
local slotList -- Keep track of which slots (in chests) items are located
local hasPredCache -- Keep track of which items have predicates
local function countItems()
  local hasDrawnRefresh = false
  
  local lastList = slotList

  list = {}
  hasPredCache = {}
  slotList = {}

  -- Perform some initial transformations on the data
  for i = 1, #config.items do local item = config.items[i] -- do
    local bName = util.toListName(item.modid, 0)
    if not hasPredCache[bName] then
      hasPredCache[bName] = item.predicateID ~= nil
    end

    if config.showBlanks then
      local lName = util.toListName(item.modid, item.predicateID or 0)
      list[lName] = 0
      slotList[lName] = {}
    end
  end
  
  -- Iterate over all known chests
  for ck = 1, #chestPeriphs do
    local chestPeriph = chestPeriphs[ck]
    processChest(chestPeriph, list, slotList, hasPredCache)
  end

  if not util.equals(lastList, slotList) then
    local els = renderer.querySelector("table.stock-table")
    for i = 1, #els do
      els[i].adapter:updateData(list)
    end

    repaintMonitor()
  end
end

local function dispense(mcname, count)
  local toMoveCount = count
  while toMoveCount > 0 do
    -- We don't need to check for item availability here because
    -- we already did that in processPayment()

    for i = #slotList[mcname], 1, -1 do
      local chestPeriph = slotList[mcname][i][3]
      local amountPushed = 0
      -- if config.outChest then
      --   local tempSlot = getFreeSlot()
      --   amountPushed = chestPeriph.pushItems(config.self, slotList[mcname][i][1], toMoveCount, tempSlot)
      --   outChest.pullItems(config.self, tempSlot)
      -- else
      amountPushed = chestPeriph.pushItems(chestToSelf[chestPeriph], slotList[mcname][i][1], toMoveCount)
      -- end

      toMoveCount = toMoveCount - amountPushed

      if toMoveCount <= 0 then
        break
      end

      if not anyFree() then -- and not config.outChest then
        for j = 1, 16 do
          if turtle.getItemCount(j) > 0 then
            turtle.select(j)
            turtle.drop()
          end
        end
      end
    end
  end

  -- if config.outChest then
  --   local toBeDispensed = count
  --   local iList, iSlotList = {}, {}
  --   processChest(outChest, iList, iSlotList, hasPredCache)
  --   for i = #iSlotList[mcname], 1, -1 do
  --     toBeDispensed = toBeDispensed -
  --       outChest.drop(
  --         iSlotList[mcname][i][1],
  --         math.min(iSlotList[mcname][i][2], toBeDispensed),
  --         config.outChestDir or "up")

  --     if toBeDispensed <= 0 then
  --       break
  --     end
  --   end
  -- else
  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      turtle.drop()
    end
  end
  -- end

  countItems()
end

local function findItem(name)
  for k, item in pairs(config.items) do
    if item.addy == name then
      return item, util.toListName(item.modid, item.predicateID or 0)
    end
  end

  return false
end

--== Payment Processing Functions ==--

local messages = {
  overpaid = "message=You paid {amount} KST more than you should have, here is your change, {buyer}.",
  underpaid = "error=You must pay at least {price} KST for {item}(s), you have been refunded, {buyer}.",
  outOfStock = "error=We do not have any {item}(s) at the moment, sorry for any inconvenience, {buyer}.",
  unknownItem = "error=We do not currently sell {item}(s), sorry for any inconvenience, {buyer}."
}

if config.messages then
  for k, v in pairs(config.messages) do
    messages[k] = v
  end
end

local function escapeSemi(txt)
  return txt:gsub("[%;%=]", "")
end

local function template(str, context)
  for k, v in pairs(context) do
    str = str:gsub("{" .. k .. "}", v)
  end

  return str
end

local function processPayment(tx, meta)
  local item, mcname = findItem(meta.name)

  if item then
    local count = math.floor(tonumber(tx.value) / item.price)

    local ac = math.min(count, list[mcname] or 0)
    if ac > 0 then
      logger.info("Dispensing " .. count .. " " .. item.disp .. "(s)")
      logger.info("Xenon (" .. (config.title or "Shop") .. "): " ..
          (meta.meta and meta.meta["username"] or "Someone") .. " bought " .. ac .. " " .. item.disp .. "(s) (" .. (ac * item.price) .. " KST)!",
        (config.logger or {}).purchase or false)
    end

    if (list[mcname] or 0) < count then
      logger.warn("More items were requested than available, refunding..")

      if (list[mcname] ~= 0) then
        logger.warn("Xenon (" .. (config.title or "Shop") .. "): " ..
            (meta.meta and meta.meta["username"] or "Someone") .. " bought all remaining " .. item.disp .. "(s), they are now out of stock.",
          (config.logger or {}).outOfStock or false)
      end

      if meta.meta and meta.meta["return"] then
        local refundAmt = math.floor(tx.value - (list[mcname] * item.price))

        if ac == 0 then
          await(kapi.makeTransaction, config.pkey, meta.meta["return"], refundAmt,
            template(messages.outOfStock, { item = item.disp, price = item.price, amount = refundAmt, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
        else
          await(kapi.makeTransaction, config.pkey, meta.meta["return"], refundAmt,
            template(messages.overpaid, { item = item.disp, price = item.price, amount = refundAmt, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
        end
      end
      count = list[mcname]
      tx.value = math.ceil(list[mcname] * item.price)
    end

    if tx.value < item.price then
      local refundAmt = tx.value

      await(kapi.makeTransaction, config.pkey, meta.meta["return"], refundAmt,
        template(messages.underpaid, { item = item.disp, amount = refundAmt, price = item.price, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
    elseif tx.value > count * item.price then
      if meta.meta and meta.meta["return"] then
        local refundAmt = tx.value - (count * item.price)

        if refundAmt >= 1 then
          await(kapi.makeTransaction, config.pkey, meta.meta["return"], refundAmt,
            template(messages.overpaid, { item = item.disp, amount = refundAmt, price = item.price, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
        end
      end
    end

    if list[mcname] and list[mcname] ~= 0 then
      dispense(mcname, count)
    end
  else
    logger.warn("Payment was sent for an invalid item (" .. meta.name .. "), aborting..")
    if meta.meta and meta.meta["return"] then
      await(kapi.makeTransaction, config.pkey, meta.meta["return"], tx.value,
        template(messages.unknownItem, { item = escapeSemi(meta.name), amount = refundAmt, buyer = (meta.meta and meta.meta["username"] or "Someone") }))
    end
  end
end


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

-- Not local because of forward declaration
function drawRefresh()
  monPeriph.setPaletteColor(2^0, 0x2F3542)
  monPeriph.setPaletteColor(2^1, 0x747D8C)

  monPeriph.setBackgroundColor(2^0)
  monPeriph.setTextColor(2^1)
  monPeriph.clear()

  local str = "Refreshing stock..."
  monPeriph.setCursorPos(math.ceil((monW - #str) / 2), math.ceil(monH / 2))
  monPeriph.write(str)
end


    -- Initialize Item List
    countItems()

    drawStartup()

--== Krist Interface Setup ==--

local ws -- Krist Websocket forward declaration

rapi.init(jua)
wapi.init(jua)
kapi.init(jua, json, wapi, rapi)

jua.on("terminate", function()
  if ws then ws.close() end
  jua.stop()
  logger.error("Terminated")
  logger.close()
end)

-- Double check that the config is self-consistent (pkey matches address, address owns name)
if not config.pkey then
  error("No private-key (config.pkey)")
end

if config.pkeyFormat == "kwallet" then
  config.pkey = kapi.toKristWalletFormat(config.pkey)
end

do
  local pkeyAddress = kapi.makev2address(config.pkey)
  if config.host ~= pkeyAddress then
    error("Generated host (" .. pkeyAddress .. ") does not match config.host (" .. config.host .. ")")
  end

  local success, nameInfo = jua.await(kapi.name, config.name)

  if not success then
    if nameInfo.error then
      if nameInfo.error == "name_not_found" then
        error("Error validating name, name '" .. config.name .. "' does not exist/has not been purchased.")
      end
    end

    error("Error validating name, could not retrieve name info from Krist server.")
  end

  if nameInfo.owner ~= config.host then
    error("Host (" .. config.host ..") does not own name (" .. config.name .. ")")
  end
end

--== Misc Jua Hooks ==--

local await = jua.await

local lightVal = false
local redstoneTimer = 0
local updateTimer = 0
local intervalInc = math.min(config.redstoneInterval or 5, config.updateInterval or 30)
jua.setInterval(function()
  redstoneTimer = redstoneTimer + intervalInc
  updateTimer = updateTimer + intervalInc

  if redstoneTimer >= (config.redstoneInterval or 5) then
    lightVal = not lightVal

    if type(config.redstoneSide) == "table" then
      for i = 1, #config.redstoneSide do local side = config.redstoneSide[i] -- do
        rs.setOutput(side, lightVal)
      end
    elseif type(config.redstoneSide) == "string" then
      rs.setOutput(config.redstoneSide, lightVal)
    end
    
    for i = 1, #rsIntegrators do local integrator = rsIntegrators[i] -- do
      integrator[1].setOutput(integrator[2], lightVal)
    end

    redstoneTimer = 0
  end

  if updateTimer >= (config.updateInterval or 30) then
    countItems()

    updateTimer = 0
  end
end, intervalInc)

--== Handlers ==--
local function handleTransaction(data)
  local tx = data.transaction

  if tx.to == config.host then
    if tx.metadata then
      local meta = tx.metadata
      if type(meta) == "string" then
        meta = kapi.parseMeta(meta)
      end

      if meta.domain == config.name then
        logger.info("Received " .. tx.value .. "kst from " .. tx.from .. " (Meta: " .. tostring(tx.metadata) .. ")")

        processPayment(tx, meta)
      end
    end
  end
end

--== Main Loop ==--

jua.go(function()
  logger.info("Startup!", false, true)

  local success
  success, ws = await(kapi.connect, config.pkey or "no-pkey")

  if success then
    logger.info("Connected to websocket.", false, true)
    ws.on("hello", function(helloData)
      logger.info("MOTD: " .. helloData.motd, false, true)
      local subscribeSuccess = await(ws.subscribe, "transactions", handleTransaction)

      if subscribeSuccess then
        logger.info("Subscribed successfully", false, true)
        repaintMonitor()
      else
        logger.error("Failed to subscribe")
        jua.stop()

        error("Failed to subscribe to Krist transactions")
      end
    end)

    ws.on("closed", function()
      os.reboot()
    end)
  else
    logger.error("Failed to request a websocket url")
    jua.stop()

    error("Failed to request a websocket url")
  end
end)

  end
end

local success, error = pcall(xenon)

if not success then
  local isColor = term.isColor()
  local setBG = isColor and term.setBackgroundColor or function() end
  local setFG = isColor and term.setTextColor or function() end

  setBG(colors.black)
  setFG(colors.red)

  print("[ERROR] Xenon terminated with error: '" .. error .. "'")

  setFG(colors.blue)
  print("This computer will reboot in 10 seconds..")

  if successTools.monitor then
    local mon = successTools.monitor
    local monW, monH = mon.getSize()
    local isMonColor = mon.isColor()

    if isMonColor then
      mon.setPaletteColor(2^0, 0xFFA502)
      mon.setPaletteColor(2^1, 0xFFFFFF)
      mon.setPaletteColor(2^2, 0xFF4757)

      mon.setBackgroundColor(2^0)
      mon.setTextColor(2^1)
    end

    mon.clear()

    if isMonColor then
      mon.setBackgroundColor(2^2)
    end

    for i = 2, 4 do
      mon.setCursorPos(1, i)
      mon.write((" "):rep(monW))
    end

    mon.setCursorPos(2, 3)
    mon.write("Xenon ran into an error!")

    if isMonColor then
      mon.setBackgroundColor(2^0)
    end

    mon.setCursorPos(2, 6)
    mon.write("Error Details:")
    mon.setCursorPos(2, 7)
    mon.write(error)

    local str = "Xenon will reboot in 10 seconds.."
    mon.setCursorPos(math.ceil((monW - #str) / 2), monH - 1)
    mon.write(str)
  end

  if successTools.logger then
    successTools.logger.error("Xenon (" .. ((config or {}).title or "Shop") .. "): Terminated with error: '" .. error .. "'",
      ((config or {}).logger or {}).crash or false)
  end

  sleep(10)
  os.reboot()
else
  if successTools.monitor then
    local mon = successTools.monitor
    local monW, monH = mon.getSize()
    local isMonColor = mon.isColor()

    if isMonColor then
      mon.setPaletteColor(2^0, 0x2F3542)
      mon.setPaletteColor(2^1, 0x747D8C)

      mon.setBackgroundColor(2^0)
      mon.setTextColor(2^1)
    end

    mon.clear()

    local str = "Xenon was terminated..."
    mon.setCursorPos(math.ceil((monW - #str) / 2), math.ceil(monH / 2))
    mon.write(str)
  end
end

