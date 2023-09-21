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
local ObserverManager = {
    ---@type StorageState
    state = nil,
    ---@type { [number]: ObserverFunc[]? }
    observers = {}
}
storageState.ObserverManager = util.makeClass(ObserverManager)
function ObserverManager.new(state)
    return ObserverManager.construct {
        state = state,
    } --[[@as ObserverManager]]
end

---@alias ObserverFunc fun(state: StorageState, amountChange: number): boolean

---Func needs to return true to be kept alive
---@param func ObserverFunc
function ObserverManager:observe(itemIDs, func)
    for _, itemID in ipairs(itemIDs) do
        local observers = self.observers[itemID]
        if observers == nil then
            observers = {}
            self.observers[itemID] = observers
        end
        table.insert(observers, func)
    end
end

function ObserverManager:triggerObservers(itemID, amountChange)
    if amountChange == 0 then return end
    local observers = self.observers[itemID]
    if observers then
        util.arrayRemoveIf(observers, function (func)
            local continue = func(self.state, amountChange)
            return not continue
        end)
        if #observers == 0 then self.observers[itemID] = nil end
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
    storageChests = {},

    ---@type { name: string, id: number }[]
    tags = {},
    ---@type { [number]: number[] }
    tagIDToItemIDs = {},

    ---@type { name: string, id: number }[]
    craftMethods = {},

    ---[itemID]: [methodID, amount, inputs itemID/tagID...]
    ---tag ids are represented as negative
    ---@type { [number]: number[] }
    crafts = {},

    ---@type { name: string, nbt: string, id: number, maxCount: number }[]
    items = {},

    -- we optimize for four types of lookups:
    -- - find number of items / number of specific item id
    -- - retrive items from item id, get slotids back from least items to most
    -- - add items to storage, stacking them efficiently
    -- - find an empty slot

    ---@type { [number]: number[] }
    itemIDToSlots = {
        -- this works as a stack, when we retrieve, we pop from the back
        -- when we add items we push back
        --
        -- this means we have to sort these slots from most amount of items
        -- to least
        -- [itemID] = {slotID, slotID, slotID}
    },
    ---@type { [number]: number }
    itemIDToAmounts = {
        -- [itemID] = number of items
    },

    -- slotID[]
    -- should be poped/pushed from the back
    ---@type number[]
    emptySlots = {},

    ---@type CraftManager?
    craftManager = nil,

    isUp = false,

    ---@type ObserverManager
    observers = nil,

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
        itemIDToAmounts = {},
        emptySlots = {},
        craftManager = nil,
        isUp = false,
    } --[[@as StorageState]]
    state.observers = ObserverManager:new()
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

                local item = self:getItemInfo(detail, true, periph.getItemLimit(slot))
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

    -- sort items slots
    for _, slots in pairs(self.itemIDToSlots) do
        local amounts = {} -- [slotid]: number of items

        for _, slotID in ipairs(slots) do
            local chest, chestSlot = self:getStorageChestFromSlotID(slotID)
            local chestObj = peripheral.wrap(chest.name)
            amounts[slotID] = chestObj.getItemDetail(chestSlot).count
        end
        table.sort(slots, function(slotA, slotB)
            return amounts[slotB] < amounts[slotA]
        end)
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

---@class Paging
---@field skip number number of items to skip
---@field limit number number of items to return

function StorageState:pagedItemList()

end

---@class NonoPointer: Object
NonoPointer = {
    ---@type number
    itemID = nil,
    ---@type number
    amount = nil,
}
craft.NonoPointer = util.makeClass(NonoPointer)

---@return NonoPointer
function StorageState:nonoStoragePointer(itemID, amount)
    return StoragePointer.construct {
        itemID = itemID,
        amount = amount or self.itemIDToAmounts[itemID],
    } --[[@as NonoPointer]]
end

function NonoPointer:getAmount()
    return self.amount
end

function NonoPointer:storeItems(amount, _, _)
    self.amount = self.amount + amount
end

function NonoPointer:retrieveItems(amount, _, _)
    self.amount = self.amount - amount
end

---@class StoragePointer: Object
StoragePointer = {
    ---@type StorageState
    state = nil,
    ---@type number
    itemID = nil,
    ---@type number
    maxCount = nil,
    ---@type number
    firstNonStackI = nil,
}
craft.StoragePointer = util.makeClass(StoragePointer)

---@return StoragePointer
function StorageState:storagePointer(item)
    if type(item) == "number" then
        return StoragePointer.construct {
            itemID = item,
            maxCount = self:itemIDToItemInfo(item).maxCount,
            state = self,
        } --[[@as StoragePointer]]
    end
    return StoragePointer.construct {
        itemID = item.id,
        maxCount = item.maxCount,
        state = self,
    } --[[@as StoragePointer]]
end

function StoragePointer:getAmount()
    return self.state.itemIDToAmounts[self.itemID] or 0
end

---@private
function StoragePointer:initFirstNonStackI(slots)
    if self.firstNonStackI == nil then
        self.firstNonStackI = 1
        for index = #slots, 1, -1 do
            local slotID = slots[index]
            local chest, chestSlot = self.state:getStorageChestFromSlotID(slotID)
            local chestObj = peripheral.wrap(chest.name)
            local amount = chestObj.getItemDetail(chestSlot).count

            if amount >= self.maxCount then
                break
            end
            self.firstNonStackI = index
        end
    end
end

function StoragePointer:storeItems(amount, sourceName, sourceSlot)
    local slots = self.state.itemIDToSlots[self.itemID]
    if slots == nil then
        slots = {}
        self.state.itemIDToSlots[self.itemID] = slots
    end
    self:initFirstNonStackI(slots)

    -- optim: skip a pushItem when we need to store maxCount items
    -- for example, with slots being [64, 64, 13], (firstNonStackI = 3)
    -- we want to push a new stack of 64 ; instead of pushing it to the one
    -- with 13, and then rolling the rest over to a new slot,
    -- we push directly the 64 to a new slot, and insert that slot before the 13
    if self.maxCount == amount and #self.state.emptySlots > 0 then
        -- get a new slot
        local slotID = table.remove(self.state.emptySlots, #self.state.emptySlots)

        local chest, chestSlot = self.state:getStorageChestFromSlotID(slotID)
        local chestObj = peripheral.wrap(chest.name)

        chestObj.pullItems(sourceName, sourceSlot, self.maxCount, chestSlot)
        self.state.itemIDToAmounts[self.itemID] = (self.state.itemIDToAmounts[self.itemID] or 0) + self.maxCount

        table.insert(slots, self.firstNonStackI, slotID)
        self.firstNonStackI = self.firstNonStackI + 1

        return true, nil, self.maxCount
    end

    local totalTransfered = 0

    -- fill existing slots
    for i = self.firstNonStackI, #slots do
        if amount == totalTransfered then
            break
        end

        local slotID = slots[i]

        local chest, chestSlot = self.state:getStorageChestFromSlotID(slotID)
        local chestObj = peripheral.wrap(chest.name)
        local inSlotAmount = chestObj.getItemDetail(chestSlot).count

        local toTransfer = math.min(self.maxCount - inSlotAmount, amount - totalTransfered)
        totalTransfered = totalTransfered + toTransfer
        if inSlotAmount + toTransfer == self.maxCount then
            self.firstNonStackI = i + 1
        end
        chestObj.pullItems(sourceName, sourceSlot, toTransfer, chestSlot)
        self.state.itemIDToAmounts[self.itemID] = (self.state.itemIDToAmounts[self.itemID] or 0) + toTransfer
    end

    -- occupy empty slots!
    if totalTransfered < amount then
        for emptySlotI = #self.state.emptySlots, 1, -1 do
            if totalTransfered == amount then
                break
            end

            local slotID = table.remove(self.state.emptySlots, emptySlotI)

            local chest, chestSlot = self.state:getStorageChestFromSlotID(slotID)
            local chestObj = peripheral.wrap(chest.name)

            local toTransfer = math.min(self.maxCount, amount - totalTransfered)
            totalTransfered = totalTransfered + toTransfer

            chestObj.pullItems(sourceName, sourceSlot, toTransfer, chestSlot)
            self.state.itemIDToAmounts[self.itemID] = (self.state.itemIDToAmounts[self.itemID] or 0) + toTransfer

            table.insert(slots, slotID)
            if toTransfer == self.maxCount then
                self.firstNonStackI = #slots + 1
            end
        end
    end

    if totalTransfered < amount then
        return false, "not enough space in storage", totalTransfered
    end
    return true, nil, totalTransfered
end

function StoragePointer:retrieveItems(amount, destName, destSlot)
    local slots = self.state.itemIDToSlots[self.itemID]
    if slots == nil then
        slots = {}
        self.state.itemIDToSlots[self.itemID] = slots
    end

    local totalTransfered = 0

    -- as with store items, we implement an optim for maxCount
    if amount == self.maxCount then
        self:initFirstNonStackI(slots)

        if self.firstNonStackI > 1 then
            local slotID = table.remove(slots, self.firstNonStackI - 1)

            local chest, chestSlot = self.state:getStorageChestFromSlotID(slotID)
            local chestObj = peripheral.wrap(chest.name)

            chestObj.pushItems(destName, chestSlot, self.maxCount, destSlot)
            self.state.itemIDToAmounts[self.itemID] = (self.state.itemIDToAmounts[self.itemID] or 0) + self.maxCount

            table.insert(slots, self.firstNonStackI, slotID)
            self.firstNonStackI = self.firstNonStackI + 1

            return true, nil, self.maxCount
        end
    end

    -- traverse slots from end to begin
    for i = #slots, 1, -1 do
        if amount == totalTransfered then
            break
        end

        local slotID = slots[i]

        local chest, chestSlot = self.state:getStorageChestFromSlotID(slotID)
        local chestObj = peripheral.wrap(chest.name)
        local inSlotAmount = chestObj.getItemDetail(chestSlot).count

        local toTransfer = math.min(inSlotAmount, amount - totalTransfered)
        totalTransfered = totalTransfered + toTransfer
        chestObj.pushItems(destName, chestSlot, toTransfer, destSlot)
        self.state.itemIDToAmounts[self.itemID] = (self.state.itemIDToAmounts[self.itemID] or 0) - toTransfer
        if inSlotAmount == self.maxCount and self.firstNonStackI ~= nil then
            self.firstNonStackI = self.firstNonStackI - 1
        end
        if inSlotAmount - toTransfer == 0 then
            table.remove(slots, i)
            table.insert(self.state.emptySlots, slotID)
        end
    end

    if totalTransfered < amount then
        return false, "not enough items in storage", totalTransfered
    end
    return true, nil, totalTransfered
end

return storageState
