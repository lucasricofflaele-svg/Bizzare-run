-- language: Lua, file: LHub_v88.lua, target: Roblox (Delta Executor)
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CONFIG_FILE = "LHub_Config_v88.json"

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
-- 3. CORE LOGIC (Aimbot, ESP, Coleta, Race)
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
local aimbotTarget = nil
local aimbotHighlight = Instance.new("Highlight")
aimbotHighlight.FillColor = Color3.fromRGB(147, 51, 255)
aimbotHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
aimbotHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
aimbotHighlight.Enabled = false
aimbotHighlight.Parent = CoreGui
_G.LHub.Highlight = aimbotHighlight

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = Config.fovCircleOn
fovCircle.Radius = Config.aimbotFov
fovCircle.Color = Color3.fromRGB(147, 51, 255)
fovCircle.Thickness = 1.5
fovCircle.Filled = false
_G.LHub.FovCircle = fovCircle

RunService:BindToRenderStep("LHubAimbot", Enum.RenderPriority.Last.Value, function(dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
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

-- Race Core (State Machine)
task.spawn(function()
    local lastState = "WAITING"
    while task.wait(0.5) do
        if not Config.autoRaceEnabled then continue end
        local char = LocalPlayer.Character
        if not char or not char.Parent then continue end
        local rigs = Workspace:FindFirstChild("Rigs")
        local myRig = rigs and rigs:FindFirstChild(LocalPlayer.Name)
        local placement = myRig and myRig:GetAttribute("Placement") or 0
        local isFinished = myRig and myRig:GetAttribute("Finished") == true
        local guiEnded = PlayerGui:FindFirstChild("RaceEnded") and PlayerGui.RaceEnded.Enabled
        
        if guiEnded or isFinished then
            lastState = "FINISHED"
        elseif placement > 0 and not guiEnded then
            lastState = "RUNNING"
        else
            lastState = "WAITING"
        end
    end
end)

-- ==========================================
-- 4. FLUENT PRO UI (MODULAR)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FluentProUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end
_G.LHub.Gui = screenGui

-- Paleta Fluent Design
local Theme = {
    Background = Color3.fromRGB(32, 32, 32),      -- Fundo Mica (Acrylic)
    Surface = Color3.fromRGB(43, 43, 43),         -- Cards e Sidebar
    Primary = Color3.fromRGB(0, 120, 212),        -- Azul Fluent (Accent)
    Text = Color3.fromRGB(255, 255, 255),
    Subtext = Color3.fromRGB(170, 170, 170),
    Border = Color3.fromRGB(255, 255, 255)        -- Para UIStroke com transparência
}

-- ==========================================
-- 5. BOTÃO FLUTUANTE PREMIUM (Glassmorphism + Neon)
-- ==========================================
local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 55, 0, 55)
floatBtn.Position = UDim2.new(Config.floatBtnPosXScale, Config.floatBtnPosXOffset, Config.floatBtnPosYScale, Config.floatBtnPosYOffset)
floatBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20) -- Fundo Glass escuro
floatBtn.BackgroundTransparency = 0.3
floatBtn.Text = ""
floatBtn.AutoButtonColor = false
floatBtn.Active = true
floatBtn.Parent = screenGui

local fCorner = Instance.new("UICorner", floatBtn)
fCorner.CornerRadius = UDim.new(1, 0)

-- Borda Neon com Gradiente
local fStroke = Instance.new("UIStroke", floatBtn)
fStroke.Thickness = 2
fStroke.Transparency = 0.1
fStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local fGradient = Instance.new("UIGradient")
fGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Primary),        -- Azul
    ColorSequenceKeypoint.new(1, Color3.fromRGB(147, 51, 255)) -- Roxo Neon
})
fGradient.Rotation = 45
fGradient.Parent = fStroke

-- Ícone do Botão
local fIcon = Instance.new("TextLabel", floatBtn)
fIcon.Size = UDim2.new(1, 0, 1, 0)
fIcon.BackgroundTransparency = 1
fIcon.Text = "L"
fIcon.TextColor3 = Color3.new(1, 1, 1)
fIcon.Font = Enum.Font.GothamBlack
fIcon.TextSize = 28

local fIconGradient = Instance.new("UIGradient", fIcon)
fIconGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
})
fIconGradient.Rotation = 90
fIconGradient.Parent = fIcon

-- Sombra/Glow externo
local fGlow = Instance.new("Frame", floatBtn)
fGlow.Size = UDim2.new(1, 10, 1, 10)
fGlow.Position = UDim2.new(0, -5, 0, -5)
fGlow.BackgroundColor3 = Color3.fromRGB(147, 51, 255)
fGlow.BackgroundTransparency = 0.85
fGlow.ZIndex = 0
floatBtn.ZIndex = 2
fIcon.ZIndex = 3
local fGlowCorner = Instance.new("UICorner", fGlow)
fGlowCorner.CornerRadius = UDim.new(1, 0)

-- Micro-interações (Hover / Touch)
local function animateScale(scale)
    local targetSize = UDim2.new(0, 55 * scale, 0, 55 * scale)
    local offset = (55 - 55 * scale) / 2
    local targetPos = UDim2.new(floatBtn.Position.X.Scale, floatBtn.Position.X.Offset + offset, floatBtn.Position.Y.Scale, floatBtn.Position.Y.Offset + offset)
    TweenService:Create(floatBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = targetSize, Position = targetPos }):Play()
end

floatBtn.MouseEnter:Connect(function()
    animateScale(1.1)
    TweenService:Create(fGlow, TweenInfo.new(0.2), { BackgroundTransparency = 0.6 }):Play()
    TweenService:Create(fStroke, TweenInfo.new(0.2), { Thickness = 2.5 }):Play()
end)

floatBtn.MouseLeave:Connect(function()
    animateScale(1.0)
    TweenService:Create(fGlow, TweenInfo.new(0.2), { BackgroundTransparency = 0.85 }):Play()
    TweenService:Create(fStroke, TweenInfo.new(0.2), { Thickness = 2 }):Play()
end)

floatBtn.MouseButton1Down:Connect(function()
    animateScale(0.95)
end)

floatBtn.MouseButton1Up:Connect(function()
    animateScale(1.1)
end)

-- ==========================================
-- 6. JANELA PRINCIPAL (FLUENT DESIGN)
-- ==========================================
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 800, 0, 480)
mainFrame.Position = UDim2.new(0.5, -400, 0.5, -240)
mainFrame.BackgroundColor3 = Theme.Background
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
local mS = Instance.new("UIStroke", mainFrame); mS.Color = Theme.Border; mS.Thickness = 1; mS.Transparency = 0.85

local uiScale = Instance.new("UIScale", mainFrame)
local function updateScale()
    local vp = Workspace.CurrentCamera.ViewportSize
    uiScale.Scale = math.min(vp.X / 850, vp.Y / 550)
end
updateScale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- Topbar (Header)
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 50)
topBar.BackgroundTransparency = 1
topBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 300, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "L HUB"
title.TextColor3 = Theme.Text
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local subTitle = Instance.new("TextLabel")
subTitle.Size = UDim2.new(0, 300, 1, 0)
subTitle.Position = UDim2.new(0, 75, 0, 0)
subTitle.BackgroundTransparency = 1
subTitle.Text = "Fluent Edition"
subTitle.TextColor3 = Theme.Primary
subTitle.Font = Enum.Font.Gotham
subTitle.TextSize = 12
subTitle.TextXAlignment = Enum.TextXAlignment.Left
subTitle.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -45, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Theme.Text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 160, 1, -60)
sidebar.Position = UDim2.new(0, 10, 0, 50)
sidebar.BackgroundColor3 = Theme.Surface
sidebar.BackgroundTransparency = 0.3
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local sList = Instance.new("UIListLayout", sidebar); sList.Padding = UDim.new(0, 5); sList.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", sidebar).PaddingTop = UDim.new(0, 10)

-- Content Area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -180, 1, -60)
contentArea.Position = UDim2.new(0, 180, 0, 50)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local scrollContent = Instance.new("ScrollingFrame")
scrollContent.Size = UDim2.new(1, 0, 1, 0)
scrollContent.BackgroundTransparency = 1
scrollContent.ScrollBarThickness = 2
scrollContent.ScrollBarImageColor3 = Theme.Primary
scrollContent.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollContent.Parent = contentArea
local cList = Instance.new("UIListLayout", scrollContent); cList.Padding = UDim.new(0, 8); cList.SortOrder = Enum.SortOrder.LayoutOrder
cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scrollContent.CanvasSize = UDim2.new(0, 0, 0, cList.AbsoluteContentSize.Y + 20) end)

-- ==========================================
-- 7. UI COMPONENTS (FLUENT DESIGN)
-- ==========================================

local function CreateCard(parent, titleText, descText, initialState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -10, 0, 60)
    card.BackgroundColor3 = Theme.Surface
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", card); stroke.Color = Theme.Border; stroke.Transparency = 0.9
    
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -80, 0, 20); t.Position = UDim2.new(0, 15, 0, 10); t.BackgroundTransparency = 1
    t.Text = titleText; t.TextColor3 = Theme.Text; t.Font = Enum.Font.GothamBold; t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = card
    
    local d = Instance.new("TextLabel")
    d.Size = UDim2.new(1, -80, 0, 20); d.Position = UDim2.new(0, 15, 0, 30); d.BackgroundTransparency = 1
    d.Text = descText; d.TextColor3 = Theme.Subtext; d.Font = Enum.Font.Gotham; d.TextSize = 11; d.TextXAlignment = Enum.TextXAlignment.Left
    d.Parent = card
    
    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 40, 0, 20); track.Position = UDim2.new(1, -55, 0.5, -10)
    track.BackgroundColor3 = initialState and Theme.Primary or Color3.fromRGB(60, 60, 60); track.Text = ""
    track.Parent = card
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.Position = initialState and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 4, 0.5, -6)
    thumb.BackgroundColor3 = Theme.Text
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    
    local state = initialState
    track.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = state and Theme.Primary or Color3.fromRGB(60, 60, 60) }):Play()
        TweenService:Create(thumb, TweenInfo.new(0.15), { Position = state and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 4, 0.5, -6) }):Play()
        pcall(callback, state)
    end)
    
    card.MouseEnter:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.6 }):Play() end)
    card.MouseLeave:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Transparency = 0.9 }):Play() end)
end

local Tabs = {}
local TabButtons = {}

local function CreateTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 36)
    btn.BackgroundColor3 = Theme.Surface
    btn.BackgroundTransparency = 1
    btn.Text = "   " .. name
    btn.TextColor3 = Theme.Subtext
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    -- Indicador lateral (Fluent Pill)
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0.4, 0); indicator.Position = UDim2.new(0, 0, 0.3, 0)
    indicator.BackgroundColor3 = Theme.Primary; indicator.Visible = false
    indicator.Parent = btn
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 0); frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1; frame.Visible = false
    frame.Parent = scrollContent
    local tLayout = Instance.new("UIListLayout", frame); tLayout.Padding = UDim.new(0, 8); tLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    TabButtons[name] = btn
    Tabs[name] = frame
    
    btn.MouseButton1Click:Connect(function()
        for _, f in pairs(Tabs) do f.Visible = false end
        for _, b in pairs(TabButtons) do
            TweenService:Create(b, TweenInfo.new(0.15), { BackgroundTransparency = 1, TextColor3 = Theme.Subtext }):Play()
            b:FindFirstChildWhichIsA("Frame").Visible = false
        end
        frame.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(50, 50, 50), BackgroundTransparency = 0.4, TextColor3 = Theme.Text }):Play()
        indicator.Visible = true
    end)
    
    return frame
end

-- ==========================================
-- 8. POPULATING TABS
-- ==========================================
local TabHome = CreateTab("Home")
local TabAutoRace = CreateTab("Auto Race")
local TabPlayer = CreateTab("Player")
local TabVisuals = CreateTab("Visuals")
local TabMisc = CreateTab("Misc")

-- HOME
local welcomeCard = Instance.new("Frame")
welcomeCard.Size = UDim2.new(1, -10, 0, 100); welcomeCard.BackgroundColor3 = Theme.Surface
welcomeCard.BackgroundTransparency = 0.2; welcomeCard.Parent = TabHome
Instance.new("UICorner", welcomeCard).CornerRadius = UDim.new(0, 8)
local wText = Instance.new("TextLabel")
wText.Size = UDim2.new(1, -20, 1, -20); wText.Position = UDim2.new(0, 10, 0, 10)
wText.BackgroundTransparency = 1; wText.Text = "Bem-vindo ao L HUB FluentPro.\nSelecione uma opção na barra lateral para começar."
wText.TextColor3 = Theme.Text; wText.Font = Enum.Font.Gotham; wText.TextSize = 13; wText.TextXAlignment = Enum.TextXAlignment.Left; wText.TextYAlignment = Enum.TextYAlignment.Top
wText.Parent = welcomeCard

-- AUTO RACE
CreateCard(TabAutoRace, "Enable Auto Race", "Sistema de corrida automática e bypass de checkpoints.", Config.autoRaceEnabled, function(s) Config.autoRaceEnabled = s; SaveConfig() end)

-- PLAYER
CreateCard(TabPlayer, "Enable Aimbot", "Ativa a mira automática (Aim Assist).", Config.aimbotEnabled, function(s) Config.aimbotEnabled = s; SaveConfig() end)
CreateCard(TabPlayer, "FOV Circle", "Mostra o alcance da mira na tela.", Config.fovCircleOn, function(s) Config.fovCircleOn = s; fovCircle.Visible = s; SaveConfig() end)

-- VISUALS
CreateCard(TabVisuals, "ESP Rokakaka Plant", "Destaca plantas no mapa.", Config.espRokaPlant, function(s) Config.espRokaPlant = s; SaveConfig() end)
CreateCard(TabVisuals, "ESP Rokakaka Fruit", "Destaca frutas no mapa.", Config.espRokaFruit, function(s) Config.espRokaFruit = s; SaveConfig() end)
CreateCard(TabVisuals, "ESP Arrow", "Destaca flechas normais.", Config.espArrow, function(s) Config.espArrow = s; SaveConfig() end)
CreateCard(TabVisuals, "ESP Arrow Shiny", "Destaca flechas raras.", Config.espShiny, function(s) Config.espShiny = s; SaveConfig() end)

-- MISC
CreateCard(TabMisc, "Auto Collect", "Coleta itens (Rokakaka) automaticamente.", Config.autoCollect, function(s) Config.autoCollect = s; SaveConfig() end)

-- Default Tab
TabButtons["Home"].BackgroundColor3 = Color3.fromRGB(50, 50, 50)
TabButtons["Home"].BackgroundTransparency = 0.4
TabButtons["Home"].TextColor3 = Theme.Text
TabButtons["Home"]:FindFirstChildWhichIsA("Frame").Visible = true
Tabs["Home"].Visible = true

-- ==========================================
-- 9. DRAG & FINAL BINDINGS
-- ==========================================
local dragging, dragInput, dragStart, startPos
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

-- Drag do Botão Flutuante
local btnDragging = false
local btnDragStart, btnStartPos

floatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        btnDragging = true
        btnDragStart = input.Position
        btnStartPos = floatBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                btnDragging = false
                Config.floatBtnPosXScale = floatBtn.Position.X.Scale
                Config.floatBtnPosXOffset = floatBtn.Position.X.Offset
                Config.floatBtnPosYScale = floatBtn.Position.Y.Scale
                Config.floatBtnPosYOffset = floatBtn.Position.Y.Offset
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

-- Ação de clicar e abrir o menu
floatBtn.MouseButton1Click:Connect(function()
    if not btnDragging then
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            mainFrame.Size = UDim2.new(0, 800, 0, 480)
            mainFrame.Position = UDim2.new(0.5, -400, 0.5, -240)
        end
    end
end)

warn("[L HUB v88] UI FluentPro e Botão Premium Carregados.")
