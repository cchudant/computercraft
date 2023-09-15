local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

local childEnv = {}
setmetatable(childEnv, { __index = _ENV })
local newShell = {}
setmetatable(newShell, { __index = shell })
childEnv.shell = shell
childEnv.multishell = multishell

local load = load
function childEnv.load(ld, source, mode, env)
	print(ld, source, mode, env)
	if env == nil then
		env = childEnv
	end
	env.require = childEnv.require
	env.package = childEnv.package
	return load(ld, source, mode, env)
end

local function setPaths(firmware)
	shell.setPath(shell.path() .. ":" .. firmware .. "/programs")
	local newRequire, newPackage = require('cc.require').make(childEnv, firmware .. "/apis")
	newPackage.path = newPackage.path .. ";" .. firmware .. "/apis/?.lua;" .. firmware .. "/apis/?;" .. firmware .. "/apis/?/init.lua"
	childEnv.require = newRequire
	childEnv.package = newPackage
	print('hello', newPackage.path)
end

if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	setPaths("/disk/firmware")
else
	setPaths("/firmware")
end

local controlApi = childEnv.require("controlApi")
if JUST_FLASHED == nil then
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
