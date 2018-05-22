--== Chests ==--

if config.chest then
  config.chests = { config.chest }
end

-- Wrap the peripherals
if not config.chests then
  local periphs = peripheral.getNames()
  local chest
  foreach(periph, periphs) do
    if periph:match("chest") then
      chest = periph
    end
  end

  if not chest then
    error("No configured chest(s), and none could be found")
  else
    config.chests = { chest }
  end
end

local chestPeriphs = {}
foreach(chest, config.chests) do
  chestPeriphs[#chestPeriphs + 1] = peripheral.wrap(chest)

  if not chestPeriphs[#chestPeriphs] then
    chestPeriphs[#chestPeriphs] = nil
    logger.error("No chest by name '" .. chest .. "'")
  end
end

if #chestPeriphs == 0 then
  error("No valid chest(s) could be found")
end

if not config.self then
  -- Attempt to find by chestPeriph reverse search
  local cp = chestPeriphs[1]
  local list = cp.getTransferLocations()
  foreach(loc, list) do
    if loc:match("^turtle") then
      config.self = loc
      logger.warn("config.self not specified, assuming turtle connection '" .. config.self .. "'")

      break
    end
  end

  if not config.self then
    error("config.self not specified, and was unable to infer self, please add to config")
  end
end

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

monPeriph.setTextScale(0.5)
successTools.monitor = monPeriph