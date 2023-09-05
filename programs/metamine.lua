os.loadAPI("/firmware/apis/mine2.lua")

local FUEL = 'minecraft:dried_kelp_block'

local depth, right, height, facing = ...
if depth == nil or right == nil or height == nil then
	print("usage: metamine <depth> <right> <height> <facing>")
	return
end

depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)


if facing ~= 'south' and facing ~= 'north' and facing ~= 'west' and facing ~= 'east' then
	print("invalid facing")
	print("usage: metamine <depth> <right> <height> <facing>")
	return
end

local TURTLE1 = "computercraft:turtle_normal"
local TURTLE2 = "computercraft:turtle_advanced"

local nTurtles = 0
for slot=1,16 do
	local detail = turtle.getItemDetail(slot)
	if detail ~= nil and (detail.name == TURTLE1 or detail.name == TURTLE2) then
		nTurtles = nTurtles + detail.count
	end
end

function selectTurtle()
	for slot=1,16 do
		local detail = turtle.getItemDetail(slot)
		if detail ~= nil and (detail.name == TURTLE1 or detail.name == TURTLE2) then
			turtle.select(slot)
			return true
		end
	end
	return false
end

print("I have " .. nTurtles .. " turtles.")
if nTurtles == 0 then
	print("Not enough turtles, need at least one")
	return
end

function placeTurtle(side, depth, right, height)
	selectTurtle()
	if side == 'front' then while not turtle.place() do end
	elseif side == 'top' then while not turtle.placeUp() do end
	else while not turtle.placeDown() do end end

	local t
	repeat
		sleep(0.1)
		t = peripheral.wrap(side)
	until t ~= nil 
	t.turnOn()
	local id = t.getID()

	local success, detail
	if side == 'front' then success, detail = turtle.inspect()
	elseif side == 'top' then success, detail = turtle.inspectUp()
	else success, detail = turtle.inspectDown() end

	if not success then error(detail) end

	local facings = {
		south = 0,
		east = 1,
		north = 2,
		west = 3,
	}

	local control = controlApi.connectControl(id)
	local remoteTurtle = control.turtle
	while not controlApi.waitForReady(id, 1) do
		print("waiting for " .. id)
	end

	while remoteTurtle.getFuelLevel() < mine2.digCuboidFuelRequired(depth, right, height) do
		print("refueling " .. id)
		while not mine2.selectItem(turtle, FUEL) do
			os.sleep(0.1)
			print("please provide fuel")
		end
		if side == 'front' then turtle.drop(1)
		elseif side == 'top' then turtle.dropUp(1)
		else turtle.dropDown(1) end
		mine2.selectItem(remoteTurtle, FUEL)
		remoteTurtle.refuel(1)
	end

	local nLeft = (facings[facing] - facings[detail.state.facing]) % 4
	return function()
		for i = 1,nLeft do
			remoteTurtle.turnLeft()
		end

		print(id .. ' started')

		control.shellRun("/firmware/programs/metamineCb " .. depth .. " " .. right .. " " .. height)

		-- remoteTurtle.turnLeft()
		-- remoteTurtle.turnLeft()
		-- remoteTurtle.turnLeft()
		-- remoteTurtle.turnLeft()
		-- remoteTurtle.turnRight()
		-- remoteTurtle.turnLeft()
		-- remoteTurtle.turnRight()
		-- remoteTurtle.turnLeft()
		-- remoteTurtle.turnRight()
		-- remoteTurtle.turnLeft()
		-- remoteTurtle.turnRight()
		-- remoteTurtle.turnLeft()

		
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

function forward()
	while turtle.dig() do end
	while not turtle.forward() do end
	mine2.removeUselessItems(turtle)
end
function up()
	while turtle.digUp() do end
	while not turtle.up() do end
	mine2.removeUselessItems(turtle)
end

forward()

for ch = 1, nChunksHeight-1 do
	local nForChunkHeight = gnForChunkHeight(ch)
	for k = 1, nForChunkHeight do
		up()
	end
end

for ch = nChunksHeight, 1, -1 do
	local nForChunkHeight = gnForChunkHeight(ch)

	if ch ~= nChunksHeight then
		for k = 2, nForChunkHeight do
			turtle.down()
		end

	end

	if nChunksRight ~= 1 then
		turtle.turnRight()
		for cr = 1, nChunksRight-1 do
			local nForChunkRight = gnForChunkRight(cr)
			for k = 1, nForChunkRight do
				forward()
			end
		end

		turtle.back()
		-- place forward
		table.insert(turtles, placeTurtle('front', depth, gnForChunkRight(nChunksRight), nForChunkHeight))
		--
		
		for cr = nChunksRight-1, 2, -1 do
			local nForChunkRight = gnForChunkRight(cr)
			for k = 1, nForChunkRight do
				turtle.back()
			end
			-- place forward
			table.insert(turtles, placeTurtle('front', depth, nForChunkRight, nForChunkHeight))
			--
		end
		local nForChunkRight = gnForChunkRight(1)
		for k = 2, nForChunkRight do
			turtle.back()
		end

		turtle.turnLeft()
	end

	if ch ~= 1 then
		turtle.down()
		-- place up
		table.insert(turtles, placeTurtle('top', depth, gnForChunkRight(1), nForChunkHeight))
		--
	end
end
local nForChunkRight = gnForChunkRight(1)
local nForChunkHeight = gnForChunkHeight(1)

turtle.back()
-- place forward
table.insert(turtles, placeTurtle('front', depth, nForChunkRight, nForChunkHeight))
--

print("Running turtles...")

parallel.waitForAll(unpack(turtles))
