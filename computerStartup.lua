local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

local function setPaths(firmware)
	shell.setPath(shell.path() .. ":" .. firmware .. "/programs")
	local env = setmetatable({}, { __index = _ENV })
	require = require('cc.require').make(env, firmware .. "/apis")
	env.require = require
end

local controlApi
if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	setPaths("/disk/firmware")
	controlApi = require("controlApi")
else
	os.loadAPI("/firmware/apis/controlApi.lua")
	setPaths("/firmware")
	controlApi = require("controlApi")
	controlApi.autoUpdate()
end

print("Running ControlAPI " .. controlApi.VERSION .. " on computer " .. os.getComputerID() .. ".")

parallel.waitForAny(
	function() controlApi.sourceTask(shell) end,
	function()
		if fs.exists("autorun.lua") then
			shell.run("autorun")
		else
			shell.run("shell")
		end
	end
)
