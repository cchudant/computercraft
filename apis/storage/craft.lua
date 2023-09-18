local util = require("util")
local controlApi = require("controlApi")
local transfers = require("storage.transfers")

local craft = {}

---@class Step
---@field method number
---@field inputAmount number
---@field produced number
---@field crafts { inputAmount: number, inputs: number[] }[]
---@field depth number

---@alias Steps { [number]: Step }

function craft.craftingTurtleTask()
    print("Serving crafting requests")
    local craftSlots = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }
    while true do
        local craft, _, sender, nonce = controlApi.protocolReceive("storage:craft", nil, nil, nil)
        ---@cast craft { inputAmount: number, inputs: number[] }

        for inputI, i in ipairs(craftSlots) do
            if craft.inputs[inputI] ~= 0 then
                turtle.select(i)
                turtle.suck(craft.inputAmount)
            end
        end

        turtle.select(15)
        while turtle.craft() do
            turtle.drop(64)
        end

        for i = 1, 15 do
            if turtle.getItemCount(i) > 0 then
                turtle.select(i)
                turtle.drop()
            end
        end

        print("Done one request")
        controlApi.protocolSend(sender, "storage:craftRep", nil, nonce)
    end
end

---@return CraftProcessor
function craft.craftingTurtleProcessor(turtleid, chestName)
    ---@class CraftProcessor
    local processor = { }

    ---@param craft { inputAmount: number, inputs: number[] }
    ---@param storageState StorageState
    function processor.craft(craft, storageState)
        for shapeI, slot in ipairs(craft) do
            if slot ~= 0 then
                transfers.transfer(storageState, {
                    type = "retrieveItems",
                    name = slot,
                    destination = chestName,
                    amount = craft.inputAmount,
                    slots = { shapeI },
                }, { acceptIDs = true })
            end
        end
        controlApi.sendRoundtrip(turtleid, "storage:craft", craft)
        transfers.transfer(storageState, {
            type = "storeItems",
            source = chestName,
        })
    end

    return processor
end

---@class CraftingTask
---@field steps Steps
---@field id number
---@field done number[] list of items done in steps
---@field nSteps number

---@param crafters { [number]: CraftProcessor[] }
function craft.makeManager(crafters)
    ---@class CraftManager
    local state = {
        ---indexed by method id
        ---@type { [number]: CraftProcessor[] }
        crafters = crafters,

        ---Current task queue
        ---@type CraftingTask[]
        tasks = {},

        taskIDCounter = 1,
    }

    ---@param steps Steps
    function state.runCraft(steps)
        local id = state.taskIDCounter
        local task = {
            steps = steps,
            id = state.taskIDCounter,
            done = {},
            nSteps = #util.objectKeys(steps)
        }
        state.taskIDCounter = state.taskIDCounter + 1

        table.insert(state.tasks, task)
        os.queueEvent("storage:craft:newTask")
        os.pullEvent("storage:craft:finished:" .. id)
    end

    local function crafterTask(storageState, method, crafter)
        return function()
            local doingTaskI = 0
            while true do
                -- choose a task

                local foundTask, foundCraft, taskItemID

                for i = 1, #state.tasks do
                    local roundBobbinI = (doingTaskI + i) % #state.tasks
                    local task = state.tasks[roundBobbinI]

                    for itemID, craft in ipairs(task.steps) do
                        if not util.arrayContains(task.done, itemID) and craft.method == method then
                            local children = craft.children
                            local childrenDone = true

                            for itemID, _ in pairs(children) do
                                if not util.arrayContains(task.done, itemID) then
                                    childrenDone = false
                                    break
                                end
                            end

                            if childrenDone then
                                -- pop a craft and do it

                                local craft = table.remove(craft.crafts, #craft.crafts)
                                foundTask, foundCraft, taskItemID = task, craft, itemID
                                break
                            end
                        end
                    end

                    if foundCraft ~= nil then
                        break
                    end
                end

                doingTaskI = (doingTaskI + 1) % #state.tasks

                if foundTask then
                    crafter.craft(foundCraft, storageState)

                    if #foundCraft.crafts == 0 then
                        table.insert(foundTask.done, taskItemID)
                    end

                    if #foundTask.done >= foundTask.nSteps then
                        -- craft is finished
                        local index = util.arrayIndexOf(state.tasks, foundTask)
                        table.remove(state.tasks, index)
                        os.queueEvent("storage:craft:finished:" .. foundTask.id)
                    end
                else
                    os.pullEvent("storage:craft:newTask")
                end
            end
        end
    end

    ---@param storageState StorageState
    function state.runManager(storageState)
        local tasks = {}
        for method, crafters in pairs(state.crafters) do
            for _, crafter in ipairs(crafters) do
                table.insert(tasks, crafterTask(method, crafter, storageState))
            end
        end

        parallel.waitForAll(table.unpack(tasks))
    end

    return state
end

---@param state StorageState
---@param itemArg ItemArg
---@param consumed { [number]: number }?
---@return Steps? steps
---@return { [number]: number }? missing
---@return { [number]: number }? consumed
function craft.craftLookup(state, itemArg, count, consumed)
    consumed = consumed or {}
    ---@type Steps
    local steps = {}
    local parents = {}
    local handleItem
    local function handleTags(itemArg, count, consumed, directChildren)
        -- local function itemArgName()
        --     local name
        --     if type(itemArg) == "string" then
        --         name = itemArg
        --     elseif type(itemArg) == "number" and itemArg < 0 then
        --         name = '#' .. util.arrayFind(state.tags, function(tag)
        --             return tag.id == -itemArg
        --         end).name
        --     elseif type(itemArg) == "number" and itemArg > 0 then
        --         name = state.itemIDToItemInfo(itemArg).name
        --     end
        --     return name
        -- end
        local itemIDs = state.resolveItemArg(itemArg, nil, true, true, true)
        if itemIDs == nil then
            return {
                [itemArg] = count
            }, 0, {}
        end

        if #itemIDs == 1 then
            -- local consumed_ = util.objectCopy(consumed)
            local missing, totalAvailable = handleItem(itemIDs[1], count, consumed, directChildren)
            return missing, totalAvailable, { [itemIDs[1]] = totalAvailable }
        end

        table.sort(itemIDs, function(a, b)
            return (state.itemIDToAmounts[a] or 0)
                > (state.itemIDToAmounts[b] or 0)
        end)

        local totalAvailable = 0
        local amounts = {}
        for _, itemID in ipairs(itemIDs) do
            if count - totalAvailable < 1 then break end
            -- local consumed_ = util.objectCopy(consumed)
            local _, available = handleItem(itemID, count - totalAvailable, consumed, directChildren)
            if available > 0 then
                amounts[itemID] = available
            end
            totalAvailable = totalAvailable + available
        end
        local missing
        if count - totalAvailable > 0 then
            missing = {
                [itemArg] = count - totalAvailable
            }
        end

        return missing, totalAvailable, amounts
    end

    function handleItem(itemID, count, consumed, directChildren)
        local inStorage = (state.itemIDToAmounts[itemID] or 0) - (consumed[itemID] or 0)
        local fullfiled = math.min(count, inStorage)

        if fullfiled ~= 0 then
            consumed[itemID] = (consumed[itemID] or 0) + fullfiled
        end
        local missing = nil

        local toCraft = count - fullfiled
        local craftObj = state.crafts[itemID]

        if toCraft > 0 and craftObj ~= nil and not util.arrayContains(parents, itemID) then
            local doCraftNTimes = math.ceil(count / craftObj[2])
            local totalCraftsDone = doCraftNTimes

            directChildren[itemID] = true

            ---@type ({ [number]: number }|0)[]
            local itemsPerSlot = {}

            -- craft!
            local directChildren = {}
            for i = 3, #craftObj do
                local ingredient = craftObj[i]
                if ingredient == 0 then
                    table.insert(itemsPerSlot, 0)
                else
                    local missing_, available, amounts = handleTags(ingredient, doCraftNTimes, consumed, directChildren)

                    if missing_ then
                        missing = missing or {}
                        for k, v in pairs(missing_) do
                            missing[k] = (missing[k] or 0) + v
                        end
                        totalCraftsDone = math.min(available, totalCraftsDone)
                    end

                    table.insert(itemsPerSlot, amounts)
                end
            end

            if steps[itemID] == nil then
                steps[itemID] = {
                    method = craftObj[1],
                    inputAmount = doCraftNTimes,
                    produced = craftObj[2] * doCraftNTimes,
                    inputs = itemsPerSlot,
                    children = directChildren,
                    crafts = {},
                }
            else
                -- merge
                steps[itemID].inputAmount = steps[itemID].inputAmount + doCraftNTimes
                steps[itemID].produced = steps[itemID].produced + craftObj[2] * doCraftNTimes
                for slot, items in ipairs(itemsPerSlot) do
                    if items ~= 0 then
                        ---@cast items { [number]: number }
                        local slot = steps[itemID].inputs[slot]
                        for itemID, amount in pairs(items) do
                            slot[itemID]
                            = (slot[itemID] or 0) + amount
                        end
                    end
                end
            end

            if missing == nil then
                fullfiled = fullfiled + craftObj[2] * doCraftNTimes
            end

            table.remove(parents, #parents)
        end

        if fullfiled < count then
            missing = missing or {}
            missing[itemID] = (missing[itemID] or 0) + count - fullfiled
        end
        if fullfiled > count then
            -- produced too much, put the excess as negative consumed value
            -- so that other crafts can use that excess
            consumed[itemID] = (consumed[itemID] or 0) - (fullfiled - count)
        end

        return missing, math.min(fullfiled, count)
    end

    local missing = handleTags(itemArg, count, consumed, {})
    if missing then
        return nil, missing
    end

    for itemID, itemsPerSlot in pairs(steps) do
        -- pack the crafts
        while true do
            -- find the biggest craft we can do
            local biggestCraftAmount = 1 / 0
            local inputs = {}

            for _, v in ipairs(itemsPerSlot.inputs) do
                local itemIDMax, amountMax = 0, 0
                if v ~= 0 then
                    for itemID, amount in pairs(v) do
                        if amount > amountMax then
                            itemIDMax, amountMax = itemID, amount
                        end
                        amountMax = math.max(amountMax, amount)
                    end
                    biggestCraftAmount = math.min(biggestCraftAmount, amountMax)
                end
                table.insert(inputs, itemIDMax)
            end

            -- break condition: if one of the items is lacking, break
            if biggestCraftAmount == 0 then
                break
            end

            -- output stacked crafts
            local maxCount = state.itemIDToItemInfo(itemID).maxCount
            local lastStack = math.ceil(biggestCraftAmount / maxCount)
            for i = 1, lastStack do
                local count = maxCount
                if i == lastStack then
                    if biggestCraftAmount % maxCount ~= 0 then
                        count = biggestCraftAmount % maxCount
                    end
                end
                -- craft it
                table.insert(steps[itemID].crafts, {
                    inputAmount = count,
                    inputs = inputs
                })
            end

            -- update state
            for i, v in ipairs(itemsPerSlot.inputs) do
                if v ~= 0 then
                    v[inputs[i]] = v[inputs[i]] - biggestCraftAmount
                end
            end
        end
        itemsPerSlot.inputs = nil
    end

    return steps, nil, consumed
end

return craft
