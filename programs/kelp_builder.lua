os.loadAPI("/firmware/apis/kelp.lua")

local depth, right, height = ...
if depth == nil or right == nil or height == nil then
	print("usage: mine2 <depth> <right> <height>")
	return
end

depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)