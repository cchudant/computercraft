local control = require(".firmware.apis.control")

local computerID = ...
if computerID == nil then
	print("usage: connect <computerID>")
	return 1
end

control.remoteTermClient(tonumber(computerID) --[[@as number]])
