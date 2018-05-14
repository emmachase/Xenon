--#ignore 4
local tableComponent = require("table")
local headerComponent = require("header")
local asideComponent = require("aside")
local detailsComponent = require("aside")

--#require "src/styles/components/table.lua" as tableComponent
--#require "src/styles/components/header.lua" as headerComponent
--#require "src/styles/components/aside.lua" as asideComponent
--#require "src/styles/components/details.lua" as detailsComponent

return {
  table = tableComponent,
  header = headerComponent,
  aside = asideComponent,
  details = detailsComponent
}
