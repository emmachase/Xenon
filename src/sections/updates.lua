local ghURL = "https://api.github.com/repos/incinirate/Xenon/releases/latest"

if config.checkForUpdates ~= false then
  local handle = http.get(ghURL)

  if handle then
    local releaseData = handle.readAll()
    handle.close()

    local release = json.decode(releaseData)
    if release.tag_name ~= versionTag then
      logger.warn("Version mismatch, latest release is "
        .. release.version_tag .. ", but running version is " .. versionTag)
    end
  else
      logger.warn("Unable to fetch release data")
  end
end
