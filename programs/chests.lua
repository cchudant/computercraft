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

local totalCount = {}
function calcTotalCount()
	for periph, inv in pairs(fullInv) do
		for i, el in pairs(inv) do
			if totalCount[el.name] == nil then
				totalCount[el.name] = 0
			end
			totalCount[el.name] = totalCount[el.name] + el.count
		end
	end
end

calcTotalCount()
print(textutils.serialize(totalCount))

