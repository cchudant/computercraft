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
	while mine2.protectedDig('front') do end
	while not turtle.forward() do end
end
for d = 1,offsetHeight do
	while mine2.protectedDig('up') do end
	while not turtle.up() do end
end
if offsetRight > 0 then
	turtle.turnRight()
	for d = 1,offsetRight do
		while mine2.protectedDig('front') do end
		while not turtle.forward() do end
	end
	turtle.turnLeft()
end

print("starting")

mine2.digCuboid(turtle, {
	depth = depth, right = right, height = height,
	prepareSameLevel = function() end,
	prepareUpOne = function(funcs, isDownwards)
		if isDownwards then while mine2.protectedDig('down') do end
		else mine2.protectedDig('up') end
		funcs.up()
		if isDownwards then while mine2.protectedDig('down') do end
		else while mine2.protectedDig('up') do end end
	end,
	finish = function() mine2.removeUselessItems(turtle, true) end
})

print("finished")

local _, _, snd, nonce = controlApi.protocolReceive('metamine:back')

print("backing")

if offsetRight > 0 then
	turtle.turnLeft()
	for d = 1,offsetRight do
		while mine2.protectedDig('front') do end
		while not turtle.forward() do end
	end
	turtle.turnRight()
end
for d = 1,offsetHeight do
	while mine2.protectedDig('up') do end
	while not turtle.up() do end
end
for d = 1,offsetDepth do
	while mine2.protectedDig('front') do end
	while not turtle.forward() do end
end

print("back!")

controlApi.protocolSend(snd, 'metamine:backRep', nil, nonce)
