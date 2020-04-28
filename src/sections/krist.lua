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
