local ui = require("apis.ui")
local storage = require("apis.storage")
local storageUI = require("apis.storage.ui")
local util = require("apis.util")

local startStorageServer, makeStorageConnection = storage.storageServer({
    crafters = {{ inventory = "minecraft:chest_30", computerID = 28 }},
    storageChests = { "minecraft:chest_24", "minecraft:chest_23", "minecraft:chest_22" },
    craft = true,
})

util.prettyPrint("2", makeStorageConnection)

local monitor = peripheral.find('monitor') --[[@as Monitor]]
monitor.setTextScale(0.5)

parallel.waitForAny(
    startStorageServer,
    -- function() storageUI.runUI(monitor, makeStorageConnection()) end,
    function()
        local connection = makeStorageConnection()
        local success, missing, consumed = connection.craftItem("minecraft:dried_kelp_block", 1)
        -- util.prettyPrint({success, missing, consumed})
        print('finished')
    end
)
