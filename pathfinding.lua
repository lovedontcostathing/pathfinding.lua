local function getClosestTarget()
	if not root then
		return nil
	end

	local closestModel
	local closestHumanoid
	local closestRoot
	local shortest = math.huge

	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("Model") and object ~= character then

			local enemyHumanoid = object:FindFirstChildOfClass("Humanoid")

			local enemyRoot =
				object:FindFirstChild("HumanoidRootPart")
				or object:FindFirstChild("UpperTorso")
				or object:FindFirstChild("Torso")
				or object.PrimaryPart

			if enemyHumanoid
				and enemyRoot
				and enemyHumanoid.Health > 0
			then

				-- Don't target players
				if not Players:GetPlayerFromCharacter(object) then

					local distance =
						(enemyRoot.Position - root.Position).Magnitude

					if distance < shortest then
						shortest = distance
						closestModel = object
						closestHumanoid = enemyHumanoid
						closestRoot = enemyRoot
					end
				end
			end
		end
	end

	return closestModel, closestHumanoid, closestRoot, shortest
end
