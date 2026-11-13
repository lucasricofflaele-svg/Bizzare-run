-- language: Lua, file: LHub_v89.lua, target: Roblox (Delta Executor)
-- ==========================================
-- 1. ENVIRONMENT & CONFIG MANAGER
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CONFIG_FILE = "LHub_Config_v89.json"

local Config = {
    aimbotEnabled = false, aimbotFov = 120, aimbotTurnChar = true,
    dashStrong = true, aimCamHeight = 8, aimYawOff = 0, aimPitchOff = 0,
    autoCollect = false, fovCircleOn = false, tpKillHeight = 6,
    floatBtnPosXScale = 0.05, floatBtnPosXOffset = 0,
    floatBtnPosYScale = 0.4, floatBtnPosYOffset = 0,
    espRokaPlant = false, espRokaFruit = false, espArrow = false, espShiny = false,
    autoRaceEnabled = false
}

if isfile and isfile(CONFIG_FILE) then
    local s, d = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if s and type(d) == "table" then for k, v in pairs(d) do if Config[k] ~= nil then Config[k] = v end end end
end

local function SaveConfig()
    if writefile then
        local d = {}
        for k, v in pairs(Config) do d[k] = v end
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(d)) end)
    end
end

-- ==========================================
-- 2. CLEANUP & STATE
-- ==========================================
if _G.LHub then
    pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
    if _G.LHub.Tasks then for _, t in pairs(_G.LHub.Tasks) do if coroutine.status(t) ~= "dead" then pcall(task.cancel, t) end end end
    if _G.LHub.Conns then for _, c in pairs(_G.LHub.Conns) do pcall(function() c:Disconnect() end) end end
    if _G.LHub.Gui then pcall(function() _G.LHub.Gui:Destroy() end) end
    if _G.LHub.ESPObjects then for _, obj in pairs(_G.LHub.ESPObjects) do if obj.hl then obj.hl:Destroy() end if obj.bb then obj.bb:Destroy() end end end
    if _G.LHub.FovCircle then pcall(function() _G.LHub.FovCircle:Remove() end) end
    if _G.LHub.Highlight then pcall(function() _G.LHub.Highlight:Destroy() end) end
end

_G.LHub = { Gui = nil, Tasks = {}, Conns = {}, ESPObjects = {}, NoclipStates = {} }

-- ==========================================
-- 3. UI SOUND DESIGN
-- ==========================================
local UI_SOUNDS = {
    OpenUI    = { Id = "rbxassetid://6895079853", Volume = 0.40, Speed = 1.05 },
    CloseUI   = { Id = "rbxassetid://6895079853", Volume = 0.35, Speed = 0.85 },
    TabSwitch = { Id = "rbxassetid://6042053626", Volume = 0.30, Speed = 1.15 },
    ToggleOn  = { Id = "rbxassetid://876939830",  Volume = 0.45, Speed = 1.10 },
    ToggleOff = { Id = "rbxassetid://876939830",  Volume = 0.40, Speed = 0.90 },
    Click     = { Id = "rbxassetid://421058925",  Volume = 0.40, Speed = 1.00 },
    Notify    = { Id = "rbxassetid://4590657391", Volume = 0.50, Speed = 1.00 },
    Tick      = { Id = "rbxassetid://421058925",  Volume = 0.15, Speed = 1.45 }
}

local loadedSounds = {}
for name, data in pairs(UI_SOUNDS) do
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = data.Id
    sound.Volume = data.Volume
    sound.PlaybackSpeed = data.Speed
    sound.Parent = SoundService
    loadedSounds[name] = sound
end

local function playUISound(soundName)
    local sound = loadedSounds[soundName]
    if sound then
        local clone = sound:Clone()
        clone.Parent = SoundService
        clone:Play()
        clone.Ended:Once(function() clone:Destroy() end)
    end
end

local lastTickTime = 0
local function playSliderTick()
    local now = os.clock()
    if now - lastTickTime >= 0.045 then
        lastTickTime = now
        playUISound("Tick")
    end
end

-- ==========================================
-- 4. CORE LOGIC (Aimbot, ESP, Coleta, Race)
-- ==========================================
local function bypassAntiCheat()
    local char = LocalPlayer.Character
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    local function killScripts(parent)
        if not parent then return end
        for _, v in ipairs(parent:GetDescendants()) do
            local n = string.lower(v.Name)
            if v:IsA("LocalScript") or v:IsA("Script") then
                if n:find("detector") or n:find("anticheat") or n:find("vr") or n:find("teleport") or n:find("speed") then
                    pcall(function() if v:IsA("LocalScript") then v.Disabled = true end v:Destroy() end)
                end
            end
        end
    end
    if ps then killScripts(ps) end
    if char then killScripts(char) end
end

local function safeTweenTeleport(targetPos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(bypassAntiCheat)
    local targetCF = CFrame.new(targetPos)
    local startCF = hrp.CFrame
    hrp.Anchored = true
    hrp.AssemblyLinearVelocity = Vector3.zero
    for i = 1, 20 do
        if not hrp.Parent then break end
        hrp.CFrame = startCF:Lerp(targetCF, i / 20)
        task.wait(0.05)
    end
    hrp.CFrame = targetCF
    hrp.Anchored = false
end

-- Aimbot Core
local aimbotHighlight = Instance.new("Highlight")
aimbotHighlight.FillColor = Color3.fromRGB(56, 189, 248)
aimbotHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
aimbotHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
aimbotHighlight.Enabled = false
aimbotHighlight.Parent = CoreGui
_G.LHub.Highlight = aimbotHighlight

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = Config.fovCircleOn
fovCircle.Radius = Config.aimbotFov
fovCircle.Color = Color3.fromRGB(56, 189, 248)
fovCircle.Thickness = 1.5
fovCircle.Filled = false
_G.LHub.FovCircle = fovCircle

RunService:BindToRenderStep("LHubAimbot", Enum.RenderPriority.Last.Value, function(dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    fovCircle.Position = center

    if not Config.aimbotEnabled then
        aimbotHighlight.Enabled = false
        return
    end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local closest, minDist = nil, Config.aimbotFov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            local targetPart = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
            if targetPart then
                local sp, os = cam:WorldToViewportPoint(targetPart.Position)
                if os then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < minDist then minDist = d; closest = targetPart end
                end
            end
        end
    end

    if closest then
        aimbotHighlight.Enabled = true
        aimbotHighlight.Adornee = closest.Parent
        local targetPos = closest.Position
        local dir = (targetPos - cam.CFrame.Position).Unit
        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + dir)
    else
        aimbotHighlight.Enabled = false
    end
end)

-- Coleta Core
local isCollecting = false
task.spawn(function()
    while task.wait(1) do
        if Config.autoCollect and not isCollecting then
            isCollecting = true
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local itemsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Items") and Workspace.Map.Gameplay.Items:FindFirstChild("Spawned")
                if itemsFolder then
                    for _, item in ipairs(itemsFolder:GetChildren()) do
                        if string.find(string.lower(item.Name), "roka") then
                            local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if prompt then
                                safeTweenTeleport(item.Position + Vector3.new(0, 3, 0))
                                prompt:InputHoldBegin()
                                task.wait(prompt.HoldDuration > 0 and prompt.HoldDuration or 0.5)
                                prompt:InputHoldEnd()
                            end
                        end
                    end
                end
            end)
            isCollecting = false
        end
    end
end)

-- ==========================================
-- 5. FLUENT UI (MODULAR & NOTIFICATIONS)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FluentProUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end
_G.LHub.Gui = screenGui

local Theme = {
    Background = Color3.fromRGB(32, 32, 32),
    Surface = Color3.fromRGB(43, 43, 43),
    Primary = Color3.fromRGB(56, 189, 248), -- Azul Fluent
    Text = Color3.fromRGB(255, 255, 255),
    Subtext = Color3.fromRGB(170, 170, 170),
    Border = Color3.fromRGB(255, 255, 255)
}

-- Notificações
local notifyContainer = Instance.new("Frame")
notifyContainer.Name = "Notifications"
notifyContainer.Size = UDim2.new(0, 330, 1, -32)
notifyContainer.Position = UDim2.new(1, -346, 0, 16)
notifyContainer.BackgroundTransparency = 1
notifyContainer.Parent = screenGui

local nLayout = Instance.new("UIListLayout", notifyContainer)
nLayout.SortOrder = Enum.SortOrder.LayoutOrder
nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
nLayout.Padding = UDim.new(0, 12)

local THEMES = {
    Info    = { Accent = Color3.fromRGB(56, 189, 248),  Icon = "ℹ" },
    Success = { Accent = Color3.fromRGB(16, 185, 129),  Icon = "✓" },
    Warning = { Accent = Color3.fromRGB(245, 158, 11),  Icon = "⚠" },
    Error   = { Accent = Color3.fromRGB(244, 63, 94),   Icon = "✕" }
}

local function notifyPro(config)
    local title = config.Title or "Sistema"
    local text = config.Message or ""
    local duration = config.Duration or 4.5
    local theme = THEMES[config.Type or "Info"] or THEMES.Info
    
    playUISound("Notify")

    local wrapper = Instance.new("Frame")
    wrapper.Size = UDim2.new(1, 0, 0, 0)
    wrapper.AutomaticSize = Enum.AutomaticSize.Y
    wrapper.BackgroundTransparency = 1
    wrapper.Parent = notifyContainer

    local shadow = Instance.new("ImageLabel")
    shadow.Size = UDim2.new(1, 24, 1, 24)
    shadow.Position = UDim2.new(0, -12, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6014261993"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.45
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.ZIndex = 1
    shadow.Parent = wrapper

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Position = UDim2.new(1, 50, 0, 0)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    card.BackgroundTransparency = 0.10
    card.ClipsDescendants = true
    card.ZIndex = 2
    card.Parent = wrapper
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", card); stroke.Color = Theme.Border; stroke.Transparency = 0.88

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 0, 0); content.AutomaticSize = Enum.AutomaticSize.Y
    content.BackgroundTransparency = 1; content.ZIndex = 3; content.Parent = card
    local pad = Instance.new("UIPadding", content); pad.PaddingTop = UDim.new(0, 12); pad.PaddingBottom = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)

    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0, 28, 0, 28); badge.BackgroundColor3 = theme.Accent; badge.BackgroundTransparency = 0.84
    badge.ZIndex = 4; badge.Parent = content
    Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
    local icon = Instance.new("TextLabel", badge); icon.Size = UDim2.new(1, 0, 1, 0); icon.BackgroundTransparency = 1
    icon.Text = theme.Icon; icon.TextColor3 = theme.Accent; icon.Font = Enum.Font.GothamBold; icon.TextSize = 14

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -64, 0, 18); titleLabel.Position = UDim2.new(0, 38, 0, 0)
    titleLabel.BackgroundTransparency = 1; titleLabel.Text = title; titleLabel.TextColor3 = Theme.Text
    titleLabel.Font = Enum.Font.GothamBold; titleLabel.TextSize = 13; titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 4; titleLabel.Parent = content

    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, -38, 0, 0); msgLabel.Position = UDim2.new(0, 38, 0, 20)
    msgLabel.AutomaticSize = Enum.AutomaticSize.Y; msgLabel.BackgroundTransparency = 1; msgLabel.Text = text
    msgLabel.TextColor3 = Theme.Subtext; msgLabel.Font = Enum.Font.GothamMedium; msgLabel.TextSize = 12
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left; msgLabel.TextWrapped = true; msgLabel.ZIndex = 4; msgLabel.Parent = content

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20); closeBtn.Position = UDim2.new(1, -20, 0, -2)
    closeBtn.BackgroundTransparency = 1; closeBtn.Text = "×"; closeBtn.TextColor3 = Theme.Subtext
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 16; closeBtn.ZIndex = 5; closeBtn.Parent = content

    local progressTrack = Instance.new("Frame")
    progressTrack.Size = UDim2.new(1, 0, 0, 2); progressTrack.Position = UDim2.new(0, 0, 1, -2)
    progressTrack.BackgroundColor3 = Theme.Border; progressTrack.BackgroundTransparency = 0.94
    progressTrack.ZIndex = 4; progressTrack.Parent = card
    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(1, 0, 1, 0); progressFill.BackgroundColor3 = theme.Accent
    progressFill.ZIndex = 5; progressFill.Parent = progressTrack

    local isClosed, isPaused, timeLeft = false, false, duration
    local function closeToast()
        if isClosed then return end
        isClosed = true
        TweenService:Create(shadow, TweenInfo.new(0.25), { ImageTransparency = 1 }):Play()
        local outTween = TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(1, 50, 0, 0), BackgroundTransparency = 1 })
        outTween:Play(); outTween.Completed:Once(function() wrapper:Destroy() end)
    end

    closeBtn.MouseButton1Click:Connect(closeToast)
    card.MouseEnter:Connect(function() isPaused = true; TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.72 }):Play() end)
    card.MouseLeave:Connect(function() isPaused = false; TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.88 }):Play() end)

    TweenService:Create(card, TweenInfo.new(0.38, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()

    task.spawn(function()
        local lastTick = os.clock()
        while timeLeft > 0 and not isClosed do
            local dt = os.clock() - lastTick; lastTick = os.clock()
            if not isPaused then
                timeLeft = math.max(0, timeLeft - dt)
                progressFill.Size = UDim2.new(timeLeft / duration, 0, 1, 0)
            end
            task.wait()
        end
        closeToast()
    end)
end

-- Botão Flutuante Premium
local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 55, 0, 55)
floatBtn.Position = UDim2.new(Config.floatBtnPosXScale, Config.floatBtnPosXOffset, Config.floatBtnPosYScale, Config.floatBtnPosYOffset)
floatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
floatBtn.BackgroundTransparency = 0.3
floatBtn.Text = ""; floatBtn.AutoButtonColor = false; floatBtn.Active = true; floatBtn.Parent = screenGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)

local fStroke = Instance.new("UIStroke", floatBtn); fStroke.Thickness = 2; fStroke.Transparency = 0.1
local fGradient = Instance.new("UIGradient", fStroke)
fGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.Primary), ColorSequenceKeypoint.new(1, Color3.fromRGB(147, 51, 255)) })
fGradient.Rotation = 45

local fIcon = Instance.new("TextLabel", floatBtn); fIcon.Size = UDim2.new(1,0,1,0); fIcon.BackgroundTransparency = 1
fIcon.Text = "L"; fIcon.TextColor3 = Theme.Text; fIcon.Font = Enum.Font.GothamBlack; fIcon.TextSize = 28

local fGlow = Instance.new("Frame", floatBtn); fGlow.Size = UDim2.new(1,10,1,10); fGlow.Position = UDim2.new(0,-5,0,-5)
fGlow.BackgroundColor3 = Color3.fromRGB(147, 51, 255); fGlow.BackgroundTransparency = 0.85; fGlow.ZIndex = 0
Instance.new("UICorner", fGlow).CornerRadius = UDim.new(1, 0)
floatBtn.ZIndex = 2; fIcon.ZIndex = 3

local function animateScale(scale)
    local targetSize = UDim2.new(0, 55 * scale, 0, 55 * scale)
    local offset = (55 - 55 * scale) / 2
    local targetPos = UDim2.new(floatBtn.Position.X.Scale, floatBtn.Position.X.Offset + offset, floatBtn.Position.Y.Scale, floatBtn.Position.Y.Offset + offset)
    TweenService:Create(floatBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = targetSize, Position = targetPos }):Play()
end
floatBtn.MouseEnter:Connect(function() animateScale(1.1); TweenService:Create(fGlow, TweenInfo.new(0.2), { BackgroundTransparency = 0.6 }):Play() end)
floatBtn.MouseLeave:Connect(function() animateScale(1.0); TweenService:Create(fGlow, TweenInfo.new(0.2), { BackgroundTransparency = 0.85 }):Play() end)
floatBtn.MouseButton1Down:Connect(function() animateScale(0.95) end)
floatBtn.MouseButton1Up:Connect(function() animateScale(1.1) end)

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 800, 0, 480); mainFrame.Position = UDim2.new(0.5, -400, 0.5, -240)
mainFrame.BackgroundColor3 = Theme.Background; mainFrame.BackgroundTransparency = 0.05; mainFrame.Visible = false; mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", mainFrame).Color = Theme.Border; mainFrame:FindFirstChildWhichIsA("UIStroke").Transparency = 0.85

local uiScale = Instance.new("UIScale", mainFrame)
local function updateScale()
    local vp = Workspace.CurrentCamera.ViewportSize
    uiScale.Scale = math.min(vp.X / 850, vp.Y / 550)
end
updateScale(); Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local topBar = Instance.new("Frame", mainFrame); topBar.Size = UDim2.new(1,0,0,50); topBar.BackgroundTransparency = 1
local title = Instance.new("TextLabel", topBar); title.Size = UDim2.new(0,300,1,0); title.Position = UDim2.new(0,20,0,0); title.BackgroundTransparency = 1
title.Text = "L HUB"; title.TextColor3 = Theme.Text; title.Font = Enum.Font.GothamBold; title.TextSize = 18; title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", topBar); closeBtn.Size = UDim2.new(0,30,0,30); closeBtn.Position = UDim2.new(1,-45,0.5,-15)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "X"; closeBtn.TextColor3 = Theme.Text; closeBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

local sidebar = Instance.new("Frame", mainFrame); sidebar.Size = UDim2.new(0,160,1,-60); sidebar.Position = UDim2.new(0,10,0,50)
sidebar.BackgroundColor3 = Theme.Surface; sidebar.BackgroundTransparency = 0.3
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)
local sList = Instance.new("UIListLayout", sidebar); sList.Padding = UDim.new(0, 5); sList.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", sidebar).PaddingTop = UDim.new(0, 10)

local contentArea = Instance.new("Frame", mainFrame); contentArea.Size = UDim2.new(1,-180,1,-60); contentArea.Position = UDim2.new(0,180,0,50)
contentArea.BackgroundTransparency = 1
local scrollContent = Instance.new("ScrollingFrame", contentArea); scrollContent.Size = UDim2.new(1,0,1,0); scrollContent.BackgroundTransparency = 1
scrollContent.ScrollBarThickness = 2; scrollContent.ScrollBarImageColor3 = Theme.Primary; scrollContent.CanvasSize = UDim2.new(0,0,0,0)
local cList = Instance.new("UIListLayout", scrollContent); cList.Padding = UDim.new(0, 8); cList.SortOrder = Enum.SortOrder.LayoutOrder
cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scrollContent.CanvasSize = UDim2.new(0,0,0,cList.AbsoluteContentSize.Y + 20) end)

-- ==========================================
-- 6. UI COMPONENTS (Card, Slider, Toggle)
-- ==========================================
local function CreateCard(parent, titleText, descText, initialState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 60); card.BackgroundColor3 = Theme.Surface; card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0; card.Parent = parent; Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", card); stroke.Color = Theme.Border; stroke.Transparency = 0.9
    
    local t = Instance.new("TextLabel", card); t.Size = UDim2.new(1, -80, 0, 20); t.Position = UDim2.new(0, 15, 0, 10); t.BackgroundTransparency = 1
    t.Text = titleText; t.TextColor3 = Theme.Text; t.Font = Enum.Font.GothamBold; t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Left
    local d = Instance.new("TextLabel", card); d.Size = UDim2.new(1, -80, 0, 20); d.Position = UDim2.new(0, 15, 0, 30); d.BackgroundTransparency = 1
    d.Text = descText; d.TextColor3 = Theme.Subtext; d.Font = Enum.Font.Gotham; d.TextSize = 11; d.TextXAlignment = Enum.TextXAlignment.Left
    
    local track = Instance.new("TextButton", card); track.Size = UDim2.new(0, 40, 0, 20); track.Position = UDim2.new(1, -55, 0.5, -10)
    track.BackgroundColor3 = initialState and Theme.Primary or Color3.fromRGB(60, 60, 60); track.Text = ""
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", track); thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = initialState and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 4, 0.5, -6)
    thumb.BackgroundColor3 = Theme.Text; Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    
    local state = initialState
    track.MouseButton1Click:Connect(function()
        state = not state
        playUISound(state and "ToggleOn" or "ToggleOff")
        -- Squash & Stretch
        TweenService:Create(thumb, TweenInfo.new(0.1), { Size = UDim2.new(0, 16, 0, 16) }):Play()
        task.delay(0.1, function() TweenService:Create(thumb, TweenInfo.new(0.1), { Size = UDim2.new(0, 12, 0, 12) }):Play() end)
        
        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = state and Theme.Primary or Color3.fromRGB(60, 60, 60) }):Play()
        TweenService:Create(thumb, TweenInfo.new(0.15), { Position = state and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 4, 0.5, -6) }):Play()
        pcall(callback, state)
    end)
    
    card.MouseEnter:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.6 }):Play() end)
    card.MouseLeave:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.9 }):Play() end)
end

local function CreateModernSlider(parent, config)
    local titleText = config.Title or "Ajuste"
    local minVal, maxVal = config.Min or 0, config.Max or 100
    local currentValue = math.clamp(config.Default or minVal, minVal, maxVal)
    local increment = config.Increment or 1
    local suffix = config.Suffix or ""
    local callback = config.Callback
    local isDragging = false

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 56); row.BackgroundColor3 = Color3.fromRGB(30, 30, 36); row.BackgroundTransparency = 0.35; row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", row); pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 10); pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)

    local t = Instance.new("TextLabel", row); t.Size = UDim2.new(1, -70, 0, 18); t.BackgroundTransparency = 1
    t.Text = titleText; t.TextColor3 = Theme.Text; t.Font = Enum.Font.GothamMedium; t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Left

    local pill = Instance.new("Frame", row); pill.Size = UDim2.new(0, 54, 0, 20); pill.Position = UDim2.new(1, -54, 0, -1)
    pill.BackgroundColor3 = Color3.fromRGB(22, 22, 27); pill.BackgroundTransparency = 0.2
    Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)
    local pillStroke = Instance.new("UIStroke", pill); pillStroke.Color = Theme.Border; pillStroke.Transparency = 0.9
    local vLabel = Instance.new("TextLabel", pill); vLabel.Size = UDim2.new(1,0,1,0); vLabel.BackgroundTransparency = 1
    vLabel.Text = tostring(currentValue) .. suffix; vLabel.TextColor3 = Theme.Primary; vLabel.Font = Enum.Font.GothamBold; vLabel.TextSize = 11

    local hitArea = Instance.new("TextButton", row); hitArea.Size = UDim2.new(1, 0, 0, 20); hitArea.Position = UDim2.new(0, 0, 1, -18)
    hitArea.BackgroundTransparency = 1; hitArea.Text = ""; hitArea.AutoButtonColor = false

    local track = Instance.new("Frame", hitArea); track.Size = UDim2.new(1, 0, 0, 5); track.Position = UDim2.new(0, 0, 0.5, -2.5)
    track.BackgroundColor3 = Color3.fromRGB(48, 48, 56); track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initialPercent = (currentValue - minVal) / (maxVal - minVal)
    local fill = Instance.new("Frame", track); fill.Size = UDim2.new(initialPercent, 0, 1, 0); fill.BackgroundColor3 = Theme.Primary; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame", track); thumb.Size = UDim2.new(0, 14, 0, 14); thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new(initialPercent, 0, 0.5, 0); thumb.BackgroundColor3 = Theme.Text; thumb.ZIndex = 3
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", thumb).Color = Theme.Primary; thumb:FindFirstChildWhichIsA("UIStroke").Thickness = 2

    local function setSliderValue(newVal, silent)
        local stepped = math.floor(((newVal - minVal) / increment) + 0.5) * increment + minVal
        stepped = math.clamp(stepped, minVal, maxVal)
        stepped = math.floor(stepped * 100 + 0.5) / 100

        if stepped ~= currentValue then
            currentValue = stepped
            vLabel.Text = tostring(currentValue) .. suffix
            if not silent then playSliderTick() end
            if callback then callback(currentValue) end
        end
        local percent = (currentValue - minVal) / (maxVal - minVal)
        TweenService:Create(fill, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(percent, 0, 1, 0) }):Play()
        TweenService:Create(thumb, TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(percent, 0, 0.5, 0) }):Play()
    end

    hitArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            TweenService:Create(thumb, TweenInfo.new(0.16), { Size = UDim2.new(0, 18, 0, 18) }):Play()
            TweenService:Create(pillStroke, TweenInfo.new(0.16), { Color = Theme.Primary, Transparency = 0.4 }):Play()
            local relX = input.Position.X - track.AbsolutePosition.X
            setSliderValue(minVal + (maxVal - minVal) * math.clamp(relX / track.AbsoluteSize.X, 0, 1), false)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local relX = input.Position.X - track.AbsolutePosition.X
            setSliderValue(minVal + (maxVal - minVal) * math.clamp(relX / track.AbsoluteSize.X, 0, 1), false)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isDragging = false
            TweenService:Create(thumb, TweenInfo.new(0.16), { Size = UDim2.new(0, 14, 0, 14) }):Play()
            TweenService:Create(pillStroke, TweenInfo.new(0.16), { Color = Theme.Border, Transparency = 0.9 }):Play()
        end
    end)
end

local Tabs, TabButtons = {}, {}
local function CreateTab(name)
    local btn = Instance.new("TextButton", sidebar); btn.Size = UDim2.new(1, -20, 0, 36)
    btn.BackgroundColor3 = Theme.Surface; btn.BackgroundTransparency = 1
    btn.Text = "   " .. name; btn.TextColor3 = Theme.Subtext; btn.Font = Enum.Font.GothamBold; btn.TextSize = 13; btn.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local ind = Instance.new("Frame", btn); ind.Size = UDim2.new(0, 3, 0.4, 0); ind.Position = UDim2.new(0, 0, 0.3, 0)
    ind.BackgroundColor3 = Theme.Primary; ind.Visible = false; Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    
    local frame = Instance.new("Frame", scrollContent); frame.Size = UDim2.new(1,0,0,0); frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1; frame.Visible = false
    local tLayout = Instance.new("UIListLayout", frame); tLayout.Padding = UDim.new(0, 8); tLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    TabButtons[name] = btn; Tabs[name] = frame
    
    btn.MouseButton1Click:Connect(function()
        playUISound("TabSwitch")
        for _, f in pairs(Tabs) do f.Visible = false end
        for _, b in pairs(TabButtons) do
            TweenService:Create(b, TweenInfo.new(0.15), { BackgroundTransparency = 1, TextColor3 = Theme.Subtext }):Play()
            b:FindFirstChildWhichIsA("Frame").Visible = false
        end
        frame.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(50, 50, 50), BackgroundTransparency = 0.4, TextColor3 = Theme.Text }):Play()
        ind.Visible = true
    end)
    return frame
end

-- ==========================================
-- 7. POPULATING TABS & BINDING ACTIONS
-- ==========================================
local TabHome = CreateTab("Home")
local TabAutoRace = CreateTab("Auto Race")
local TabPlayer = CreateTab("Player")
local TabVisuals = CreateTab("Visuals")
local TabMisc = CreateTab("Misc")

-- HOME
local homeLabel = Instance.new("TextLabel", TabHome); homeLabel.Size = UDim2.new(1, 0, 0, 80); homeLabel.BackgroundTransparency = 1
homeLabel.Text = "Bem-vindo ao L HUB FluentPro.\nSinta a experiência definitiva com áudio e animações."; homeLabel.TextColor3 = Theme.Subtext
homeLabel.Font = Enum.Font.Gotham; homeLabel.TextSize = 14; homeLabel.TextXAlignment = Enum.TextXAlignment.Left; homeLabel.TextYAlignment = Enum.TextYAlignment.Top

-- AUTO RACE
CreateCard(TabAutoRace, "Enable Auto Race", "Piloto automático com bypass de checkpoints.", Config.autoRaceEnabled, function(s) Config.autoRaceEnabled = s; SaveConfig() end)

-- PLAYER
CreateCard(TabPlayer, "Enable Aimbot", "Ativa a mira automática (Aim Assist).", Config.aimbotEnabled, function(s) Config.aimbotEnabled = s; SaveConfig() end)
CreateCard(TabPlayer, "FOV Circle", "Mostra o alcance da mira na tela.", Config.fovCircleOn, function(s) Config.fovCircleOn = s; fovCircle.Visible = s; SaveConfig() end)

CreateModernSlider(TabPlayer, {
    Title = "FOV Size", Min = 30, Max = 300, Default = Config.aimbotFov, Increment = 5, Suffix = "px",
    Callback = function(val) Config.aimbotFov = val; fovCircle.Radius = val; SaveConfig() end
})

-- VISUALS
CreateCard(TabVisuals, "ESP Rokakaka Plant", "Destaca plantas no mapa.", Config.espRokaPlant, function(s) Config.espRokaPlant = s; SaveConfig() end)
CreateCard(TabVisuals, "ESP Rokakaka Fruit", "Destaca frutas no mapa.", Config.espRokaFruit, function(s) Config.espRokaFruit = s; SaveConfig() end)
CreateCard(TabVisuals, "ESP Arrow", "Destaca flechas normais.", Config.espArrow, function(s) Config.espArrow = s; SaveConfig() end)
CreateCard(TabVisuals, "ESP Arrow Shiny", "Destaca flechas raras.", Config.espShiny, function(s) Config.espShiny = s; SaveConfig() end)

-- MISC
CreateCard(TabMisc, "Auto Collect", "Coleta itens automaticamente.", Config.autoCollect, function(s) Config.autoCollect = s; SaveConfig() end)

CreateModernSlider(TabMisc, {
    Title = "WalkSpeed (Dash)", Min = 16, Max = 100, Default = 50, Increment = 2, Suffix = " ws",
    Callback = function(val) Config.dashStrong = (val > 16); local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid"); if h then h.WalkSpeed = val end end
})

-- Default Tab
playUISound("Click")
TabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 50); TabButtons["Home"].BackgroundTransparency = 0.4
TabButtons["Home"].TextColor3 = Theme.Text; TabButtons["Home"]:FindFirstChildWhichIsA("Frame").Visible = true; Tabs["Home"].Visible = true

-- ==========================================
-- 8. FINAL BINDINGS & DRAG
-- ==========================================
local dragging, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local btnDragging, btnDragStart, btnStartPos = false, nil, nil
floatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        btnDragging = true; btnDragStart = input.Position; btnStartPos = floatBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                btnDragging = false
                Config.floatBtnPosXScale = floatBtn.Position.X.Scale; Config.floatBtnPosXOffset = floatBtn.Position.X.Offset
                Config.floatBtnPosYScale = floatBtn.Position.Y.Scale; Config.floatBtnPosYOffset = floatBtn.Position.Y.Offset
                SaveConfig()
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if btnDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - btnDragStart
        floatBtn.Position = UDim2.new(btnStartPos.X.Scale, btnStartPos.X.Offset + delta.X, btnStartPos.Y.Scale, btnStartPos.Y.Offset + delta.Y)
    end
end)

floatBtn.MouseButton1Click:Connect(function()
    if not btnDragging then
        mainFrame.Visible = not mainFrame.Visible
        playUISound(mainFrame.Visible and "OpenUI" or "CloseUI")
        if mainFrame.Visible then
            mainFrame.Size = UDim2.new(0, 800, 0, 480)
            mainFrame.Position = UDim2.new(0.5, -400, 0.5, -240)
            notifyPro({ Title = "Bem-vindo", Message = "L HUB FluentPro carregado com sucesso.", Type = "Success", Duration = 4 })
        end
    end
end)

closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false; playUISound("CloseUI") end)

warn("[L HUB v89] FluentPro Experience Loaded.")
