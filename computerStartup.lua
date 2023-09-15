local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

local requireEnv
local function setPaths(firmware)
	shell.setPath(shell.path() .. ":" .. firmware .. "/programs")
	requireEnv = setmetatable({}, { __index = _ENV })
	print(requireEnv, requireEnv.require, require, firmware .. "/apis")
	local requireFn = require('cc.require').make(requireEnv, firmware .. "/apis")
	requireEnv.require = requireFn
end

local controlApi
if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	setPaths("/disk/firmware")
	controlApi = requireEnv.require("controlApi")
else
	setPaths("/firmware")
	controlApi = requireEnv.require("controlApi")
	controlApi.autoUpdate()
end

print("Running ControlAPI " .. controlApi.VERSION .. " on computer " .. os.getComputerID() .. ".")

parallel.waitForAny(
	function() controlApi.sourceTask(shell) end,
	function()
		if fs.exists("/autorun.lua") then
			os.run(requireEnv, "/autorun.lua")
		else
			os.run(requireEnv, shell.resolveProgram("shell"))
		end
	end
)
