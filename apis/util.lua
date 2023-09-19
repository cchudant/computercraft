local util = {}

---@generic T
---@param ... T[]
---@return T[]
function util.arrayConcat(...)
    local newTable = {}
    for _, arr in ipairs({ ... }) do
        for _, el in ipairs(arr) do
            table.insert(newTable, el)
        end
    end
    return newTable
end

---@generic T
---@param arr T[]
---@param func fun(t: T, i: number, arr: T[]): boolean
---@return boolean
function util.arrayAll(arr, func)
    for i, el in ipairs(arr) do
        if not func(el, i, arr) then
            return false
        end
    end
    return true
end

---@generic T
---@param arr T[]
---@param func fun(t: T, i: number, arr: T[]): boolean
---@return boolean
function util.arrayAny(arr, func)
    for i, el in ipairs(arr) do
        if func(el, i, arr) then
            return true
        end
    end
    return false
end

---@generic T
---@param arr T[]
---@param func fun(t: T, i: number, arr: T[]): boolean
---@return T[]
function util.arrayFilter(arr, func)
    local newTable = {}
    for i, el in ipairs(arr) do
        if func(el, i, arr) then
            table.insert(newTable, el)
        end
    end
    return newTable
end

---@generic T
---@param arr T[]
---@param func fun(t: T, i: number, arr: T[]): boolean
---@return T? element
---@return number? index
function util.arrayFind(arr, func)
    for i, el in ipairs(arr) do
        if func(el, i, arr) then
            return el, i
        end
    end
end

---@generic T
---@param arr T[]
---@param func fun(t: T, i: number, arr: T[]): boolean
---@return T? element
---@return number? index
function util.arrayFindLast(arr, func)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if func(el, i, arr) then
            return el, i
        end
    end
end

---@generic T
---@param arr T[][]
---@param depth number? defaults to 1
---@return T[]
function util.arrayFlat(arr, depth)
    local function arrFlat(newTable, arr, depth)
        if type(arr) == 'table' and depth > 0 then
            for i, el in ipairs(arr) do
                if not arrFlat(newTable, arr, depth - 1) then
                    table.insert(newTable, el)
                end
            end
            return true
        else
            return false
        end
    end
    local newTable = {}
    arrFlat(newTable, arr, depth or 1)
    return newTable
end

---@generic T
---@generic U
---@param arr T[][]
---@param func fun(t: T, i: number, arr: T[]): U
---@param depth number? defaults to 1
---@return U[]
function util.arrayFlatMap(arr, func, depth)
    local function arrFlat(newTable, arr, depth)
        if type(arr) == 'table' and depth > 0 then
            for i, el in ipairs(arr) do
                local elem = func(el, i, arr)
                if not arrFlat(newTable, arr, depth - 1) then
                    table.insert(newTable, elem)
                end
            end
            return true
        else
            return false
        end
    end
    local newTable = {}
    arrFlat(newTable, arr, depth or 1)
    return newTable
end

---@generic T
---@param arr T[]
---@param func fun(t: T, i: number, arr: T[])
---@return T[] arr
function util.arrayForEach(arr, func)
    for i, el in ipairs(arr) do
        func(el, i, arr)
    end
    return arr
end

---@generic T
---@param arr T[]
---@return boolean
function util.arrayContains(arr, elem)
    for i, el in ipairs(arr) do
        if elem == el then
            return true
        end
    end
    return false
end

---@generic T
---@param arr T[]
---@return number
function util.arrayIndexOf(arr, elem)
    for i, el in ipairs(arr) do
        if elem == el then
            return i
        end
    end
    return 0
end

---@generic T
---@param arr T[]
---@return number
function util.arrayLastIndexOf(arr, elem)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if elem == el then
            return i
        end
    end
    return 0
end

---@generic T
---@param arr T[]
---@param separator string? defaults to ','
---@return string
function util.arrayJoin(arr, separator)
    return table.concat(arr, separator or ",")
end

if fs then
    -- computercraft
    local pretty = require('cc.pretty').pretty_print
    ---@param ... any
    function util.prettyPrint(...)
        for _, v in pairs({ ... }) do
            pretty(v)
        end
    end
else
    -- unit testing
    local inspect = require('inspect')
    ---@param ... any
    function util.prettyPrint(...)
        print(table.unpack(util.arrayMap({ ... }, inspect)))
    end
end

---@generic T
---@generic U
---@param arr T[]
---@param func fun(t: T): U
---@return U[]
function util.arrayMap(arr, func)
    local newTable = {}
    for i, el in ipairs(arr) do
        local newEl = func(el)
        table.insert(newTable, newEl)
    end
    return newTable
end

---@generic T
---@param arr T[]
---@return T?
function util.arrayPop(arr)
    return table.remove(arr, #arr)
end

---@generic T
---@param arr T[]
---@param el T
function util.arrayPush(arr, el)
    table.insert(arr, el)
end

---@generic T
---@param arr T[]
---@return number
function util.arrayLen(arr)
    return #arr
end

---@generic T
---@generic Acc
---@param arr T[]
---@param func fun(accumulator: Acc, t: T, i: number, arr: T[]): Acc
---@param accumulator Acc initial state
---@return Acc accumulator final state
function util.arrayReduce(arr, func, accumulator)
    for i, v in ipairs(arr) do
        accumulator = func(accumulator, v, i, arr)
    end
    return accumulator
end

---@generic T
---@generic Acc
---@param arr T[]
---@param func fun(accumulator: Acc, t: T, i: number, arr: T[]): Acc
---@param accumulator Acc initial state
---@return Acc accumulator final state
function util.arrayReduceRight(arr, func, accumulator)
    for i = #arr, 1, -1 do
        local v = arr[i]
        accumulator = func(accumulator, v, i, arr)
    end
    return accumulator
end

---@generic T
---@param arr T[]
---@return T[]
function util.arrayReverse(arr)
    local newTable = {}
    for i = #arr, 1, -1 do
        local v = arr[i]
        table.insert(newTable, v)
    end
    return newTable
end

---@generic T
---@param arr T[]
---@return T[]
function util.arrayShift(arr)
    return table.remove(arr, 1)
end

---does not support negative indexes yet
---@generic T
---@param arr T[]
---@param start number
---@param end_ number
---@return T[]
function util.arraySlice(arr, start, end_)
    local newTable = {}
    for i = start, end_ do
        local v = arr[i]
        table.insert(newTable, v)
    end
    return newTable
end

---@generic T
---@param arr T[]
---@param comp? fun(a: T, b: T): boolean
---@return T[]
function util.arraySort(arr, comp)
    table.sort(arr, comp)
    return arr
end

---@generic T
---@param arr T[]
---@param ... T elements
---@return T[]
function util.arrayUnshift(arr, ...)
    local index = 1
    for _, v in ipairs({ ... }) do
        table.insert(arr, v, index)
        index = index + 1
    end
    return arr
end

---@generic T
---@param obj { [T]: any }
---@return T[]
function util.objectKeys(obj)
    local tab = {}
    for k, _ in pairs(obj) do
        table.insert(tab, k)
    end
    return tab
end

---@param obj table
---@return number
function util.objectCountEntries(obj)
    local total = 0
    for _, _ in pairs(obj) do
        total = total + 1
    end
    return total
end

---@generic T
---@param obj { [any]: T }
---@return T[]
function util.objectValues(obj)
    local tab = {}
    for _, v in pairs(obj) do
        table.insert(tab, v)
    end
    return tab
end

---@generic K
---@generic V
---@param obj { [K]: V }
---@return { [1]: K, [2]: V }[]
function util.objectEntries(obj)
    local tab = {}
    for k, v in pairs(obj) do
        table.insert(tab, { k, v })
    end
    return tab
end

---@generic K
---@generic V
---@param entries { [1]: K, [2]: V }[]
---@return { [K]: V }
function util.objectFromEntries(entries)
    local obj = {}
    for _, v in ipairs(entries) do
        local k, el = table.unpack(v)
        obj[k] = el
    end
    return obj
end

---Removes duplicates
---@generic T
---@param arr T[]
---@return T[]
function util.arrayUnique(arr)
    local res = {}
    local hash = {}
    for _, v in ipairs(arr) do
        if not hash[v] then
            table.insert(res, v)
            hash[v] = true
        end
    end
    return res
end

---Pass each key,value pair to the map function and construct a new object with
---its results
---@generic K
---@generic V
---@generic NewK
---@generic NewV
---@param obj { [K]: V } object
---@param func fun(key: K, value: V): NewK, NewV
---@return { [NewK]: NewV }
function util.objectMap(obj, func)
    local newObj = {}
    for k, v in pairs(obj) do
        local newk, newv = func(k, v)
        newObj[newk] = newv
    end
    return newObj
end

---@generic T: table
---@param obj T
---@return T
function util.objectCopy(obj)
    local newObj = {}
    for k, v in pairs(obj) do
        newObj[k] = v
    end
    return newObj
end

---@generic K
---@generic V
---@param obj { [K]: V }
---@param func fun(key: K, value: V): boolean
---@return boolean
function util.objectAny(obj, func)
    for k, v in pairs(obj) do
        if func(k, v) then
            return true
        end
    end
    return false
end

---@generic K
---@generic V
---@param obj { [K]: V }
---@param func fun(key: K, value: V): boolean
---@return boolean
function util.objectAll(obj, func)
    for k, v in pairs(obj) do
        if not func(k, v) then
            return false
        end
    end
    return true
end

---@generic K
---@generic V
---@param obj { [K]: V }
---@param func fun(key: K, value: V): boolean
---@return K? key
---@return V? value
function util.objectFind(obj, func)
    for k, v in pairs(obj) do
        if func(k, v) then
            return k, v
        end
    end
end

---@generic T
---@param arr T[]
---@return number? max
---@return number? index
function util.arrayMax(arr)
    local imax, max
    for i, v in ipairs(arr) do
        if v > (max or 0) then
            imax, max = i, v
        end
    end
    return max, imax
end

---@generic K
---@generic V
---@param ... { [K]: V }
---@return { [K]: V }
function util.objectMerge(...)
    local newObj = {}
    for _, obj in pairs({ ... }) do
        for k, v in pairs(obj) do
            newObj[k] = v
        end
    end
    return newObj
end

---@param str string
---@param prefix string
---@return boolean
function util.stringStartsWith(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

---@param path string
---@return any
function util.readJSON(path)
    if fs then
        local f = fs.open(path, 'r')
        if f == nil then return nil end
        return textutils.unserializeJSON(f.readAll())
    else
        local lunajson = require('lunajson')
        if string.sub(path, 1, 1) == '/' then
            path = '.' .. path
        end

        path = string.gsub(path, "firmware", ".")

        local f = io.open(path, 'r')
        if f == nil then return nil end
        local s = f:read("*a")
        f:close()
        return lunajson.decode(s)
    end
end

---@generic T
---@param options table?
---@param defaults T
---@return T
function util.defaultArgs(options, defaults)
    if options == nil then options = {} end
    for k, _ in pairs(defaults) do
        if options[k] == nil then
            options[k] = defaults[k]
        end
    end
    return options
end

---@class Object
---@field construct fun(o: table): Object

---@generic T
---@generic U
---@param class T
---@param parent U?
---@return T 
function util.makeClass(class, parent)
    local metatable = { __index = class }
    if parent then
        setmetatable(class, { __index = parent })
    end
    function class.construct(o)
        setmetatable(o, metatable)
        return o
    end
    return class
end

---@generic T
---@generic U
---@param class T
---@param parent U?
---@return T 
function util.makeAbstractClass(class, parent)
    local metatable = { __index = class }
    if parent then
        setmetatable(class, { __index = parent })
    end
    function class.construct(o)
        error("instanciating abstract class", 2)
    end
    return class
end

---Create a new random nonce
---@return string
function util.newNonce()
    return tostring(math.floor(math.random() * 10000000))
end

---Create and block on a parallel group. This is like `parallel.waitForAll`, but you can add
---new tasks to the group during execution.
---
---Usage:
---```
---util.parallelGroup(function (addTask)
---  addTask(function()
---      os.sleep(2)
---      print("2 finished")
---  end)
---  addTask(function()
---      os.sleep(1)
---      addTask(function() os.sleep(3) print("3 finished") end)
---      print("1 finished")
---  end)
---end)
---print("all tasks have finished")
---```
---
---The function will ultimately return when every task in the task group has been completed.
---
---@param ... fun(addTask: fun(...: fun()))
function util.parallelGroup(...)
    local coroutineIDCounter = 1
    local coroutines = {}
    local filters = {}
    local nCoroutines = 0

    local nonce = util.newNonce()

    local addedCoroutines = {}

    for _, func in ipairs({ ... }) do
        local coroutineID = coroutineIDCounter
        coroutineIDCounter = coroutineIDCounter + 1
        coroutines[coroutineID] = coroutine.create(function()
            local function addTask(...)
                for _, func in ipairs({ ... }) do
                    local coroutineID = coroutineIDCounter
                    coroutineIDCounter = coroutineIDCounter + 1
                    addedCoroutines[coroutineID] = func
                    os.queueEvent("parallelGroup:add:" .. nonce, coroutineID)
                end
            end
            func(addTask)
            os.queueEvent("parallelGroup:end:" .. nonce, coroutineID)
        end)
        local ok, filter = coroutine.resume(coroutines[coroutineID])
        if not ok then
            error(filter, 0)
        end
        filters[coroutineID] = filter
        nCoroutines = nCoroutines + 1
    end

    while nCoroutines > 0 do
        local bag = table.pack(os.pullEvent())

        if bag[1] == "parallelGroup:add:" .. nonce then
            local coroutineID = bag[2]
            local func = addedCoroutines[coroutineID]
            addedCoroutines[coroutineID] = nil
            coroutines[coroutineID] = coroutine.create(function()
                func()
                os.queueEvent("parallelGroup:end:" .. nonce, coroutineID)
            end)
            local ok, filter = coroutine.resume(coroutines[coroutineID])
            if not ok then
                error(filter, 0)
            end
            filters[coroutineID] = filter
            nCoroutines = nCoroutines + 1
        elseif bag[1] == "parallelGroup:end:" .. nonce then
            local coroutineID = bag[2]
            coroutines[coroutineID] = nil
            filters[coroutineID] = nil
            nCoroutines = nCoroutines - 1
        end
        for k, co in pairs(coroutines) do
            if filters[k] == nil or filters[k] == bag[1] or bag[1] == 'terminate' then
                if coroutine.status(co) ~= 'dead' then
                    local ok, filter = coroutine.resume(co, table.unpack(bag, 1, bag.n))
                    if not ok then
                        error(filter, 0)
                    end
                    filters[k] = filter
                end
            end
        end
    end
end

return util
