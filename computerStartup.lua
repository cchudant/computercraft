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
	p.path = p.path ..
		";" .. firmwareDir .. "/?.lua;" .. firmwareDir .. "/?;" .. firmwareDir .. "/?/init.lua"

	return r, p
end

local newRequire, newPackage = newModule.make(
	_ENV,
	firmwareDir .. "/apis"
)
_G.require, _G.package = newRequire, newPackage
_ENV.require, _ENV.package = newRequire, newPackage

local originalDofile = dofile
local function newDofile(filename)
	if filename == "rom/modules/main/cc/require.lua" then
		return newModule
	end

	return originalDofile(filename)
end
dofile = newDofile

-- end hack

local control = require("apis.control")
if JUST_FLASHED == nil then
	control.autoUpdate()
end

print("Running control " .. control.VERSION .. " on computer " .. os.getComputerID() .. ".")

parallel.waitForAny(
	function() control.sourceTask(shell) end,
	function()
		if fs.exists("/autorun.lua") then
			os.run(_ENV, "/rom/programs/shell.lua", "/autorun.lua")
		else
			os.run(_ENV, "/rom/programs/shell.lua")
		end
	end
)
