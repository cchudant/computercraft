local control = require(".firmware.apis.control")
local util = require(".firmware.apis.util")
local storageState = require(".firmware.apis.storage.state")
local storageTransfers = require(".firmware.apis.storage.transfers")
local storageCraft = require(".firmware.apis.storage.craft")

local storage = {}

local protocolString = "Storage"

---StorageConnection has higher level methods than driver for clients
---@param connection control.Connection<StorageServer>
---@return StorageConnection
local function wrapConnection(connection)
    ---@class StorageConnection: control.Connection<StorageServer>
    local storageConnection = setmetatable({}, { __index = connection })

    ---@param func fun(value: any)
    function storageConnection.listTopItems(fuzzySearch, limit, func)
        -- get initial value & sub to the topic
        storageConnection.subscribeEvent("amountsUpdate")
        while true do
            local value = storageConnection.getTopItems(fuzzySearch, limit)
            func(value)
            storageConnection.pullEvent("amountsUpdate")
        end
    end

    return storageConnection
end

---@class Settings
---@field craft boolean?
---@field crafters { inventory: string, computerID: number }[]
---@field storageChests string[] network ids

---Create a storage driver, which is in charge of the actual moving and driving
---@param settings Settings
---@return fun() startServer
---@return StorageServer storageServer the sync server
---@return fun(): StorageConnection getLocalConnection
function storage.newStorageServer(settings, serverID)
    ---@class StorageServer
    ---@field server control.Server
    local storageServer = {}

    local state = storageState.StorageState:new()

    function storageServer.getID(clientID)
        return serverID
    end

    function storageServer.getComputerID(clientID)
        return os.getComputerID()
    end

    ---@alias ItemArg string | { name: string?, nbt: string?, tag: string? }
    ---Format: "minecraft:dirt" is an item, "#minecraft:logs" is a tag
    ---NBT must be exact. When nil, it will only match with items that have no NBT.

    ---Get an item amount
    ---@param name ItemArg
    ---@param nbt string?
    ---@return number
    function storageServer.getItemAmount(clientID, name, nbt)
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
    function storageServer.getItemsAmount(clientID, args)
        local itemIDs = state:resolveItemArgs(args, false, false)
        ---@cast itemIDs number[]

        local total = 0
        for _, itemID in ipairs(itemIDs) do
            total = total + (state.itemIDToAmounts[itemID] or 0)
        end
        return total
    end

    function storageServer.getItemDetails(clientID, name, nbt)
        local itemIDs = state:resolveItemArg(name, nbt, false, false)
        ---@cast itemIDs number[]

        if #itemIDs ~= 1 then
            return nil
        end

        local total = state.itemIDToAmounts[itemIDs[1]] or 0
        local info = state:itemIDToItemInfo(itemIDs[1])
        return {
            name = info.name,
            nbt = info.nbt,
            count = total,
            maxCount = info.maxCount,
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
    function storageServer.batchTransfer(clientID, requests, options)
        options = options or {}
        options.acceptIDs = false
        return storageTransfers.batchTransfer(state, requests, options)
    end

    ---@param req StoreItemsRequest|RetrieveItemsRequest
    ---@param options { allOrNothing: boolean?, nono: boolean?, collectResults: boolean? }?
    ---@return boolean success
    ---@return TransferError? error
    ---@return number? totalItemsTransfered
    ---@return TransferResult[]? results
    function storageServer.transfer(clientID, req, options)
        options = options or {}
        options.acceptIDs = false
        return storageTransfers.transfer(state, req, options)
    end

    ---@param itemArg any
    ---@param amount any
    ---@return boolean success
    ---@return { [string]: number }? missing
    ---@return { [string]: number }? consumed
    function storageServer.craftItem(clientID, itemArg, amount)
        local steps, missing, consumed = storageCraft.craftLookup(state, itemArg, amount)

        local function idToName(itemID)
            if itemID < 0 then
                return "#" .. util.arrayFind(state.tags, function(t)
                    return t.id == -itemID
                end).name
            else
                return util.arrayFind(state.items, function(i)
                    return i.id == itemID
                end).name
            end
        end
        local function converIdsToName(arr)
            return util.objectMap(arr, function(k, v) return idToName(k), v end)
        end

        if missing then
            return false, converIdsToName(missing)
        end

        ---@cast steps Steps
        state.craftManager:runCraft(steps)

        return true, converIdsToName(consumed)
    end

    function storageServer.craftLookup(clientID, itemArg, count, consumed)
        return storageCraft.craftLookup(state, itemArg, count, consumed)
    end

    local function stripped(s)
        return string.gsub(
        string.gsub(string.gsub(string.lower(string.gsub(s, '_', ' ')), 'minecraft:', ''), 'computercraft:', ''),
            'chunkloaders:', '')
    end

    function storageServer.getTopItems(clientID, fuzzySearch, limit)
        local ret = {}
        local i = 1
        while (not limit or #ret < limit) and i < #state.itemIDAmountsSorted do
            local tuple = state.itemIDAmountsSorted[i]
            local item = state:itemIDToItemInfo(tuple[1])
            local strippedItem = stripped(item.name)
            if util.stringStartsWith(strippedItem, stripped(fuzzySearch)) then
                table.insert(ret, { displayName = strippedItem, name = item.name, count = tuple[2] })
            end
            i = i + 1
        end
        return ret
    end

    state:initialStateSetup(settings)

    local startNetwork, server, getServerConnection = control.makeServer(storageServer, protocolString, serverID)
    storageServer.server = server

    state.amountObservers:observeGlobal(function()
        server.triggerEvent("amountsUpdate")
        return true
    end)

    local function startServer()
        startNetwork(
            function(_) -- run craft manager if present
                if storageState.craftManager then
                    storageState.craftManager:run(storageState)
                end
            end
        )
    end

    local function getLocalConnection()
        return wrapConnection(getServerConnection())
    end

    return startServer, storageServer, getLocalConnection, state
end

---@return StorageConnection
function storage.localConnect(serverID)
    return wrapConnection(control.localConnect(protocolString, serverID))
end

---@return StorageConnection
function storage.remoteConnect(computerID, serverID)
    return wrapConnection(control.remoteConnect(protocolString, computerID, serverID))
end

return storage
