local util = require(".firmware.apis.util")
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
function transfers.handleStoreItemsRequest(state, ireq, req, results, nono, acceptIDs, balance)
    local sourcePeriph, error = state:openNonStorage(req.source)
    if sourcePeriph == nil then
        return 0, {
            request = ireq,
            reason = error,
        }
    end

    local reqAmount = req.amount

    local amountLeft = reqAmount
    local amountLeft_ = amountLeft
    if type(amountLeft_) == "string" then
        amountLeft_ = 1 / 0
    end
    local transfered = 0

    local sourceItems = sourcePeriph.list()

    local reqItemIDs
    if req.items ~= nil then
        reqItemIDs = state:resolveItemArgs(req.items, acceptIDs, false, true, nil)
    elseif req.name ~= nil then
        reqItemIDs = state:resolveItemArg({ name = req.name, nbt = req.nbt, tag = req.tag }, nil, acceptIDs, false, true,
            nil)
    end

    local storagePointers = {}

    for sourceSlot, detail in pairs(sourceItems) do
        local originalAmount = detail.count
        if amountLeft == 0 then
            break
        end

        -- find the item id
        local item = state:getItemInfo(detail, true, sourcePeriph.getItemLimit(sourceSlot))
        local itemID = item.id

        if (not reqItemIDs or util.arrayContains(reqItemIDs, itemID))
            and (req.slots == nil or util.arrayContains(req.slots, sourceSlot))
        then

            local storagePointer = storagePointers[itemID]
            if storagePointer == nil then
                if nono then
                    storagePointer = state:nonoStoragePointer(itemID)
                else
                    storagePointer = state:storagePointer(itemID)
                end
                storagePointers[itemID] = storagePointer
            end

            local success, _, transferedFromSlot = storagePointer:storeItems(
                originalAmount, req.source, sourceSlot)

            balance[itemID] = (balance[itemID] or 0) + transferedFromSlot

            if not success and type(amountLeft) == "number" and amountLeft > 0 and req.amountMustBeExact then
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
function transfers.handleRetrieveItemRequest(state, ireq, req, results, nono, acceptIDs, balance)
    local destinationPeriph, error = state:openNonStorage(req.destination)
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
        itemIDs = state:resolveItemArgs(req.items, acceptIDs)
    else
        if acceptIDs and type(req.name) == "number" then
            itemIDs = { req.name }
        else
            itemIDs = state:resolveItemArg({ name = req.name, nbt = req.nbt, tag = req.tag }, nil, acceptIDs)
        end
    end
    ---@cast itemIDs number[]

    -- traverse the slots array
    local amountLeft = req.amount

    local itemID
    local item
    local amountInStorage
    local destPeriphSize = destinationPeriph.size()

    local totalTransfered = 0

    local storagePointer

    local destSlot = 1
    local iDestSlot = 1
    if req.slots ~= nil then
        destSlot = req.slots[iDestSlot] or (destPeriphSize + 1)
    end

    local iItemID = 0 -- first round will set to one
    while destSlot <= destPeriphSize
        and (req.slots == nil or iDestSlot <= #req.slots)
        and (type(amountLeft) ~= "number" or amountLeft > 0)
    do -- for each retrieve chest slot
        local destItem = destinationPeriph.getItemDetail(destSlot)

        -- cboose an item
        if storagePointer == nil or storagePointer:getAmount() == 0 then
            storagePointer = nil
            local destInfo = destItem and state:getItemInfo(destItem, true)

            if destItem == nil then
                -- dest is air, find any item
                while true do
                    iItemID = iItemID + 1
                    if iItemID > #itemIDs then break end

                    itemID = itemIDs[iItemID]
                    -- choose item to retrieve
                    if nono then
                        storagePointer = state:nonoStoragePointer(itemID)
                    else
                        storagePointer = state:storagePointer(itemID)
                    end
                    amountInStorage = storagePointer:getAmount()
                    item = state:itemIDToItemInfo(itemID)

                    if amountLeft == 'stack' then
                        amountLeft = item.maxCount or 999 -- there are 0 left in storage
                    end

                    if amountInStorage > 0 then
                        break
                    end
                end
                if iItemID > #itemIDs then break end
            elseif util.arrayContains(itemIDs, destInfo.id) then
                -- dest is not air, continue filling it
                itemID = item.id
                if nono then
                    storagePointer = state:nonoStoragePointer(itemID)
                else
                    storagePointer = state:storagePointer(itemID)
                end
                item = destInfo

                if amountLeft == 'stack' then
                    amountLeft = item.maxCount or 999 -- there are 0 left in storage
                end
            end
        end

        local inDestinationSlot = 0
        if destItem ~= nil then
            inDestinationSlot = destItem.count
        end
        local canReceive = item and item.maxCount - inDestinationSlot

        local amountInStorage = storagePointer and storagePointer:getAmount()
        if storagePointer ~= nil and amountInStorage > 0 and canReceive > 0 then
            local wantTransfer = amountInStorage --[[@as number]]
            if type(amountLeft) == "number" then
                wantTransfer = math.min(amountLeft, amountInStorage)
            end
            local _, _, totalTransferedToSlot = storagePointer:retrieveItems(
                math.min(wantTransfer, item.maxCount, canReceive),
                req.destination, destSlot)
            balance[itemID] = (balance[itemID] or 0) - totalTransferedToSlot

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
            destSlot = req.slots[iDestSlot] or (destPeriphSize + 1)
        else
            destSlot = destSlot + 1
        end
    end

    if req.amountMustBeExact and amountLeft ~= 0 and amountLeft ~= 'all' then
        return totalTransfered, {
            request = ireq,
            reason = "not enough items in storage"
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
    local balance = {}
    local results
    if options.collectResults then
        results = {}
    end
    for ireq, req in ipairs(requests) do
        local transfered, error
        if req.type == 'storeItems' then
            transfered, error = transfers.handleStoreItemsRequest(state, ireq, req --[[@as StoreItemsRequest]],
                results, options.nono, options.acceptIDs, balance)
        elseif req.type == 'retrieveItems' then
            transfered, error = transfers.handleRetrieveItemRequest(state, ireq,
                req --[[@as RetrieveItemsRequest]], results,
                options.nono, options.acceptIDs, balance)
        end
        if error ~= nil then
            table.insert(errors, error)
        else
            totalTransfered = totalTransfered + transfered
        end
    end

    state.amountObservers:triggerTransaction(balance)

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

    local balance = {}

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
            options.nono, options.acceptIDs, balance)
    elseif req.type == 'retrieveItems' then
        transfered, error = transfers.handleRetrieveItemRequest(state, nil, req --[[@as RetrieveItemsRequest]],
            results, options.nono, options.acceptIDs, balance)
    end

    state.amountObservers:triggerTransaction(balance)

    if error == nil then
        return true, nil, transfered, results
    else
        return false, error
    end
end

return transfers
