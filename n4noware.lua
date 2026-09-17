--[[
	n4noware
	A small Roblox interface library, structured so it can be hosted as a
	single raw file and loaded the same way Rayfield is:

		local N4noware = loadstring(game:HttpGet('https://your-host/n4noware'))()

		local Window = N4noware:CreateWindow({ Name = "My Hub" })
		local Tab = Window:CreateTab("Main")
		Tab:CreateButton({ Name = "Do thing", Callback = function() end })

	Everything below `return N4noware` at the bottom is the whole public
	surface. Nothing runs on its own until a caller calls :CreateWindow().
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

--==================================================
-- THEME
--==================================================

local Theme = {
	Background = Color3.fromRGB(5, 8, 6),
	Window = Color3.fromRGB(9, 13, 10),
	Surface = Color3.fromRGB(13, 18, 15),
	SurfaceHover = Color3.fromRGB(20, 28, 22),

	Border = Color3.fromRGB(42, 58, 46),

	Text = Color3.fromRGB(235, 242, 237),
	Muted = Color3.fromRGB(132, 146, 137),

	Accent = Color3.fromRGB(66, 225, 120),
	AccentBright = Color3.fromRGB(105, 255, 150),
	AccentDark = Color3.fromRGB(24, 67, 39),

	Danger = Color3.fromRGB(215, 70, 70),
}

--==================================================
-- UTILITIES
--==================================================

local function New(className, properties, parent)
	local object = Instance.new(className)

	for property, value in pairs(properties or {}) do
		object[property] = value
	end

	object.Parent = parent

	return object
end

local function Corner(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object

	return corner
end

local function Stroke(object, transparency, thickness)
	local stroke = Instance.new("UIStroke")

	stroke.Color = Theme.Border
	stroke.Transparency = transparency or 0
	stroke.Thickness = thickness or 1

	stroke.Parent = object

	return stroke
end

local function Tween(object, duration, properties, style, direction)
	return TweenService:Create(
		object,
		TweenInfo.new(
			duration,
			style or Enum.EasingStyle.Quart,
			direction or Enum.EasingDirection.Out
		),
		properties
	)
end

local function IsPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

--==================================================
-- LIBRARY TABLE
--==================================================
-- One publicly returned table. Everything else (Theme, New, Corner, etc.)
-- stays local to this file/closure -- library users only ever touch what
-- hangs off N4noware, Window, and Tab.

local N4noware = {}

--==================================================
-- CreateWindow
--==================================================

function N4noware:CreateWindow(config)
	config = config or {}

	local WindowConfig = {
		Name = config.Name or "n4noware",
		LoadingSubtitle = config.LoadingSubtitle or "interface system",
		ToggleUIKeybind = config.ToggleUIKeybind or Enum.KeyCode.RightControl,
	}

	--==============================
	-- Per-window state
	--==============================
	-- Every CreateWindow() call gets its own ScreenGui, its own connection
	-- list, and its own drag controller. Two windows from two separate
	-- scripts don't share or clash with each other's listeners.

	local Connections = {}

	local function Track(connection)
		table.insert(Connections, connection)
		return connection
	end

	local function Cleanup()
		for _, connection in ipairs(Connections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end

		table.clear(Connections)
	end

	local PlayerGui = Player:WaitForChild("PlayerGui")

	local ExistingName = "N4noware_" .. WindowConfig.Name
	local Existing = PlayerGui:FindFirstChild(ExistingName)
	if Existing then
		Existing:Destroy()
	end

	local Gui = New("ScreenGui", {
		Name = ExistingName,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	}, PlayerGui)

	Gui.Destroying:Connect(Cleanup)

	--==============================
	-- Shared drag controller (window + resize + orb; tabs don't pop
	-- out as separate windows here, so there's no per-tab listener
	-- multiplication to worry about)
	--==============================

	local ActiveDrags = {}

	local function RegisterDrag(target, onStart, onMove)
		Track(target.InputBegan:Connect(function(input)
			if not IsPointer(input) then
				return
			end

			ActiveDrags[target] = {
				Start = input.Position,
				Origin = onStart(),
				OnMove = onMove
			}
		end))
	end

	Track(UIS.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		for _, drag in pairs(ActiveDrags) do
			drag.OnMove(drag.Origin, input.Position - drag.Start)
		end
	end))

	Track(UIS.InputEnded:Connect(function(input)
		if IsPointer(input) then
			table.clear(ActiveDrags)
		end
	end))

	--==============================
	-- Frame
	--==============================

	local WindowFrame = New("Frame", {
		Name = "MainWindow",
		Size = UDim2.fromOffset(460, 320),
		Position = UDim2.new(0.5, -230, 0.5, -160),
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0
	}, Gui)

	Corner(WindowFrame, 15)
	Stroke(WindowFrame, 0.08)

	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Window),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 10, 8))
		})
	}, WindowFrame)

	local GlowLine = New("Frame", {
		Size = UDim2.new(1, -30, 0, 2),
		Position = UDim2.fromOffset(15, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0
	}, WindowFrame)

	Corner(GlowLine, 3)

	--==============================
	-- Header
	--==============================

	local Header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		ZIndex = 5
	}, WindowFrame)

	New("TextLabel", {
		Size = UDim2.fromOffset(35, 54),
		Position = UDim2.fromOffset(13, 0),
		BackgroundTransparency = 1,
		Text = "N4",
		TextColor3 = Theme.Accent,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		ZIndex = 6
	}, Header)

	New("TextLabel", {
		Size = UDim2.new(1, -115, 0, 21),
		Position = UDim2.fromOffset(52, 7),
		BackgroundTransparency = 1,
		Text = WindowConfig.Name,
		TextColor3 = Theme.Text,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6
	}, Header)

	New("TextLabel", {
		Size = UDim2.new(1, -115, 0, 17),
		Position = UDim2.fromOffset(52, 29),
		BackgroundTransparency = 1,
		Text = WindowConfig.LoadingSubtitle,
		TextColor3 = Theme.Muted,
		TextSize = 9,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6
	}, Header)

	local Close = New("TextButton", {
		Size = UDim2.fromOffset(29, 29),
		Position = UDim2.new(1, -38, 0, 12),
		BackgroundColor3 = Theme.SurfaceHover,
		BorderSizePixel = 0,
		Text = "×",
		TextColor3 = Theme.Muted,
		TextSize = 17,
		Font = Enum.Font.GothamMedium,
		AutoButtonColor = false,
		ZIndex = 7
	}, Header)

	Corner(Close, 8)

	Close.MouseEnter:Connect(function()
		Tween(Close, 0.14, { BackgroundColor3 = Theme.Danger, TextColor3 = Theme.Text }):Play()
	end)

	Close.MouseLeave:Connect(function()
		Tween(Close, 0.14, { BackgroundColor3 = Theme.SurfaceHover, TextColor3 = Theme.Muted }):Play()
	end)

	RegisterDrag(Header,
		function()
			return WindowFrame.Position
		end,
		function(origin, delta)
			WindowFrame.Position = UDim2.new(
				origin.X.Scale, origin.X.Offset + delta.X,
				origin.Y.Scale, origin.Y.Offset + delta.Y
			)
		end
	)

	--==============================
	-- Navigation (tabs get added here as they're created)
	--==============================

	local Navigation = New("Frame", {
		Name = "Navigation",
		Size = UDim2.new(1, -28, 0, 40),
		Position = UDim2.fromOffset(14, 68),
		BackgroundTransparency = 1,
		ZIndex = 5
	}, WindowFrame)

	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 7)
	}, Navigation)

	local Body = New("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -28, 1, -126),
		Position = UDim2.fromOffset(14, 118),
		BackgroundTransparency = 1,
		ZIndex = 4
	}, WindowFrame)

	--==============================
	-- Toggle keybind + minimize orb
	--==============================

	local Orb = New("TextButton", {
		Name = "N4Orb",
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(0.5, -26, 0.5, -26),
		BackgroundColor3 = Theme.AccentDark,
		BorderSizePixel = 0,
		Text = "N",
		TextColor3 = Theme.Accent,
		TextSize = 19,
		Font = Enum.Font.GothamBold,
		Visible = false,
		AutoButtonColor = false,
		ZIndex = 150
	}, Gui)

	Corner(Orb, 30)
	Stroke(Orb, 0.05, 1.5).Color = Theme.Accent

	local Minimized = false

	local function SetMinimized(state)
		Minimized = state

		if Minimized then
			WindowFrame.Visible = false
			Orb.Visible = true
			Orb.Size = UDim2.fromOffset(0, 0)

			Tween(Orb, 0.3, { Size = UDim2.fromOffset(52, 52) }, Enum.EasingStyle.Back):Play()
		else
			Tween(Orb, 0.2, { Size = UDim2.fromOffset(0, 0) }):Play()

			task.delay(0.2, function()
				Orb.Visible = false
				Orb.Size = UDim2.fromOffset(52, 52)
				WindowFrame.Visible = true
			end)
		end
	end

	Close.Activated:Connect(function() SetMinimized(true) end)
	Orb.Activated:Connect(function() SetMinimized(false) end)

	RegisterDrag(Orb,
		function()
			return Orb.Position
		end,
		function(origin, delta)
			Orb.Position = UDim2.new(
				origin.X.Scale, origin.X.Offset + delta.X,
				origin.Y.Scale, origin.Y.Offset + delta.Y
			)
		end
	)

	Track(UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == WindowConfig.ToggleUIKeybind then
			SetMinimized(not Minimized)
		end
	end))

	--==============================
	-- Window object
	--==============================

	local Window = {}
	local ActiveTabButton = nil

	--==============================
	-- Window:CreateTab
	--==============================

	function Window:CreateTab(name)
		local TabButton = New("TextButton", {
			Size = UDim2.fromOffset(104, 38),
			BackgroundColor3 = Theme.Surface,
			BorderSizePixel = 0,
			Text = name,
			TextColor3 = Theme.Muted,
			TextSize = 10,
			Font = Enum.Font.GothamMedium,
			AutoButtonColor = false,
			ZIndex = 6
		}, Navigation)

		Corner(TabButton, 8)
		Stroke(TabButton, 0.5)

		local Indicator = New("Frame", {
			Size = UDim2.fromOffset(3, 16),
			Position = UDim2.new(0, 5, 0.5, -8),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 7
		}, TabButton)

		Corner(Indicator, 3)

		local Page = New("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Theme.Accent,
			Visible = false,
			ZIndex = 4
		}, Body)

		New("UIListLayout", {
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder
		}, Page)

		TabButton.MouseEnter:Connect(function()
			if ActiveTabButton ~= TabButton then
				Tween(TabButton, 0.13, { BackgroundColor3 = Theme.SurfaceHover }):Play()
			end
		end)

		TabButton.MouseLeave:Connect(function()
			if ActiveTabButton ~= TabButton then
				Tween(TabButton, 0.13, { BackgroundColor3 = Theme.Surface }):Play()
			end
		end)

		local function Activate()
			if ActiveTabButton == TabButton then
				return
			end

			for _, sibling in ipairs(Navigation:GetChildren()) do
				if sibling:IsA("TextButton") then
					local siblingIndicator = sibling:FindFirstChild("Frame")
					Tween(sibling, 0.15, { BackgroundColor3 = Theme.Surface, TextColor3 = Theme.Muted }):Play()
				end
			end

			for _, page in ipairs(Body:GetChildren()) do
				if page:IsA("ScrollingFrame") then
					page.Visible = false
				end
			end

			ActiveTabButton = TabButton
			Page.Visible = true

			Tween(TabButton, 0.18, { BackgroundColor3 = Theme.AccentDark, TextColor3 = Theme.Text }):Play()
			Tween(Indicator, 0.18, { BackgroundTransparency = 0 }):Play()
		end

		TabButton.Activated:Connect(Activate)

		if not ActiveTabButton then
			Activate()
		end

		--==============================
		-- Tab object
		--==============================

		local Tab = {}

		function Tab:CreateSection(title)
			New("TextLabel", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = title,
				TextColor3 = Theme.Accent,
				TextSize = 8,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5
			}, Page)
		end

		function Tab:CreateButton(options)
			options = options or {}

			local Button = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Surface,
				BorderSizePixel = 0,
				Text = options.Name or "Button",
				TextColor3 = Theme.Text,
				TextSize = 10,
				Font = Enum.Font.GothamMedium,
				AutoButtonColor = false,
				ZIndex = 5
			}, Page)

			Corner(Button, 8)
			Stroke(Button, 0.4)

			Button.MouseEnter:Connect(function()
				Tween(Button, 0.13, { BackgroundColor3 = Theme.SurfaceHover }):Play()
			end)

			Button.MouseLeave:Connect(function()
				Tween(Button, 0.13, { BackgroundColor3 = Theme.Surface }):Play()
			end)

			Button.Activated:Connect(function()
				Tween(Button, 0.1, { BackgroundColor3 = Theme.AccentDark }):Play()

				task.delay(0.12, function()
					Tween(Button, 0.15, { BackgroundColor3 = Theme.Surface }):Play()
				end)

				if options.Callback then
					local ok, err = pcall(options.Callback)
					if not ok then
						warn("[n4noware] button callback error:", err)
					end
				end
			end)

			return { Object = Button }
		end

		function Tab:CreateToggle(options)
			options = options or {}
			local value = options.CurrentValue == true

			local ToggleButton = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Surface,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 5
			}, Page)

			Corner(ToggleButton, 8)
			Stroke(ToggleButton, 0.4)

			New("TextLabel", {
				Size = UDim2.new(1, -65, 1, 0),
				Position = UDim2.fromOffset(11, 0),
				BackgroundTransparency = 1,
				Text = options.Name or "Toggle",
				TextColor3 = Theme.Text,
				TextSize = 10,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6
			}, ToggleButton)

			local Track_ = New("Frame", {
				Size = UDim2.fromOffset(40, 21),
				Position = UDim2.new(1, -51, 0.5, -10),
				BackgroundColor3 = Theme.Border,
				BorderSizePixel = 0,
				ZIndex = 6
			}, ToggleButton)

			Corner(Track_, 12)

			local Knob = New("Frame", {
				Size = UDim2.fromOffset(15, 15),
				Position = UDim2.fromOffset(3, 3),
				BackgroundColor3 = Theme.Muted,
				BorderSizePixel = 0,
				ZIndex = 7
			}, Track_)

			Corner(Knob, 9)

			local function Render()
				Tween(Track_, 0.2, { BackgroundColor3 = value and Theme.AccentDark or Theme.Border }):Play()
				Tween(Knob, 0.23, {
					Position = value and UDim2.fromOffset(22, 3) or UDim2.fromOffset(3, 3),
					BackgroundColor3 = value and Theme.Accent or Theme.Muted
				}):Play()
			end

			ToggleButton.Activated:Connect(function()
				value = not value
				Render()

				if options.Callback then
					local ok, err = pcall(options.Callback, value)
					if not ok then
						warn("[n4noware] toggle callback error:", err)
					end
				end
			end)

			Render()

			return {
				Object = ToggleButton,
				Get = function() return value end,
				Set = function(new) value = new == true; Render() end
			}
		end

		function Tab:CreateDropdown(options)
			options = options or {}
			local items = options.Options or {}
			local selected = math.clamp(options.CurrentOption and table.find(items, options.CurrentOption) or 1, 1, math.max(#items, 1))
			local open = false

			local Holder = New("Frame", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				ZIndex = 5
			}, Page)

			local DropdownButton = New("TextButton", {
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Surface,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 6
			}, Holder)

			Corner(DropdownButton, 8)
			Stroke(DropdownButton, 0.4)

			New("TextLabel", {
				Size = UDim2.new(0.48, 0, 1, 0),
				Position = UDim2.fromOffset(11, 0),
				BackgroundTransparency = 1,
				Text = options.Name or "Dropdown",
				TextColor3 = Theme.Text,
				TextSize = 10,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 7
			}, DropdownButton)

			local SelectedText = New("TextLabel", {
				Size = UDim2.new(0.42, 0, 1, 0),
				Position = UDim2.new(0.48, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = items[selected] or "",
				TextColor3 = Theme.Accent,
				TextSize = 10,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 7
			}, DropdownButton)

			local List = New("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.fromOffset(0, 45),
				BackgroundColor3 = Theme.Window,
				BorderSizePixel = 0,
				Visible = false,
				ClipsDescendants = true,
				ZIndex = 20
			}, Holder)

			Corner(List, 8)
			Stroke(List, 0.2)

			New("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, List)

			local function Select(index)
				selected = index
				SelectedText.Text = items[index]

				if options.Callback then
					local ok, err = pcall(options.Callback, items[index], index)
					if not ok then
						warn("[n4noware] dropdown callback error:", err)
					end
				end
			end

			for index, item in ipairs(items) do
				local OptionButton = New("TextButton", {
					Size = UDim2.new(1, -8, 0, 32),
					Position = UDim2.fromOffset(4, 0),
					BackgroundColor3 = Theme.Surface,
					BorderSizePixel = 0,
					Text = item,
					TextColor3 = Theme.Text,
					TextSize = 10,
					Font = Enum.Font.GothamMedium,
					AutoButtonColor = false,
					LayoutOrder = index,
					ZIndex = 21
				}, List)

				Corner(OptionButton, 6)

				OptionButton.Activated:Connect(function()
					Select(index)
					open = false
					Tween(List, 0.18, { Size = UDim2.new(1, 0, 0, 0) }):Play()
					task.delay(0.18, function()
						if not open then List.Visible = false end
					end)
				end)
			end

			DropdownButton.Activated:Connect(function()
				open = not open

				if open then
					List.Visible = true
					List.Size = UDim2.new(1, 0, 0, 0)
					Tween(List, 0.24, { Size = UDim2.new(1, 0, 0, math.min(#items * 35 + 5, 145)) }):Play()
				else
					Tween(List, 0.18, { Size = UDim2.new(1, 0, 0, 0) }):Play()
					task.delay(0.18, function()
						if not open then List.Visible = false end
					end)
				end
			end)

			return {
				Object = Holder,
				Get = function() return items[selected] end,
				Set = function(index) if items[index] then Select(index) end end
			}
		end

		return Tab
	end

	--==============================
	-- Window:Destroy
	--==============================

	function Window:Destroy()
		Gui:Destroy()
	end

	return Window
end

return N4noware
