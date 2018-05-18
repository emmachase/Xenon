--#ignore 2
local tableComponent = require("table")
local basicComponent = require("basic")

--#require "src/styles/components/table.lua" as tableComponent
--#require "src/styles/components/basic.lua" as basicComponent

return {
  table = tableComponent,
  header = basicComponent,
  aside = basicComponent,
  details = basicComponent,
  text = basicComponent
}
