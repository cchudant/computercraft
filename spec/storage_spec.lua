package.path = package.path .. ";./?;./?.lua;./?/init.lua"
package.path = package.path .. ";./spec/?;./spec/?.lua;./spec/?/init.lua"
local util = require("apis.util")
local inspect = require('inspect')
local peripheralMock = require("peripheralMock")
local storage = require("apis.storage")

describe('Storage', function()
    -- it('normal transfer', function()
    --     peripheralMock.resetPeripherals()
    --     local chest1 = peripheralMock.addChestPeripheral("minecraft:chest_1", {
    --         [1] = { name = "minecraft:chest", count = 1, maxCount = 64 },
    --         [2] = { name = "minecraft:dirt", count = 64, maxCount = 64 },
    --         [5] = { name = "minecraft:chest", count = 1, maxCount = 64 },
    --     })
    --     local chest2 = peripheralMock.addChestPeripheral("minecraft:chest_2", {
    --     })
    --     local storageServer = storage.newStorageDriver(
    --         { "minecraft:chest_1" },
    --         util.newNonce()
    --     )
    --     print(storageServer.getItemAmount('minecraft:chest'))
    --     local success, error, transfered, results = storageServer.transfer({
    --         type = 'retrieveItems',
    --         destination = "minecraft:chest_2",
    --         items = {"minecraft:cod","minecraft:dirt"},
    --         amount = 62,
    --         amountMustBeExact = true,
    --     }, { collectResults = true })

    --     print(inspect({success, error, transfered, results}))

    --     assert.is_equal(storageServer.getItemAmount("minecraft:dirt"), 62)
    --     assert.is_equal(storageServer.getItemAmount("minecraft:chest"), 2)
    -- end)
    -- it('normal transfer', function()
    --     peripheralMock.resetPeripherals()
    --     local chest1 = peripheralMock.addChestPeripheral("minecraft:chest_1", {
    --         [1] = { name = "minecraft:stick", count = 2, maxCount = 64 },
    --         [5] = { name = "minecraft:diamond", count = 3, maxCount = 64 },
    --     })
    --     local chest2 = peripheralMock.addChestPeripheral("minecraft:chest_2", {
    --     })
    --     local storageServer = storage.newStorageDriver(
    --         { "minecraft:chest_1" },
    --         util.newNonce()
    --     )
    --     print(storageServer.getItemAmount('minecraft:chest'))
    --     local steps, missing = storageServer.craftLookup("minecraft:diamond_pickaxe", 1)

    --     print(inspect({steps, missing}))

    --     -- assert.is_equal(storageServer.getItemAmount("minecraft:dirt"), 0)
    --     -- assert.is_equal(storageServer.getItemAmount("minecraft:diamond_pickaxe"), 1)
    -- end)
    -- it('craft stacks and tags', function()
    --     peripheralMock.resetPeripherals()
    --     local chest1 = peripheralMock.addChestPeripheral("minecraft:chest_1", {
    --         [1] = { name = "minecraft:oak_planks", count = 32, maxCount = 64 },
    --     })
    --     local chest2 = peripheralMock.addChestPeripheral("minecraft:chest_2", {
    --     })
    --     local storageServer = storage.newStorageDriver(
    --         { "minecraft:chest_1" },
    --         util.newNonce()
    --     )
    --     print(storageServer.getItemAmount('minecraft:chest'))
    --     local steps, missing = storageServer.craftLookup("minecraft:stick", 64*2)

    --     print(inspect({steps, missing}))

    --     assert.is_same(steps, {
    --         { {
    --             inputAmount = 32,
    --             inputs = { 288, 0, 0, 288, 0, 0 },
    --             method = 1,
    --             produced = 128
    --         } }
    --     })
    -- end)
    -- it('craft stacks and tags', function()
    --     peripheralMock.resetPeripherals()
    --     local chest1 = peripheralMock.addChestPeripheral("minecraft:chest_1", {
    --         [1] = { name = "minecraft:oak_planks", count = 32, maxCount = 64 },
    --         [2] = { name = "minecraft:birch_planks", count = 16, maxCount = 64 },
    --         [3] = { name = "minecraft:jungle_planks", count = 1, maxCount = 64 },
    --     })
    --     local chest2 = peripheralMock.addChestPeripheral("minecraft:chest_2", {
    --     })
    --     local storageServer = storage.newStorageDriver(
    --         { "minecraft:chest_1" },
    --         util.newNonce()
    --     )
    --     print(storageServer.getItemAmount('minecraft:chest'))
    --     local steps, missing = storageServer.craftLookup("minecraft:stick", 65)

    --     print(inspect({steps, missing}))

    --     assert.is_same(steps, { {
    --         inputAmount = 15,
    --         inputs = { 288, 0, 0, 288, 0, 0 },
    --         method = 1,
    --         produced = 60
    --       }, {
    --         inputAmount = 2,
    --         inputs = { 288, 0, 0, 304, 0, 0 },
    --         method = 1,
    --         produced = 8
    --       } })
    -- end)
  --   it('craft cake', function()
  --     peripheralMock.resetPeripherals()
  --     local chest1 = peripheralMock.addChestPeripheral("minecraft:chest_1", {
  --         [1] = { name = "minecraft:milk_bucket", count = 1, maxCount = 1 },
  --         [27] = { name = "minecraft:milk_bucket", count = 1, maxCount = 1 },
  --         [26] = { name = "minecraft:milk_bucket", count = 1, maxCount = 1 },
  --         [2] = { name = "minecraft:egg", count = 1, maxCount = 16 },
  --         [3] = { name = "minecraft:sugar_cane", count = 2, maxCount = 64 },
  --         [5] = { name = "minecraft:wheat", count = 5, maxCount = 64 },
  --     })
  --     local storageServer = storage.newStorageDriver(
  --         { "minecraft:chest_1" },
  --         util.newNonce()
  --     )
  --     print(storageServer.getItemAmount('minecraft:chest'))
  --     local steps, missing = storageServer.craftLookup("minecraft:cake", 1)

  --     print(inspect({steps, missing}))

  --     assert.is_same(steps, { {
  --         inputAmount = 1,
  --         inputs = { 767 },
  --         method = 2,
  --         produced = 1
  --       }, {
  --         inputAmount = 1,
  --         inputs = { 767 },
  --         method = 2,
  --         produced = 1
  --       }, {
  --         inputAmount = 1,
  --         inputs = { 816, 816, 816, 250, 716, 250, 695, 695, 695 },
  --         method = 2,
  --         produced = 1
  --       } })
  -- end)
--   it('craft turtle advanced', function()
--     peripheralMock.resetPeripherals()
--     peripheralMock.addChestPeripheral("minecraft:chest_1", {
--         { name = "minecraft:oak_log", count = 64, maxCount = 64 },
--         { name = "minecraft:oak_log", count = 64, maxCount = 64 },
--         { name = "minecraft:oak_log", count = 19, maxCount = 64 },
--         { name = "minecraft:redstone", count = 64, maxCount = 64 },
--         { name = "minecraft:sand", count = 24, maxCount = 64 },
--         { name = "minecraft:ender_pearl", count = 16, maxCount = 16 },
--         { name = "minecraft:ender_pearl", count = 16, maxCount = 16 },
--         { name = "minecraft:ender_pearl", count = 16, maxCount = 16 },
--         { name = "minecraft:ender_pearl", count = 16, maxCount = 16 },
--         { name = "minecraft:blaze_rod", count = 32, maxCount = 64 },
--         { name = "minecraft:diamond", count = 64, maxCount = 64 },
--         { name = "minecraft:diamond", count = 64, maxCount = 64 },
--         { name = "minecraft:diamond", count = 64, maxCount = 64 },
--     })
--     peripheralMock.addChestPeripheral("minecraft:chest_2", {
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--         { name = "minecraft:gold_ingot", count = 64, maxCount = 64 },
--     })
--     local storageServer = storage.newStorageDriver(
--       { crafters = {}, storageChests = { "minecraft:chest_1", "minecraft:chest_2" }, craft = true },
--       util.newNonce()
--     )
--     local steps, missing, consumed = storageServer.craftLookup("computercraft:turtle_advanced", 1)

--     print("final", inspect(steps), inspect(missing), inspect(consumed))
-- end)
it('craft turtle advanced', function()
    peripheralMock.resetPeripherals()
    peripheralMock.addChestPeripheral("minecraft:chest_1", {
        { name = "minecraft:glass_pane", count = 64, maxCount = 64 },
        { name = "minecraft:stone", count = 64, maxCount = 64 },
        { name = "minecraft:redstone", count = 19, maxCount = 64 },
        { name = "minecraft:stone", count = 1, maxCount = 64 },
        { name = "minecraft:iron_ingot", count = 64, maxCount = 64 },
        { name = "minecraft:iron_ingot", count = 64, maxCount = 64 },
        { name = "minecraft:iron_ingot", count = 64, maxCount = 64 },
        { name = "minecraft:iron_ingot", count = 60, maxCount = 64 },
        { name = "minecraft:oak_log", count = 48, maxCount = 64 },
    })
    peripheralMock.addChestPeripheral("minecraft:chest_2", {
        { name = "computercraft:computer_normal", count = 1, maxCount = 64 },
    })
    local storageServer = storage.newStorageDriver(
      { crafters = {}, storageChests = { "minecraft:chest_1" }, craft = true },
      util.newNonce()
    )
    local steps, missing, consumed = storageServer.transfer({
      source = "minecraft:chest_2",
      type = "storeItems",
      amount = "all",
    })

    print("final", inspect(steps), inspect(missing), inspect(consumed))
end)
end)
