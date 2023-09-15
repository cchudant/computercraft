local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

local controlApi
if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	os.loadAPI("/disk/firmware/apis/controlApi.lua")
	shell.setPath(shell.path() .. ":/disk/firmware/programs")
	package.path = package.path .. ";/disk/firmware/apis/?.lua"
	controlApi = require("controlApi")
else
	os.loadAPI("/firmware/apis/controlApi.lua")
	shell.setPath(shell.path() .. ":/firmware/programs")
	package.path = package.path .. ";/firmware/apis/?.lua"
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
