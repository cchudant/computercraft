local ui = require('ui')
local storage = require('storage')
local storageUI = require('storage.ui')
local pretty = require('cc.pretty').pretty_print

local startStorageServer, storageConnection = storage.storageServer()


local monitor = peripheral.find('monitor') --[[@as Monitor]]
monitor.setTextScale(0.5)

parallel.waitForAny(
    startStorageServer,
    storageUI.create(monitor, storageConnection),
    function()
        local success, missing, consumed = storageConnection.craftItem("minecraft:dried_kelp_block", 1)
        pretty({success, missing, consumed})
        print('finished')
    end
)
