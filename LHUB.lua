--[[
    L HUB FluentPro v90 - UI REBUILD
    Target: Roblox / Delta (mobile + desktop)
    This file rebuilds the interface only. It does not bypass anti-cheat or
    recreate game-specific automation. Connect existing, legitimate feature
    functions through _G.LHubActions before enabling the corresponding toggle.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CONFIG_FILE = "LHub_FluentPro_v90.json"

-- Cleanup a previous copy of this UI.
if _G.LHubFluentPro and _G.LHubFluentPro.Gui then
    pcall(function() _G.LHubFluentPro.Gui:Destroy() end)
end
_G.LHubFluentPro = { Gui = nil, Connections = {} }

local Defaults = {
    autoRaceEnabled = false,
    espRokaPlant = false,
    espRokaFruit = false,
    espArrow = false,
    espShiny = false,
    aimbotEnabled = false,
    fovCircleOn = false,
    aimbotFov = 120,
    aimbotTurnChar = true,
    dashStrong = true,
    autoCollect = false,
    floatX = 0.04,
    floatY = 0.42
}

local Config = {}
for key, value in pairs(Defaults) do Config[key] = value end

local function loadConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    local ok, raw = pcall(function()
        if isfile(CONFIG_FILE) then return readfile(CONFIG_FILE) end
    end)
    if not ok or type(raw) ~= "string" then return end
    local decodedOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if decodedOk and type(data) == "table" then
        for key, default in pairs(Defaults) do
            if data[key] ~= nil and type(data[key]) == type(default) then
                Config[key] = data[key]
            end
        end
    end
end

local function saveConfig()
    if type(writefile) ~= "function" then return false end
    local ok = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
    end)
    return ok
end
loadConfig()

local Theme = {
    Background = Color3.fromRGB(16, 18, 24),
    Sidebar = Color3.fromRGB(20, 23, 31),
    Surface = Color3.fromRGB(27, 31, 41),
    SurfaceHover = Color3.fromRGB(35, 40, 52),
    Border = Color3.fromRGB(48, 55, 69),
    Accent = Color3.fromRGB(91, 155, 245),
    AccentSoft = Color3.fromRGB(35, 66, 105),
    Text = Color3.fromRGB(239, 243, 250),
    Muted = Color3.fromRGB(148, 158, 175),
    Off = Color3.fromRGB(65, 72, 86),
    Danger = Color3.fromRGB(225, 91, 99)
}

local function corner(object, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = object
    return c
end

local function stroke(object, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Border
    s.Transparency = transparency or 0
    s.Thickness = 1
    s.Parent = object
    return s
end

local function tween(object, duration, properties)
    local t = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        properties
    )
    t:Play()
    return t
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local gui = Instance.new("ScreenGui")
gui.Name = "LHubFluentPro_v90"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
pcall(function() gui.Parent = CoreGui end)
if not gui.Parent then gui.Parent = PlayerGui end
_G.LHubFluentPro.Gui = gui

local floating = make("TextButton", {
    Name = "FloatingButton",
    Size = UDim2.fromOffset(54, 54),
    Position = UDim2.new(Config.floatX, 0, Config.floatY, 0),
    BackgroundColor3 = Theme.Surface,
    Text = "L",
    TextColor3 = Theme.Accent,
    Font = Enum.Font.GothamBlack,
    TextSize = 25,
    AutoButtonColor = false,
    ZIndex = 20
}, gui)
corner(floating, 27)
local floatStroke = stroke(floating, Theme.Accent, 0.1)
floatStroke.Thickness = 2

local main = make("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(760, 485),
    BackgroundColor3 = Theme.Background,
    Visible = false,
    ClipsDescendants = true
}, gui)
corner(main, 14)
stroke(main, Theme.Border, 0.15)

local scale = make("UIScale", { Scale = 1 }, main)

local function updateScale()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    scale.Scale = math.clamp(math.min((viewport.X - 24) / 760, (viewport.Y - 24) / 485), 0.48, 1)
end
updateScale()
if Workspace.CurrentCamera then
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)

local topbar = make("Frame", {
    Name = "Topbar",
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0
}, main)
local title = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(18, 7),
    Size = UDim2.new(1, -100, 0, 25),
    Text = "L HUB  /  FLUENTPRO",
    TextColor3 = Theme.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left
}, topbar)
local subtitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(19, 31),
    Size = UDim2.new(1, -100, 0, 16),
    Text = "Interface v90  •  Mobile ready",
    TextColor3 = Theme.Muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left
}, topbar)
local close = make("TextButton", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(1, -46, 0, 12),
    BackgroundColor3 = Theme.Surface,
    Text = "×",
    TextColor3 = Theme.Muted,
    Font = Enum.Font.GothamMedium,
    TextSize = 22,
    AutoButtonColor = false
}, topbar)
corner(close, 10)

local sidebar = make("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(12, 70),
    Size = UDim2.new(0, 158, 1, -82),
    BackgroundColor3 = Theme.Sidebar,
    BorderSizePixel = 0
}, main)
corner(sidebar, 12)
make("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingLeft = UDim.new(0, 9),
    PaddingRight = UDim.new(0, 9)
}, sidebar)
local navLayout = make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder
}, sidebar)

local content = make("Frame", {
    Name = "Content",
    Position = UDim2.new(0, 182, 0, 70),
    Size = UDim2.new(1, -194, 1, -82),
    BackgroundTransparency = 1
}, main)

local pageTitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -8, 0, 32),
    Position = UDim2.fromOffset(4, 0),
    Text = "Dashboard",
    TextColor3 = Theme.Text,
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextXAlignment = Enum.TextXAlignment.Left
}, content)

local search = make("TextBox", {
    Position = UDim2.new(1, -190, 0, 2),
    Size = UDim2.fromOffset(186, 29),
    BackgroundColor3 = Theme.Surface,
    Text = "",
    PlaceholderText = "Search controls...",
    PlaceholderColor3 = Theme.Muted,
    TextColor3 = Theme.Text,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    ClearTextOnFocus = false
}, content)
corner(search, 8)
stroke(search, Theme.Border, 0.3)

local pages = {}
local navButtons = {}
local currentPage = "Home"
local controlRecords = {}
local filterControls

local function notify(message, isError)
    local toast = make("TextLabel", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(250, 42),
        BackgroundColor3 = Theme.Surface,
        Text = message,
        TextColor3 = isError and Theme.Danger or Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextWrapped = true,
        ZIndex = 50
    }, main)
    corner(toast, 9)
    stroke(toast, isError and Theme.Danger or Theme.Accent, 0.25)
    toast.BackgroundTransparency = 1
    toast.TextTransparency = 1
    tween(toast, 0.18, { BackgroundTransparency = 0, TextTransparency = 0 })
    task.delay(2.4, function()
        if toast.Parent then
            tween(toast, 0.18, { BackgroundTransparency = 1, TextTransparency = 1 })
            task.wait(0.2)
            if toast.Parent then toast:Destroy() end
        end
    end)
end

local function createPage(name, iconText)
    local nav = make("TextButton", {
        Name = "Nav_" .. name,
        Size = UDim2.new(1, 0, 0, 37),
        BackgroundColor3 = Theme.Sidebar,
        BackgroundTransparency = 1,
        Text = iconText .. "   " .. name,
        TextColor3 = Theme.Muted,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false
    }, sidebar)
    corner(nav, 8)

    local page = make("ScrollingFrame", {
        Name = "Page_" .. name,
        Position = UDim2.fromOffset(0, 40),
        Size = UDim2.new(1, 0, 1, -40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false
    }, content)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 8)
    }, page)
    local layout = make("UIListLayout", {
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, page)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 18)
    end)

    pages[name] = page
    navButtons[name] = nav
    nav.Activated:Connect(function()
        for pageName, frame in pairs(pages) do
            frame.Visible = pageName == name
        end
        for pageName, button in pairs(navButtons) do
            local selected = pageName == name
            tween(button, 0.15, {
                BackgroundColor3 = selected and Theme.AccentSoft or Theme.Sidebar,
                BackgroundTransparency = selected and 0 or 1,
                TextColor3 = selected and Theme.Text or Theme.Muted
            })
        end
        currentPage = name
        pageTitle.Text = name
        search.Text = ""
        filterControls("")
    end)
    return page
end

filterControls = function(query)
    query = string.lower(query or "")
    for _, record in ipairs(controlRecords) do
        if record.page == currentPage then
            local visible = query == "" or string.find(string.lower(record.searchText), query, 1, true) ~= nil
            record.object.Visible = visible
        end
    end
end

local function registerControl(pageName, object, searchText)
    table.insert(controlRecords, {
        page = pageName,
        object = object,
        searchText = searchText
    })
end

local function section(page, pageName, heading, description)
    local card = make("Frame", {
        Name = "Section_" .. heading,
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0
    }, page)
    corner(card, 11)
    stroke(card, Theme.Border, 0.45)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 13),
        PaddingRight = UDim.new(0, 13)
    }, card)
    local list = make("UIListLayout", {
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, card)
    local headingLabel = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 19),
        BackgroundTransparency = 1,
        Text = string.upper(heading),
        TextColor3 = Theme.Accent,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left
    }, card)
    if description then
        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = Theme.Muted,
            Font = Enum.Font.Gotham,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left
        }, card)
    end
    return card
end

local function createToggle(pageName, parent, label, description, configKey)
    local row = make("Frame", {
        Name = label,
        Size = UDim2.new(1, 0, 0, description and 48 or 36),
        BackgroundTransparency = 1
    }, parent)
    local text = make("TextLabel", {
        Position = UDim2.fromOffset(0, 1),
        Size = UDim2.new(1, -62, 0, 19),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left
    }, row)
    if description then
        make("TextLabel", {
            Position = UDim2.fromOffset(0, 21),
            Size = UDim2.new(1, -62, 0, 17),
            BackgroundTransparency = 1,
            Text = description,
            TextColor3 = Theme.Muted,
            Font = Enum.Font.Gotham,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left
        }, row)
    end

    local track = make("TextButton", {
        Name = "Switch",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(42, 23),
        BackgroundColor3 = Config[configKey] and Theme.Accent or Theme.Off,
        Text = "",
        AutoButtonColor = false
    }, row)
    corner(track, 15)
    local knob = make("Frame", {
        Size = UDim2.fromOffset(17, 17),
        Position = Config[configKey] and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(250, 251, 255),
        BorderSizePixel = 0
    }, track)
    corner(knob, 12)

    local state = Config[configKey] == true
    local function setState(value, invoke)
        state = value == true
        Config[configKey] = state
        tween(track, 0.16, { BackgroundColor3 = state and Theme.Accent or Theme.Off })
        tween(knob, 0.16, {
            Position = state and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        })
        saveConfig()

        if invoke then
            local actions = _G.LHubActions
            local callback = type(actions) == "table" and actions[configKey]
            if type(callback) == "function" then
                local ok, err = pcall(callback, state, Config)
                if not ok then notify("Feature error: " .. tostring(err), true) end
            else
                notify(label .. ": " .. (state and "ON" or "OFF") .. " (UI state saved)")
            end
        end
    end

    track.Activated:Connect(function() setState(not state, true) end)
    registerControl(pageName, row, label .. " " .. (description or ""))
    return { Set = setState, Row = row }
end

local function createButton(pageName, parent, label, callback)
    local button = make("TextButton", {
        Name = label,
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.SurfaceHover,
        Text = label,
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        AutoButtonColor = false
    }, parent)
    corner(button, 8)
    stroke(button, Theme.Border, 0.45)
    button.Activated:Connect(function()
        local ok, err = pcall(callback)
        if not ok then notify(tostring(err), true) end
    end)
    registerControl(pageName, button, label)
    return button
end

local function createSlider(pageName, parent, label, minValue, maxValue, step, configKey)
    local row = make("Frame", {
        Name = label,
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1
    }, parent)
    local valueLabel = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = label .. "  •  " .. tostring(Config[configKey]),
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left
    }, row)
    local minus = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -34, 0, 0),
        Size = UDim2.fromOffset(26, 22),
        BackgroundColor3 = Theme.SurfaceHover,
        Text = "−",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 15
    }, row)
    corner(minus, 6)
    local plus = make("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(26, 22),
        BackgroundColor3 = Theme.SurfaceHover,
        Text = "+",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 15
    }, row)
    corner(plus, 6)

    local bar = make("Frame", {
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0
    }, row)
    corner(bar, 5)
    local fill = make("Frame", {
        Size = UDim2.new((Config[configKey] - minValue) / (maxValue - minValue), 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0
    }, bar)
    corner(fill, 5)

    local function update(value)
        value = math.clamp(value, minValue, maxValue)
        value = minValue + math.floor(((value - minValue) / step) + 0.5) * step
        value = math.clamp(value, minValue, maxValue)
        Config[configKey] = value
        valueLabel.Text = label .. "  •  " .. tostring(value)
        tween(fill, 0.12, { Size = UDim2.new((value - minValue) / (maxValue - minValue), 0, 1, 0) })
        saveConfig()
        local actions = _G.LHubActions
        if type(actions) == "table" and type(actions[configKey]) == "function" then
            pcall(actions[configKey], value, Config)
        end
    end
    minus.Activated:Connect(function() update(Config[configKey] - step) end)
    plus.Activated:Connect(function() update(Config[configKey] + step) end)
    registerControl(pageName, row, label)
    return { Update = update, Row = row }
end

local home = createPage("Home", "⌂")
local race = createPage("Auto Race", "◇")
local visuals = createPage("Visuals", "◉")
local player = createPage("Player", "◎")
local teleport = createPage("Teleport", "↗")
local misc = createPage("Misc", "⚙")
local settings = createPage("Settings", "☰")

local homeCard = section(home, "Welcome", "L HUB FluentPro v90")
make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1,
    Text = "A clean, responsive interface designed for touch and desktop. Use the sidebar to navigate.",
    TextColor3 = Theme.Muted,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left
}, homeCard)

local statusCard = section(home, "Status", "Interface status")
local statusLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "UI loaded • configuration ready",
    TextColor3 = Theme.Accent,
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left
}, statusCard)

local raceCard = section(race, "Race controls", "Race automation settings")
createToggle("Auto Race", raceCard, "Enable Auto Race", "Stores the selected state; connect your race handler separately.", "autoRaceEnabled")

local visualCard = section(visuals, "Item ESP", "Visual options")
createToggle("Visuals", visualCard, "Rokakaka Plant ESP", nil, "espRokaPlant")
createToggle("Visuals", visualCard, "Rokakaka Fruit ESP", nil, "espRokaFruit")
createToggle("Visuals", visualCard, "Arrow ESP", nil, "espArrow")
createToggle("Visuals", visualCard, "Shiny Arrow ESP", nil, "espShiny")

local playerCard = section(player, "Player settings", "Aim and movement preferences")
createToggle("Player", playerCard, "Aimbot", "Preference toggle only; no aiming logic is included.", "aimbotEnabled")
createToggle("Player", playerCard, "FOV Circle", nil, "fovCircleOn")
createToggle("Player", playerCard, "Turn Character", nil, "aimbotTurnChar")
createToggle("Player", playerCard, "Strong Dash", nil, "dashStrong")
createSlider("Player", playerCard, "FOV Size", 30, 300, 5, "aimbotFov")

local tpCard = section(teleport, "Teleport", "Manual teleport integration")
make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundTransparency = 1,
    Text = "No game-specific coordinates or teleport behavior were copied from the corrupted source. Add trusted destinations to your own handler.",
    TextColor3 = Theme.Muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left
}, tpCard)

local miscCard = section(misc, "Collection", "Item collection settings")
createToggle("Misc", miscCard, "Auto Collect", "Stores the selected state; connect your collection handler separately.", "autoCollect")

local settingsCard = section(settings, "Configuration", "Save or reset interface settings")
createButton("Settings", settingsCard, "Save configuration", function()
    if saveConfig() then
        notify("Configuration saved.")
    else
        notify("Executor file API unavailable; settings remain for this session.", true)
    end
end)
createButton("Settings", settingsCard, "Reset configuration", function()
    for key, value in pairs(Defaults) do Config[key] = value end
    saveConfig()
    notify("Settings reset. Re-execute the UI to refresh every control.")
end)

search:GetPropertyChangedSignal("Text"):Connect(function()
    filterControls(search.Text)
end)

local function selectPage(name)
    for pageName, page in pairs(pages) do page.Visible = pageName == name end
    for pageName, button in pairs(navButtons) do
        local selected = pageName == name
        button.BackgroundColor3 = selected and Theme.AccentSoft or Theme.Sidebar
        button.BackgroundTransparency = selected and 0 or 1
        button.TextColor3 = selected and Theme.Text or Theme.Muted
    end
    currentPage = name
    pageTitle.Text = name
    filterControls(search.Text)
end
selectPage("Home")

-- Drag the main window with mouse or touch.
local windowDragInput, windowDragStart, windowStartPosition
topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        windowDragInput = input
        windowDragStart = input.Position
        windowStartPosition = main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if windowDragInput and (input == windowDragInput or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - windowDragStart
        main.Position = UDim2.new(
            windowStartPosition.X.Scale, windowStartPosition.X.Offset + delta.X,
            windowStartPosition.Y.Scale, windowStartPosition.Y.Offset + delta.Y
        )
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if windowDragInput and (input == windowDragInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
        windowDragInput = nil
    end
end)

-- Floating button: drag threshold prevents a drag from being mistaken for a tap.
local floatInput, floatStart, floatStartPosition, floatMoved
floating.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        floatInput = input
        floatStart = input.Position
        floatStartPosition = floating.Position
        floatMoved = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if floatInput and (input == floatInput or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - floatStart
        if delta.Magnitude > 6 then floatMoved = true end
        if floatMoved then
            floating.Position = UDim2.new(
                floatStartPosition.X.Scale, floatStartPosition.X.Offset + delta.X,
                floatStartPosition.Y.Scale, floatStartPosition.Y.Offset + delta.Y
            )
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if floatInput and (input == floatInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
        if not floatMoved then
            main.Visible = not main.Visible
            if main.Visible then
                main.Size = UDim2.fromOffset(760, 485)
                updateScale()
            end
        else
            local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
            if viewport then
                Config.floatX = math.clamp(floating.Position.X.Scale, 0, 1)
                Config.floatY = math.clamp(floating.Position.Y.Scale, 0, 1)
                saveConfig()
            end
        end
        floatInput = nil
    end
end)

close.Activated:Connect(function() main.Visible = false end)

_G.LHubFluentPro.Config = Config
_G.LHubFluentPro.Notify = notify
_G.LHubFluentPro.SelectPage = selectPage

notify("L HUB FluentPro v90 interface loaded.")
print("[L HUB FluentPro v90] UI loaded.")
