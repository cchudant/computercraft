local util = {}

function util.arrayConcat(...)
    local newTable = {}
    for _,arr in ipairs({...}) do
        for _,el in ipairs(arr) do
            table.insert(newTable, el)
        end
    end
    return newTable
end

function util.arrayEvery(arr, func)
    for i,el in ipairs(arr) do
        if not func(el, i, arr) then
            return false
        end
    end
    return true
end

function util.arrayAny(arr, func)
    for i,el in ipairs(arr) do
        if func(el, i, arr) then
            return true
        end
    end
    return false
end

function util.arrayFilter(arr, func)
    local newTable = {}
    for i,el in ipairs(arr) do
        if func(el, i, arr) then
            table.insert(newTable, el)
        end
    end
    return newTable
end

function util.arrayFind(arr, func)
    for i,el in ipairs(arr) do
        if func(el, i, arr) then
            return el
        end
    end
    return nil
end

function util.arrayFindIndex(arr, func)
    for i,el in ipairs(arr) do
        if func(el, i, arr) then
            return i
        end
    end
    return 0
end

function util.arrayFindLast(arr, func)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if func(el, i, arr) then
            return el
        end
    end
    return nil
end

function util.arrayFindLastIndex(arr, func)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if func(el, i, arr) then
            return i
        end
    end
    return 0
end

function util.arrayFlat(arr, depth)
    local function arrFlat(newTable, arr, depth)
        if type(arr) == 'table' and (depth == nil or depth > 0) then
            for i,el in ipairs(arr) do
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
    arrFlat(newTable, arr, depth)
    return newTable
end

function util.arrayFlatMap(arr, func, depth)
    local function arrFlat(newTable, arr, depth)
        if type(arr) == 'table' and (depth == nil or depth > 0) then
            for i,el in ipairs(arr) do
                local elem = func(el)
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
    arrFlat(newTable, arr, depth)
    return newTable
end

function util.arrayForEach(arr, func)
    for i,el in ipairs(arr) do
        func(el, i, arr)
    end
    return arr
end

function util.arrayContains(arr, elem)
    for i,el in ipairs(arr) do
        if elem == el then
            return true
        end
    end
    return false
end

function util.arrayIndexOf(arr, elem)
    for i,el in ipairs(arr) do
        if elem == el then
            return i
        end
    end
    return 0
end

function util.arrayLastIndexOf(arr, elem)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if elem == el then
            return i
        end
    end
    return 0
end

function util.arrayJoin(arr, separator)
    if separator == nil then separator = ',' end
    local res = ''
    for i,el in ipairs(arr) do
        if i == 1 then
            res = tostring(el)
        else
            res = res .. separator .. el
        end
    end
    return res
end

function util.arrayMap(arr, func)
    local newTable = {}
    for i,el in ipairs(arr) do
        local newEl = func(el)
        table.insert(newTable, newEl)
    end
    return newTable
end

function util.arrayPop(arr)
    return table.remove(arr, #arr)
end

function util.arrayPush(arr, el)
    return table.insert(arr, el)
end

function util.arrayLen(arr)
    return #arr
end

function util.arrayReduce(arr, func, accumulator)
    for i,v in ipairs(arr) do
        accumulator = func(accumulator, v, i, arr)
    end
    return accumulator
end

function util.arrayReduceRight(arr, func, accumulator)
    for i = #arr, 1, -1 do
        local v = arr[i]
        accumulator = func(accumulator, v, i, arr)
    end
    return accumulator
end

function util.arrayReverse(arr)
    local newTable = {}
    for i = #arr, 1, -1 do
        local v = arr[i]
        table.insert(newTable, v)
    end
    return newTable
end

function util.arrayShift(arr)
    return table.remove(arr, 1)
end

-- does not support negative indexes yet
function util.arraySlice(arr, start, end_)
    local newTable = {}
    for i = start, end_ do
        local v = arr[i]
        table.insert(newTable, v)
    end
    return newTable
end

function util.arraySort(arr, func)
    return table.sort(arr, func)
end

function util.arrayUnshift(arr, ...)
    local index = 1
    for _,v in ipairs({...}) do
        table.insert(arr, v, index)
        index = index + 1
    end
    return #arr
end

function util.objectKeys(obj)
    local table = {}
    for k,_ in pairs(obj) do
        table.insert(table, k)
    end
    return table
end

function util.objectValues(obj)
    local table = {}
    for _,v in pairs(obj) do
        table.insert(table, v)
    end
    return table
end

function util.objectEntries(obj)
    local table = {}
    for k,v in pairs(obj) do
        table.insert(table, { k, v })
    end
    return table
end

function util.objectFromEntries(entries)
    local obj = {}
    for _,v in ipairs(entries) do
        local k,el = table.unpack(v)
        obj[k] = el
    end
    return obj
end

function util.defaultArgs(options, defaults)
	for k,_ in pairs(defaults) do
		if options[k] == nil then
			options[k] = defaults[k]
		end
	end
end

return util
