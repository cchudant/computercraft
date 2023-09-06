local retrieveChest = 'minecraft:chest_4'

local peripherals = {}
for _,v in ipairs(peripheral.getNames()) do
	if peripheral.hasType(v, 'inventory') then
		table.insert(peripherals, v)
	end
end

local invSizes = {}
local fullInv = {}

for _,v in ipairs(peripherals) do
	if v ~= retrieveChest then
		local p = peripheral.wrap(v)
		fullInv[v] = p.list()
		invSizes[v] = p.size()
	end
end

function transferToRetreiveChest(periph, i, toPush)
	print('transferToRetreiveChest', periph, i, toPush)
	local amount = math.min(fullInv[periph][i].count, toPush)
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

function retrieve(item, count)
	if totalCountMap[item] == nil or totalCountMap[item] < count then
		return 0
	end

	local got = 0
	for periph, inv in pairs(fullInv) do
		for i, el in pairs(inv) do
			if el.name == item then
				local toPush = count - got
				
				got = got + transferToRetreiveChest(periph, i, toPush)
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

function _findEmptySlot()
	for periph, inv in pairs(fullInv) do
		for i = 1, invSizes[periph] do
			if inv[i] == nil then
				return periph, i
			end
		end
	end
end

function push()
	local retrieve_ = peripheral.wrap(retrieveChest)
	for retI, retEl in pairs(retrieve_.list()) do
		local retCount = retEl.count
		local itemsPushed = 0
		for periph, inv in pairs(fullInv) do
			for i, el in pairs(inv) do
				if el.name == retEl.name then
					local stackLimit = retrieve_.getItemLimit(retI)
					local toPush = stackLimit - (el.count + retCount)

					print(el.name, el.count, retCount, toPush)

					peripheral.wrap(retrieveChest).pushItems(periph, retI, toPush, i)
					fullInv[periph][i].count = fullInv[periph][i].count + toPush
					calcTotalCount()

					itemsPushed = itemsPushed + toPush
				end
				if itemsPushed >= retCount then
					break
				end
			end
			if itemsPushed >= retCount then
				break
			end
		end

		print(itemsPushed, retCount)

		if itemsPushed < retCount then
			local periph, i = _findEmptySlot()
			local toPush = retCount - itemsPushed

			peripheral.wrap(retrieveChest).pushItems(periph, retI, toPush, i)
			fullInv[periph][i] = retEl
			fullInv[periph][i].count = toPush
		end
	end
end

print(push())
