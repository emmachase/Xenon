return {
  title         = "My Shop",   -- Name of the shop, for logging purposes only
--  slackURL    = "<url>",     -- The slack webhook url for logging to a slack channel
--  slackName   = "myUsername" -- Your username in slack for mentions
--  discordURL  = "<url>",     -- The discord webhook url for logging to a discord channel
--  discordName = "123456789012345678" -- Your discord user id for mentions (Find this by typing '\@yourUsernameHere' in Discord)
  logger = { -- Which events are worthy of a message/mention in slack / discord
    -- Valid values are false = no message, true = message, "important" = mention
    purchase = true,          -- When someone purchases anything
    outOfStock = "important", -- When someone purchases all remaining items of a certain type
    crash = true,             -- When Xenon crashes
  },

  layout = "layout.html", -- The file from which xenon should load the layout
  styles = "styles.css",  -- The file from which xenon should load the stylesheet

  host  = "k123456789", -- * The Krist Address to listen to (*Required)
  name  = "name",     -- * The Krist Name to use for purchases (*Required)
  pkey  = "",         -- * The private key to use for refunds (*Required)
  pkeyFormat = "raw", -- Either 'raw' or 'kwallet', defaults to 'raw'
  -- NOTE: It is not recommended to use kwallet, the best practice is to convert your pkey (using
  -- kwallet format) to raw pkey yourself first, and then use that here. Thus improving security.

  textScale = 0.5,   --   The text scale to draw the monitor with
  monitor = "right", --   The network name of the monitor to use (If not present, peripheral.find is used)
  chest   = "left",  -- * The direction/name of the storage chest (*Required if 'chests' is not present)
--  chests = {    -- * An array of the directions/names of the storage chests (*Required if 'chest' is not present)
--    "minecraft:chest_1",
--    "minecraft:chest_6",
--  },
  updateInterval = 30,   --   The time in seconds between stock updates, defaults to 30 seconds

  redstoneSide     = "top", -- The side for redstone heartbeat, if not present, heartbeat is disabled
  redstoneIntegrator = {"redstone_integrator_2", "top"}, -- Redstone integrator net name, and side to actuate on
  redstoneInterval = 5,     -- The time in seconds between redstone heartbeats, defaults to 5 seconds

  messages = { -- Message templates for refunding scenarios, what you see here are the defaults
    overpaid    = "message=You paid {amount} KST more than you should have, here is your change, {buyer}.",
    underpaid   = "error=You must pay at least {price} KST for {item}(s), you have been refunded, {buyer}.",
    outOfStock  = "error=We do not have any {item}(s) at the moment, sorry for any inconvenience, {buyer}.",
    unknownItem = "error=We do not currently sell {item}(s), sorry for any inconvenience, {buyer}."
  },

  showBlanks = false, -- Whether or not to show items that are not in stock on the list, defaults to false
  items = { -- An array object of all the items you wish to sell
    {
      modid  = "minecraft:dye",-- * The modid of the item you wish to sell (*Required)
      price  = 1,              -- * The price in kst each unit of this item should cost (*Required)
      disp   = "Lapis Lazuli", --   The name to display in the table, not technically required, but highly recommended
      addy   = "llz",          -- * The krist metaname to assign to this item, e.g. this one points 'llz@name.kst' to lapis (*Required)
      order  = 1               --   The priority order this item should get in the listing, 1 means it
                               --   will be the first item, 2 would be the second, and so on.. (if not
                               --   present items will be sorted alphabetically)
    },
    {
      modid = "minecraft:diamond_pickaxe",
      disp  = "Silk Touch Diamond Pick",
      addy  = "stdp",
      price = 50,
      predicate = {                  -- Predicates contain a template to match an item's metadata against
        enchantments = {
          {
            fullName = "Silk Touch"
          }
        }
      }
    }
  },

  example = { -- Example chest data to be used with layoutMode (xenon --layout)
    ["minecraft:gold_ingot::0"] = 212, -- Key is modname:itemname::predicateID
    ["minecraft:iron_ingot::0"] = 8,   -- Value is amount in stock
    ["minecraft:diamond::0"] = 27,
    ["minecraft:diamond_pickaxe::1"] = 2,
    ["minecraft:lapis_lazuli::0"] = 13,
  }
}
