--== Load required libs / files ==--

--#ignore 2
local surface = require("surface.lua")
local fontData = require("font.lua")

--#require "vendor/surface.lua" as surface
--#require "src/font.lua" as fontData

local font = surface.loadFont(surface.load(fontData, true))

--#ignore 9
local json = require("../vendor/json.lua")

local wapi = require("../vendor/w.lua")
local rapi = require("../vendor/r.lua")
local kapi = require("../vendor/k.lua")
local jua  = require("../vendor/jua.lua")

local logger = require("logger.lua")
local util = require("util.lua")

--#require "vendor/w.lua" as wapi
--#require "vendor/r.lua" as rapi
--#require "vendor/k.lua" as kapi
--#require "vendor/jua.lua" as jua

--#require "src/logger.lua" as logger
logger.init(true, config.title)
successTools.logger = logger

--#require "src/util.lua" as util

--#require "vendor/json.lua" as json
