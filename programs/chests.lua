local retrieveChest = 'minecraft:chest_4'

local peripherals = {}
for _,v in ipairs(peripheral.getNames()) do
	if peripheral.hasType(v, 'inventory') then
		table.insert(peripherals, v)
	end
end

local fullInv = {}

for _,v in ipairs(peripherals) do
	if v ~= retrieveChest then
		local items = peripheral.wrap(v).list()
		fullInv[v] = items
	end
end

function transferToRetreiveChest(periph, i, toPush)
	print('transferToRetreiveChest', periph, i, toPush)
	local amount = math.max(fullInv[periph][i].count - toPush, 0)
	peripheral.wrap(periph).pushItems(retrieveChest, i, amount)
	fullInv[periph][i].count = fullInv[periph][i].count - amount

	if fullInv[periph][i].count == 0 then
		fullInv[periph][i] = nil
	end
	calcTotalCount()
	return amount	
end

local totalCountMap
local totalCount
function calcTotalCount()
	totalCountMap = {}
	for periph, inv in pairs(fullInv) do
		for i, el in pairs(inv) do
			if totalCountMap[el.name] == nil then
				totalCountMap[el.name] = 0
			end
			totalCountMap[el.name] = totalCountMap[el.name] + el.count
		end
	end
	totalCount = {}
	for el, n in pairs(totalCountMap) do
		table.insert(totalCount, { el, n })
	end
	table.sort(totalCount, function (a, b) return a[2] < b[2] end)
end
calcTotalCount()

local demanded = 'minecraft:obsidian'

function demand(item, count)
		print("ad", totalCountMap[item])
	if totalCountMap[item] == nil or totalCountMap[item] < count then
		return 0
	end
		print("add")

	local got = 0
	for periph, inv in pairs(fullInv) do
		print("a")
		for i, el in pairs(inv) do
			print(el.name, el.count)
			if el.name == item then
				local toPush = count - got
				
				transferToRetreiveChest(periph, i, toPush)

				got = got + el.count
				if got >= count then
					break
				end
			end
		end
		if got >= count then
			break
		end
	end

	return got
end

print(demand(demanded, 38))
