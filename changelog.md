# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

### [Unreleased]
### Added
- Ability to drop items via `config.outChest` rather than a turtle dropping them (This means Xenon can run on computers now instead of turtles if this option is used)

### 1.1.1
### Changed
- Improved tick usage by reducing rerenders

### Fixed
- Fixed bug with using percentages and rem not displaying elements

## 1.1.0
### Added
- It is now possible to use redstone integrators for rs heartbeat using `redstoneIntegrator` config option, allows for multiple using same syntax as `redstoneSide`
- Added `textScale` option to config, which allows monitor scale to be configurable
- Added `layout` and `styles` options to config to specify where the files the layout/stylesheet are loaded from  
- Added `justify` mode for text-align
- Added support for non-advanced computers / monitors (note this is very rudimentary and it is **highly** recommended that your monitor is advanced)

### Changed
- `redstoneSide` config option can now be a table, if you wish to have multiple outputs for redstone heartbeat
- It is now legal to use `return {}` in the config file to be more lua compliant (Xenon is backwards compatible with the old method)
- Creating a config at `.config` is now deprecated, they should now be named `config.lua` 

## 1.0.1
### Fixed
- Fixed broken error handler

## 1.0.0
### Added
- Major version mismatch safety warning
- Predicate system for more specific item matching

### Fixed
- Fixed compatibility for multiple items with the same modid

### Changed
- Tables **must** have class 'stock-table' to be filled with stock data
- Instead of putting the modid as the key in the `items` table in the config, you **must** now use numerical keys (don't use explicit keys), and instead put the modid as a config option. For example:
```
items = {
  {
    modid = "minecraft:glowstone",
    disp  = "Glowstone Block",
    addy  = "glow",
    price = 3
  }
}
```

## 0.0.7 - 2018-05-20
### Added
- Added sanity checks for peripheral wraps

### Fixed
- Discord webhooks now work

### Changed
- Updated examples

## 0.0.6 - 2018-05-20
### Fixed
- Fixed a bug with message templates

### Changed
- Error message for invalid config is cleaner

## 0.0.5 - 2018-05-20
### Fixed
- Fixed a bug in vendor libraries, preventing transactions going through when checkForUpdates is enabled

## 0.0.4 - 2018-05-19
### Fixed
- Fixed fatal crash due to missing lib functions

## 0.0.3 - 2018-05-19
### Fixed
- Update notifications work properly

## 0.0.2 - 2018-05-19
### Changed
- New version checking is now done asyncronously

### Fixed
- Fix redstone/inventory intervals being longer than configured
- `line-height` property now works correctly

## 0.0.1 - 2018-05-19
### Added
- This CHANGELOG file
- The release of Xenon
