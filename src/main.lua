-- vim: syntax=lua
-- luacheck: globals loadRemote getRemote fs loadstring peripheral

-- Load local config
local configHandle = fs.open(".config", "r")
local config = loadstring("return " .. configHandle.readAll())()
configHandle.close()

-- Load required libs / files

--#ignore 2
local surface = require("surface.lua")
local fontData = require("font.lua")

--#require "vendor/surface.lua" as surface
--#require "src/font.lua" as fontData

local font = surface.loadFont(surface.load(fontData, true))

--#ignore 6
local wapi = require("../vendor/w.lua")
local rapi = require("../vendor/r.lua")
local kapi = require("../vendor/k.lua")
local jua  = require("../vendor/jua.lua")

local logger = require("logger.lua")

--#require "vendor/w.lua" as wapi
--#require "vendor/r.lua" as rapi
--#require "vendor/k.lua" as kapi
--#require "vendor/jua.lua" as jua

--#require "src/logger.lua" as logger
logger.init(true)

--#require "vendor/json.lua" as json


local defaultLayout =
--#ignore
[[]]
--#includeFile "src/styles/default.html"

local defaultStyles =
--#ignore
[[]]
--#includeFile "src/styles/default.css"

--#require "src/styles/renderer.lua" as renderer
renderer.inflateXML(defaultLayout)
renderer.processStyles(defaultStyles)




if config.chest then
  config.chests = { config.chest }
end

-- Wrap the peripherals
local chestPeriphs = {}
for i = 1, #config.chests do
  chestPeriphs[#chestPeriphs + 1] = peripheral.wrap(config.chests[i])
end
local monPeriph = peripheral.wrap(config.monitor)
local altMonPeriph = peripheral.wrap(config.altmon)

if not monPeriph or not chestPeriphs[1] or not altMonPeriph then
  os.reboot()
end

monPeriph.setTextScale(0.5)
if altMonPeriph then
  altMonPeriph.setTextScale(0.5)
end

--==[[ Lib Functions ]]==--

local function toListName(name, damage)
  return name .. "::" .. damage
end

local function fromListName(lName)
  return lName:match("(.+)%:%:")
end

local drawStock

local list -- Item count list
local slotList
local function countItems()
  list = {}
  slotList = {}

  for ck = 1, #chestPeriphs do
    local chestPeriph = chestPeriphs[ck]
    local cTable = chestPeriph.list()
    if not cTable then
      return drawStock(true)
    end

    for k, v in pairs(cTable) do
      local lName = toListName(v.name, v.damage)

      if not list[lName] then
        list[lName] = v.count
        slotList[lName] = { { k, v.count, ck } }
      else
        list[lName] = list[lName] + v.count
        slotList[lName][#slotList[lName] + 1] = { k, v.count, ck }
      end
    end
  end

  local rm = {}
  for k, _ in pairs(list) do
    if not config.items[fromListName(k)] then
      rm[#rm + 1] = k
    end
  end

  for i = 1, #rm do
    list[rm[i]] = nil
  end

  drawStock()
end

local function anyFree()
  local c = 0
  for i = 1, 16 do
    c = c + turtle.getItemSpace(i)
  end

  return c > 0
end

local function dispense(mcname, count)
  while count > 0 do
    -- We don't need to check for item availability here because
    -- we already did that in processPayment()

    for i = #slotList[mcname], 1, -1 do
      local chestPeriph = chestPeriphs[slotList[mcname][i][3]]
      chestPeriph.pushItems(config.self, slotList[mcname][i][1], count)

      local psh = math.min(count, slotList[mcname][i][2])
      count = count - psh

      if count <= 0 then
        break
      end

      if not anyFree() then
        for j = 1, 16 do
          if turtle.getItemCount(j) > 0 then
            turtle.select(i)
            turtle.drop()
          end
        end
      end
    end
  end

  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      turtle.drop()
    end
  end

  countItems()
end

local function findItem(name)
  for k, item in pairs(config.items) do
    if item.addy == name then
      return item, toListName(k, item.damage or 0)
    end
  end

  return false
end

local function escapeSemi(txt)
  return txt:gsub("[%;%=]", "")
end

local function processPayment(tx, meta)
  local item, mcname = findItem(meta.name)

  if item then
    local count = math.floor(tonumber(tx.value) / item.price)

    logger.info("Dispensing " .. count .. " " .. item.disp .. "(s)")
    logger.externMention((meta.meta and meta.meta["username"] or "Someone") .. " bought " .. count .. " " .. item.disp .. "(s) from " .. config.title .. "!")

    if (list[mcname] or 0) < count then
      logger.warn("More items were requested than available, refunding..")
      if meta.meta and meta.meta["return"] then
        await(kapi.makeTransaction, config.pkey, meta.meta["return"], math.floor(tx.value - (list[mcname] * item.price)), "error=We only had '" .. (list[mcname] or 0) .. "' of item '" .. escapeSemi(meta.name) .. "' avaliable right now!")
      end
      count = list[mcname]
      tx.value = math.ceil(list[mcname] * item.price)
    end

    if tx.value > count * item.price then
      if meta.meta and meta.meta["return"] then
        local refund = tx.value - (count * item.price)

        if refund >= 1 then
          await(kapi.makeTransaction, config.pkey, meta.meta["return"], refund, "error=You sent too much krist!")
        end
      end
    end

    if list[mcname] and list[mcname] ~= 0 then
      dispense(mcname, count)
    end
  else
    logger.warn("Payment was sent for an invalid item (" .. meta.name .. "), aborting..")
    if meta.meta and meta.meta["return"] then
      await(kapi.makeTransaction, config.pkey, meta.meta["return"], tx.value, "error=Item '" .. escapeSemi(meta.name) .. "' does not exist!")
    end
  end
end

local function wrappedWrite(surf, text, x, y, width)
  local stX = x
  for word in text:gmatch("%S+") do
    if x + #word > stX + width then
      x = stX
      y = y + 1
    end

    local col = colors.white
    if word:upper() == word then
      col = colors.red
    end
    surf:drawString(word, x, y, nil, col)
    x = x + #word + 1
  end
end


local monW, monH = monPeriph.getSize()
local altW, altH
if altMonPeriph then
  altW, altH = altMonPeriph.getSize()
end

-- Setup monitor
monPeriph.setPaletteColor(colors.black, 0x222f3e)
monPeriph.setPaletteColor(colors.blue, 0x341f97)
monPeriph.setPaletteColor(colors.purple, 0x5f27cd)
monPeriph.setPaletteColor(colors.white, 0xc8d6e5)
monPeriph.setPaletteColor(colors.lightGray, 0x8395a7)
monPeriph.setPaletteColor(colors.gray, 0x576574)
monPeriph.setPaletteColor(colors.red, 0xee5253)

if altMonPeriph then
  altMonPeriph.setPaletteColor(colors.black, 0x222f3e)
  altMonPeriph.setPaletteColor(colors.white, 0xc8d6e5)
  altMonPeriph.setPaletteColor(colors.red, 0xee5253)
end

-- Draw to monitor
local displaySurf = surface.create(monW, monH)
local banner = surface.create(monW * 2, 12)
local warnToast = surface.create(monW * 2, 12)

local disclaimer = surface.create(altW, altH)

local function drawDisclaimer()
  if altMonPeriph then
    disclaimer:clear()

    wrappedWrite(disclaimer, "If the lamp below is NOT flashing, then the shop is not open. DO NOT buy unless it is flashing!",
      1, 1, altW - 2)

    altMonPeriph.clear()
    disclaimer:output(altMonPeriph)
  end
end

function drawStock(warn)
  displaySurf:clear()

  do
    banner:clear(colors.purple)
    banner:drawText(config.title, font, 2, 3, colors.white)

    displaySurf:drawSurfaceSmall(banner, 0, 0)
  end

  displaySurf:drawString("Stock", 1, 5, nil, colors.white)
  displaySurf:drawString("Item Name", 7, 5, nil, colors.white)
  displaySurf:drawString("Price", 26, 5, nil, colors.white)
  displaySurf:drawString("Address", 34, 5, nil, colors.white)

  local sortedList = {}
  for k, v in pairs(list) do
    sortedList[#sortedList + 1] = k
  end

  table.sort(sortedList, function(str1, str2)
    str1 = config.items[fromListName(str1)].disp
    str2 = config.items[fromListName(str2)].disp

    local i = 0
    local c1, c2
    repeat
      i = i + 1
      c1 = str1:sub(i, i):lower()
      c2 = str2:sub(i, i):lower()
    until i == #str1 or i == #str2 or c1 ~= c2

    return c1:byte() < c2:byte()
  end)

  local index = 0
  for sI = 1, #sortedList do
    local k = fromListName(sortedList[sI])
    local v = tostring(list[sortedList[sI]])

    displaySurf:drawString(v, 6 - #v, 7 + index, nil, colors.lightGray)
    displaySurf:drawString(config.items[k].disp or k, 7, 7 + index, nil, colors.white)

    local pStr = config.items[k].price .. "kst/i"
    displaySurf:drawString(pStr, 31 - #pStr, 7 + index, nil, colors.white)

    displaySurf:drawString(config.items[k].addy .. "@" .. config.name .. ".kst", 34, 7 + index, nil, colors.lightGray)
    index = index + 1
  end

  displaySurf:fillRect(monW - 30, 4, 30, monH - 4, colors.blue)
  wrappedWrite(displaySurf, "Welcome! To make a purchase, use /pay to send the exact amount of kst to the respective address. Excess krist will be refunded.",
    monW - 29, 5, 29)

  displaySurf:drawString("By @Incin", 0, monH - 1, nil, colors.gray)

  if warn then
    warnToast:clear(colors.red)
    warnToast:drawText("Out of service", font, monW * 2 - surface.getTextSize("Out of service", font) - 2, 4, colors.white)

    displaySurf:drawSurfaceSmall(warnToast, 0, monH - 4)
  end

  monPeriph.clear()
  displaySurf:output(monPeriph)
end

countItems()
drawDisclaimer()

--==[[ Setup Krist APIS ]]==--

local await = jua.await

rapi.init(jua)
wapi.init(jua)
kapi.init(jua, json, wapi, rapi)

local ws

-- jua.setInterval(countItems, 5)

drawStock(true)
--if true then error("Fix ur sockets m9") end

local lightVal = false
local lightCount = 0
jua.setInterval(function()
  lightVal = not lightVal
  lightCount = lightCount + 1
  rs.setOutput("top", lightVal)

  if lightCount > 2 then
    lightCount = 0
    countItems()
  end
end, 2)

jua.on("terminate", function()
  if ws then ws.close() end
  jua.stop()
  logger.error("Terminated")
  logger.close()
  error()
end)

jua.go(function()
  print("Startup!")

  local success
  success, ws = await(kapi.connect, config.pkey)

  if success then
    print("Connected to websocket.")
    ws.on("hello", function(helloData)
      print("MOTD: " .. helloData.motd)
      local subscribeSuccess = await(ws.subscribe, "transactions", function(data)
        local tx = data.transaction

        if tx.to == config.host then
          if tx.metadata then
            local meta = kapi.parseMeta(tx.metadata)

            if meta.domain == config.name then
              logger.info("Received " .. tx.value .. "kst from " .. tx.from .. " (Meta: " .. tx.metadata .. ")")

              if meta.name == "cloud" then
                tx.value = 128
                meta.name = "mln"
                processPayment(tx, meta)
              else
                processPayment(tx, meta)
              end
            end
          end
        end
      end)
      if subscribeSuccess then
        print("Subscribed successfully.")
        drawStock()
      else
        logger.error("Failed to subscribe.")
        drawStock(true)
        jua.stop()
      end
    end)

    ws.on("closed", function()
      os.reboot()
    end)
  else
    logger.error("Failed to request a websocket url.")
    drawStock(true)
    jua.stop()

    sleep(10)
    os.reboot()
  end
end)

