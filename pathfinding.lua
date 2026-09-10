local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local enabled = false
local qEnabled = true
local eEnabled = true

local ATTACK_RANGE = 11
local Q_RANGE = 11
local E_RANGE = 8

local Q_COOLDOWN = 1
local E_COOLDOWN = 1.5

local lastQ = 0
local lastE = 0

local character
local humanoid
local root

local function setupCharacter()
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
end

setupCharacter()

player.CharacterAdded:Connect(function()
	task.wait(1)
	setupCharacter()
end)

--------------------------------------------------
-- GUI
--------------------------------------------------

local oldGui = playerGui:FindFirstChild("PathfindingUI")

if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "PathfindingUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 240)
frame.Position = UDim2.new(0, 30, 0.5, -120)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 45)
title.BackgroundTransparency = 1
title.Text = "Pathfinding"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 28)
status.Position = UDim2.fromOffset(10, 45)
status.BackgroundTransparency = 1
status.Text = "Status: OFF"
status.TextColor3 = Color3.fromRGB(190,190,190)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.Parent = frame

local function createButton(text, y)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -20, 0, 40)
	button.Position = UDim2.fromOffset(10, y)
	button.BackgroundColor3 = Color3.fromRGB(35,35,35)
	button.TextColor3 = Color3.fromRGB(255,255,255)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 15
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = frame

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = button

	return button
end

local mainButton = createButton("Start", 80)
local qButton = createButton("Q Attack: ON", 130)
local eButton = createButton("E Attack: ON", 180)

mainButton.MouseButton1Click:Connect(function()
	enabled = not enabled

	if enabled then
		mainButton.Text = "Stop"
		status.Text = "Status: Searching..."
	else
		mainButton.Text = "Start"
		status.Text = "Status: OFF"

		if humanoid and root then
			humanoid:MoveTo(root.Position)
		end
	end
end)

qButton.MouseButton1Click:Connect(function()
	qEnabled = not qEnabled
	qButton.Text = "Q Attack: " .. (qEnabled and "ON" or "OFF")
end)

eButton.MouseButton1Click:Connect(function()
	eEnabled = not eEnabled
	eButton.Text = "E Attack: " .. (eEnabled and "ON" or "OFF")
end)

--------------------------------------------------
-- DRAGGING
--------------------------------------------------

local dragging = false
local dragStart
local startPosition

title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPosition = frame.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart

		frame.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

--------------------------------------------------
-- ATTACKS
--------------------------------------------------

local function pressKey(key)
	VirtualInputManager:SendKeyEvent(true, key, false, game)
	task.wait(0.05)
	VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function faceTarget(targetRoot)
	if not root or not targetRoot then
		return
	end

	local lookPosition = Vector3.new(
		targetRoot.Position.X,
		root.Position.Y,
		targetRoot.Position.Z
	)

	root.CFrame = CFrame.lookAt(root.Position, lookPosition)
end

local function attack(targetRoot, distance)
	faceTarget(targetRoot)

	local now = os.clock()

	if qEnabled and distance <= Q_RANGE and now - lastQ >= Q_COOLDOWN then
		lastQ = now
		pressKey(Enum.KeyCode.Q)
	end

	if eEnabled and distance <= E_RANGE and now - lastE >= E_COOLDOWN then
		lastE = now
		pressKey(Enum.KeyCode.E)
	end
end

--------------------------------------------------
-- TARGET FINDER
--------------------------------------------------

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

			if enemyHumanoid and enemyRoot and enemyHumanoid.Health > 0 then
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

--------------------------------------------------
-- PATHFINDING
--------------------------------------------------

local function createPath(destination)
	if not root then
		return nil
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 4
	})

	local success = pcall(function()
		path:ComputeAsync(root.Position, destination)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		return path
	end

	return nil
end

--------------------------------------------------
-- MAIN LOOP
--------------------------------------------------

task.spawn(function()
	while task.wait(0.15) do
		if not enabled then
			continue
		end

		if
			not character
			or not character.Parent
			or not humanoid
			or humanoid.Health <= 0
			or not root
		then
			continue
		end

		local target, targetHumanoid, targetRoot, distance =
			getClosestTarget()

		if not target or not targetRoot then
			status.Text = "Status: No target"
			continue
		end

		status.Text =
			"Target: "
			.. target.Name
			.. " | "
			.. math.floor(distance)
			.. " studs"

		if distance <= ATTACK_RANGE then
			humanoid:MoveTo(root.Position)
			attack(targetRoot, distance)
			continue
		end

		local path = createPath(targetRoot.Position)

		if path then
			local waypoints = path:GetWaypoints()

			for i = 2, math.min(#waypoints, 4) do
				if not enabled then
					break
				end

				if
					not target.Parent
					or targetHumanoid.Health <= 0
				then
					break
				end

				local currentDistance =
					(targetRoot.Position - root.Position).Magnitude

				if currentDistance <= ATTACK_RANGE then
					break
				end

				local waypoint = waypoints[i]

				if waypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end

				humanoid:MoveTo(waypoint.Position)

				task.wait(0.12)
			end
		else
			status.Text = "Status: Direct movement"
			humanoid:MoveTo(targetRoot.Position)
		end
	end
end)
