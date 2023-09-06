os.loadAPI("/firmware/apis/mine2.lua")

local FUEL = 'minecraft:dried_kelp_block'

local depth, right, height, turtles, facing = ...
if depth == nil or right == nil or height == nil or turtles == nil then
	print("usage: metamine <depth> <right> <height> <turtles> <facing>")
	return
end

depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)
nTurtles = tonumber(turtles)

if facing ~= 'south' and facing ~= 'north' and facing ~= 'west' and facing ~= 'east' then
	print("invalid facing")
	print("usage: metamine2 <depth> <right> <height> <turtles> <facing>")
	return
end

local TURTLE1 = "computercraft:turtle_normal"
local TURTLE2 = "computercraft:turtle_advanced"

print("I have " .. nTurtles .. " turtles.")
if nTurtles == 0 then
	print("Not enough turtles, need at least one")
	return
end

function placeTurtle(offsetDepth, offsetRight, offsetHeight, depth, right, height)
	print(offsetDepth, offsetRight, offsetHeight, depth, right, height)
	while not mine2.selectItem(turtle, {TURTLE1, TURTLE2}) do
		turtle.suckUp()
	end

	while not turtle.place() do end

	local t
	repeat
		sleep(0.1)
		t = peripheral.wrap('front')
	until t ~= nil 
	t.turnOn()
	local id = t.getID()

	local success, detail = turtle.inspect()
	if not success then error(detail) end

	local facings = {
		south = 0,
		east = 1,
		north = 2,
		west = 3,
	}

	local control = controlApi.connectControl(id)
	local remoteTurtle = control.turtle
	repeat
		print("waiting for " .. id)
	until controlApi.waitForReady(id, 15)

	while remoteTurtle.getFuelLevel() < mine2.digCuboidFuelRequired(depth, right, height) do
		print("refueling " .. id)
		while not mine2.selectItem(turtle, FUEL) do
			os.sleep(0.1)
			print("please provide fuel")
		end
		turtle.drop(1)
		mine2.selectItem(remoteTurtle, FUEL)
		remoteTurtle.refuel(1)
	end

	local nLeft = (facings[facing] - facings[detail.state.facing]) % 4
	return function()
		for i = 1,nLeft do
			remoteTurtle.turnLeft()
		end

		print(id .. ' started')

		control.shellRun("/firmware/programs/metamineCb "..offsetDepth.." "..offsetRight.." "..offsetHeight.." "..depth.." "..right.." "..height)
		
		print(id .. ' finished')
	end
end

function findBest(nChunksRight, nChunksHeight)
	local usedTurtles = nChunksHeight * nChunksRight

	local wouldUseIfChunkedRight = usedTurtles + nChunksHeight
	local wouldUseIfChunkedHeight = usedTurtles + nChunksRight

	local canChunkRight = math.ceil(right / nChunksRight) > 1 and wouldUseIfChunkedRight <= nTurtles
	local canChunkHeight = math.ceil(height / nChunksHeight) > 1 and wouldUseIfChunkedHeight <= nTurtles

	if canChunkRight and canChunkHeight then
		local nChunksRight1, nChunksHeight1 = findBest(nChunksRight + 1, nChunksHeight)
		local nChunksRight2, nChunksHeight2 = findBest(nChunksRight, nChunksHeight + 1)
		if nChunksRight1 * nChunksHeight1 >= nChunksRight2 * nChunksHeight2 then
			return nChunksRight1, nChunksHeight1
		else
			return nChunksRight2, nChunksHeight2
		end
	elseif canChunkRight then
		return findBest(nChunksRight + 1, nChunksHeight)
	elseif canChunkHeight then
		return findBest(nChunksRight, nChunksHeight + 1)
	end

	return nChunksRight, nChunksHeight
end

local nChunksRight, nChunksHeight = findBest(1, 1)

print("Tiling found is " .. nChunksRight .. "x" .. nChunksHeight)

local nGoBackHeight = 0

local turtles = {}

function gnForChunkHeight(ch)
	local nForChunkHeight = math.floor(height / nChunksHeight)
	if ch <= height % nChunksHeight then
		nForChunkHeight = nForChunkHeight + 1
	end
	return nForChunkHeight
end
function gnForChunkRight(cr)
	local nForChunkRight = math.floor(right / nChunksRight)
	if cr <= right % nChunksRight then
		nForChunkRight = nForChunkRight + 1
	end
	return nForChunkRight
end

function startTask()
	while turtle.dig() do end
	mine2.removeUselessItems(turtle, true)

	for ch = nChunksHeight, 1, -1 do
		for cr = nChunksRight, 1, -1 do
			local offsetDepth = 0
			local offsetRight = 0
			local offsetHeight = 0
			for i = 1, ch-1 do
				local nForChunkHeight = gnForChunkHeight(i)
				offsetHeight = offsetHeight + nForChunkHeight
			end
			for i = 1, cr-1 do
				local nForChunkRight = gnForChunkRight(i)
				offsetRight = offsetRight + nForChunkRight
			end
			turtleFunc = placeTurtle(offsetDepth, offsetRight, offsetHeight, depth, gnForChunkRight(cr), gnForChunkHeight(ch))
			print("metamine:newTurtle", turtleFunc)
			os.queueEvent("metamine:newTurtle", turtleFunc)
		end
	end
end

function launchTurtlesTask(functions)
	local coroutines = {}
	local filters = {}

	for _, func in ipairs(functions) do
		table.insert(coroutines, coroutine.create(func))
	end

	while #coroutines > 0 do

		local bag = {os.pullEvent()}
		print(bag[1])
		print(bag[2])
		if bag[1] == "metamine:newTurtle" then
			table.insert(coroutines, coroutine.create(bag[2]))
		end

		local i = 1
		while i <= #coroutines do
			local co = coroutines[i]
			local filter = filters[i]

			if filter == nil or filter == bag[1] or bag[1] == 'terminate' then
				local ok, filter = coroutine.resume(co, unpack(bag))
				if not ok then
					error(filter, 0)
				end
				filters[i] = filter
				if coroutine.status(co) == 'dead' then
					table.remove(coroutines, i)
					table.remove(filters, i)
				else
					i = i + 1
				end
			else
				i = i + 1
			end
		end

	end
end

launchTurtlesTask({startTask})

parallel.waitForAll(unpack(turtles))
