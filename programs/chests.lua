local peripherals = {}
for _,v in ipairs(peripheral.getNames()) do
	if peripheral.hasType(v, 'inventory') then
		table.insert(peripherals, v)
	end
end

local fullInv = {}

for _,v in ipairs(peripherals) do
	local items = peripheral.wrap(v).list()
	fullInv[v] = items
end

function calcTotalCount()
	local totalCountMap = {}
	for periph, inv in pairs(fullInv) do
		for i, el in pairs(inv) do
			if totalCountMap[el.name] == nil then
				totalCountMap[el.name] = 0
			end
			totalCountMap[el.name] = totalCountMap[el.name] + el.count
		end
	end
	local totalCountList = {}
	for el, n in pairs(totalCountMap) do
		table.insert(totalCountList, { el, n })
	end
	table.sort(totalCountList, function (a, b) return a[2] > b[2] end)
	totalCount = totalCountList
end

calcTotalCount()


print(textutils.serialize(totalCount))

