local util = require("apis.util")
local transfers = {}

---Internal Store Item Request
---@param state StorageState
---@param ireq number? index of request
---@param req StoreItemsRequest request
---@param results TransferResult[]? array of results to insert into
---@param nono boolean nono
---@param acceptIDs boolean defaults to false
---@return integer transfered number of items transfered
---@return TransferError? error
function transfers.handleStoreItemsRequest(state, ireq, req, results, nono, acceptIDs)
    local sourcePeriph, error = state.openNonStorage(req.source)
    print("opened")
    if sourcePeriph == nil then
        return 0, {
            request = ireq,
            reason = error,
        }
    end

    local reqAmount = req.amount

    local amountLeft = reqAmount
    local transfered = 0

    local sourceItems = sourcePeriph.list()

    local reqItemIDs
    if req.items ~= nil then
        reqItemIDs = state.resolveItemArgs(req.items, acceptIDs, false, true, nil)
    elseif req.name ~= nil then
        reqItemIDs = state.resolveItemArg({ name = req.name, nbt = req.nbt, tag = req.tag }, nil, acceptIDs, false, true,
            nil)
    end

    print("loop")

    for sourceSlot, detail in pairs(sourceItems) do
        print("sourceitem", sourceSlot)
        if amountLeft == 0 then
            print("no amount left")
            break
        end

        local transferedFromSlot = 0
        local originalAmount = detail.count

        -- find the item id
        local item = state.getItemInfo(detail, true, sourcePeriph.getItemLimit(sourceSlot))
        local itemID = item.id

        if (not reqItemIDs or util.arrayContains(reqItemIDs, itemID))
            and (req.slots == nil or util.arrayContains(req.slots, sourceSlot))
        then
            local slots = state.itemIDToSlots[itemID] or {}

            -- find the first non maxed out stack
            local beginSlot = #slots + 1
            for i = #slots, 1, -1 do
                local slotID = slots[i]
                local chest, chestSlot = state.getStorageChestFromSlotID(slotID)
                local chestObj = peripheral.wrap(chest.name)
                local amount = chestObj.getItemDetail(chestSlot).count

                if amount == item.maxCount then
                    break
                end
                beginSlot = i
            end

            local canPush = detail.count

            -- fill existing slots
            for i = beginSlot, #slots do
                if amountLeft == 0 then
                    break
                end

                local slotID = slots[i]

                local chest, chestSlot = state.getStorageChestFromSlotID(slotID)
                local chestObj = peripheral.wrap(chest.name)
                local amount = chestObj.getItemDetail(chestSlot).count

                local toTransfer = math.min(item.maxCount - amount, canPush, amountLeft)
                transfered = transfered + toTransfer
                canPush = canPush - toTransfer
                transferedFromSlot = transferedFromSlot + toTransfer

                if not nono then
                    sourcePeriph.pushItems(chest.name, sourceSlot, toTransfer, chestSlot)

                    -- update state
                    state.itemIDToAmounts[itemID] = state.itemIDToAmounts[itemID] + toTransfer
                end

                if reqAmount ~= 'all' and reqAmount ~= 'slot' then
                    amountLeft = amountLeft - toTransfer
                end
            end

            -- occupy empty slots!
            for emptySlotI = #state.emptySlots, 1, -1 do
                if canPush <= 0 then break end
                if amountLeft == 0 then
                    break
                end

                local slotID = state.emptySlots[emptySlotI]

                local chest, chestSlot = state.getStorageChestFromSlotID(slotID)

                local toTransfer = math.min(item.maxCount, canPush, amountLeft)
                transfered = transfered + toTransfer
                canPush = canPush - toTransfer
                transferedFromSlot = transferedFromSlot + toTransfer

                if not nono then
                    table.remove(state.emptySlots, emptySlotI)
                    sourcePeriph.pushItems(chest.name, sourceSlot, toTransfer, chestSlot)
                    state.itemIDToAmounts[itemID] = (state.itemIDToAmounts[itemID] or 0) + toTransfer
                end

                if reqAmount ~= 'all' and reqAmount ~= 'slot' then
                    amountLeft = amountLeft - toTransfer
                end
            end

            -- not enough space in storage
            if type(amountLeft) == "number" and amountLeft > 0 and req.amountMustBeExact then
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
                        newAmount = originalAmount - transferedFromSlot,
                        request = ireq
                    })
                end
                if reqAmount == 'slot' then
                    break
                end
            end
        end
    end

    -- not enough space in storage
    if req.amountMustBeExact and type(reqAmount) == "number" and amountLeft > 0 then
        return transfered, {
            request = ireq,
            reason = "not enough items in inventory"
        }
    end

    return transfered
end

---Internal Retrieve Item Request
---@param state StorageState
---@param ireq number? index of request
---@param req RetrieveItemsRequest request
---@param results TransferResult[]? array of results to insert into
---@param nono boolean nono
---@return integer transfered number of items transfered
---@return TransferError? error
function transfers.handleRetrieveItemRequest(state, ireq, req, results, nono, acceptIDs)
    local destinationPeriph, error = state.openNonStorage(req.destination)
    if destinationPeriph == nil then
        return 0, {
            request = ireq,
            reason = error,
        }
    end

    -- for each destination slot
    --   find next item or break
    --   for each storage slot for item id
    --     put items
    --   end
    -- end

    local itemIDs
    if req.items ~= nil then
        itemIDs = state.resolveItemArgs(req.items, acceptIDs)
    else
        if acceptIDs and type(req.name) == "number" then
            itemIDs = {req.name}
        else
            itemIDs = state.resolveItemArg({ name = req.name, nbt = req.nbt, tag = req.tag }, nil, acceptIDs)
        end
    end
    ---@cast itemIDs number[]

    util.prettyPrint(itemIDs)

    -- traverse the slots array
    local reqAmount = req.amount
    local amountLeft = reqAmount

    local itemID
    local item
    local amountInStorage
    local destPeriphSize = destinationPeriph.size()

    local slots
    local slotI

    local totalTransfered = 0

    local destSlot = 1
    local iDestSlot = 1
    local iItemID = 0 -- first round will set to one
    print("z")
    while destSlot <= destPeriphSize
        and (req.slots == nil or iDestSlot <= #req.slots)
        and (type(amountLeft) ~= "number" or amountLeft > 0)
    do -- for each retrieve chest slot
        local destItem = destinationPeriph.getItemDetail(destSlot)

        print("a")

        if slots == nil or slotI < 1 then
        print("b")
        if destItem == nil then
        print("c")
        while true do
        print("d")
        iItemID = iItemID + 1
                    if iItemID > #itemIDs then break end

                    -- choose item to retrieve
                    itemID = itemIDs[iItemID]
                    item = state.itemIDToItemInfo(itemID)
                    amountInStorage = state.itemIDToAmounts[itemID] or 0

                    print(itemID, amountInStorage)

                    if amountLeft == 'stack' then
                        amountLeft = item.maxCount or 999 -- there are 0 left in storage
                        reqAmount = item.maxCount
                    end

                    slots = state.itemIDToSlots[itemID] or {}
                    slotI = #slots

                    if amountInStorage > 0 then
                        break
                    end
                end
                if iItemID > #itemIDs then break end
            else
                item = state.getItemInfo(destItem, true)
                itemID = item.id
                slots = state.itemIDToSlots[itemID] or {}
                slotI = #slots
            end
        end

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


                local chest, chestSlot = state.getStorageChestFromSlotID(slotID)
                local chestObj = peripheral.wrap(chest.name)
                local amount = item.maxCount
                local destDetail = chestObj.getItemDetail(chestSlot)
                if destDetail ~= nil then
                    amount = destDetail.count
                end

                local actuallyTransfered = math.min(item.maxCount, amountLeft, canReceive, amount)

                if not nono then
                    destinationPeriph.pullItems(chest.name, chestSlot, actuallyTransfered, destSlot)

                    -- update state
                    state.itemIDToAmounts[itemID] = state.itemIDToAmounts[itemID] - actuallyTransfered
                    if state.itemIDToAmounts[itemID] == 0 then state.itemIDToAmounts[itemID] = nil end

                    if actuallyTransfered >= amount then
                        table.remove(slots, slotI)
                        table.insert(state.emptySlots, slotID)
                        slotI = slotI - 1
                    end
                end

                if req.amount ~= 'all' then
                    amountLeft = amountLeft - actuallyTransfered
                end
                canReceive = canReceive - actuallyTransfered

                totalTransfered = totalTransfered + actuallyTransfered
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

    if req.amountMustBeExact and iItemID > #itemIDs then
        return totalTransfered, {
            request = ireq,
            reason = "not enough items"
        }
    end

    if req.amountMustBeExact and
        (destSlot > destPeriphSize or (req.slots ~= nil and iDestSlot > #req.slots)) then
        return totalTransfered, {
            request = ireq,
            reason = "not enough space in destination inventory"
        }
    end

    return totalTransfered
end

---@param state StorageState
---@param requests (StoreItemsRequest|RetrieveItemsRequest)[]
---@param options { allOrNothing: boolean?, nono: boolean?, collectResults: boolean?, acceptIDs: boolean? }?
---@return boolean success
---@return TransferError[]? errors
---@return number? totalItemsTransfered
---@return TransferResult[]? results
function transfers.batchTransfer(state, requests, options)
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
                _, error = transfers.handleStoreItemsRequest(state, ireq, req --[[@as StoreItemsRequest]], nil,
                    true, false)
            elseif req.type == 'retrieveItems' then
                _, error = transfers.handleRetrieveItemRequest(state, ireq, req --[[@as RetrieveItemsRequest]],
                    nil, true, false)
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
            transfered, error = transfers.handleStoreItemsRequest(state, ireq, req --[[@as StoreItemsRequest]],
                results, options.nono, options.acceptIDs)
        elseif req.type == 'retrieveItems' then
            transfered, error = transfers.handleRetrieveItemRequest(state, ireq,
                req --[[@as RetrieveItemsRequest]], results,
                options.nono, options.acceptIDs)
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

---@param state StorageState
---@param req StoreItemsRequest|RetrieveItemsRequest
---@param options { allOrNothing: boolean?, nono: boolean?, collectResults: boolean?, acceptIDs: boolean? }?
---@return boolean success
---@return TransferError? error
---@return number? totalItemsTransfered
---@return TransferResult[]? results
function transfers.transfer(state, req, options)
    options = util.defaultArgs(options, {
        allOrNothing = false,
        nono = false,
        collectResults = false,
    })

    if options.allOrNothing then
        local error
        if req.type == 'storeItems' then
            _, error = transfers.handleStoreItemsRequest(state, nil, req --[[@as StoreItemsRequest]], nil, true,
                options.acceptIDs)
        elseif req.type == 'retrieveItems' then
            _, error = transfers.handleRetrieveItemRequest(state, nil, req --[[@as RetrieveItemsRequest]], nil,
                true, options.acceptIDs)
        end
        if error ~= nil then
            return false, error
        end
    end

    local results
    if options.collectResults then
        results = {}
    end
    local transfered, error
    if req.type == 'storeItems' then
        transfered, error = transfers.handleStoreItemsRequest(state, nil, req --[[@as StoreItemsRequest]], results,
            options.nono, options.acceptIDs)
    elseif req.type == 'retrieveItems' then
        transfered, error = transfers.handleRetrieveItemRequest(state, nil, req --[[@as RetrieveItemsRequest]],
            results, options.nono, options.acceptIDs)
    end

    if error == nil then
        return true, nil, transfered, results
    else
        return false, error
    end
end

return transfers
