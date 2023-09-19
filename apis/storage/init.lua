local control = require("apis.control")
local util = require("apis.util")
local storageState = require("apis.storage.state")
local storageTransfers = require("apis.storage.transfers")
local storageCraft = require("apis.storage.craft")

local storage = {}

---@class Settings
---@field craft boolean?
---@field crafters { inventory: string, computerID: number }[]
---@field storageChests string[] network ids

---StorageConnection has higher level methods than driver
---@param storageDriver StorageDriver
---@return StorageConnection
function storage.makeConnection(storageDriver)
    ---@class StorageConnection: StorageDriver
    local storageConnection = setmetatable({}, { __index = storageDriver })

    -- function 

    return storageConnection
end

---Create a storage driver, which is in charge of the actual moving and driving
---@param settings Settings
---@return StorageDriver storageServer the sync server
function storage.newStorageDriver(settings, serverID)
    ---@class StorageDriver
    local storageDriver = {}

    local state = storageState.StorageState:new()

    function storageDriver.getID()
        return serverID
    end

    ---@alias ItemArg string | { name: string?, nbt: string?, tag: string? }
    ---Format: "minecraft:dirt" is an item, "#minecraft:logs" is a tag
    ---NBT must be exact. When nil, it will only match with items that have no NBT.

    ---Get an item amount
    ---@param name ItemArg
    ---@param nbt string?
    ---@return number
    function storageDriver.getItemAmount(name, nbt)
        local itemIDs = state:resolveItemArg(name, nbt, false, false)
        ---@cast itemIDs number[]

        local total = 0
        for _, itemID in ipairs(itemIDs) do
            total = total + (state.itemIDToAmounts[itemID] or 0)
        end
        return total
    end

    ---Get the total amount of items
    ---@param args ItemArg[]
    ---@return number
    function storageDriver.getItemsAmount(args)
        local itemIDs = state:resolveItemArgs(args, false, false)
        ---@cast itemIDs number[]

        local total = 0
        for _, itemID in ipairs(itemIDs) do
            total = total + (state.itemIDToAmounts[itemID] or 0)
        end
        return total
    end

    function storageDriver.getItemDetails(name, nbt)
        local itemIDs = state:resolveItemArg(name, nbt, false, false)
        ---@cast itemIDs number[]

        if #itemIDs ~= 1 then
            return nil
        end

        local total = state.itemIDToAmounts[itemIDs[1]] or 0
        local info = state:itemIDToItemInfo(itemIDs[1])
        return {
            name = info.name, nbt = info.nbt,
            count = total, maxCount = info.maxCount,
        }
    end 

    ---@alias TransferError { request: number, reason: string }

    ---@class RetrieveItemsRequest
    ---@field type 'retrieveItems'
    ---@field destination string
    ---@field slots number[]?
    ---@field items ItemArg[]?
    ---@field name string? item like 'minecraft:dirt'. '#minecraft:logs' is a tag
    ---@field nbt string? must match exact nbt
    ---@field tag string? tag without '#' prefix
    ---@field amount number|'stack'|'all'?
    ---@field amountMustBeExact boolean?

    ---@class StoreItemsRequest
    ---@field type 'storeItems'
    ---@field source string
    ---@field slots number[]?
    ---@field items ItemArg[]?
    ---@field name string? item like 'minecraft:dirt'. '#minecraft:logs' is a tag
    ---@field nbt string? must match exact nbt
    ---@field tag string? tag without '#' prefix
    ---@field amount number|'slot'|'all'?
    ---@field amountMustBeExact boolean?

    ---@class TransferResult collectResults must be true for results to be outputed
    ---@field request number
    ---@field name string
    ---@field nbt string?
    ---@field tag string?
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
    function storageDriver.batchTransfer(requests, options)
        options.acceptIDs = false
        storageTransfers.batchTransfer(state, requests, options)
    end

    ---@param req StoreItemsRequest|RetrieveItemsRequest
    ---@param options { allOrNothing: boolean?, nono: boolean?, collectResults: boolean? }?
    ---@return boolean success
    ---@return TransferError? error
    ---@return number? totalItemsTransfered
    ---@return TransferResult[]? results
    function storageDriver.transfer(req, options)
        options.acceptIDs = false
        storageTransfers.transfer(state, req, options)
    end

    ---comment
    ---@param itemArg any
    ---@param amount any
    ---@return boolean success
    ---@return { [string]: number }? missing
    ---@return { [string]: number }? consumed
    function storageDriver.craftItem(itemArg, amount)
        local steps, missing, consumed = storageCraft.craftLookup(state, itemArg, amount)

        local function converIdsToName(arr)
            return util.objectMap(arr, function(k, v)
                if k < 0 then
                    return "#" .. util.arrayFind(state.tags, function(t)
                        return t.id == -k
                    end).name, v
                else
                    return util.arrayFind(state.items, function(i)
                        return i.id == k
                    end).name, v
                end
            end)
        end

        if missing then
            return false, converIdsToName(missing)
        end

        ---@cast steps Steps
        state.craftManager:runCraft(steps)

        return true, converIdsToName(consumed)
    end

    function storageDriver.craftLookup(itemArg, count, consumed)
        return storageCraft.craftLookup(state, itemArg, count, consumed)
    end

    state.initialStateSetup(settings)
    return storageDriver, state
end

local storageDriverKeys = {
    "transfer", "batchTransfer", "getID", "craftItem"
}

---@param storageID number?
---@return StorageConnection
function storage.localConnect(storageID)
    local driver = {}
    for _, k in ipairs(storageDriverKeys) do
        driver[k] = function(...)
            local nonce = util.newNonce()
            os.queueEvent("storage:" .. (storageID or ""), {
                storageUniqueID = storageID,
                method = k,
                args = {...},
            }, nonce)
            while true do
                local _, args, nonce_ = os.pullEvent("storage:"  .. (storageID or "") .. "Rep")
                if nonce_ == nonce then
                    return args
                end
            end
        end
    end
    return storage.makeConnection(driver)
end

---@param computerID number
---@param storageID number?
---@return StorageConnection
function storage.remoteConnect(computerID, storageID)

    local driver = {}
    for _, k in ipairs(storageDriverKeys) do
        driver[k] = function(...)
            return control.sendRoundtrip(computerID, "storage:" .. (storageID or ""), {
                storageUniqueID = storageID,
                method = k,
                args = {...},
            })
        end
    end
    return storage.makeConnection(driver)
end

---@param storageID number?
---@param settings Settings
---@return fun() startStorageServer function to start the server
---@return fun(): StorageConnection storageConnection make a local connection
function storage.storageServer(settings, storageID)
    local storageDriver, storageState = storage.newStorageDriver(settings, storageID)

    local function start()
        local function handleRpc(addTask, args, answer)
            addTask(function()
                if args.storageUniqueID == storageDriver.getID() then
                    local ret = { storageDriver[args.method](table.unpack(args.args)) }
                    answer(ret)
                end
            end)
        end
        util.parallelGroup(
            function(addTask) -- network requests
                while true do
                    local args, _, sender, nonce = control.protocolReceive("storage")
                    handleRpc(addTask, args, function(ret)
                        control.protocolSend(sender --[[@as number]], "storageRep", ret, nonce)
                    end)
                end
            end,
            function(addTask) -- local requests
                while true do
                    local _, args, nonce = os.pullEvent("storage:" .. (storageID or ""))
                    handleRpc(addTask, args, function(ret)
                        os.queueEvent("storage:" .. (storageID or "") .. "Rep", ret, nonce)
                    end)
                end
            end,
            function(_) -- run craft manager if present
                if storageState.craftManager then
                    storageState.craftManager:run(storageState)
                end
            end,
            function(_) -- set up
                storageState.isUp = true
                os.queueEvent("storage:up:"  .. (storageID or ""))
            end
        )
    end

    local function makeLocalConnection()
        if not storageState.isUp then
            os.pullEvent("storage:up:"  .. (storageID or ""))
        end
        return storage.localConnect(storageDriver.getID())
    end

    return start, makeLocalConnection
end

return storage
