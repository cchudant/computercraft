function arrayConcat(...)
    local newTable = {}
    for _,arr in ipairs({...}) do
        for _,el in ipairs(arr) do
            table.insert(newTable, el)
        end
    end
    return newTable
end

function arrayEvery(arr, func)
    for i,el in ipairs(arr) do
        if not func(el, i, arr) then
            return false
        end
    end
    return true
end

function arrayAny(arr, func)
    for i,el in ipairs(arr) do
        if func(el, i, arr) then
            return true
        end
    end
    return false
end

function arrayFilter(arr, func)
    local newTable = {}
    for i,el in ipairs(arr) do
        if func(el, i, arr) then
            table.insert(newTable, el)
        end
    end
    return newTable
end

function arrayFind(arr, func)
    for i,el in ipairs(arr) do
        if func(el, i, arr) then
            return el
        end
    end
    return nil
end

function arrayFindIndex(arr, func)
    for i,el in ipairs(arr) do
        if func(el, i, arr) then
            return i
        end
    end
    return 0
end

function arrayFindLast(arr, func)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if func(el, i, arr) then
            return el
        end
    end
    return nil
end

function arrayFindLastIndex(arr, func)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if func(el, i, arr) then
            return i
        end
    end
    return 0
end

function arrayFlat(arr, depth)
    function arrFlat(newTable, arr, depth)
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

function arrayFlatMap(arr, func, depth)
    function arrFlat(newTable, arr, depth)
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

function arrayForEach(arr, func)
    for i,el in ipairs(arr) do
        func(el, i, arr)
    end
    return arr
end

function arrayContains(arr, elem)
    for i,el in ipairs(arr) do
        if elem == el then
            return true
        end
    end
    return false
end

function arrayIndexOf(arr, elem)
    for i,el in ipairs(arr) do
        if elem == el then
            return i
        end
    end
    return 0
end

function arrayLastIndexOf(arr, elem)
    for i = #arr, 1, -1 do
        local el = arr[i]
        if elem == el then
            return i
        end
    end
    return 0
end

function arrayJoin(arr, separator)
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

function arrayMap(arr, func)
    local newTable = {}
    for i,el in ipairs(arr) do
        local newEl = func(el)
        table.push(newTable, newEl)
    end
    return newTable
end

function arrayPop(arr)
    return table.remove(arr, #arr)
end

function arrayPush(arr, el)
    return table.insert(arr, el)
end

function arrayLen(arr)
    return #arr
end

function arrayReduce(arr, func, accumulator)
    for i,v in ipairs(arr) do
        accumulator = func(accumulator, v, i, arr)
    end
    return accumulator
end

function arrayReduceRight(arr, func, accumulator)
    for i = #arr, 1, -1 do
        local v = arr[i]
        accumulator = func(accumulator, v, i, arr)
    end
    return accumulator
end

function arrayReverse(arr)
    local newTable = {}
    for i = #arr, 1, -1 do
        local v = arr[i]
        table.insert(newTable, v)
    end
    return newTable
end

function arrayShift(arr)
    return table.remove(arr, 1)
end

-- does not support negative indexes yet
function arraySlice(arr, start, end_)
    local newTable = {}
    for i = start, end_ do
        local v = arr[i]
        table.insert(newTable, v)
    end
    return newTable
end

function arraySort(arr, func)
    return table.sort(arr, func)
end

function arrayUnshift(arr, ...)
    local index = 1
    for _,v in ipairs({...}) do
        table.insert(arr, v, index)
        index = index + 1
    end
    return #arr
end

function objectEntries(obj)
    local table = {}
    for k,v in pairs(obj) do
        table.insert(table, { k, v })
    end
    return table
end

function objectFromEntries(entries)
    local obj = {}
    for _,v in ipairs(entries) do
        local k,el = table.unpack(v)
        obj[k] = el
    end
    return obj
end

function defaultArgs(options, defaults)
	for k,v in pairs(defaults) do
		if options[k] == nil then
			options[k] = defaults[k]
		end
	end
end
