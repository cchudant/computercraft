local retrieveChest = 'minecraft:chest_13'

-- local item, amount = ...

-- amount = tonumber(amount)

function arrayAll(tab, fn)
	for _, v in ipairs(tab) do
		if fn(v) then
			return true
		end
	end
	return false
end

local peripherals = {}
for _,v in ipairs(peripheral.getNames()) do
	local ignore = v == 'top' or v == 'left' or v == 'front' or v == 'bottom' or v == 'right' or v == 'back'
	if not ignore and peripheral.hasType(v, 'inventory') then
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
	table.sort(totalCount, function (a, b) return a[2] > b[2] end)
end
calcTotalCount()

local demanded = 'minecraft:obsidian'

function retrieve(item, count)
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
	local totalPushed = 0

	local retrieve_ = peripheral.wrap(retrieveChest)
	for retI, retEl in pairs(retrieve_.list()) do
		local retCount = retEl.count
		local itemsPushed = 0
		for periph, inv in pairs(fullInv) do
			for i, el in pairs(inv) do
				if el.name == retEl.name then
					local stackLimit = retrieve_.getItemLimit(retI)
					local toPush = math.min(el.count + retCount, stackLimit) - el.count

					peripheral.wrap(retrieveChest).pushItems(periph, retI, toPush, i)
					fullInv[periph][i].count = fullInv[periph][i].count + toPush
					calcTotalCount()

					itemsPushed = itemsPushed + toPush
					totalPushed = totalPushed + toPush
				end
				if itemsPushed >= retCount then
					break
				end
			end
			if itemsPushed >= retCount then
				break
			end
		end

		if itemsPushed < retCount then
			local periph, i = _findEmptySlot()
			local toPush = retCount - itemsPushed

			peripheral.wrap(retrieveChest).pushItems(periph, retI, toPush, i)
			fullInv[periph][i] = retEl
			fullInv[periph][i].count = toPush
			totalPushed = totalPushed + toPush
		end
	end

	return totalPushed
end

-- if item == nil then
-- 	local amount = push()
-- 	print("Pushed "..amount.." items")
-- else
-- 	if amount == nil then amount = 64 end
	
function stripped(s)
	return string.gsub(string.gsub(string.gsub(string.lower(string.gsub(s, '_', ' ')), 'minecraft:', ''), 'computercraft:', ''), 'chunkloaders:', '')
end

-- 	local realItem = item

-- 	for k,_ in pairs(totalCountMap) do
-- 		if stripped(k) == stripped(item) then
-- 			realItem = k
-- 			break
-- 		end
-- 	end

-- 	local amount = retrieve(realItem, amount)
-- 	print("Got "..amount.." of "..realItem)
-- end

function strLimitSize(str, limit)
	return string.sub(str, 1, limit)
end

function formatAmount(amount)
	if amount < 1000 then
		return tostring(amount)
	elseif amount < 1000000 then
		return tostring(math.floor(amount / 1000)) .. "K"
	else
		return tostring(math.floor(amount / 1000000)) .. "M"
	end
end

local typed = ''
local foundItems

local selected = {}
function updateFoundItems()
	if typed == '' then
		foundItems = totalCount
		return
	end

	local found = {}
	for _,v in ipairs(totalCount) do
		local item, number = unpack(v)
		if string.match(stripped(item), stripped(typed)) then
			table.insert(found, v)
		end
	end
	foundItems = found
end
updateFoundItems()

sizeLimit = 25

function redraw(term)
	local width, height = term.getSize()

	local nTabs = math.floor(width / sizeLimit)
	local tabSize = math.floor(width / nTabs)

	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	term.setCursorBlink(false)
	term.clear()
	local blinkCusorPosX, blinkCusorPosY = 1, 1

	-- seach bar
	term.setCursorPos(width - 22, 1)
	term.setBackgroundColor(colors.gray)
	term.write('Search:')
	term.setBackgroundColor(colors.lightGray)

	term.setCursorPos(width - 22 + 7, 1)
	for _ = width - 22 + 7, width do
		term.write(' ')
	end

	term.setCursorPos(width - 22 + 7, 1)
	local shown = string.sub(typed, string.len(typed) - (22-7), string.len(typed))
	term.write(shown)

	blinkCusorPosX, blinkCusorPosY = term.getCursorPos()

	local line = 1
	local tab = 1
	for _,v in ipairs(foundItems) do
		local item, number = unpack(v)

		term.setBackgroundColor(colors.black)
		if arrayAll(selected, function(el) return el[1] == tab and el[2] == line end) then
			term.setBackgroundColor(colors.lightGray)
		end

		term.setCursorPos((tab-1) * tabSize + 1, line + 1)
		for _ = 1, tabSize do
			term.write(' ')
		end

		term.setCursorPos((tab-1) * tabSize + 1, line + 1)

		local shown = strLimitSize(stripped(item), tabSize)
		term.write(shown)

		local snumber = formatAmount(number)
		term.setCursorPos(tab * tabSize - string.len(snumber), line + 1)
		term.write(snumber)

		if tab == nTabs then
			tab = 1
			line = line + 1
		else
			tab = tab + 1
		end
		if line + 1 > height then break end
	end

	term.setBackgroundColor(colors.black)
	term.setCursorPos(blinkCusorPosX, blinkCusorPosY)
	term.setCursorBlink(true)
end

function redrawAll()
	-- redraw(term)
	local monitor = peripheral.find('monitor')
	if monitor ~= nil then
		monitor.setTextScale(0.7)
		redraw(monitor)
	end
end

function eventsTask()
	function handleClick(x, y, w, h)
		print(x, y, w, h)
		if y < 1 then return end

		local nTabs = math.floor(w / sizeLimit)
		local tabSize = math.floor(w / nTabs)

		local tab = math.floor(x / w * nTabs) + 1
		local line = y - 1

		local index = (line-1) * nTabs + (tab-1)+1
		print(line, tab, index, nTabs)
		local item = foundItems[index]
		if item ~= nil then
			selected = {{tab, line}}
			redrawAll()

			print(unpack(item))

			retrieve(item[1], 64)
			updateFoundItems()
			os.sleep(0.5)
			selected = {}
			redrawAll()
		end
	end


	parallel.waitForAll(
		function()
			while true do
				_, char = os.pullEvent('char')
				typed = typed .. char
				updateFoundItems()
				redrawAll()
			end
		end,
		function()
			while true do
				_, key = os.pullEvent('key')
				if key == 259 then -- backspace
					typed = string.sub(typed, 1, string.len(typed) - 1)
					updateFoundItems()
					redrawAll()
				end
			end
		end,
		function()
			while true do
				local _, _, x, y = os.pullEvent('monitor_touch')
				local w, h = peripheral.find('monitor').getSize()
				handleClick(x, y, w, h)
			end
		end,
		function()
			while true do
				local _, _, x, y = os.pullEvent('mouse_click')
				local w, h = term.getSize()
				handleClick(x, y, w, h)
			end
		end
	)
end

redrawAll()
eventsTask()
