local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	os.loadAPI("/disk/firmware/apis/controlApi.lua")
	shell.setPath(shell.path() .. ":/disk/firmware/programs")
else
	os.loadAPI("/firmware/apis/controlApi.lua")
	shell.setPath(shell.path() .. ":/firmware/programs")

	controlApi.autoUpdate()
end

print("Running ControlAPI " .. controlApi.VERSION .. " on computer " .. os.getComputerID() .. ".")

parallel.waitForAny(
	function() controlApi._sourceTask(shell) end,
	function()
		if fs.exists("autorun.lua") then
			shell.run("autorun")
		else
			shell.run("shell")
		end
	end
)
