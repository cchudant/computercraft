local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

local firmwareDir
if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	firmwareDir = "/disk/firmware"
else
	firmwareDir = "/firmware"
end

shell.setPath(shell.path() .. ":" .. firmwareDir .. "/programs")

-- fix require importing with the shell program
-- this is a hack

local module = require("cc.require")
local newModule = setmetatable({}, { __index = module })
function newModule.make(...)
	local r, p = module.make(...)
	p.loaded["cc.require"] = newModule
	p.path = p.path .. ";" .. firmwareDir .. "/apis/?.lua;" .. firmwareDir .. "/apis/?;" .. firmwareDir .. "/apis/?/init.lua"
	return r, p
end

local newRequire, newPackage = newModule.make(childEnv, firmwareDir .. "/apis")
require, package = newRequire, newPackage

local originalDofile = dofile
local function newDofile(filename)
	if filename == "rom/modules/main/cc/require.lua" then
		return newModule
	end

	return originalDofile(filename)
end
dofile = newDofile

-- end hack

local controlApi = require("controlApi")
if JUST_FLASHED == nil then
	controlApi.autoUpdate()
end

print("Running ControlAPI " .. controlApi.VERSION .. " on computer " .. os.getComputerID() .. ".")

parallel.waitForAny(
	function() controlApi.sourceTask(shell) end,
	function()
		if fs.exists("/autorun.lua") then
			os.run(_ENV, "/rom/programs/shell.lua", "/autorun.lua")
		else
			os.run(_ENV, "/rom/programs/shell.lua")
		end
	end
)
