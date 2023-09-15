local controlApi = require("controlApi")

print("Finding updates...")
local success, peers = controlApi.autoUpdate()

if not success then
	print("No new update found from " .. peers .. " peers.")
end
