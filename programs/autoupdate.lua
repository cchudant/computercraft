print("Finding updates...")
success, peers = controlApi.autoUpdate()

if not sucess then
	print("No new update found from " .. peers .. " peers.")
end
