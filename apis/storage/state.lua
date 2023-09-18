local util = require("util")
local craft = require("storage.craft")

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

---@return StorageState
function storageState.makeStorageDriverState()
    ---@class StorageState
    local state = {
        -- begin of storage state

        storageChestIDCounter = 1,
        itemIDCounter = 1,
        slotIDCounter = 1,
        tagsIDCounter = 1,
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

        -- end storage state
    }
    ---@class CraftFile
    ---@field tagNames { [number]: string } { [tagID]: name }
    ---@field items { [number]: string } { [itemID]: name }
    ---@field tags { [number]: number[] } { [tagID]: itemID[] }
    ---@field crafts { [number]: number[] } { [itemID]: [methodID, amount, inputs itemID/tagID...] }
    ---@field methods { [number]: string } { [methodID]: name }
    ---@field maxCounts { [number]: number } { [itemID]: maxCount }

    ---@param settings
    local function initFromCraftsFile(settings)
        ---@type CraftFile
        local craftFile = util.readJSON('/firmware/apis/storage/crafts.json')
        if craftFile == nil then error("craft list not found") end

        for tagID, name in pairs(craftFile.tagNames) do
            table.insert(state.tags, { id = tagID, name = name })
            state.tagsIDCounter = math.max(state.tagsIDCounter, tagID + 1)
        end
        for tagID, itemIDs in pairs(craftFile.tags) do
            state.tagIDToItemIDs[tagID] = itemIDs
        end
        for itemID, name in pairs(craftFile.items) do
            table.insert(state.items, { id = itemID, name = name })
            state.itemIDCounter = math.max(state.itemIDCounter, itemID + 1)
        end
        for methodID, name in pairs(craftFile.methods) do
            table.insert(state.craftMethods, { id = methodID, name = name })
            state.craftMethodsIDCounter = math.max(state.craftMethodsIDCounter, methodID + 1)
        end
        for itemID, craft in pairs(craftFile.crafts) do
            state.crafts[itemID] = craft
        end
        for itemID, maxCount in pairs(craftFile.maxCounts) do
            state.itemIDToItemInfo(itemID).maxCount = maxCount
        end
    end

    local function resolveItemArgOne(finalItems, itemArg, nbt, acceptIDs, strict, addIt, addItMaxCount)
        local tag = false
        local item = nil

        if itemArg == 'minecraft:air' or itemArg == 0 then return end
        if not acceptIDs and type(itemArg) == "number" then
            return false, "item cannot be found"
        end

        if type(itemArg) == 'string' and itemArg:sub(1, 1) == '#' then
            tag = true
            local found = util.arrayFind(state.tags, function(tag)
                return tag.name == itemArg:sub(2)
            end)
            if found then item = found.id end
        elseif type(itemArg) == 'string' then
            local found = state.getItemInfo({ name = itemArg, nbt = nbt }, addIt, addItMaxCount)
            if found then item = found.id end
        elseif type(itemArg) == "table" and itemArg.name ~= nil then
            local found = state.getItemInfo({ name = itemArg.name, nbt = itemArg.nbt }, false)
            if found then item = found.id end
        elseif type(itemArg) == "table" and itemArg.tag ~= nil then
            tag = true
            local found = util.arrayFind(state.tags, function(tag)
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

            local ids = state.tagIDToItemIDs[item]
            for _, val in ipairs(ids) do
                local success, message = resolveItemArgOne(finalItems, val, nil, acceptIDs, strict, addIt, addItMaxCount)
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
    function state.resolveItemArg(itemArg, nbt, acceptIDs, strict, addIt, addItMaxCount)
        local finalItems = {}
        local success, message = resolveItemArgOne(finalItems, itemArg, nbt, acceptIDs, strict, addIt, addItMaxCount)
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
    function state.resolveItemArgs(itemArgs, acceptIDs, strict, addIt, addItMaxCount)
        local finalItems = {}
        for _, itemArg in ipairs(itemArgs) do
            local success, message = resolveItemArgOne(finalItems, itemArg, nil, acceptIDs, strict, addIt, addItMaxCount)
            if strict and not success then
                return nil, message
            end
        end
        return util.arrayUnique(finalItems) -- remove duplicates
    end

    function state.itemIDToItemInfo(itemID)
        return util.arrayFind(state.items, function(item)
            return itemID == item.id
        end)
    end

    function state.getStorageChestFromSlotID(slotID)
        for _, storChest in pairs(state.storageChests) do
            if slotID >= storChest.firstSlotId and
                slotID <= storChest.firstSlotId + storChest.size
            then
                return storChest, slotID - storChest.firstSlotId
            end
        end
    end

    function state.initialStateSetup(settings)
        -- fill up storageChests
        for _, name in ipairs(settings.storageChests) do
            local p = peripheral.wrap(name)
            table.insert(state.storageChests, {
                name = name,
                id = state.storageChestIDCounter,
                firstSlotId = state.slotIDCounter,
                size = p.size()
            })
            state.storageChestIDCounter = state.storageChestIDCounter + 1
            state.slotIDCounter = state.slotIDCounter + p.size()
        end

        -- fill up items
        for _, v in ipairs(state.storageChests) do
            local periph = peripheral.wrap(v.name)
            local list = periph.list()
            for slot = 1, v.size do
                local detail = list[slot]
                local slotIndex = v.firstSlotId + slot

                if detail ~= nil then
                    -- get/create item id

                    local item = state.getItemInfo(detail, true, periph.getItemLimit(slot))
                    local itemID = item.id

                    print("ItemID ", itemID)

                    -- update itemIDToSlots and itemIDToAmounts

                    local slots = state.itemIDToSlots[itemID] or {}
                    table.insert(slots, slotIndex)
                    state.itemIDToSlots[itemID] = slots

                    state.itemIDToAmounts[itemID] = (state.itemIDToAmounts[itemID] or 0) + detail.count
                else
                    -- free slot
                    table.insert(state.emptySlots, slotIndex)
                end
            end
        end

        -- sort items slots
        for _, slots in pairs(state.itemIDToSlots) do
            local amounts = {} -- [slotid]: number of items

            for _, slotID in ipairs(slots) do
                local chest, chestSlot = state.getStorageChestFromSlotID(slotID)
                local chestObj = peripheral.wrap(chest.name)
                amounts[slotID] = chestObj.getItemDetail(chestSlot).count
            end
            table.sort(slots, function(slotA, slotB)
                return amounts[slotB] < amounts[slotA]
            end)
        end

        if settings.craft then
            initFromCraftsFile(settings)

            -- fill up crafters
            local crafters = {}
            for _, c in ipairs(settings.crafters) do
                local crafter = craft.craftingTurtleProcessor(c.computerid, c.inventory)
                local methodID = util.arrayFind(state.craftMethods, function(method)
                    return method.name == "crafting"
                end)
                crafters[methodID] = crafters[methodID] or {}
                table.insert(crafters[methodID], crafter)
            end

            state.craftManager = craft.makeManager(crafters)
        end
    end

    function state.getItemInfo(detail, addIt, maxCount)
        -- find the item id
        local item = util.arrayFind(state.items, function(obj)
            return obj.name == detail.name and
                obj.nbt == obj.nbt
        end)

        if item ~= nil and addIt and (detail.maxCount or maxCount) ~= nil then
            item.maxCount = detail.maxCount or maxCount
        end

        print("Get info", detail.name)

        if addIt and item == nil then
            -- new item id
            item = {
                name = detail.name,
                nbt = detail.nbt,
                id = state.itemIDCounter,
                maxCount = detail.maxCount or maxCount,
            }
            table.insert(state.items, item)
            state.itemIDCounter = state.itemIDCounter + 1
        end

        return item
    end

    function state.itemsReqAsArray(req)
        if req.name ~= nil then
            local item = util.arrayFind(state.items, function(obj)
                return obj.name == req.name and
                    not (req.nbt ~= nil and obj.nbt == req.nbt)
            end)
            return { item }
        elseif req.items ~= nil then
            local arr = {}
            for i, item in ipairs(req.items) do
                local found = util.arrayFind(state.items, function(obj)
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

    function state.openNonStorage(periph)
        if util.arrayAny(state.storageChests, function(c)
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

    function state.pagedItemList()

    end

    return state
end

return storageState
