os.loadAPI("/firmware/apis/mine2.lua")

local depth, right, height = ...
if depth == nil or right == nil or height == nil then
	print("usage: metamine <depth> <right> <height>")
	return
end

function dig()
	while turtle.dig() do end
end
function digDown()
	while turtle.digDown() do end
end
function digUp()
	while turtle.digUp() do end
end
mine2.digCuboid(turtle, {
	depth = depth, right = right, height = height,
	prepareSameLevel = function() end,
	prepareUpOne = function(funcs, isDownwards)
		if isDownwards then digDown() 
		else digUp() end
		funcs.up()
		if isDownwards then digDown() 
		else digUp() end
	end,
	finish = function() end
})
