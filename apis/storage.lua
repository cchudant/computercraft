local controlApi = require("controlApi")
local util = require("util")
local pretty = require('cc.pretty').pretty_print

local storage = {}

local bannedPeripheralNames = {
    "front", "up", "down", "right", "left", "back"
}

local function findChests()
    local peripherals = {}
    for _, v in ipairs(peripheral.getNames()) do
        local ignore = util.arrayContains(bannedPeripheralNames, v)
        if not ignore and peripheral.hasType(v, 'inventory') then
            table.insert(peripherals, v)
        end
    end
    return peripherals
end

function storage.storageServer()
    ---@class StorageServer
    local storageServer = {}

    -- begin of storage state

    local storageChestIDCounter = 1
    local itemIDCounter = 1
    local slotIDCounter = 1

    -- a chest takes up firstSlotId..(firstSlotId+size) slots
    ---@type { name: string, id: number, size: number, firstSlotId: number }[]
    local storageChests = {}

    ---@type { name: string, nbt: string, id: number, maxCount: number }[]
    local uniqueItems = {}

    -- we optimize for four types of lookups:
    -- - find number of items / number of specific item id
    -- - retrive items from item id, get slotids back from least items to most
    -- - add items to storage, stacking them efficiently
    -- - find an empty slot

    local itemIDToSlots = {
        -- this works as a stack, when we retrieve, we pop from the back
        -- when we add items we push back
        --
        -- this means we have to sort these slots from most amount of items
        -- to least
        -- [itemID] = {slotID, slotID, slotID}
    }
    local itemIDToAmounts = {
        -- [itemID] = number of items
    }
    -- slotID[]
    -- should be poped/pushed from the back
    local emptySlots = {}

    -- end storage state

    local function getStorageChestFromSlotID(slotID)
        for _, storChest in pairs(storageChests) do
            if slotID >= storChest.firstSlotId and
                slotID <= storChest.firstSlotId + storChest.size
            then
                return storChest, slotID - storChest.firstSlotId
            end
        end
    end

    local function initialStateSetup()
        storageChests = {}
        uniqueItems = {}
        itemIDToSlots = {}
        itemIDToAmounts = {}
        storageChestIDCounter = 1
        itemIDCounter = 1
        slotIDCounter = 1

        -- fill up storageChests
        for _, name in ipairs(findChests()) do
            if name ~= 'minecraft:chest_20' then
                local p = peripheral.wrap(name)
                table.insert(storageChests, {
                    name = name,
                    id = storageChestIDCounter,
                    firstSlotId = slotIDCounter,
                    size = p.size()
                })
                storageChestIDCounter = storageChestIDCounter + 1
                slotIDCounter = slotIDCounter + p.size()
            end
        end

        -- fill up items
        for _, v in ipairs(storageChests) do
            local periph = peripheral.wrap(v.name)
            local list = periph.list()
            for slot = 1, v.size do
                local detail = list[slot]
                local slotIndex = v.firstSlotId + slot

                if detail ~= nil then
                    -- get/create item id
                    local found = util.arrayFind(uniqueItems, function(obj)
                        return obj.name == detail.name and obj.nbt == detail.nbt
                    end)
                    local itemID
                    if found ~= nil then itemID = found.id end

                    if itemID == nil then
                        local maxCount = periph.getItemLimit(slot)
                        table.insert(uniqueItems, {
                            name = detail.name,
                            nbt = detail.nbt,
                            maxCount = maxCount,
                            id = itemIDCounter,
                        })
                        itemID = itemIDCounter
                        itemIDCounter = itemIDCounter + 1
                    end

                    -- update itemIDToSlots and itemIDToAmounts

                    local slots = itemIDToSlots[itemID] or {}
                    table.insert(slots, slotIndex)
                    itemIDToSlots[itemID] = slots

                    itemIDToAmounts[itemID] = (itemIDToAmounts[itemID] or 0) + detail.count
                else
                    -- free slot
                    table.insert(emptySlots, slotIndex)
                end
            end
        end

        -- sort items slots
        for _, slots in pairs(itemIDToSlots) do
            local amounts = {} -- [slotid]: number of items

            for _, slotID in ipairs(slots) do
                local chest, chestSlot = getStorageChestFromSlotID(slotID)
                local chestObj = peripheral.wrap(chest.name)
                amounts[slotID] = chestObj.getItemDetail(chestSlot).count
            end
            table.sort(slots, function(slotA, slotB)
                return amounts[slotB] < amounts[slotA]
            end)
        end
    end

    local function openNonStorage(periph)
        if util.arrayAny(storageChests, function(c) return c.name == periph end) then
            return nil, "destination is a storage chest"
        end

        if util.arrayContains(bannedPeripheralNames, periph) then
            return nil, "destination is not on network"
        end
        local destinationPeriph = peripheral.wrap(periph)
        if destinationPeriph == nil then
            return nil, "peripheral cannot be found"
        end
        if not peripheral.hasType(periph, 'inventory') then
            return nil, "destination is not an inventory"
        end
        return destinationPeriph
    end

    ---@class StoreItemsRequest
    ---@field source string
    ---@field slots number[]?
    ---@field name string?
    ---@field nbt string?
    ---@field amount number|'slot'|'all'?
    ---@field amountMustBeExact boolean?

    ---@class StoreItemsOptions
    ---@field allOrNothing boolean?
    ---@field nono boolean?

    ---@class StoreItemsError
    ---@field request number
    ---@field reason string

    ---@class StoreItemsResult
    ---@field request number
    ---@field name string
    ---@field nbt string?
    ---@field source string
    ---@field slot string
    ---@field amount number amount transfered into the inventory
    ---@field newAmount number the new amount now in inventory

    ---@param requests StoreItemsRequest[]
    ---@param options StoreItemsOptions
    ---@return boolean success
    ---@return StoreItemsError[]? errors
    ---@return number? totalItemsTransfered
    ---@return StoreItemsResult[]? results
    function storageServer.storeItems(requests, options)
        util.defaultArgs(options, {
            allOrNothing = false,
            nono = false,
        })

        local function handleOneRequest(ireq, req, results, nono)
            local sourcePeriph, error = openNonStorage(req.source)
            if sourcePeriph == nil then
                return 0, {
                    request = ireq,
                    reason = error,
                }
            end

            local reqAmount = req.amount

            local amountLeft = reqAmount
            local transfered = 0

            for sourceSlot, detail in pairs(sourcePeriph.list()) do
                if amountLeft == 0 then
                    break
                end

                -- find the item id
                local item = util.arrayFind(uniqueItems, function(obj)
                    return obj.name == detail.name and
                        obj.nbt == detail.nbt
                end)

                if item ~= nil
                    and (req.name == nil or req.name == item.name)
                    and (req.nbt == nil or req.nbt == item.nbt)
                    and (req.slots == nil or util.arrayContains(req.slots, sourceSlot))
                then
                    local itemID = item.id
                    local slots = itemIDToSlots[itemID]

                    -- find the first non maxed out stack
                    local beginSlot = #slots
                    for i = #slots, 1, -1 do
                        local slotID = slots[i]
                        local chest, chestSlot = getStorageChestFromSlotID(slotID)
                        local chestObj = peripheral.wrap(chest.name)
                        local amount = chestObj.getItemDetail(chestSlot).count

                        if amount == item.maxCount then
                            break
                        end
                        beginSlot = i
                    end

                    local needToPush = detail.count

                    -- fill existing slots
                    for i = beginSlot, #slots do
                        if amountLeft == 0 then
                            break
                        end

                        local slotID = slots[i]

                        local chest, chestSlot = getStorageChestFromSlotID(slotID)
                        local chestObj = peripheral.wrap(chest.name)
                        local amount = chestObj.getItemDetail(chestSlot).count

                        local toTransfer = math.min(item.maxCount - amount, needToPush)
                        transfered = transfered + toTransfer

                        if not nono then
                            sourcePeriph.pushItems(chest.name, sourceSlot, toTransfer, chestSlot)

                            -- update state
                            itemIDToAmounts[itemID] = itemIDToAmounts[itemID] + toTransfer
                        end

                        if reqAmount ~= 'all' and reqAmount ~= 'slot' then
                            amountLeft = amountLeft - toTransfer
                        end
                        needToPush = needToPush - toTransfer
                    end

                    -- occupy empty slots!
                    for emptySlotI = #emptySlots, 1, -1 do
                        if needToPush <= 0 then break end
                        if amountLeft == 0 then
                            break
                        end

                        local slotID = emptySlots[emptySlotI]

                        local chest, chestSlot = getStorageChestFromSlotID(slotID)

                        local toTransfer = math.min(item.maxCount, needToPush)
                        transfered = transfered + toTransfer
                        needToPush = needToPush - toTransfer

                        if not nono then
                            table.remove(emptySlots, emptySlotI)
                            sourcePeriph.pushItems(chest.name, sourceSlot, toTransfer, chestSlot)
                            itemIDToAmounts[itemID] = itemIDToAmounts[itemID] + toTransfer
                        end

                        if reqAmount ~= 'all' and reqAmount ~= 'slot' then
                            amountLeft = amountLeft - toTransfer
                        end
                    end

                    -- not enough space in storage
                    if needToPush > 0 and req.amountMustBeExact then
                        return nil, {
                            request = ireq,
                            reason = "not enough space in storage"
                        }
                    end

                    if reqAmount == 'slot' then
                        break
                    end

                    table.insert(results, {
                        name = item.name,
                        nbt = item.nbt,
                        source = req.source,
                        slot = sourceSlot,
                        request = ireq
                    })
                end
            end
            return transfered
        end

        if options.allOrNothing then
            local errors = {}
            local results = {}
            for ireq, req in ipairs(requests) do
                local _, error = handleOneRequest(ireq, req, results, true)
                if error ~= nil then
                    table.insert(errors, error)
                end
            end
            if #errors > 0 then
                return false, errors
            end
        end

        local totalTransfered = 0
        local errors = {}
        local results = {}
        for ireq, req in ipairs(requests) do
            local transfered, error = handleOneRequest(ireq, req, results, options.nono)
            if error ~= nil then
                table.insert(errors, error)
            else
                totalTransfered = totalTransfered + transfered
            end
        end

        if #errors == 0 then
            return true, nil, totalTransfered, results
        else
            return false, errors
        end
    end

    ---@class RetrieveItemsRequest
    ---@field destination string
    ---@field slots number[]?
    ---@field name string?
    ---@field nbt string?
    ---@field amount number|'stack'|'all'?
    ---@field amountMustBeExact boolean?

    ---@class RetrieveItemsOptions
    ---@field allOrNothing boolean?
    ---@field nono boolean?

    ---@class RetrieveItemsError
    ---@field request number
    ---@field reason string

    ---@class RetrieveItemsResult
    ---@field request number
    ---@field name string
    ---@field nbt string?
    ---@field destination string
    ---@field slot string
    ---@field added number amount transfered into the inventory
    ---@field newAmount number the new amount now in inventory

    ---@param requests RetrieveItemsRequest[]
    ---@param options RetrieveItemsOptions
    ---@return boolean success
    ---@return RetrieveItemsError[]? errors
    ---@return number? totalItemsTransfered
    ---@return RetrieveItemsResult[]? results
    function storageServer.retrieveItems(requests, options)
        util.defaultArgs(options, {
            allOrNothing = false,
            nono = false,
        })

        local function handleOneRequest(ireq, req, results, nono)
            local destinationPeriph, error = openNonStorage(req.destination)
            if destinationPeriph == nil then
                return 0, {
                    request = ireq,
                    reason = error,
                }
            end

            -- find the item id
            local item = util.arrayFind(uniqueItems, function(obj)
                return obj.name == req.name and
                    not (req.nbt ~= nil and obj.nbt == req.nbt)
            end)
            if item == nil then
                if req.amountMustBeExact then
                    return 0, {
                        request = ireq,
                        reason = "not enough items",
                    }
                end
                return 0
            end
            local itemID = item.id

            local reqAmount = req.amount
            if req.amount == 'stack' or req.amount == 'all' then
                reqAmount = item.maxCount
            end

            -- do we have enough?
            if itemIDToAmounts[itemID] < reqAmount then
                if req.amountMustBeExact then
                    return 0, {
                        request = ireq,
                        reason = "not enough items",
                    }
                end
            end

            -- find available slots in destination periph

            -- traverse the slots array
            local amountLeft = reqAmount

            -- local destSlot, canReceive, inInv = nextSlotInDest()

            local destPeriphSize = destinationPeriph.size()
            local slots = itemIDToSlots[itemID]
            local slotI = #slots

            local destSlot = 1
            local iDestSlot = 1
            while destSlot <= destPeriphSize
                and (req.slots == nil or iDestSlot <= #req.slots)
                and slotI >= 1
                and amountLeft > 0
            do -- for each retrieve chest slot
                local destItem = destinationPeriph.getItemDetail(destSlot)

                local totalTransferedToSlot = 0
                local inDestinationSlot = 0
                if destItem ~= nil then
                    inDestinationSlot = destItem.count
                end
                local canReceive = item.maxCount - inDestinationSlot

                if
                    (destItem == nil or (destItem.name == item.name and destItem.nbt == item.nbt))
                    and canReceive > 0
                then
                    while slotI >= 1
                        and amountLeft > 0
                        and canReceive > 0
                    do -- for each slot in storage chest

                        local slotID = slots[slotI]


                        local chest, chestSlot = getStorageChestFromSlotID(slotID)
                        local chestObj = peripheral.wrap(chest.name)
                        local amount = item.maxCount
                        local destDetail = chestObj.getItemDetail(chestSlot)
                        if destDetail ~= nil then
                            amount = destDetail.count
                        end

                        local actuallyTransfered = math.min(item.maxCount, reqAmount, canReceive, amount)

                        if not nono then
                            destinationPeriph.pullItems(chest.name, chestSlot, actuallyTransfered, destSlot)

                            -- update state
                            itemIDToAmounts[itemID] = itemIDToAmounts[itemID] - actuallyTransfered
                            if actuallyTransfered >= amount then
                                table.remove(slots, slotI)
                                table.insert(emptySlots, slotID)
                                slotI = slotI - 1
                            end
                        end

                        if req.amount ~= 'all' then
                            amountLeft = amountLeft - actuallyTransfered
                        end
                        canReceive = canReceive - actuallyTransfered

                        totalTransferedToSlot = totalTransferedToSlot + actuallyTransfered
                    end

                    table.insert(results, {
                        name = item.name,
                        nbt = item.nbt,
                        destination = req.destination,
                        slot = destSlot,
                        request = ireq,
                        added = totalTransferedToSlot,
                        newAmount = inDestinationSlot + totalTransferedToSlot,
                    })
                end
                if req.slots ~= nil then
                    iDestSlot = iDestSlot + 1
                    destSlot = req.slots[iDestSlot] or destPeriphSize + 1
                else
                    destSlot = destSlot + 1
                end
            end

            if req.amountMustBeExact and
                (destSlot > destPeriphSize or (req.slots ~= nil and iDestSlot > #req.slots)) then
                return reqAmount - amountLeft, {
                    request = ireq,
                    reason = "not enough space in destination inventory"
                }
            end

            return reqAmount - amountLeft
        end

        if options.allOrNothing then
            local errors = {}
            local results = {}
            for ireq, req in ipairs(requests) do
                local _, error = handleOneRequest(ireq, req, results, true)
                if error ~= nil then
                    table.insert(errors, error)
                end
            end
            if #errors > 0 then
                return false, errors
            end
        end

        local totalTransfered = 0
        local errors = {}
        local results = {}
        for ireq, req in ipairs(requests) do
            local transfered, error = handleOneRequest(ireq, req, results, options.nono)
            if error ~= nil then
                table.insert(errors, error)
            else
                totalTransfered = totalTransfered + transfered
            end
        end

        if #errors == 0 then
            return true, nil, totalTransfered, results
        else
            return false, errors, totalTransfered
        end
    end

    initialStateSetup()

    return storageServer
end

return storage
