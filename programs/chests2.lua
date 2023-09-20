local ui = require("apis.ui")
local storage = require("apis.storage")
local storageUI = require("apis.storage.ui")
local util = require("apis.util")

local item, amount = ...

-- local startStorageServer, makeStorageConnection = storage.storageServer({
--     crafters = {{ inventory = "minecraft:chest_30", computerID = 13 }},
--     storageChests = { "minecraft:chest_24", "minecraft:chest_23", "minecraft:chest_22" },
--     smelters = { "minecraft:furnace_0" },
--     fuel = "minecraft:dried_kelp",
--     smeltingStackCraftsTo = 10,
--     craft = true,
-- })

-- ender turtle
-- ender modem + turtle
-- computercraft:turtle_normal@7ba076d7713f07b2707a48fd5f59eaf8 

-- ender mining turtle
-- ender turtle + diamond pickaxe
-- computercraft:turtle_normal@91f2c8ac24f3536cd789d49ae1309000

local monitor = peripheral.find('monitor') --[[@as Monitor]]
monitor.setTextScale(0.5)

parallel.waitForAny(
    -- startStorageServer,
    function() storageUI.runUI(monitor, nil) end
    -- function()
    --     local connection = makeStorageConnection()
    --     local success, missing, consumed = connection.craftItem(item or 'computercraft:turtle_normal', tonumber(amount) or 1)
    --     util.prettyPrint({success, missing, consumed})
    --     print('finished')
    -- end
)
