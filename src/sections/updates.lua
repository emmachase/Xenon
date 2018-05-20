local ghURL = "https://api.github.com/repos/incinirate/Xenon/releases/latest"

if config.checkForUpdates ~= false then
  local success = http.request(ghURL)

  if not success then
      logger.warn("Unable to fetch release data")
  end
end

jua.on("http_success", function(url, handle)
  if url == ghURL then
    local releaseData = handle.readAll()
    handle.close()

    local release = json.decode(releaseData)
    if release.tag_name ~= versionTag then
      logger.warn("Version mismatch, latest release is "
        .. release.version_tag .. ", but running version is " .. versionTag)
    end
  end
end)

jua.on("http_failure", function(url)
  if url == ghURL then
    logger.warn("Unable to fetch release data")
  end
end)
