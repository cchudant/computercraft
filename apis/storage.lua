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

    function itemsReqAsArray(req)
        if req.name ~= nil then
            local item = util.arrayFind(uniqueItems, function(obj)
                return obj.name == req.name and
                    not (req.nbt ~= nil and obj.nbt == req.nbt)
            end)
            return { item }
        elseif req.items ~= nil then
            local arr = {}
            for i, item in ipairs(req.items) do
                local found = util.arrayFind(uniqueItems, function(obj)
                    return obj.name == item.name and
                        not (item.nbt ~= nil and obj.nbt == item.nbt)
                end)
                arr[i] = found
            end
            return arr
        else
            return nil
        end
    end

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

    ---@alias TransferError { request: number, reason: string }

    ---Internal Store Item Request
    ---@param ireq number? index of request
    ---@param req StoreItemsRequest request
    ---@param results TransferResult[]? array of results to insert into
    ---@param nono boolean nono
    ---@return integer transfered number of items transfered
    ---@return TransferError? error
    local function handleStoreItemRequest(ireq, req, results, nono)
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

            local transferedFromSlot = 0
            local originalAmount = detail.count

            -- find the item id
            local item = util.arrayFind(uniqueItems, function(obj)
                return obj.name == detail.name and
                    obj.nbt == detail.nbt
            end)

            if item == nil then
                -- new item id
                local maxCount = sourcePeriph.getItemLimit(sourceSlot)
                item = {
                    name = detail.name,
                    nbt = detail.nbt,
                    id = itemIDCounter,
                    maxCount = maxCount,
                }
                table.insert(uniqueItems, item)
                itemIDCounter = itemIDCounter + 1
            end

            if item ~= nil
                and (req.name == nil or req.name == item.name)
                and (req.nbt == nil or req.nbt == item.nbt)
                and (req.slots == nil or util.arrayContains(req.slots, sourceSlot))
            then
                local itemID = item.id
                local slots = itemIDToSlots[itemID] or {}

                -- find the first non maxed out stack
                local beginSlot = #slots + 1
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
                    transferedFromSlot = transferedFromSlot + toTransfer

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
                        itemIDToAmounts[itemID] = (itemIDToAmounts[itemID] or 0) + toTransfer
                    end

                    if reqAmount ~= 'all' and reqAmount ~= 'slot' then
                        amountLeft = amountLeft - toTransfer
                    end
                end

                -- not enough space in storage
                if needToPush > 0 and req.amountMustBeExact then
                    return transfered, {
                        request = ireq,
                        reason = "not enough space in storage"
                    }
                end

                if transferedFromSlot > 0 then
                    if results ~= nil then
                        table.insert(results, {
                            name = item.name,
                            nbt = item.nbt,
                            source = req.source,
                            slot = sourceSlot,
                            taken = transferedFromSlot,
                            newAmount = originalAmount + transferedFromSlot,
                            request = ireq
                        })
                    end
                    if reqAmount == 'slot' then
                        break
                    end
                end
            end
        end

        return transfered
    end

    ---Internal Retrieve Item Request
    ---@param ireq number? index of request
    ---@param req RetrieveItemsRequest request
    ---@param results TransferResult[]? array of results to insert into
    ---@param nono boolean nono
    ---@return integer transfered number of items transfered
    ---@return TransferError? error
    local function handleRetrieveItemRequest(ireq, req, results, nono)
        local destinationPeriph, error = openNonStorage(req.destination)
        if destinationPeriph == nil then
            return 0, {
                request = ireq,
                reason = error,
            }
        end

        -- for each item id in request
        -- for each destination slot
        -- for each storage slot for item id
        -- give items

        -- find the item id
        local items = itemsReqAsArray(req)

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
        -- if itemIDToAmounts[itemID] < reqAmount then
        --     if req.amountMustBeExact then
        --         return 0, {
        --             request = ireq,
        --             reason = "not enough items",
        --         }
        --     end
        -- end

        -- traverse the slots array
        local amountLeft = reqAmount

        -- local destSlot, canReceive, inInv = nextSlotInDest()

        -- for _, item

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

            -- choose item to retrieve
            local item
            if destItem ~= nil then
                item = util.find(items, function (it)
                    return it.name == destItem.name and it.nbt == destItem.nbt
                end)
            end

            if item == nil then
                -- get first item with count > 0
                item = util.find(items, function (it)
                    if itemIDToAmounts[it.id] > 0 then
                        return true
                    end
                    return false
                end)
            end

            if item == nil then
                if req.amountMustBeExact then
                    return reqAmount - amountLeft, {
                        request = ireq,
                        reason = "not enough items",
                    }
                end
                break
            end

            local itemID = item.id

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
                        if itemIDToAmounts[itemID] == 0 then itemIDToAmounts[itemID] = nil end

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

                if results ~= nil then
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


    ---@class RetrieveItemsRequest
    ---@field type 'retrieveItems'
    ---@field destination string
    ---@field slots number[]?
    ---@field items ({ name: string, nbt: string }|string)[]
    ---@field name string?
    ---@field nbt string?
    ---@field amount number|'stack'|'all'?
    ---@field amountMustBeExact boolean?

    ---@class StoreItemsRequest
    ---@field type 'storeItems'
    ---@field source string
    ---@field slots number[]?
    ---@field items ({ name: string, nbt: string }|string)[]
    ---@field name string?
    ---@field nbt string?
    ---@field amount number|'slot'|'all'?
    ---@field amountMustBeExact boolean?

    ---@class TransferResult collectResults must be true for results to be outputed
    ---@field request number
    ---@field name string
    ---@field nbt string?
    ---@field destination string
    ---@field slot string
    ---@field added number? amount transfered into the inventory
    ---@field taken number? amount transfered from the inventory
    ---@field newAmount number the new amount now in inventory

    ---@param requests (StoreItemsRequest|RetrieveItemsRequest)[]
    ---@param options { allOrNothing: boolean?, nono: boolean?, collectResults: boolean? }?
    ---@return boolean success
    ---@return TransferError[]? errors
    ---@return number? totalItemsTransfered
    ---@return TransferResult[]? results
    function storageServer.batchTransfer(requests, options)
        options = util.defaultArgs(options, {
            allOrNothing = false,
            nono = false,
            collectResults = false,
        })

        if options.allOrNothing then
            local errors = {}
            for ireq, req in ipairs(requests) do
                local _, error
                if req.type == 'storeItems' then
                    _, error = handleStoreItemRequest(ireq, req --[[@as StoreItemsRequest]], nil, true)
                elseif req.type == 'retrieveItems' then
                    _, error = handleRetrieveItemRequest(ireq, req --[[@as RetrieveItemsRequest]], nil, true)
                end
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
        local results
        if options.collectResults then
            results = {}
        end
        for ireq, req in ipairs(requests) do
            local transfered, error
            if req.type == 'storeItems' then
                transfered, error = handleStoreItemRequest(ireq, req --[[@as StoreItemsRequest]], results, options.nono)
            elseif req.type == 'retrieveItems' then
                transfered, error = handleRetrieveItemRequest(ireq, req --[[@as RetrieveItemsRequest]], results,
                    options.nono)
            end
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

    ---@param req StoreItemsRequest|RetrieveItemsRequest
    ---@param options { allOrNothing: boolean?, nono: boolean?, collectResults: boolean? }?
    ---@return boolean success
    ---@return TransferError? error
    ---@return number? totalItemsTransfered
    ---@return TransferResult[]? results
    function storageServer.transfer(req, options)
        options = util.defaultArgs(options, {
            allOrNothing = false,
            nono = false,
            collectResults = false,
        })

        if options.allOrNothing then
            local error
            if req.type == 'storeItems' then
                _, error = handleStoreItemRequest(nil, req --[[@as StoreItemsRequest]], nil, true)
            elseif req.type == 'retrieveItems' then
                _, error = handleRetrieveItemRequest(nil, req --[[@as RetrieveItemsRequest]], nil, true)
            end
            if error ~= nil then
                return false, error
            end
        end

        local errors = {}
        local results
        if options.collectResults then
            results = {}
        end
        local transfered, error
        if req.type == 'storeItems' then
            transfered, error = handleStoreItemRequest(nil, req --[[@as StoreItemsRequest]], results, options.nono)
        elseif req.type == 'retrieveItems' then
            transfered, error = handleRetrieveItemRequest(nil, req --[[@as RetrieveItemsRequest]], results, options.nono)
        end

        if error ~= nil then
            return true, nil, transfered, results
        else
            return false, errors
        end
    end

    local function start()
        

    end

    initialStateSetup()
    return storageServer, start
end

return storage
