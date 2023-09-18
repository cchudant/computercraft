local mine2 = require("apis.mine2")

local depth, right, height = ...
if depth == nil or right == nil or height == nil then
	print("usage: mine2 <depth> <right> <height>")
	return
end

depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)

mine2.digCuboid(turtle, {depth = depth, right = right, height = height})
