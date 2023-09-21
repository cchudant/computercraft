local mine2 = require(".firmware.apis.mine2")

local depth, right, height = ...
if depth == nil or right == nil or height == nil then
	print("usage: clearLava <depth> <right> <height>")
	return
end

depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)

mine2.clearLava(turtle, {depth = depth, right = right, height = height})
