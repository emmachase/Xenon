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
