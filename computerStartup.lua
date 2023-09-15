local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

local childEnv = {}
setmetatable(childEnv, { __index = _ENV })
childEnv.shell = shell
childEnv.multishell = multishell

local function setPaths(firmware)
	shell.setPath(shell.path() .. ":" .. firmware .. "/programs")
	print(childEnv, childEnv.require, require, firmware .. "/apis")
	require = require('cc.require').make(childEnv, firmware .. "/apis")
	package = require
	childEnv.require = require
	childEnv.package = package
end

local controlApi
if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	setPaths("/disk/firmware")
	controlApi = childEnv.require("controlApi")
else
	setPaths("/firmware")
	controlApi = childEnv.require("controlApi")
	controlApi.autoUpdate()
end

print("Running ControlAPI " .. controlApi.VERSION .. " on computer " .. os.getComputerID() .. ".")

parallel.waitForAny(
	function() controlApi.sourceTask(shell) end,
	function()
		if fs.exists("/autorun.lua") then
			-- shell.run("autorun")
			os.run(childEnv, "/autorun.lua")
		else
			os.run(childEnv, shell.resolveProgram("shell"))
		end
	end
)
