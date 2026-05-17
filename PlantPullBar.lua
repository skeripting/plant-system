-- Connected Discord-GitHub
-- Discord: script_ing | Roblox: script_ingdev
return function(_p)
	-- _p is a dictionary that contains keys that are module names and values that are the required modules. It's my own framework.
	-- This way, I can access module X by using _p.X, etc.
	local PlantPullBar = {}

	local player = game.Players.LocalPlayer
	local playerGui = player.PlayerGui

	local barGUI = playerGui:WaitForChild("PlantBarGUI")
	local UIGradients = game.ReplicatedStorage.UIGradients

	local userInputService = game:GetService("UserInputService")
	local runService = game:GetService("RunService")

	type GradientIndex = number
	type Gradient = "White" | "Yellow" | "Green" | "PullZone"

	local GRADIENTS_FROM_INDEX: { Gradient } =
		{ -- This table allows me to get the gradient name from the index specified in bar data.
			[1] = "White",
			[2] = "Yellow",
			[3] = "Green",
			[4] = "PullZone",
		}

	-- To create a bar, there's actually 20 Frame entries. This is because the bar is made up of 20 evenly spaced frames.
	-- I made it so that we can change the num frames in a bar here.
	local N_ENTRIES_IN_BAR = 20

	local INDICATOR_X_MIN = 0
	local INDICATOR_X_MAX = 1

	-- Physics constants. I tuned these through a bunch of testing.
	local PUSH_IMPULSE = 1.35
	local HOLD_ACCEL = 4.2
	local RETURN_ACCEL = 6.8
	local DRAG = 10.5
	local BOUNCE = 0.25

	-- Pull zone constants
	local TARGET_HOLD_SECONDS = 3 -- How long (in seconds) you have to hold in the pull zone for for a success
	local FAIL_SECONDS = 7 -- How long (in seconds) you have to get a success until auto failure

	local COLOR_RED = Color3.fromRGB(255, 0, 0)
	local COLOR_YELLOW = Color3.fromRGB(255, 255, 0)
	local COLOR_GREEN = Color3.fromRGB(0, 255, 0)

	local function Clamp01(x: number): number
		return math.clamp(x, 0, 1)
	end

	-- Linear interpolation of color3
	-- I gave a tutorial on lerp here on YT https://www.youtube.com/watch?v=8jpJhgMuVDU
	local function LerpColor(a: Color3, b: Color3, t: number): Color3
		t = Clamp01(t)
		return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
	end

	-- Turns a progress to a color3.
	local function ProgressToColor(progress: number): Color3
		progress = Clamp01(progress)
		if progress <= 0.5 then
			return LerpColor(COLOR_RED, COLOR_YELLOW, progress / 0.5)
		end
		return LerpColor(COLOR_YELLOW, COLOR_GREEN, (progress - 0.5) / 0.5)
	end

	local function GetPullZoneRange(barData: { GradientIndex }): (number, number)
		local startIndex: number? = nil
		local endIndex: number? = nil

		for i = 1, #barData do
			if barData[i] == 4 then
				if startIndex == nil then
					startIndex = i
				end
				endIndex = i
			end
		end

		assert(startIndex ~= nil and endIndex ~= nil, "BarData has no PullZone entries (4)")

		local startScale = (startIndex - 1) / N_ENTRIES_IN_BAR
		local endScale = endIndex / N_ENTRIES_IN_BAR

		startScale = Clamp01(startScale)
		endScale = Clamp01(endScale)

		return startScale, endScale
	end

	-- This function generates the bar, given bar data.
	-- Each bar is comprised of different frames.
	-- Bar data is calculated server-sided.
	function PlantPullBar:GenerateBar(barData: { GradientIndex })
		local frame = barGUI.PlantPullBar.Frame

		for _, child in frame:GetChildren() do
			if child:IsA("Frame") and child.Name ~= "temp" then
				child:Destroy()
			end
		end

		for i = 1, #barData do
			local gradientIndex: GradientIndex = barData[i]
			local gradientName: Gradient = GRADIENTS_FROM_INDEX[gradientIndex]

			local temp: Frame = frame.temp:Clone()
			temp.Parent = frame
			temp.Name = i

			local gradient: UIGradient = UIGradients[gradientName]:Clone()
			gradient.Parent = temp

			temp.Visible = true

			task.wait(0.01)
		end
	end

	-- Some cool dopamine stuff for when there was a successful plant pull
	function PlantPullBar:OnSuccess()
		local pullZoneProgressBar = barGUI.PullZoneHeldProgressBar

		local successRemarks = { "Awesome!", "Perfect!", "Nice!", "Great job!" }

		local h = math.random(35, 299) / 360
		local s1 = 199 / 255
		local v1 = 255 / 255

		local s2 = 223 / 255
		local v2 = 170 / 255

		barGUI.indicator.Text = successRemarks[math.random(1, #successRemarks)]:upper()

		barGUI.indicator.TextColor3 = Color3.fromHSV(h, s1, v1)
		barGUI.indicator.UIStroke.Color = Color3.fromHSV(h, s2, v2)

		barGUI.indicator.Position = UDim2.new(0.3 + math.random() / 4, 0, 0.3 + math.random() / 2, 0)

		_p.Utilities.sound(4612378086)

		task.spawn(function()
			_p.SimulatorGUI:AnimStatIncrease(barGUI.indicator, barGUI.indicator.Position, true)
		end)

		_p.Network:post("onSuccessfulPlantPull")

		pullZoneProgressBar.Visible = false

		self:Hide()

		task.wait(1)

		_p.Utilities.lookBackAtMe(1) -- This is a function that makes the camera look back at the player over 1 second.
	end

	-- Failure :(
	function PlantPullBar:OnFailure()
		local pullZoneProgressBar = barGUI.PullZoneHeldProgressBar

		barGUI.indicator.Text = "FAILED!"
		barGUI.indicator.TextColor3 = COLOR_RED
		barGUI.indicator.UIStroke.Color = COLOR_RED

		barGUI.indicator.Position = UDim2.new(0.32 + math.random() / 5, 0, 0.45 + math.random() / 4, 0)

		_p.Utilities.sound(138719267809645)

		task.spawn(function()
			_p.SimulatorGUI:AnimStatIncrease(barGUI.indicator, barGUI.indicator.Position, false)
		end)

		_p.Network:post("onFailedPlantPull")

		pullZoneProgressBar.Visible = false

		self:Hide()

		task.wait(1)

		_p.Utilities.lookBackAtMe(1)
	end

	-- Hiding the plant pull bar
	function PlantPullBar:Hide()
		local bar = barGUI.PlantPullBar

		_p.Spring.target(bar, 0.7, 2, {
			Position = UDim2.new(0.307, 0, -0.5, 0),
		})

		_p.CutsceneClient:HideBlackBars()
		_p.CameraShaker:EndEarthquake(0.05)
	end

	-- Showing the plant pull bar
	function PlantPullBar:Show(barData: { GradientIndex })
		local bar = barGUI.PlantPullBar
		local indicator = bar.Indicator

		local pullZoneProgressBar = barGUI.PullZoneHeldProgressBar
		local pullZoneProgressBarFill: Frame = pullZoneProgressBar.fill

		_p.Spring.target(bar, 0.7, 2, { -- Spring module allows me to create these cool animations using Hooke's law
			Position = UDim2.new(0.307, 0, 0.1, 0),
		})

		self:GenerateBar(barData)

		local pullZoneStart, pullZoneEnd = GetPullZoneRange(barData)

		local x = Clamp01(indicator.Position.X.Scale)
		local v = 0

		local isHolding = false
		local holdTimer = 0
		local succeeded = false

		local timeSinceShow = 0

		local function ResetPullZoneProgress()
			holdTimer = 0
			pullZoneProgressBar.Visible = false
			pullZoneProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
			pullZoneProgressBarFill.BackgroundColor3 = COLOR_RED
		end

		local function UpdatePullZoneProgress(dt: number)
			local inPullZone = (x >= pullZoneStart and x <= pullZoneEnd)

			if not inPullZone then
				ResetPullZoneProgress()
				return
			end

			holdTimer += dt
			pullZoneProgressBar.Visible = true

			local progress = Clamp01(holdTimer / TARGET_HOLD_SECONDS)
			pullZoneProgressBarFill.Size = UDim2.new(progress, 0, 1, 0)
			pullZoneProgressBarFill.BackgroundColor3 = ProgressToColor(progress)

			if holdTimer >= TARGET_HOLD_SECONDS then
				succeeded = true
				self:OnSuccess()
			end
		end

		local function SetIndicatorX(newX: number)
			x = Clamp01(newX)
			indicator.Position = UDim2.new(x, 0, indicator.Position.Y.Scale, indicator.Position.Y.Offset)
		end

		SetIndicatorX(x)
		ResetPullZoneProgress()

		if self._inputBeganConnection then
			self._inputBeganConnection:Disconnect()
			self._inputBeganConnection = nil
		end

		if self._inputEndedConnection then
			self._inputEndedConnection:Disconnect()
			self._inputEndedConnection = nil
		end

		if self._barMovementConnection then
			self._barMovementConnection:Disconnect()
			self._barMovementConnection = nil
		end

		self._inputBeganConnection = userInputService.InputBegan:Connect(
			function(input: InputObject, gameProcessedEvent: boolean)
				if gameProcessedEvent then
					return
				end

				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					isHolding = true
					v += PUSH_IMPULSE
				end
			end
		)

		self._inputEndedConnection = userInputService.InputEnded:Connect(
			function(input: InputObject, gameProcessedEvent: boolean)
				if gameProcessedEvent then
					return
				end

				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					isHolding = false
				end
			end
		)

		-- This is the main bar movement stuff. It does a bunch of physics and sets the indicator's x position accordingly.
		self._barMovementConnection = runService.RenderStepped:Connect(function(dt: number)
			if succeeded then
				return
			end

			timeSinceShow += dt

			local accel = 0

			if isHolding then
				accel += HOLD_ACCEL
			else
				accel -= RETURN_ACCEL
			end

			accel -= v * DRAG -- I added drag for realism.

			-- velocity and x are just physics equations and math.
			v += accel * dt
			x += v * dt

			if x <= INDICATOR_X_MIN then
				x = INDICATOR_X_MIN
				if v < 0 then
					v = -v * BOUNCE
				end
			elseif x >= INDICATOR_X_MAX then
				x = INDICATOR_X_MAX
				if v > 0 then
					v = -v * BOUNCE
				end
			end

			SetIndicatorX(x)

			local inPullZone = (x >= pullZoneStart and x <= pullZoneEnd)

			if timeSinceShow >= FAIL_SECONDS then
				succeeded = true
				self:OnFailure()
				return
			end

			UpdatePullZoneProgress(dt)
		end)
	end

	return PlantPullBar
end
