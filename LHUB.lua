-- language: Lua, file: LHub_v91.lua, target: Roblox (Delta Executor)
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
local CONFIG_FILE = "LHub_Config_v91.json"

local Config = {
    aimbotEnabled = false, aimbotFov = 120, aimbotTurnChar = true,
    dashStrong = true, aimCamHeight = 8, aimYawOff = 0, aimPitchOff = 0,
    autoCollect = false, fovCircleOn = false, tpKillHeight = 6,
    floatBtnPosXScale = 0.05, floatBtnPosXOffset = 0,
    floatBtnPosYScale = 0.4, floatBtnPosYOffset = 0,
    espRokaPlant = false, espRokaFruit = false, espArrow = false, espShiny = false,
    autoRaceEnabled = false, theme = "Obsidian Violet"
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
aimbotHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
aimbotHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
aimbotHighlight.Enabled = false
aimbotHighlight.Parent = CoreGui
_G.LHub.Highlight = aimbotHighlight

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = Config.fovCircleOn
fovCircle.Radius = Config.aimbotFov
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
-- 5. UI DEFINITIONS & THEMES
-- ==========================================
local ThemePalettes = {
    ["Obsidian Violet"] = { Background = Color3.fromRGB(18, 16, 24), Surface = Color3.fromRGB(28, 25, 36), Primary = Color3.fromRGB(168, 85, 247) },
    ["Midnight Fluent"] = { Background = Color3.fromRGB(24, 24, 28), Surface = Color3.fromRGB(32, 32, 38), Primary = Color3.fromRGB(96, 165, 250) },
    ["Emerald Glass"] = { Background = Color3.fromRGB(15, 23, 20), Surface = Color3.fromRGB(22, 33, 29), Primary = Color3.fromRGB(52, 211, 153) },
    ["Crimson Dark"] = { Background = Color3.fromRGB(26, 17, 19), Surface = Color3.fromRGB(36, 24, 27), Primary = Color3.fromRGB(244, 63, 94) },
    ["Monochrome"] = { Background = Color3.fromRGB(20, 20, 20), Surface = Color3.fromRGB(30, 30, 30), Primary = Color3.fromRGB(220, 220, 225) }
}

local Theme = {}
local function LoadTheme(name)
    local t = ThemePalettes[name] or ThemePalettes["Obsidian Violet"]
    Theme.Background = t.Background
    Theme.Surface = t.Surface
    Theme.Primary = t.Primary
    Theme.Text = Color3.fromRGB(255, 255, 255)
    Theme.Subtext = Color3.fromRGB(170, 170, 180)
    Theme.Border = Color3.fromRGB(255, 255, 255)
    Theme.Inactive = Color3.fromRGB(130, 130, 140)
end
LoadTheme(Config.theme)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FluentProUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end
_G.LHub.Gui = screenGui

-- Notificações
local notifyContainer = Instance.new("Frame", screenGui)
notifyContainer.Size = UDim2.new(0, 330, 1, -32); notifyContainer.Position = UDim2.new(1, -346, 0, 16); notifyContainer.BackgroundTransparency = 1
local nLayout = Instance.new("UIListLayout", notifyContainer); nLayout.SortOrder = Enum.SortOrder.LayoutOrder; nLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom; nLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; nLayout.Padding = UDim.new(0, 12)

local THEMES_NOTIFY = {
    Info    = { Accent = Color3.fromRGB(96, 165, 250),  Icon = "ℹ" },
    Success = { Accent = Color3.fromRGB(16, 185, 129),  Icon = "✓" },
    Warning = { Accent = Color3.fromRGB(245, 158, 11),  Icon = "⚠" },
    Error   = { Accent = Color3.fromRGB(244, 63, 94),   Icon = "✕" }
}

local function notifyPro(config)
    local theme = THEMES_NOTIFY[config.Type or "Info"] or THEMES_NOTIFY.Info
    playUISound("Notify")
    
    local wrapper = Instance.new("Frame", notifyContainer); wrapper.Size = UDim2.new(1, 0, 0, 0); wrapper.AutomaticSize = Enum.AutomaticSize.Y; wrapper.BackgroundTransparency = 1
    local shadow = Instance.new("ImageLabel", wrapper); shadow.Size = UDim2.new(1, 24, 1, 24); shadow.Position = UDim2.new(0, -12, 0, -10)
    shadow.BackgroundTransparency = 1; shadow.Image = "rbxassetid://6014261993"; shadow.ImageColor3 = Color3.new(0,0,0); shadow.ImageTransparency = 0.45; shadow.ScaleType = Enum.ScaleType.Slice; shadow.SliceCenter = Rect.new(49,49,450,450); shadow.ZIndex = 1
    
    local card = Instance.new("Frame", wrapper); card.Size = UDim2.new(1, 0, 0, 0); card.AutomaticSize = Enum.AutomaticSize.Y
    card.Position = UDim2.new(1, 50, 0, 0); card.BackgroundColor3 = Theme.Background; card.BackgroundTransparency = 0.1; card.ZIndex = 2
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", card).Color = Theme.Border
    
    local content = Instance.new("Frame", card); content.Size = UDim2.new(1, 0, 0, 0); content.AutomaticSize = Enum.AutomaticSize.Y; content.BackgroundTransparency = 1; content.ZIndex = 3
    local pad = Instance.new("UIPadding", content); pad.PaddingTop = UDim.new(0, 12); pad.PaddingBottom = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)
    
    local badge = Instance.new("Frame", content); badge.Size = UDim2.new(0, 28, 0, 28); badge.BackgroundColor3 = theme.Accent; badge.BackgroundTransparency = 0.84; badge.ZIndex = 4
    Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
    local icon = Instance.new("TextLabel", badge); icon.Size = UDim2.new(1,0,1,0); icon.BackgroundTransparency = 1; icon.Text = theme.Icon; icon.TextColor3 = theme.Accent; icon.Font = Enum.Font.GothamBold; icon.TextSize = 14
    
    local titleL = Instance.new("TextLabel", content); titleL.Size = UDim2.new(1, -64, 0, 18); titleL.Position = UDim2.new(0, 38, 0, 0); titleL.BackgroundTransparency = 1
    titleL.Text = config.Title or "Sistema"; titleL.TextColor3 = Theme.Text; titleL.Font = Enum.Font.GothamBold; titleL.TextSize = 13; titleL.TextXAlignment = Enum.TextXAlignment.Left
    
    local msgL = Instance.new("TextLabel", content); msgL.Size = UDim2.new(1, -38, 0, 0); msgL.Position = UDim2.new(0, 38, 0, 20); msgL.AutomaticSize = Enum.AutomaticSize.Y; msgL.BackgroundTransparency = 1
    msgL.Text = config.Message or ""; msgL.TextColor3 = Theme.Subtext; msgL.Font = Enum.Font.GothamMedium; msgL.TextSize = 12; msgL.TextWrapped = true; msgL.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeBtn = Instance.new("TextButton", content); closeBtn.Size = UDim2.new(0, 20, 0, 20); closeBtn.Position = UDim2.new(1, -20, 0, -2); closeBtn.BackgroundTransparency = 1; closeBtn.Text = "×"; closeBtn.TextColor3 = Theme.Subtext; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 16
    
    local pTrack = Instance.new("Frame", card); pTrack.Size = UDim2.new(1, 0, 0, 2); pTrack.Position = UDim2.new(0, 0, 1, -2); pTrack.BackgroundColor3 = Theme.Border; pTrack.BackgroundTransparency = 0.94
    local pFill = Instance.new("Frame", pTrack); pFill.Size = UDim2.new(1, 0, 1, 0); pFill.BackgroundColor3 = theme.Accent
    
    local isClosed, isPaused, timeLeft = false, false, config.Duration or 4.5
    local function closeToast()
        if isClosed then return end
        isClosed = true
        local t = TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.new(1, 50, 0, 0), BackgroundTransparency = 1 })
        t:Play(); t.Completed:Once(function() wrapper:Destroy() end)
    end
    closeBtn.MouseButton1Click:Connect(closeToast)
    card.MouseEnter:Connect(function() isPaused = true end)
    card.MouseLeave:Connect(function() isPaused = false end)
    TweenService:Create(card, TweenInfo.new(0.38, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()
    task.spawn(function()
        local lt = os.clock()
        while timeLeft > 0 and not isClosed do
            local dt = os.clock() - lt; lt = os.clock()
            if not isPaused then timeLeft = math.max(0, timeLeft - dt); pFill.Size = UDim2.new(timeLeft / (config.Duration or 4.5), 0, 1, 0) end
            task.wait()
        end
        closeToast()
    end)
end

-- ==========================================
-- 6. FLUTUANTE E MAIN FRAME
-- ==========================================
local floatBtnContainer = Instance.new("Frame", screenGui)
floatBtnContainer.Size = UDim2.new(0, 50, 0, 50); floatBtnContainer.Position = UDim2.new(Config.floatBtnPosXScale, Config.floatBtnPosXOffset, Config.floatBtnPosYScale, Config.floatBtnPosYOffset)
floatBtnContainer.BackgroundTransparency = 1

local dropShadow = Instance.new("ImageLabel", floatBtnContainer)
dropShadow.Size = UDim2.new(1, 8, 1, 8); dropShadow.Position = UDim2.new(0, -4, 0, -4); dropShadow.BackgroundTransparency = 1
dropShadow.Image = "rbxassetid://6014261993"; dropShadow.ImageColor3 = Color3.new(0,0,0); dropShadow.ImageTransparency = 0.5; dropShadow.ScaleType = Enum.ScaleType.Slice; dropShadow.SliceCenter = Rect.new(49,49,450,450); dropShadow.ZIndex = 1

local floatBtn = Instance.new("TextButton", floatBtnContainer)
floatBtn.Size = UDim2.new(1, 0, 1, 0); floatBtn.BackgroundColor3 = Theme.Background; floatBtn.BackgroundTransparency = 0.15
floatBtn.Text = ""; floatBtn.AutoButtonColor = false; floatBtn.ZIndex = 2
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)

local fStroke = Instance.new("UIStroke", floatBtn)
fStroke.Thickness = 1.2; fStroke.Color = Theme.Inactive; fStroke.Transparency = 0.4; fStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local fGradient = Instance.new("UIGradient", fStroke)
fGradient.Rotation = 45
fGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 0.2) })
fGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.Inactive), ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255)) })

local fIcon = Instance.new("TextLabel", floatBtn)
fIcon.Size = UDim2.new(1, 0, 1, 0); fIcon.BackgroundTransparency = 1; fIcon.Text = "L"; fIcon.TextColor3 = Theme.Inactive; fIcon.Font = Enum.Font.GothamMedium; fIcon.TextSize = 24; fIcon.ZIndex = 3

local uiScale = Instance.new("UIScale", floatBtn)
local tHover = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
floatBtn.MouseEnter:Connect(function() TweenService:Create(uiScale, tHover, { Scale = 1.07 }):Play() end)
floatBtn.MouseLeave:Connect(function() TweenService:Create(uiScale, tHover, { Scale = 1 }):Play() end)
floatBtn.MouseButton1Down:Connect(function() TweenService:Create(uiScale, tHover, { Scale = 0.92 }):Play() end)
floatBtn.MouseButton1Up:Connect(function() TweenService:Create(uiScale, tHover, { Scale = 1.07 }):Play() end)

-- Main Frame
local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 800, 0, 480); mainFrame.Position = UDim2.new(0.5, -400, 0.5, -240)
mainFrame.BackgroundColor3 = Theme.Background; mainFrame.BackgroundTransparency = 0.05; mainFrame.Visible = false
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
local mStroke = Instance.new("UIStroke", mainFrame); mStroke.Color = Theme.Border; mStroke.Transparency = 0.85

local mainScale = Instance.new("UIScale", mainFrame)
local function updateScale()
    local vp = Workspace.CurrentCamera.ViewportSize
    mainScale.Scale = math.min(vp.X / 850, vp.Y / 550)
end
updateScale(); Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- Topbar
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

local contentArea = Instance.new("Frame", mainFrame); contentArea.Size = UDim2.new(1,-180,1,-60); contentArea.Position = UDim2.new(0,180,0,50); contentArea.BackgroundTransparency = 1
local scrollContent = Instance.new("ScrollingFrame", contentArea); scrollContent.Size = UDim2.new(1,0,1,0); scrollContent.BackgroundTransparency = 1
scrollContent.ScrollBarThickness = 2; scrollContent.ScrollBarImageColor3 = Theme.Primary; scrollContent.CanvasSize = UDim2.new(0,0,0,0)
local cList = Instance.new("UIListLayout", scrollContent); cList.Padding = UDim.new(0, 8); cList.SortOrder = Enum.SortOrder.LayoutOrder
cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scrollContent.CanvasSize = UDim2.new(0,0,0,cList.AbsoluteContentSize.Y + 20) end)

-- ==========================================
-- 7. COMPONENTS & THEME APPLIER
-- ==========================================
local UI_ELEMENTS = { Surfaces = {}, Accents = {}, Texts = {} } -- Tabelas para facilitar troca de tema

local function registerSurface(frame) table.insert(UI_ELEMENTS.Surfaces, frame) end
local function registerAccent(frame) table.insert(UI_ELEMENTS.Accents, frame) end
local function registerText(label) table.insert(UI_ELEMENTS.Texts, label) end

local function ApplyTheme(themeName)
    Config.theme = themeName
    SaveConfig()
    LoadTheme(themeName)
    
    mainFrame.BackgroundColor3 = Theme.Background
    sidebar.BackgroundColor3 = Theme.Surface
    floatBtn.BackgroundColor3 = Theme.Background
    scrollContent.ScrollBarImageColor3 = Theme.Primary
    
    for _, obj in pairs(UI_ELEMENTS.Surfaces) do obj.BackgroundColor3 = Theme.Surface end
    for _, obj in pairs(UI_ELEMENTS.Accents) do obj.BackgroundColor3 = Theme.Primary end
    for _, obj in pairs(UI_ELEMENTS.Texts) do obj.TextColor3 = Theme.Primary end
    
    if isOpen then
        fStroke.Color = Theme.Primary; fIcon.TextColor3 = Theme.Primary
        fGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.Primary), ColorSequenceKeypoint.new(1, Color3.new(1,1,1)) })
    else
        fStroke.Color = Theme.Inactive; fIcon.TextColor3 = Theme.Inactive
        fGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.Inactive), ColorSequenceKeypoint.new(1, Color3.new(1,1,1)) })
    end
    
    fovCircle.Color = Theme.Primary
    aimbotHighlight.FillColor = Theme.Primary
end

-- Helpers
local function CreateCard(parent, titleText, descText, initialState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 60); card.BackgroundColor3 = Theme.Surface; card.BackgroundTransparency = 0.1
    card.Parent = parent; Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", card); stroke.Color = Theme.Border; stroke.Transparency = 0.9
    registerSurface(card)
    
    local t = Instance.new("TextLabel", card); t.Size = UDim2.new(1, -80, 0, 20); t.Position = UDim2.new(0, 15, 0, 10); t.BackgroundTransparency = 1
    t.Text = titleText; t.TextColor3 = Theme.Text; t.Font = Enum.Font.GothamBold; t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Left
    local d = Instance.new("TextLabel", card); d.Size = UDim2.new(1, -80, 0, 20); d.Position = UDim2.new(0, 15, 0, 30); d.BackgroundTransparency = 1
    d.Text = descText; d.TextColor3 = Theme.Subtext; d.Font = Enum.Font.Gotham; d.TextSize = 11; d.TextXAlignment = Enum.TextXAlignment.Left
    
    local track = Instance.new("TextButton", card); track.Size = UDim2.new(0, 40, 0, 20); track.Position = UDim2.new(1, -55, 0.5, -10)
    track.BackgroundColor3 = initialState and Theme.Primary or Color3.fromRGB(60, 60, 60); track.Text = ""
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    if initialState then registerAccent(track) end
    
    local thumb = Instance.new("Frame", track); thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = initialState and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 4, 0.5, -6)
    thumb.BackgroundColor3 = Theme.Text; Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    
    local state = initialState
    track:SetAttribute("IsOn", state)
    track.MouseButton1Click:Connect(function()
        state = not state
        track:SetAttribute("IsOn", state)
        playUISound(state and "ToggleOn" or "ToggleOff")
        TweenService:Create(thumb, TweenInfo.new(0.1), { Size = UDim2.new(0, 16, 0, 16) }):Play()
        task.delay(0.1, function() TweenService:Create(thumb, TweenInfo.new(0.1), { Size = UDim2.new(0, 12, 0, 12) }):Play() end)
        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = state and Theme.Primary or Color3.fromRGB(60, 60, 60) }):Play()
        TweenService:Create(thumb, TweenInfo.new(0.15), { Position = state and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 4, 0.5, -6) }):Play()
        if state then table.insert(UI_ELEMENTS.Accents, track) else 
            for i, v in ipairs(UI_ELEMENTS.Accents) do if v == track then table.remove(UI_ELEMENTS.Accents, i) break end end 
        end
        pcall(callback, state)
    end)
    card.MouseEnter:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.6 }):Play() end)
    card.MouseLeave:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.9 }):Play() end)
end

local Tabs, TabButtons = {}, {}
local function CreateTab(name)
    local btn = Instance.new("TextButton", sidebar); btn.Size = UDim2.new(1, -20, 0, 36)
    btn.BackgroundColor3 = Theme.Surface; btn.BackgroundTransparency = 1
    btn.Text = "   " .. name; btn.TextColor3 = Theme.Subtext; btn.Font = Enum.Font.GothamBold; btn.TextSize = 13; btn.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local ind = Instance.new("Frame", btn); ind.Size = UDim2.new(0, 3, 0.4, 0); ind.Position = UDim2.new(0, 0, 0.3, 0)
    ind.BackgroundColor3 = Theme.Primary; ind.Visible = false; Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)
    registerAccent(ind)
    
    local frame = Instance.new("Frame", scrollContent); frame.Size = UDim2.new(1,0,0,0); frame.AutomaticSize = Enum.AutomaticSize.Y; frame.BackgroundTransparency = 1; frame.Visible = false
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
-- 8. POPULANDO TABS (Incluindo Config)
-- ==========================================
local TabHome = CreateTab("Home")
local TabPlayer = CreateTab("Player")
local TabVisuals = CreateTab("Visuals")
local TabMisc = CreateTab("Misc")
local TabConfig = CreateTab("Config")

-- HOME
local homeLabel = Instance.new("TextLabel", TabHome); homeLabel.Size = UDim2.new(1, 0, 0, 60); homeLabel.BackgroundTransparency = 1
homeLabel.Text = "Bem-vindo ao L HUB FluentPro v91.\nAltere o tema do seu HUB na aba Config."; homeLabel.TextColor3 = Theme.Subtext
homeLabel.Font = Enum.Font.GothamMedium; homeLabel.TextSize = 14; homeLabel.TextXAlignment = Enum.TextXAlignment.Left; homeLabel.TextYAlignment = Enum.TextYAlignment.Top

-- PLAYER
CreateCard(TabPlayer, "Enable Aimbot", "Ativa a mira automática (Aim Assist).", Config.aimbotEnabled, function(s) Config.aimbotEnabled = s; SaveConfig() end)
CreateCard(TabPlayer, "FOV Circle", "Mostra o alcance da mira na tela.", Config.fovCircleOn, function(s) Config.fovCircleOn = s; fovCircle.Visible = s; SaveConfig() end)

-- VISUALS
CreateCard(TabVisuals, "ESP Rokakaka Plant", "Destaca plantas no mapa.", Config.espRokaPlant, function(s) Config.espRokaPlant = s; SaveConfig() end)
CreateCard(TabVisuals, "ESP Rokakaka Fruit", "Destaca frutas no mapa.", Config.espRokaFruit, function(s) Config.espRokaFruit = s; SaveConfig() end)

-- MISC
CreateCard(TabMisc, "Auto Collect", "Coleta itens automaticamente.", Config.autoCollect, function(s) Config.autoCollect = s; SaveConfig() end)

-- CONFIG (Theme Switcher)
local themeLabel = Instance.new("TextLabel", TabConfig); themeLabel.Size = UDim2.new(1, -10, 0, 20); themeLabel.BackgroundTransparency = 1
themeLabel.Text = "Selecione o Tema da UI:"; themeLabel.TextColor3 = Theme.Text; themeLabel.Font = Enum.Font.GothamBold; themeLabel.TextSize = 13; themeLabel.TextXAlignment = Enum.TextXAlignment.Left

for themeName, colors in pairs(ThemePalettes) do
    local btn = Instance.new("TextButton", TabConfig)
    btn.Size = UDim2.new(1, -10, 0, 40); btn.BackgroundColor3 = colors.Surface; btn.BackgroundTransparency = 0.2
    btn.Text = "   " .. themeName; btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 13; btn.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", btn); stroke.Color = colors.Primary; stroke.Thickness = 2; stroke.Transparency = 0.5
    
    btn.MouseButton1Click:Connect(function()
        playUISound("Click")
        ApplyTheme(themeName)
        notifyPro({ Title = "Tema Alterado", Message = "A UI foi atualizada para " .. themeName, Type = "Info", Duration = 3 })
    end)
end

-- Default Tab
TabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 50); TabButtons["Home"].BackgroundTransparency = 0.4
TabButtons["Home"].TextColor3 = Theme.Text; TabButtons["Home"]:FindFirstChildWhichIsA("Frame").Visible = true; Tabs["Home"].Visible = true

-- ==========================================
-- 9. DRAG & FINAL BINDINGS
-- ==========================================
local isOpen = false
local dragging, moved, dragInput, dragStart, startPos
local dragThreshold = 6

local function toggleMenu()
    isOpen = not isOpen
    playUISound(isOpen and "OpenUI" or "CloseUI")
    if isOpen then
        mainFrame.Visible = true
        mainScale.Scale = 0.9
        TweenService:Create(mainScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        TweenService:Create(fStroke, TweenInfo.new(0.2), { Color = Theme.Primary }):Play()
        TweenService:Create(fGradient, TweenInfo.new(0.2), { Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Primary), ColorSequenceKeypoint.new(1, Color3.new(1,1,1))}) }):Play()
        TweenService:Create(fIcon, TweenInfo.new(0.2), { TextColor3 = Theme.Primary }):Play()
    else
        local closeTween = TweenService:Create(mainScale, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Scale = 0.9 })
        closeTween:Play()
        TweenService:Create(fStroke, TweenInfo.new(0.2), { Color = Theme.Inactive }):Play()
        TweenService:Create(fGradient, TweenInfo.new(0.2), { Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.Inactive), ColorSequenceKeypoint.new(1, Color3.new(1,1,1))}) }):Play()
        TweenService:Create(fIcon, TweenInfo.new(0.2), { TextColor3 = Theme.Inactive }):Play()
        closeTween.Completed:Connect(function() if not isOpen then mainFrame.Visible = false end end)
    end
end

floatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; moved = false; dragStart = input.Position; startPos = floatBtnContainer.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if not moved then toggleMenu() end
            end
        end)
    end
end)

floatBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        if delta.Magnitude > dragThreshold then moved = true end
        if moved then
            local targetPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            TweenService:Create(floatBtnContainer, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
        end
    end
end)

floatBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if moved then
            Config.floatBtnPosXScale = floatBtnContainer.Position.X.Scale
            Config.floatBtnPosXOffset = floatBtnContainer.Position.X.Offset
            Config.floatBtnPosYScale = floatBtnContainer.Position.Y.Scale
            Config.floatBtnPosYOffset = floatBtnContainer.Position.Y.Offset
            SaveConfig()
        end
    end
end)

-- Drag Main Frame
local draggingMain, dragStartMain, startPosMain
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingMain = true; dragStartMain = input.Position; startPosMain = mainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingMain = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartMain
        mainFrame.Position = UDim2.new(startPosMain.X.Scale, startPosMain.X.Offset + delta.X, startPosMain.Y.Scale, startPosMain.Y.Offset + delta.Y)
    end
end)

-- Inicia com o tema carregado
ApplyTheme(Config.theme)

warn("[L HUB v91] FluentPro Theme Switcher Carregado.")
