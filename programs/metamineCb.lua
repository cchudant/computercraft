os.loadAPI("/firmware/apis/mine2.lua")

local offsetDepth, offsetRight, offsetHeight, depth, right, height = ...
if offsetDepth == nil or offsetRight == nil or offsetHeight == nil or depth == nil or right == nil or height == nil then
	print("usage: metamine <offsetDepth> <offsetRight> <offsetHeight> <depth> <right> <height>")
	return
end

offsetDepth = tonumber(offsetDepth)
offsetRight = tonumber(offsetRight)
offsetHeight = tonumber(offsetHeight)
depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)

print(offsetDepth, offsetRight, offsetHeight, depth, right, height)

for d = 1,offsetDepth do
	mine2.protectedDig('front')
	while not turtle.forward() do end
end
for d = 1,offsetHeight do
	mine2.protectedDig('up')
	while not turtle.up() do end
end
if offsetRight > 0 then
	turtle.turnRight()
	for d = 1,offsetRight do
		mine2.protectedDig('front')
		while not turtle.forward() do end
	end
	turtle.turnLeft()
end

print("starting")

mine2.digCuboid(turtle, {
	depth = depth, right = right, height = height,
	prepareSameLevel = function() end,
	prepareUpOne = function(funcs, isDownwards)
		if isDownwards then mine2.protectedDig('down')
		else mine2.protectedDig('up') end
		funcs.up()
		if isDownwards then mine2.protectedDig('down')
		else mine2.protectedDig('up') end
	end,
	finish = function() mine2.removeUselessItems(turtle, true) end
})


local _, _, snd, nonce = controlApi.protocolReceive('metamine:back')

print("backing")

if offsetRight > 0 then
	turtle.turnLeft()
	for d = 1,offsetRight do
		mine2.protectedDig('front')
		while not turtle.forward() do end
	end
	turtle.turnRight()
end
for d = 1,offsetHeight do
	mine2.protectedDig('up')
	while not turtle.up() do end
end
for d = 1,offsetDepth do
	mine2.protectedDig('front')
	while not turtle.forward() do end
end

print("back!")

controlApi.protocolSend(snd, 'metamine:backRep', nil, nonce)
