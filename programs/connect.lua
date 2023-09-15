local controlApi = require("controlApi")

local computerID = ...
if computerID == nil then
	print("usage: connect <computerID>")
	return 1
end

controlApi.remoteTermClient(tonumber(computerID) --[[@as number]])
