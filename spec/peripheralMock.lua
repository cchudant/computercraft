local util = require(".firmware.apis.util")
local inspect = require('inspect')

local peripheralMock = {}
peripheralMock.peripherals = {}

function peripheralMock.addPeripheral(name, obj)
    peripheralMock.peripherals[name] = obj
end

function peripheralMock.resetPeripherals()
    peripheralMock.peripherals = {}
end

peripheral = {}
function peripheral.getNames()
    return util.objectKeys(peripheralMock.peripherals)
end
function peripheral.getType(name)
    local periph = peripheralMock.peripherals[name]
    if periph == nil then return end
    return table.unpack(periph.type)
end
function peripheral.hasType(name, type)
    local periph = peripheralMock.peripherals[name]
    return util.arrayContains(periph.type, type)
end
function peripheral.wrap(name)
    return peripheralMock.peripherals[name].wrap
end
function peripheralMock.addChestPeripheral(key, items)
    local size = 27

    local wrap = {}
    function wrap.size()
        return size
    end
    function wrap.list()
        return util.objectMap(items, function(k, item)
            return k, {
                name = item.name,
                count = item.count,
                nbt = item.nbt,
            }
        end)
    end
    function wrap.getItemDetail(slot)
        return items[slot]
    end
    function wrap.getItemLimit(slot)
        return items[slot].maxCount
    end
    function wrap.pushItems(toName, fromSlot, limit, toSlot)
        print("pushItems", key, fromSlot, toName, toSlot, limit)
    end
    function wrap.pullItems(fromName, fromSlot, limit, toSlot)
        print("pullItems", fromName, fromSlot, key, toSlot, limit)
    end

    peripheralMock.addPeripheral(key, {
        type = {"minecraft:chest", "inventory"},
        wrap = wrap,
    })

    return items
end

return peripheralMock
