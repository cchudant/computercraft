local util = require(".firmware.apis.util")
local craft = require(".firmware.apis.storage.craft")

local storageState = {}

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

---@class ObserverManager: Object
local AmountsObserverManager = {
    ---@type StorageState
    state = nil,
    ---@type { [number]: ObserverFunc[]? }
    observers = {},
    ---@type GlobalObserverFunc[]
    globalObservers = {},
}
storageState.ObserverManager = util.makeClass(AmountsObserverManager)
function AmountsObserverManager.new(state)
    return AmountsObserverManager.construct {
        state = state,
    } --[[@as ObserverManager]]
end

---@alias ObserverFunc fun(state: StorageState, amountChange: number): boolean
---@alias GlobalObserverFunc fun(state: StorageState, balance: { [number]: number }): boolean

---Func needs to return true to be kept alive
---@param func ObserverFunc
function AmountsObserverManager:observe(itemIDs, func)
    for _, itemID in ipairs(itemIDs) do
        local observers = self.observers[itemID]
        if observers == nil then
            observers = {}
            self.observers[itemID] = observers
        end
        table.insert(observers, func)
    end
end

---Func needs to return true to be kept alive
---@param func GlobalObserverFunc
function AmountsObserverManager:observeGlobal(func)
    table.insert(self.globalObservers, func)
end

function AmountsObserverManager:triggerTransaction(balance)
    util.arrayRemoveIf(self.globalObservers, function(func)
        local continue = func(self.state, balance)
        return not continue
    end)
    for itemID, amountChange in pairs(balance) do
        if amountChange ~= 0 then
            local observers = self.observers[itemID]
            if observers then
                util.arrayRemoveIf(observers, function(func)
                    local continue = func(self.state, amountChange)
                    return not continue
                end)
                if #observers == 0 then self.observers[itemID] = nil end
            end
        end
    end
end

---@class StorageState: Object
local StorageState = {
    -- begin of storage state

    storageID = nil,

    ---@type number
    storageChestIDCounter = 1,
    ---@type number
    itemIDCounter = 1,
    ---@type number
    slotIDCounter = 1,
    ---@type number
    tagsIDCounter = 1,
    ---@type number
    craftMethodsIDCounter = 1,

    -- a chest takes up firstSlotId..(firstSlotId+size) slots
    ---@type { name: string, id: number, size: number, firstSlotId: number }[]
    storageChests = nil,

    ---@type { name: string, id: number }[]
    tags = nil,
    ---@type { [number]: number[] }
    tagIDToItemIDs = nil,

    ---@type { name: string, id: number }[]
    craftMethods = nil,

    ---[itemID]: [methodID, amount, inputs itemID/tagID...]
    ---tag ids are represented as negative
    ---@type { [number]: number[] }
    crafts = nil,

    ---@type { name: string, nbt: string, id: number, maxCount: number }[]
    items = nil,

    -- we optimize for four types of lookups:
    -- - find number of items / number of specific item id
    -- - retrive items from item id, get slotids back from least items to most
    -- - add items to storage, stacking them efficiently
    -- - find an empty slot

    -- this works as a stack, when we retrieve, we pop from the back
    -- when we add items we push back
    --
    -- this means we have to sort these slots from most amount of items
    -- to least
    -- [itemID] = {slotID, slotID, slotID}
    ---@type { [number]: number[] }
    itemIDToSlots = nil,
    ---@type { [number]: number }
    itemIDToSlotsFirstNonStackI = nil,
    ---@type { [number]: number } [itemID] => number of items
    itemIDToAmounts = nil,

    itemIDAmountsSorted = nil,

    -- slotID[]
    -- should be poped/pushed from the back
    ---@type number[]
    emptySlots = nil,

    ---@type CraftManager?
    craftManager = nil,

    ---@type ObserverManager
    amountObservers = nil,

    -- end storage state
}
storageState.StorageState = util.makeClass(StorageState)

function StorageState.new(storageID)
    local state = StorageState.construct {
        storageID = storageID,
        storageChestIDCounter = 1,
        itemIDCounter = 1,
        slotIDCounter = 1,
        tagsIDCounter = 1,
        craftMethodsIDCounter = 1,
        storageChests = {},
        tags = {},
        tagIDToItemIDs = {},
        craftMethods = {},
        crafts = {},
        items = {},
        itemIDToSlots = {},
        itemIDToSlotsILastStack = {},
        itemIDToAmounts = {},
        emptySlots = {},
        craftManager = nil,
    } --[[@as StorageState]]
    state.amountObservers = AmountsObserverManager:new()
    return state
end

-- function StorageState:

---@class CraftFile
---@field tagNames { [number]: string } { [tagID]: name }
---@field items { [number]: string } { [itemID]: name }
---@field tags { [number]: number[] } { [tagID]: itemID[] }
---@field crafts { [number]: number[] } { [itemID]: [methodID, amount, inputs itemID/tagID...] }
---@field methods { [number]: string } { [methodID]: name }
---@field maxCounts { [number]: number } { [itemID]: maxCount }

---@private
---@param settings Settings
---@param self StorageState
function StorageState:initFromCraftsFile(settings)
    ---@type CraftFile
    local craftFile = util.readJSON('/firmware/apis/storage/crafts.json')
    if craftFile == nil then error("craft list not found") end

    for tagID, name in pairs(craftFile.tagNames) do
        table.insert(self.tags, { id = tagID, name = name })
        self.tagsIDCounter = math.max(self.tagsIDCounter, tagID + 1)
    end
    for tagID, itemIDs in pairs(craftFile.tags) do
        self.tagIDToItemIDs[tagID] = itemIDs
    end
    for itemID, name in pairs(craftFile.items) do
        table.insert(self.items, { id = itemID, name = name })
        self.itemIDCounter = math.max(self.itemIDCounter, itemID + 1)
    end
    for methodID, name in pairs(craftFile.methods) do
        table.insert(self.craftMethods, { id = methodID, name = name })
        self.craftMethodsIDCounter = math.max(self.craftMethodsIDCounter, methodID + 1)
    end
    for itemID, craft in pairs(craftFile.crafts) do
        self.crafts[itemID] = craft
    end
    for itemID, maxCount in pairs(craftFile.maxCounts) do
        self:itemIDToItemInfo(itemID).maxCount = maxCount
    end
end

---@private
---@param self StorageState
function StorageState:resolveItemArgOne(finalItems, itemArg, nbt, acceptIDs, strict, addIt, addItMaxCount)
    local tag = false
    local item = nil

    if itemArg == 'minecraft:air' or itemArg == 0 then return end
    if not acceptIDs and type(itemArg) == "number" then
        return false, "item cannot be found"
    end

    if type(itemArg) == 'string' and itemArg:sub(1, 1) == '#' then
        tag = true
        local found = util.arrayFind(self.tags, function(tag)
            return tag.name == itemArg:sub(2)
        end)
        if found then item = found.id end
    elseif type(itemArg) == 'string' then
        local found = self:getItemInfo({ name = itemArg, nbt = nbt }, addIt, addItMaxCount)
        if found then item = found.id end
    elseif type(itemArg) == "table" and itemArg.name ~= nil then
        local found = self:getItemInfo({ name = itemArg.name, nbt = itemArg.nbt }, false)
        if found then item = found.id end
    elseif type(itemArg) == "table" and itemArg.tag ~= nil then
        tag = true
        local found = util.arrayFind(self.tags, function(tag)
            return tag.name == itemArg.tag:sub(2)
        end)
        if found then item = found.id end
    elseif type(itemArg) == "number" and acceptIDs then
        item = itemArg
    end

    if tag and item == nil then return false, "tag does not exist" end
    if item == nil then return false, "item cannot be found" end

    if item < 0 then
        tag = true
        item = -item
    end

    if tag then
        -- item is a tagID

        local ids = self.tagIDToItemIDs[item]
        for _, val in ipairs(ids) do
            local success, message = self:resolveItemArgOne(finalItems, val, nil, acceptIDs, strict, addIt, addItMaxCount)
            if strict and not success then
                return nil, message
            end
        end
    else
        table.insert(finalItems, item)
    end

    return true
end

---Tags are resolved recursively.
---@param itemArg ItemArg|number
---@param nbt string?
---@param acceptIDs boolean? true if itemArg may be numbers
---@param strict boolean? true to output errors
---@return number[]? itemIDs or nil when an error has occured
---@return string? error
---@overload fun(itemArg, nbt, acceptIDs, strict: false): number[]
function StorageState:resolveItemArg(itemArg, nbt, acceptIDs, strict, addIt, addItMaxCount)
    local finalItems = {}
    local success, message = self:resolveItemArgOne(finalItems, itemArg, nbt, acceptIDs, strict, addIt, addItMaxCount)
    if strict and not success then
        return nil, message
    end
    return util.arrayUnique(finalItems) -- remove duplicates
end

---Tags are resolved recursively.
---@param itemArgs (ItemArg|number)[]
---@param acceptIDs boolean? true if itemArg may be numbers
---@param strict boolean? true to output errors
---@return number[]? itemIDs or nil when an error has occured
---@return string? error
---@overload fun(itemArg, nbt, acceptIDs, strict: false): number[]
function StorageState:resolveItemArgs(itemArgs, acceptIDs, strict, addIt, addItMaxCount)
    local finalItems = {}
    for _, itemArg in ipairs(itemArgs) do
        local success, message = self:resolveItemArgOne(finalItems, itemArg, nil, acceptIDs, strict, addIt, addItMaxCount)
        if strict and not success then
            return nil, message
        end
    end
    return util.arrayUnique(finalItems) -- remove duplicates
end

function StorageState:itemIDToItemInfo(itemID)
    return util.arrayFind(self.items, function(item)
        return itemID == item.id
    end)
end

function StorageState:getStorageChestFromSlotID(slotID)
    for _, storChest in pairs(self.storageChests) do
        if slotID >= storChest.firstSlotId and
            slotID <= storChest.firstSlotId + storChest.size
        then
            return storChest, slotID - storChest.firstSlotId
        end
    end
end

function StorageState:initialStateSetup(settings)
    if settings.craft then
        self:initFromCraftsFile(settings)

        -- fill up crafters
        local crafters = {}
        for _, c in ipairs(settings.crafters) do
            local crafter = craft.CraftingCraftProcessor.new(c.computerID, c.inventory)
            local methodID = util.arrayFind(self.craftMethods, function(method)
                return method.name == "crafting"
            end).id
            crafters[methodID] = crafters[methodID] or {}
            table.insert(crafters[methodID], crafter)
        end


        self.craftManager = craft.CraftManager.new(crafters)
    end

    -- fill up storageChests
    for _, name in ipairs(settings.storageChests) do
        local p = peripheral.wrap(name)
        table.insert(self.storageChests, {
            name = name,
            id = self.storageChestIDCounter,
            firstSlotId = self.slotIDCounter,
            size = p.size()
        })
        self.storageChestIDCounter = self.storageChestIDCounter + 1
        self.slotIDCounter = self.slotIDCounter + p.size()
    end

    -- fill up items
    for _, v in ipairs(self.storageChests) do
        local periph = peripheral.wrap(v.name)
        local list = periph.list()
        for slot = 1, v.size do
            local detail = list[slot]
            local slotIndex = v.firstSlotId + slot

            if detail ~= nil then
                -- get/create item id

                local item = self:getItemInfo(detail, true, periph.getItemDetail(slot).maxCount)
                local itemID = item.id

                -- update itemIDToSlots and itemIDToAmounts

                local slots = self.itemIDToSlots[itemID] or {}
                table.insert(slots, slotIndex)
                self.itemIDToSlots[itemID] = slots

                self.itemIDToAmounts[itemID] = (self.itemIDToAmounts[itemID] or 0) + detail.count
            else
                -- free slot
                table.insert(self.emptySlots, slotIndex)
            end
        end
    end

    self.itemIDAmountsSorted = util.objectEntries(self.itemIDToAmounts)
    table.sort(self.itemIDAmountsSorted, function(a, b)
        return b[2] < a[2]
    end)

    -- sort items slots
    for itemID, slots in pairs(self.itemIDToSlots) do
        local amounts = {} -- [slotid]: number of items

        for _, slotID in ipairs(slots) do
            local chest, chestSlot = self:getStorageChestFromSlotID(slotID)
            local chestObj = peripheral.wrap(chest.name)
            amounts[slotID] = chestObj.getItemDetail(chestSlot).count
        end
        table.sort(slots, function(slotA, slotB)
            return amounts[slotB] < amounts[slotA]
        end)

        local firstNonStackI = 1
        for index = #slots, 1, -1 do
            local slotID = slots[index]
            local chest, chestSlot = self:getStorageChestFromSlotID(slotID)
            local chestObj = peripheral.wrap(chest.name)
            local obj = chestObj.getItemDetail(chestSlot)

            if obj ~= nil and obj.count >= self:getItemInfo(obj, false).maxCount then
                break
            end
            firstNonStackI = index
        end

        self.itemIDToSlotsFirstNonStackI[itemID] = firstNonStackI
    end
end

function StorageState:getItemInfo(detail, addIt, maxCount)
    -- find the item id
    local item = util.arrayFind(self.items, function(obj)
        return obj.name == detail.name and
            obj.nbt == obj.nbt
    end)

    if item ~= nil and addIt and (detail.maxCount or maxCount) ~= nil then
        item.maxCount = detail.maxCount or maxCount
    end

    if addIt and item == nil then
        -- new item id
        item = {
            name = detail.name,
            nbt = detail.nbt,
            id = self.itemIDCounter,
            maxCount = detail.maxCount or maxCount,
        }
        table.insert(self.items, item)
        self.itemIDCounter = self.itemIDCounter + 1
    end

    return item
end

function StorageState:itemsReqAsArray(req)
    if req.name ~= nil then
        local item = util.arrayFind(self.items, function(obj)
            return obj.name == req.name and
                not (req.nbt ~= nil and obj.nbt == req.nbt)
        end)
        return { item }
    elseif req.items ~= nil then
        local arr = {}
        for i, item in ipairs(req.items) do
            local found = util.arrayFind(self.items, function(obj)
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

function StorageState:openNonStorage(periph)
    if util.arrayAny(self.storageChests, function(c)
            return c.name == periph
        end)
    then
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

function StorageState:updateAmount(itemID, newAmount)
    local function compare(a, b) return b[2] < a[2] end
    local function equal(a, b) return a[1] == b[1] end
    local entry = { itemID, self.itemIDToAmounts[itemID] }
    if entry[2] ~= nil then
        util.sortedRemove(self.itemIDAmountsSorted, { itemID, self.itemIDToAmounts[itemID] }, compare, equal)
    end
    self.itemIDToAmounts[itemID] = newAmount
    if newAmount > 0 then
        entry[2] = newAmount
        util.sortedInsert(self.itemIDAmountsSorted, entry, compare)
    end
end

function StorageState:getAmount(itemID)
    return self.itemIDToAmounts[itemID] or 0
end

function StorageState:storeItems(itemID, amount, sourceName, sourceSlot, maxCount)
    local slots = self.itemIDToSlots[itemID]
    if slots == nil then
        slots = {}
        self.itemIDToSlots[itemID] = slots
    end

    if maxCount == nil then maxCount = self:itemIDToItemInfo(itemID).maxCount end

    -- optim: skip a pushItem when we need to store maxCount items
    -- for example, with slots being [64, 64, 13], (firstNonStackI = 3)
    -- we want to push a new stack of 64 ; instead of pushing it to the one
    -- with 13, and then rolling the rest over to a new slot,
    -- we push directly the 64 to a new slot, and insert that slot before the 13
    if maxCount == amount and #self.emptySlots > 0 then
        -- get a new slot
        local slotID = table.remove(self.emptySlots, #self.emptySlots)

        local chest, chestSlot = self:getStorageChestFromSlotID(slotID)
        local chestObj = peripheral.wrap(chest.name)

        chestObj.pullItems(sourceName, sourceSlot, maxCount, chestSlot)
        self:updateAmount(itemID, (self.itemIDToAmounts[itemID] or 0) + maxCount)

        local firstNonStackI = self.itemIDToSlotsFirstNonStackI[itemID]
        table.insert(slots, firstNonStackI, slotID)
        self.itemIDToSlotsFirstNonStackI[itemID] = firstNonStackI + 1

        return true, nil, maxCount
    end

    local totalTransfered = 0

    -- fill existing slots
    local firstNonStackI = self.itemIDToSlotsFirstNonStackI[itemID]
    for i = firstNonStackI, #slots do
        if amount == totalTransfered then
            break
        end

        local slotID = slots[i]

        local chest, chestSlot = self:getStorageChestFromSlotID(slotID)
        local chestObj = peripheral.wrap(chest.name)
        local inSlotAmount = chestObj.getItemDetail(chestSlot).count

        local toTransfer = math.min(maxCount - inSlotAmount, amount - totalTransfered)
        totalTransfered = totalTransfered + toTransfer
        if inSlotAmount + toTransfer == maxCount then
            firstNonStackI = i + 1
        end
        chestObj.pullItems(sourceName, sourceSlot, toTransfer, chestSlot)
        self:updateAmount(itemID, (self.itemIDToAmounts[itemID] or 0) + toTransfer)
    end

    -- occupy empty slots!
    if totalTransfered < amount then
        for emptySlotI = #self.emptySlots, 1, -1 do
            if totalTransfered == amount then
                break
            end

            local slotID = table.remove(self.emptySlots, emptySlotI)

            local chest, chestSlot = self:getStorageChestFromSlotID(slotID)
            local chestObj = peripheral.wrap(chest.name)

            local toTransfer = math.min(maxCount, amount - totalTransfered)
            totalTransfered = totalTransfered + toTransfer

            chestObj.pullItems(sourceName, sourceSlot, toTransfer, chestSlot)
            self:updateAmount(itemID, (self.itemIDToAmounts[itemID] or 0) + toTransfer)

            table.insert(slots, slotID)
            if toTransfer == maxCount then
                firstNonStackI = #slots + 1
            end
        end
    end

    self.itemIDToSlotsFirstNonStackI[itemID] = firstNonStackI

    if totalTransfered < amount then
        return false, "not enough space in storage", totalTransfered
    end
    return true, nil, totalTransfered
end

function StorageState:retrieveItems(itemID, amount, destName, destSlot, maxCount)
    local slots = self.itemIDToSlots[itemID]
    if slots == nil then
        slots = {}
        self.itemIDToSlots[itemID] = slots
    end

    local totalTransfered = 0
    local firstNonStackI = self.itemIDToSlotsFirstNonStackI[itemID]

    -- as with store items, we implement an optim for maxCount
    if amount == maxCount then

        if firstNonStackI > 1 then
            local slotID = table.remove(slots, firstNonStackI - 1)

            local chest, chestSlot = self:getStorageChestFromSlotID(slotID)
            local chestObj = peripheral.wrap(chest.name)

            chestObj.pushItems(destName, chestSlot, maxCount, destSlot)
            self:updateAmount(itemID, (self.itemIDToAmounts[itemID] or 0) + maxCount)

            table.insert(slots, firstNonStackI, slotID)
            self.itemIDToSlotsFirstNonStackI[itemID] = firstNonStackI + 1

            return true, nil, maxCount
        end
    end

    -- traverse slots from end to begin
    for i = #slots, 1, -1 do
        if amount == totalTransfered then
            break
        end

        local slotID = slots[i]

        local chest, chestSlot = self:getStorageChestFromSlotID(slotID)
        local chestObj = peripheral.wrap(chest.name)
        local inSlotAmount = chestObj.getItemDetail(chestSlot).count

        local toTransfer = math.min(inSlotAmount, amount - totalTransfered)
        totalTransfered = totalTransfered + toTransfer
        chestObj.pushItems(destName, chestSlot, toTransfer, destSlot)
        self:updateAmount(itemID, (self.itemIDToAmounts[itemID] or 0) - toTransfer)
        if inSlotAmount == maxCount and firstNonStackI ~= nil then
            firstNonStackI = firstNonStackI - 1
        end
        if inSlotAmount - toTransfer == 0 then
            table.remove(slots, i)
            table.insert(self.emptySlots, slotID)
        end
    end

    self.itemIDToSlotsFirstNonStackI[itemID] = firstNonStackI + 1

    if totalTransfered < amount then
        return false, "not enough items in storage", totalTransfered
    end
    return true, nil, totalTransfered
end

return storageState
