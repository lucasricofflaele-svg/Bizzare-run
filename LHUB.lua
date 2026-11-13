--[[
    L HUB FluentPro v92 - COMPLETE INTEGRATION
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
local CONFIG_FILE = "LHub_FluentPro_v92.json"

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
    aimCamHeight = 8,
    aimYawOff = 0,
    aimPitchOff = 0,
    autoCollect = false,
    tpKillHeight = 6,
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
    Background = Color3.fromRGB(13, 15, 22),
    Sidebar = Color3.fromRGB(19, 21, 30),
    Surface = Color3.fromRGB(25, 28, 39),
    SurfaceHover = Color3.fromRGB(39, 43, 57),
    Border = Color3.fromRGB(61, 54, 70),
    Accent = Color3.fromRGB(235, 55, 91),
    AccentSoft = Color3.fromRGB(76, 27, 47),
    Text = Color3.fromRGB(247, 242, 247),
    Muted = Color3.fromRGB(166, 155, 171),
    Off = Color3.fromRGB(75, 69, 83),
    Danger = Color3.fromRGB(255, 104, 123),
    CrimsonDeep = Color3.fromRGB(105, 20, 48),
    CrimsonGlow = Color3.fromRGB(255, 74, 112),
    Pink = Color3.fromRGB(255, 112, 151)
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

local function gradient(object, colorA, colorB, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colorA),
        ColorSequenceKeypoint.new(1, colorB)
    })
    g.Rotation = rotation or 0
    g.Parent = object
    return g
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
gui.Name = "LHubFluentPro_v92"
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
gradient(floating, Theme.CrimsonGlow, Theme.CrimsonDeep, 135)
local floatStroke = stroke(floating, Theme.Pink, 0.12)
floatStroke.Thickness = 1.5
local floatGlow = make("ImageLabel", {
    Name = "Glow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 24, 1, 24),
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857084",
    ImageColor3 = Theme.CrimsonGlow,
    ImageTransparency = 0.68,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(24, 24, 276, 276),
    ZIndex = 19
}, floating)

local main = make("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(760, 485),
    BackgroundColor3 = Theme.Background,
    Visible = false,
    ClipsDescendants = true
}, gui)
corner(main, 18)
stroke(main, Theme.Border, 0.08)
gradient(main, Color3.fromRGB(19, 19, 29), Color3.fromRGB(12, 14, 21), 90)

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
    Text = "CRIMSON EDITION     •     MOBILE READY",
    TextColor3 = Theme.Muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left
}, topbar)
local livePill = make("Frame", {
    Name = "LiveStatus",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -55, 0, 17),
    Size = UDim2.fromOffset(72, 23),
    BackgroundColor3 = Theme.AccentSoft,
    BorderSizePixel = 0
}, topbar)
corner(livePill, 12)
local liveDot = make("Frame", {
    Position = UDim2.fromOffset(9, 8),
    Size = UDim2.fromOffset(7, 7),
    BackgroundColor3 = Theme.CrimsonGlow,
    BorderSizePixel = 0
}, livePill)
corner(liveDot, 6)
make("TextLabel", {
    Position = UDim2.fromOffset(21, 0),
    Size = UDim2.new(1, -24, 1, 0),
    BackgroundTransparency = 1,
    Text = "ONLINE",
    TextColor3 = Theme.Pink,
    Font = Enum.Font.GothamBold,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left
}, livePill)

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
corner(sidebar, 14)
stroke(sidebar, Theme.Border, 0.55)
gradient(sidebar, Color3.fromRGB(26, 24, 36), Color3.fromRGB(18, 20, 29), 90)
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
corner(search, 10)
stroke(search, Theme.Border, 0.2)

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


-- Feature integrations recovered from the supplied v86/v89 source.
-- Deliberately excludes anti-cheat disabling and player-targeting TP-kill code.
local FeatureConnections = {}
local FeatureObjects = {}
local raceStatus = "DISABLED"
local collecting = false
local lastRaceState = "WAITING"
local defaultWalkSpeed = 16
local fovDrawing = nil
local aimHighlight = Instance.new("Highlight")
aimHighlight.Name = "LHubAimHighlight"
aimHighlight.FillColor = Theme.CrimsonGlow
aimHighlight.OutlineColor = Color3.fromRGB(255, 235, 242)
aimHighlight.Enabled = false
aimHighlight.Parent = gui

local function disconnectFeatureConnections()
    for _, connection in ipairs(FeatureConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(FeatureConnections)
end

local function clearESP()
    for instance, adornment in pairs(FeatureObjects) do
        if adornment and adornment.Parent then
            adornment:Destroy()
        end
        FeatureObjects[instance] = nil
    end
end

local function itemCategory(instance)
    local name = string.lower(instance.Name)
    if Config.espRokaPlant and (name:find("roka") and name:find("plant")) then
        return "plant"
    end
    if Config.espRokaFruit and (name:find("roka") and (name:find("fruit") or name == "rokakaka")) then
        return "fruit"
    end
    if Config.espShiny and name:find("shiny") and name:find("arrow") then
        return "shiny"
    end
    if Config.espArrow and name:find("arrow") and not name:find("shiny") then
        return "arrow"
    end
    return nil
end

local function refreshESP()
    local seen = {}
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("Model") or instance:IsA("BasePart") then
            local category = itemCategory(instance)
            if category then
                seen[instance] = true
                if not FeatureObjects[instance] then
                    local highlight = Instance.new("Highlight")
                    highlight.Name = "LHubItemESP"
                    highlight.Adornee = instance
                    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    highlight.FillTransparency = 0.78
                    highlight.OutlineTransparency = 0.08
                    local colors = {
                        plant = Color3.fromRGB(95, 225, 150),
                        fruit = Color3.fromRGB(255, 190, 95),
                        arrow = Color3.fromRGB(105, 180, 255),
                        shiny = Theme.CrimsonGlow
                    }
                    highlight.FillColor = colors[category]
                    highlight.OutlineColor = colors[category]
                    highlight.Parent = gui
                    FeatureObjects[instance] = highlight
                end
            end
        end
    end
    for instance, adornment in pairs(FeatureObjects) do
        if not seen[instance] or not instance.Parent then
            if adornment then adornment:Destroy() end
            FeatureObjects[instance] = nil
        end
    end
end

local function getRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function moveToPosition(position, duration)
    local root = getRoot()
    if not root then
        notify("Character not ready.", true)
        return false
    end
    local distance = (root.Position - position).Magnitude
    local tweenInfo = TweenInfo.new(math.clamp(distance / 90, 0.25, duration or 3), Enum.EasingStyle.Linear)
    local movement = TweenService:Create(root, tweenInfo, { CFrame = CFrame.new(position) })
    movement:Play()
    return true
end

local function runAutoCollect()
    if collecting or not Config.autoCollect then return end
    collecting = true
    task.spawn(function()
        local ok, err = pcall(function()
            local map = Workspace:FindFirstChild("Map")
            local gameplay = map and map:FindFirstChild("Gameplay")
            local items = gameplay and gameplay:FindFirstChild("Items")
            local spawned = items and items:FindFirstChild("Spawned")
            if not spawned then return end

            for _, item in ipairs(spawned:GetChildren()) do
                if not Config.autoCollect then break end
                if string.find(string.lower(item.Name), "roka", 1, true) then
                    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                    local part = item:IsA("BasePart") and item or item:FindFirstChildWhichIsA("BasePart", true)
                    if prompt and part then
                        moveToPosition(part.Position + Vector3.new(0, 2.5, 0), 2.5)
                        task.wait(0.6)
                        if Config.autoCollect and prompt.Parent then
                            pcall(function()
                                prompt:InputHoldBegin()
                                task.wait(math.max(prompt.HoldDuration, 0.15))
                                prompt:InputHoldEnd()
                            end)
                        end
                        task.wait(0.35)
                    end
                end
            end
        end)
        collecting = false
        if not ok then notify("Auto Collect error: " .. tostring(err), true) end
    end)
end

local function setDash(enabled)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if enabled then
        if humanoid.WalkSpeed <= defaultWalkSpeed then humanoid.WalkSpeed = 50 end
    else
        humanoid.WalkSpeed = defaultWalkSpeed
    end
end

local function setFOVCircle(enabled)
    if not fovDrawing and type(Drawing) == "table" and type(Drawing.new) == "function" then
        local ok, circle = pcall(function() return Drawing.new("Circle") end)
        if ok then
            fovDrawing = circle
            fovDrawing.Thickness = 1.5
            fovDrawing.Filled = false
            fovDrawing.Color = Theme.CrimsonGlow
            fovDrawing.NumSides = 64
        end
    end
    if fovDrawing then
        pcall(function()
            fovDrawing.Visible = enabled
            fovDrawing.Radius = Config.aimbotFov
        end)
    end
end

local function updateAim()
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    if fovDrawing then
        pcall(function()
            fovDrawing.Position = center
            fovDrawing.Radius = Config.aimbotFov
            fovDrawing.Visible = Config.fovCircleOn
        end)
    end
    if not Config.aimbotEnabled then
        aimHighlight.Enabled = false
        return
    end

    local bestPart, bestDistance = nil, Config.aimbotFov
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local part = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and part then
                local screenPoint, visible = camera:WorldToViewportPoint(part.Position)
                if visible then
                    local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - center).Magnitude
                    if distance < bestDistance then
                        bestDistance = distance
                        bestPart = part
                    end
                end
            end
        end
    end
    if bestPart then
        aimHighlight.Adornee = bestPart.Parent
        aimHighlight.Enabled = true
        local target = bestPart.Position + Vector3.new(Config.aimYawOff, Config.aimCamHeight * 0.05, Config.aimPitchOff)
        camera.CFrame = CFrame.lookAt(camera.CFrame.Position, target)
    else
        aimHighlight.Enabled = false
    end
end

local function getRaceState()
    local rigs = Workspace:FindFirstChild("Rigs")
    local rig = rigs and rigs:FindFirstChild(LocalPlayer.Name)
    local placement = rig and rig:GetAttribute("Placement") or 0
    local finished = rig and rig:GetAttribute("Finished") == true
    local endedGui = PlayerGui:FindFirstChild("RaceEnded")
    if finished or (endedGui and endedGui.Enabled) then
        return "FINISHED"
    elseif type(placement) == "number" and placement > 0 then
        return "RUNNING"
    end
    return "WAITING"
end

local function stopFeatures()
    Config.autoCollect = false
    Config.aimbotEnabled = false
    Config.fovCircleOn = false
    Config.autoRaceEnabled = false
    aimHighlight.Enabled = false
    setFOVCircle(false)
    raceStatus = "DISABLED"
end

_G.LHubActions = {
    autoRaceEnabled = function(enabled)
        Config.autoRaceEnabled = enabled
        raceStatus = enabled and "WAITING" or "DISABLED"
        lastRaceState = "WAITING"
        saveConfig()
    end,
    espRokaPlant = function(enabled) Config.espRokaPlant = enabled; refreshESP(); saveConfig() end,
    espRokaFruit = function(enabled) Config.espRokaFruit = enabled; refreshESP(); saveConfig() end,
    espArrow = function(enabled) Config.espArrow = enabled; refreshESP(); saveConfig() end,
    espShiny = function(enabled) Config.espShiny = enabled; refreshESP(); saveConfig() end,
    aimbotEnabled = function(enabled) Config.aimbotEnabled = enabled; if not enabled then aimHighlight.Enabled = false end; saveConfig() end,
    fovCircleOn = function(enabled) Config.fovCircleOn = enabled; setFOVCircle(enabled); saveConfig() end,
    aimbotFov = function(value) Config.aimbotFov = value; if fovDrawing then fovDrawing.Radius = value end; saveConfig() end,
    aimCamHeight = function(value) Config.aimCamHeight = value; saveConfig() end,
    aimYawOff = function(value) Config.aimYawOff = value; saveConfig() end,
    aimPitchOff = function(value) Config.aimPitchOff = value; saveConfig() end,
    aimbotTurnChar = function(enabled) Config.aimbotTurnChar = enabled; saveConfig() end,
    dashStrong = function(enabled) Config.dashStrong = enabled; setDash(enabled); saveConfig() end,
    autoCollect = function(enabled) Config.autoCollect = enabled; saveConfig(); if enabled then runAutoCollect() end end
}

table.insert(FeatureConnections, RunService.RenderStepped:Connect(updateAim))
do
    local currentCharacter = LocalPlayer.Character
    local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
    if currentHumanoid then defaultWalkSpeed = currentHumanoid.WalkSpeed end
end

table.insert(FeatureConnections, LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        defaultWalkSpeed = humanoid.WalkSpeed
        if Config.dashStrong then setDash(true) end
    end
end))

task.spawn(function()
    while gui.Parent do
        if Config.espRokaPlant or Config.espRokaFruit or Config.espArrow or Config.espShiny then
            pcall(refreshESP)
        elseif next(FeatureObjects) then
            clearESP()
        end
        if Config.autoCollect then runAutoCollect() end
        if Config.autoRaceEnabled then
            raceStatus = getRaceState()
            if raceStatus ~= lastRaceState then
                lastRaceState = raceStatus
                notify("Auto Race state: " .. raceStatus)
            end
        end
        task.wait(1.25)
    end
end)

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
    corner(nav, 10)
    nav.MouseEnter:Connect(function()
        if currentPage ~= name then
            tween(nav, 0.12, { BackgroundTransparency = 0.35, BackgroundColor3 = Theme.SurfaceHover })
        end
    end)
    nav.MouseLeave:Connect(function()
        if currentPage ~= name then
            tween(nav, 0.12, { BackgroundTransparency = 1, BackgroundColor3 = Theme.Sidebar })
        end
    end)

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
    corner(card, 14)
    stroke(card, Theme.Border, 0.35)
    gradient(card, Color3.fromRGB(31, 29, 42), Color3.fromRGB(23, 27, 37), 0)
    local marker = make("Frame", {
        Name = "CrimsonMarker",
        Position = UDim2.fromOffset(0, 13),
        Size = UDim2.fromOffset(3, 22),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0
    }, card)
    corner(marker, 3)
    gradient(marker, Theme.CrimsonGlow, Theme.CrimsonDeep, 90)
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
    corner(button, 10)
    stroke(button, Theme.Border, 0.35)
    button.MouseEnter:Connect(function()
        tween(button, 0.12, { BackgroundColor3 = Theme.AccentSoft })
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.12, { BackgroundColor3 = Theme.SurfaceHover })
    end)
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

local homeCard = section(home, "Welcome", "L HUB FluentPro v92")
make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundTransparency = 1,
    Text = "A refined control center with a Windows 11-inspired layout, soft glass surfaces and a crimson accent system. Built for touch and desktop.",
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
    Text = "●  READY  /  FluentPro Crimson Edition",
    TextColor3 = Theme.Accent,
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left
}, statusCard)

local raceCard = section(race, "Race controls", "Race automation settings")
createToggle("Auto Race", raceCard, "Enable Auto Race", "Detects WAITING / RUNNING / FINISHED. The source has no checkpoint-driving routine.", "autoRaceEnabled")
local raceStateLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 20),
    BackgroundTransparency = 1,
    Text = "Race state: DISABLED",
    TextColor3 = Theme.Pink,
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left
}, raceCard)
task.spawn(function()
    while gui.Parent and raceStateLabel.Parent do
        raceStateLabel.Text = "Race state: " .. tostring(raceStatus)
        task.wait(0.4)
    end
end)

local visualCard = section(visuals, "Item ESP", "Visual options")
createToggle("Visuals", visualCard, "Rokakaka Plant ESP", nil, "espRokaPlant")
createToggle("Visuals", visualCard, "Rokakaka Fruit ESP", nil, "espRokaFruit")
createToggle("Visuals", visualCard, "Arrow ESP", nil, "espArrow")
createToggle("Visuals", visualCard, "Shiny Arrow ESP", nil, "espShiny")

local playerCard = section(player, "Player settings", "Aim and movement preferences")
createToggle("Player", playerCard, "Aimbot", "Camera aim assist using the configured FOV.", "aimbotEnabled")
createToggle("Player", playerCard, "FOV Circle", nil, "fovCircleOn")
createToggle("Player", playerCard, "Turn Character", nil, "aimbotTurnChar")
createToggle("Player", playerCard, "Strong Dash", nil, "dashStrong")
createSlider("Player", playerCard, "FOV Size", 30, 500, 5, "aimbotFov")
createSlider("Player", playerCard, "Aim Height", -6, 30, 1, "aimCamHeight")
createSlider("Player", playerCard, "Aim Side", -10, 10, 0.25, "aimYawOff")
createSlider("Player", playerCard, "Aim Vertical", -10, 10, 0.25, "aimPitchOff")

local tpCard = section(teleport, "Teleport", "Manual stage destinations")
make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundTransparency = 1,
    Text = "Destinations recovered from your supplied script. Use only in your own test place or where permitted.",
    TextColor3 = Theme.Muted,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left
}, tpCard)
createButton("Teleport", tpCard, "Teleport • Stage 1", function()
    moveToPosition(Vector3.new(3269, -239, 2052), 3)
end)
createButton("Teleport", tpCard, "Teleport • Stage 2", function()
    moveToPosition(Vector3.new(8541, -166, -1274), 3)
end)

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
createButton("Settings", settingsCard, "Unload L HUB", function()
    if _G.LHubFluentPro and type(_G.LHubFluentPro.Unload) == "function" then
        _G.LHubFluentPro.Unload()
    end
end)
createButton("Settings", settingsCard, "Reset configuration", function()
    for key, value in pairs(Defaults) do Config[key] = value end
    saveConfig()
    stopFeatures()
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
_G.LHubFluentPro.Unload = function()
    stopFeatures()
    disconnectFeatureConnections()
    clearESP()
    if fovDrawing then pcall(function() fovDrawing:Remove() end) end
    pcall(function() aimHighlight:Destroy() end)
    saveConfig()
    if gui then gui:Destroy() end
end

notify("L HUB FluentPro v92 loaded with integrated feature handlers.")
print("[L HUB FluentPro v92] UI loaded.")
