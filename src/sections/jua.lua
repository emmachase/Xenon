--== Misc Jua Hooks ==--

local ws -- Krist Websocket forward declaration

local await = jua.await

local lightVal = false
local redstoneTimer = 0
local updateTimer = 0
local intervalInc = math.min(config.redstoneInterval or 5, config.updateInterval or 30)
jua.setInterval(function()
  redstoneTimer = redstoneTimer + intervalInc
  updateTimer = updateTimer + intervalInc

  if config.redstoneSide and redstoneTimer >= (config.redstoneInterval or 5) then
    lightVal = not lightVal

    if type(config.redstoneSide) == "table" then
      foreach(side, config.redstoneSide) do
        rs.setOutput(side, lightVal)
      end
    else
      rs.setOutput(config.redstoneSide, lightVal)
    end

    redstoneTimer = 0
  end

  if updateTimer >= (config.updateInterval or 30) then
    countItems()

    updateTimer = 0
  end
end, intervalInc)

jua.on("terminate", function()
  if ws then ws.close() end
  jua.stop()
  logger.error("Terminated")
  logger.close()
end)

--== Handlers ==--
local function handleTransaction(data)
  local tx = data.transaction

  if tx.to == config.host then
    if tx.metadata then
      local meta = kapi.parseMeta(tx.metadata)

      if meta.domain == config.name then
        logger.info("Received " .. tx.value .. "kst from " .. tx.from .. " (Meta: " .. tx.metadata .. ")")

        processPayment(tx, meta)
      end
    end
  end
end

--== Main Loop ==--

jua.go(function()
  logger.info("Startup!", false, true)

  local success
  if not config.pkey then
    logger.warn("No private-key (config.pkey), refunds will not work..")
  end

  if config.pkeyFormat == "kwallet" then
    config.pkey = kapi.toKristWalletFormat(config.pkey)
  end

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
