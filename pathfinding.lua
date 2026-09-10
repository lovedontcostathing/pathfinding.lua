local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local function pressKey(key)
	VirtualInputManager:SendKeyEvent(true, key, false, game)
	task.wait(0.05)
	VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function getClosestEnemy(maxDistance)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local closest
	local closestDistance = maxDistance or 15

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= character then
			local humanoid = obj:FindFirstChildOfClass("Humanoid")
			local enemyRoot = obj:FindFirstChild("HumanoidRootPart")

			if humanoid and enemyRoot and humanoid.Health > 0 then
				local distance = (enemyRoot.Position - root.Position).Magnitude

				if distance < closestDistance then
					closest = obj
					closestDistance = distance
				end
			end
		end
	end

	return closest, closestDistance
end

while task.wait(0.15) do
	local enemy, distance = getClosestEnemy(12)

	if enemy then
		if distance <= 10 then
			pressKey(Enum.KeyCode.Q)
			task.wait(0.4)
		end

		if distance <= 7 then
			pressKey(Enum.KeyCode.E)
			task.wait(0.6)
		end
	end
end
