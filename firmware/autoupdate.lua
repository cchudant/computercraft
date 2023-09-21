local control = require(".apis.control")

print("Finding updates...")
local success, peers = control.autoUpdate()

if not success then
	print("No new update found from " .. peers .. " peers.")
end
