--#ignore
local config = {}

local logger = {}
local slackURL = config.slackURL
local discordURL = config.discordURL
local mentionName = config.mentionName
local externName

local function time()
  return os.day("utc") .. "-" .. os.time("utc")
end

function logger.init(prints, tExternName)
  logger.printf = prints and print or function() end
  logger.handle = fs.open("/log", "a")

  externName = tExternName or os.getComputerLabel() or "Computer - " .. os.getComputerID()
end

function logger.log(text)
  logger.printf(text)
  logger.handle.write(text .. "\n")
  logger.handle.flush()
end

function logger.info(text, externRelay)
  logger.printf("[" .. time() .. "] [INFO] " .. text)
  logger.handle.write("[" .. time() .. "] [INFO] " .. text .. "\n")
  logger.handle.flush()

  if externRelay == "important" then
    logger.externMention(text)
  elseif externRelay then
    logger.externInfo(text)
  end
end

function logger.warn(text, externRelay)
  logger.printf("[" .. time() .. "] [WARN] " .. text)
  logger.handle.write("[" .. time() .. "] [WARN] " .. text .. "\n")
  logger.handle.flush()

  if externRelay then
    logger.externMention(text)
  end
end

function logger.error(text, externRelay)
  logger.printf("[" .. time() .. "] [ERROR] " .. text)
  logger.handle.write("[" .. time() .. "] [ERROR] " .. text .. "\n")
  logger.handle.flush()

  if externRelay then
    logger.externMention(text)
  end
end

function logger.externInfo(text)
  if slackURL then
    http.post(slackURL, [[payload={"username": "]] .. externName .. [[", "text":"]] .. textutils.urlEncode(text) .. [["}]])
  end

  if discordURL then
    http.post(discordURL, [[payload={"username": "]] .. externName .. [[", "content":"]] .. textutils.urlEncode(text) .. [["}]])
  end
end

function logger.externMention(text)
  if not mentionName then
    return logger.externInfo(text)
  end

  if slackURL then
    http.post(slackURL, [[payload={"username": "]] .. externName .. [[", "text":"<@]] .. mentionName .. [[> ]] .. textutils.urlEncode(text) .. [["}]])
  end

  if discordURL then
    http.post(discordURL, [[payload={"username": "]] .. externName .. [[", "content":"<@]] .. mentionName .. [[> ]] .. textutils.urlEncode(text) .. [["}]])
  end
end

function logger.close()
  logger.handle.close()
end

return logger
