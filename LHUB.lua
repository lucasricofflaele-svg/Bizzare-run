-- language: Lua, file: LHub_v87.lua, target: Roblox (Delta Executor)
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
local CONFIG_FILE = "LHub_Config_v87.json"

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
    local success, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if success and type(data) == "table" then
        for k, v in pairs(data) do if Config[k] ~= nil then Config[k] = v end end
    end
end

local function SaveConfig()
    if writefile then
        local data = {}
        for k, v in pairs(Config) do data[k] = v end
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
    end
end

-- ==========================================
-- 2. CLEANUP
-- ==========================================
if _G.LHub then
    pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
    if _G.LHub.Tasks then for _, t in pairs(_G.LHub.Tasks) do if coroutine.status(t) ~= "dead" then pcall(task.cancel, t) end end end
    if _G.LHub.Conns then for _, c in pairs(_G.LHub.Conns) do pcall(function() c:Disconnect() end) end end
    if _G.LHub.Gui then pcall(function() _G.LHub.Gui:Destroy() end) end
    if _G.LHub.ESPObjects then for _, d in pairs(_G.LHub.ESPObjects) do if d.hl then d.hl:Destroy() end if d.bb then d.bb:Destroy() end end end
    if _G.LHub.FovCircle then pcall(function() _G.LHub.FovCircle:Remove() end) end
    if _G.LHub.Highlight then pcall(function() _G.LHub.Highlight:Destroy() end) end
end

_G.LHub = { Gui = nil, Tasks = {}, Conns = {}, ESPObjects = {} }

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

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = Config.fovCircleOn
fovCircle.Radius = Config.aimbotFov
fovCircle.Color = Color3.fromRGB(147, 51, 255)
fovCircle.Thickness = 1.5
fovCircle.Filled = false

local function getAimEntry(model)
    local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
    if head then return head end
    return nil
end

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
            local targetPart = getAimEntry(plr.Character)
            if targetPart then
                local sp, os = cam:WorldToViewportPoint(targetPart.Position)
                if os then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < minDist then
                        minDist = d
                        closest = targetPart
                    end
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
            -- (O teleporte da corrida em si ocorre aqui na sua lógica de checkpoints)
        else
            lastState = "WAITING"
        end
    end
end)

-- ==========================================
-- 4. PREMIUM UI (DELTA STYLE)
-- ==========================================
local COLORS = {
    BG = Color3.fromRGB(11, 9, 17),        -- #0B0911
    SIDEBAR = Color3.fromRGB(21, 17, 31),  -- #15111F
    CARDS = Color3.fromRGB(32, 23, 45),    -- #20172D
    PRIMARY = Color3.fromRGB(147, 51, 255),-- #9333FF
    TEXT = Color3.fromRGB(255, 255, 255),
    SECONDARY = Color3.fromRGB(146, 144, 159) -- #92909F
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LHub_v86"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end
_G.LHub.Gui = screenGui

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 50, 0, 50)
floatBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
floatBtn.BackgroundColor3 = COLORS.BG
floatBtn.Text = "L"
floatBtn.TextColor3 = COLORS.PRIMARY
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 26
floatBtn.Parent = screenGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)
local fS = Instance.new("UIStroke", floatBtn); fS.Color = COLORS.PRIMARY; fS.Thickness = 2

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 900, 0, 540)
mainFrame.Position = UDim2.new(0.5, -450, 0.5, -270)
mainFrame.BackgroundColor3 = COLORS.BG
mainFrame.Visible = false
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
local mS = Instance.new("UIStroke", mainFrame); mS.Color = COLORS.CARDS; mS.Thickness = 1.5

local uiScale = Instance.new("UIScale", mainFrame)
local function updateScale()
    local vp = Workspace.CurrentCamera.ViewportSize
    uiScale.Scale = math.min(vp.X / 950, vp.Y / 600)
end
updateScale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- Topbar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 58)
topBar.BackgroundColor3 = COLORS.SIDEBAR
topBar.Parent = mainFrame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 300, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "L HUB   |   <font color='#9333FF'>SCRIPT HUB v87</font>"
title.RichText = true
title.TextColor3 = COLORS.TEXT
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -45, 0.5, -15)
closeBtn.BackgroundColor3 = COLORS.CARDS
closeBtn.Text = "X"
closeBtn.TextColor3 = COLORS.TEXT
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 165, 1, -68)
sidebar.Position = UDim2.new(0, 10, 0, 58)
sidebar.BackgroundColor3 = COLORS.SIDEBAR
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local sList = Instance.new("UIListLayout", sidebar); sList.Padding = UDim.new(0, 5); sList.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", sidebar).PaddingTop = UDim.new(0, 15)

-- Profile na Sidebar
local profile = Instance.new("Frame")
profile.Size = UDim2.new(1, -20, 0, 60)
profile.Position = UDim2.new(0, 10, 1, -70)
profile.BackgroundColor3 = COLORS.CARDS
profile.Parent = sidebar
Instance.new("UICorner", profile).CornerRadius = UDim.new(0, 6)

local pImg = Instance.new("ImageLabel")
pImg.Size = UDim2.new(0, 35, 0, 35); pImg.Position = UDim2.new(0, 10, 0.5, -17.5)
pImg.BackgroundColor3 = COLORS.PRIMARY
pImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=48&h=48"
pImg.Parent = profile
Instance.new("UICorner", pImg).CornerRadius = UDim.new(1, 0)

local pName = Instance.new("TextLabel")
pName.Size = UDim2.new(1, -50, 0, 20); pName.Position = UDim2.new(0, 50, 0, 10)
pName.BackgroundTransparency = 1; pName.Text = LocalPlayer.DisplayName
pName.TextColor3 = COLORS.TEXT; pName.Font = Enum.Font.GothamBold; pName.TextSize = 12; pName.TextXAlignment = Enum.TextXAlignment.Left
pName.Parent = profile

local pTag = Instance.new("TextLabel")
pTag.Size = UDim2.new(1, -50, 0, 15); pTag.Position = UDim2.new(0, 50, 0, 30)
pTag.BackgroundTransparency = 1; pTag.Text = "Premium"
pTag.TextColor3 = COLORS.PRIMARY; pTag.Font = Enum.Font.Gotham; pTag.TextSize = 10; pTag.TextXAlignment = Enum.TextXAlignment.Left
pTag.Parent = profile

-- Areas
local centerArea = Instance.new("Frame")
centerArea.Size = UDim2.new(0, 430, 1, -68); centerArea.Position = UDim2.new(0, 185, 0, 58)
centerArea.BackgroundTransparency = 1; centerArea.Parent = mainFrame

local previewArea = Instance.new("Frame")
previewArea.Size = UDim2.new(0, 265, 1, -68); previewArea.Position = UDim2.new(0, 625, 0, 58)
previewArea.BackgroundColor3 = COLORS.SIDEBAR; previewArea.Parent = mainFrame
Instance.new("UICorner", previewArea).CornerRadius = UDim.new(0, 8)

local previewTitle = Instance.new("TextLabel")
previewTitle.Size = UDim2.new(1, 0, 0, 40); previewTitle.BackgroundTransparency = 1
previewTitle.Text = "Visual Preview"; previewTitle.TextColor3 = COLORS.TEXT; previewTitle.Font = Enum.Font.GothamBold; previewTitle.TextSize = 14
previewTitle.Parent = previewArea

local previewImg = Instance.new("ImageLabel")
previewImg.Size = UDim2.new(0, 100, 0, 100); previewImg.Position = UDim2.new(0.5, -50, 0, 50)
previewImg.BackgroundColor3 = COLORS.BG
previewImg.Image = "rbxthumb://type=AvatarFullBody&id=" .. LocalPlayer.UserId .. "&w=420&h=420"
previewImg.Parent = previewArea
Instance.new("UICorner", previewImg).CornerRadius = UDim.new(0, 8)

local previewStatus = Instance.new("TextLabel")
previewStatus.Size = UDim2.new(1, -20, 0, 60); previewStatus.Position = UDim2.new(0, 10, 0, 160)
previewStatus.BackgroundTransparency = 1; previewStatus.Text = "Nenhuma função ativa."
previewStatus.TextColor3 = COLORS.SECONDARY; previewStatus.Font = Enum.Font.Gotham; previewStatus.TextSize = 12; previewStatus.TextWrapped = true; previewStatus.TextYAlignment = Enum.TextYAlignment.Top
previewStatus.Parent = previewArea

local applyBtn = Instance.new("TextButton")
applyBtn.Size = UDim2.new(1, -20, 0, 40); applyBtn.Position = UDim2.new(0, 10, 1, -50)
applyBtn.BackgroundColor3 = COLORS.PRIMARY; applyBtn.Text = "Apply Changes"
applyBtn.TextColor3 = COLORS.TEXT; applyBtn.Font = Enum.Font.GothamBold; applyBtn.TextSize = 13
applyBtn.Parent = previewArea
Instance.new("UICorner", applyBtn).CornerRadius = UDim.new(0, 6)
applyBtn.MouseButton1Click:Connect(function() SaveConfig() end)

local scrollContent = Instance.new("ScrollingFrame")
scrollContent.Size = UDim2.new(1, 0, 1, 0); scrollContent.BackgroundTransparency = 1
scrollContent.ScrollBarThickness = 2; scrollContent.ScrollBarImageColor3 = COLORS.PRIMARY; scrollContent.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollContent.Parent = centerArea
local cList = Instance.new("UIListLayout", scrollContent); cList.Padding = UDim.new(0, 10); cList.SortOrder = Enum.SortOrder.LayoutOrder
cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scrollContent.CanvasSize = UDim2.new(0, 0, 0, cList.AbsoluteContentSize.Y + 20) end)

-- UI Helpers
local function createCard(parent, titleText, descText, initialState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 64)
    card.BackgroundColor3 = COLORS.CARDS
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(41, 35, 51); stroke.Thickness = 1
    
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -60, 0, 20); t.Position = UDim2.new(0, 15, 0, 12); t.BackgroundTransparency = 1
    t.Text = titleText; t.TextColor3 = COLORS.TEXT; t.Font = Enum.Font.GothamBold; t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = card
    
    local d = Instance.new("TextLabel")
    d.Size = UDim2.new(1, -60, 0, 20); d.Position = UDim2.new(0, 15, 0, 32); d.BackgroundTransparency = 1
    d.Text = descText; d.TextColor3 = COLORS.SECONDARY; d.Font = Enum.Font.Gotham; d.TextSize = 11; d.TextXAlignment = Enum.TextXAlignment.Left
    d.Parent = card
    
    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 42, 0, 22); track.Position = UDim2.new(1, -57, 0.5, -11)
    track.BackgroundColor3 = initialState and COLORS.PRIMARY or Color3.fromRGB(40, 40, 50); track.Text = ""
    track.Parent = card
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 18, 0, 18)
    thumb.Position = initialState and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    thumb.BackgroundColor3 = COLORS.TEXT
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    
    local state = initialState
    track.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = state and COLORS.PRIMARY or Color3.fromRGB(40, 40, 50) }):Play()
        TweenService:Create(thumb, TweenInfo.new(0.15), { Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }):Play()
        pcall(callback, state)
    end)
    
    -- Efeito Hover
    card.MouseEnter:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Color = COLORS.PRIMARY }):Play() end)
    card.MouseLeave:Connect(function() TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(41, 35, 51) }):Play() end)
end

local Tabs = {}
local TabButtons = {}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 38)
    btn.BackgroundColor3 = COLORS.CARDS
    btn.BackgroundTransparency = 1
    btn.Text = "   " .. name
    btn.TextColor3 = COLORS.SECONDARY
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0.6, 0); indicator.Position = UDim2.new(0, 0, 0.2, 0)
    indicator.BackgroundColor3 = COLORS.PRIMARY; indicator.Visible = false
    indicator.Parent = btn
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 2)
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 0); frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1; frame.Visible = false
    frame.Parent = scrollContent
    local tLayout = Instance.new("UIListLayout", frame); tLayout.Padding = UDim.new(0, 10); tLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    TabButtons[name] = btn
    Tabs[name] = frame
    
    btn.MouseButton1Click:Connect(function()
        for _, f in pairs(Tabs) do f.Visible = false end
        for _, b in pairs(TabButtons) do
            TweenService:Create(b, TweenInfo.new(0.15), { BackgroundTransparency = 1, TextColor3 = COLORS.SECONDARY }):Play()
            b:FindFirstChildWhichIsA("Frame").Visible = false
        end
        frame.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = COLORS.CARDS, BackgroundTransparency = 0.3, TextColor3 = COLORS.TEXT }):Play()
        indicator.Visible = true
    end)
    
    return frame
end

-- ==========================================
-- 5. POPULANDO ABAS
-- ==========================================
local TabHome = createTab("Home")
local TabAutoRace = createTab("Auto Race")
local TabVisuals = createTab("Visuals")
local TabPlayer = createTab("Player")
local TabTeleport = createTab("Teleport")
local TabMisc = createTab("Misc")
local TabSettings = createTab("Settings")

-- HOME
local homeLabel = Instance.new("TextLabel")
homeLabel.Size = UDim2.new(1, 0, 0, 50); homeLabel.BackgroundTransparency = 1
homeLabel.Text = "Bem-vindo ao L HUB Nexus."
homeLabel.TextColor3 = COLORS.SECONDARY; homeLabel.Font = Enum.Font.Gotham; homeLabel.TextSize = 14; homeLabel.TextXAlignment = Enum.TextXAlignment.Left
homeLabel.Parent = TabHome

-- AUTO RACE
createCard(TabAutoRace, "Enable Auto Race", "Piloto automático para as corridas.", Config.autoRaceEnabled, function(s) Config.autoRaceEnabled = s; SaveConfig() end)

-- VISUALS
createCard(TabVisuals, "ESP Rokakaka Plant", "Destaca plantas no mapa.", Config.espRokaPlant, function(s) Config.espRokaPlant = s; SaveConfig() end)
createCard(TabVisuals, "ESP Rokakaka Fruit", "Destaca frutas no mapa.", Config.espRokaFruit, function(s) Config.espRokaFruit = s; SaveConfig() end)
createCard(TabVisuals, "ESP Arrow", "Destaca flechas normais.", Config.espArrow, function(s) Config.espArrow = s; SaveConfig() end)
createCard(TabVisuals, "ESP Arrow Shiny", "Destaca flechas brilhantes.", Config.espShiny, function(s) Config.espShiny = s; SaveConfig() end)

-- PLAYER
createCard(TabPlayer, "Enable Aimbot", "Ativa a mira automática.", Config.aimbotEnabled, function(s) Config.aimbotEnabled = s; SaveConfig() end)
createCard(TabPlayer, "FOV Circle", "Mostra o círculo de alcance.", Config.fovCircleOn, function(s) Config.fovCircleOn = s; fovCircle.Visible = s; SaveConfig() end)
createCard(TabPlayer, "Turn Character", "Gira o personagem para o alvo.", Config.aimbotTurnChar, function(s) Config.aimbotTurnChar = s; SaveConfig() end)
createCard(TabPlayer, "Strong Dash", "Aumenta a velocidade base.", Config.dashStrong, function(s) Config.dashStrong = s; SaveConfig() end)

-- TELEPORT
local btnTP1 = Instance.new("TextButton")
btnTP1.Size = UDim2.new(1, 0, 0, 45); btnTP1.BackgroundColor3 = COLORS.CARDS
btnTP1.Text = "TP Stage 1"; btnTP1.TextColor3 = COLORS.TEXT; btnTP1.Font = Enum.Font.GothamBold; btnTP1.TextSize = 13
btnTP1.Parent = TabTeleport; Instance.new("UICorner", btnTP1).CornerRadius = UDim.new(0, 8)
btnTP1.MouseButton1Click:Connect(function() safeTweenTeleport(Vector3.new(3269, -239, 2052)) end)

local btnTP2 = Instance.new("TextButton")
btnTP2.Size = UDim2.new(1, 0, 0, 45); btnTP2.BackgroundColor3 = COLORS.CARDS
btnTP2.Text = "TP Stage 2"; btnTP2.TextColor3 = COLORS.TEXT; btnTP2.Font = Enum.Font.GothamBold; btnTP2.TextSize = 13
btnTP2.Parent = TabTeleport; Instance.new("UICorner", btnTP2).CornerRadius = UDim.new(0, 8)
btnTP2.MouseButton1Click:Connect(function() safeTweenTeleport(Vector3.new(8541, -166, -1274)) end)

-- MISC
createCard(TabMisc, "Auto Collect", "Coleta Rokakaka automaticamente.", Config.autoCollect, function(s) Config.autoCollect = s; SaveConfig() end)

-- Default Tab
TabButtons["Home"].BackgroundColor3 = COLORS.CARDS
TabButtons["Home"].BackgroundTransparency = 0.3
TabButtons["Home"].TextColor3 = COLORS.TEXT
TabButtons["Home"]:FindFirstChildWhichIsA("Frame").Visible = true
Tabs["Home"].Visible = true

-- Drag Main Frame
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

floatBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
    if mainFrame.Visible then
        mainFrame.Size = UDim2.new(0, 900, 0, 540)
        mainFrame.Position = UDim2.new(0.5, -450, 0.5, -270)
    end
end)

warn("[L HUB v86] Premium UI Loaded.")Visual Preview"; previewTitle.TextColor3 = TEXT; previewTitle.Font = Enum.Font.GothamBold; previewTitle.TextSize = 14
previewTitle.Parent = previewArea

local previewInfo = Instance.new("TextLabel")
previewInfo.Size = UDim2.new(1, -20, 0, 100); previewInfo.Position = UDim2.new(0, 10, 0, 50); previewInfo.BackgroundTransparency = 1
previewInfo.Text = "Configurações em tempo real."
previewInfo.TextColor3 = SECONDARY; previewInfo.Font = Enum.Font.Gotham; previewInfo.TextSize = 12; previewInfo.TextWrapped = true; previewInfo.TextYAlignment = Enum.TextYAlignment.Top
previewInfo.Parent = previewArea

local scrollContent = Instance.new("ScrollingFrame")
scrollContent.Size = UDim2.new(1, 0, 1, 0); scrollContent.BackgroundTransparency = 1
scrollContent.ScrollBarThickness = 2; scrollContent.ScrollBarImageColor3 = PRIMARY; scrollContent.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollContent.Parent = centerArea
local cList = Instance.new("UIListLayout", scrollContent); cList.Padding = UDim.new(0, 10); cList.SortOrder = Enum.SortOrder.LayoutOrder
cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scrollContent.CanvasSize = UDim2.new(0, 0, 0, cList.AbsoluteContentSize.Y + 20) end)

-- UI Helpers
local function createCard(titleText, descText, initialState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 65)
    card.BackgroundColor3 = CARDS
    card.Parent = scrollContent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -60, 0, 20); t.Position = UDim2.new(0, 15, 0, 10); t.BackgroundTransparency = 1
    t.Text = titleText; t.TextColor3 = TEXT; t.Font = Enum.Font.GothamBold; t.TextSize = 13; t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = card
    
    local d = Instance.new("TextLabel")
    d.Size = UDim2.new(1, -60, 0, 20); d.Position = UDim2.new(0, 15, 0, 30); d.BackgroundTransparency = 1
    d.Text = descText; d.TextColor3 = SECONDARY; d.Font = Enum.Font.Gotham; d.TextSize = 11; d.TextXAlignment = Enum.TextXAlignment.Left
    d.Parent = card
    
    local track = Instance.new("TextButton")
    track.Size = UDim2.new(0, 36, 0, 18); track.Position = UDim2.new(1, -50, 0.5, -9)
    track.BackgroundColor3 = initialState and PRIMARY or Color3.fromRGB(40, 40, 50); track.Text = ""
    track.Parent = card
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.Position = initialState and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    thumb.BackgroundColor3 = TEXT
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    
    local state = initialState
    track.MouseButton1Click:Connect(function()
        state = not state
        track.BackgroundColor3 = state and PRIMARY or Color3.fromRGB(40, 40, 50)
        TweenService:Create(thumb, TweenInfo.new(0.2), { Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) }):Play()
        pcall(callback, state)
    end)
    
    return {
        setState = function(s)
            state = s
            track.BackgroundColor3 = state and PRIMARY or Color3.fromRGB(40, 40, 50)
            thumb.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        end
    }
end

local Tabs = {}
local TabButtons = {}

local function createTab(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 38)
    btn.BackgroundColor3 = CARDS
    btn.BackgroundTransparency = 1
    btn.Text = "   " .. name
    btn.TextColor3 = SECONDARY
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    -- Indicador lateral
    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 3, 0.6, 0); indicator.Position = UDim2.new(0, 0, 0.2, 0)
    indicator.BackgroundColor3 = PRIMARY; indicator.Visible = false
    indicator.Parent = btn
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 2)
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 0); frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1; frame.Visible = false
    frame.Parent = scrollContent
    local tLayout = Instance.new("UIListLayout", frame); tLayout.Padding = UDim.new(0, 10); tLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    TabButtons[name] = btn
    Tabs[name] = frame
    
    btn.MouseButton1Click:Connect(function()
        for _, f in pairs(Tabs) do f.Visible = false end
        for _, b in pairs(TabButtons) do
            TweenService:Create(b, TweenInfo.new(0.2), { BackgroundTransparency = 1, TextColor3 = SECONDARY }):Play()
            b:FindFirstChildWhichIsA("Frame").Visible = false
        end
        frame.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = CARDS, BackgroundTransparency = 0.5, TextColor3 = TEXT }):Play()
        indicator.Visible = true
    end)
    
    return frame
end

-- ==========================================
-- 5. POPULANDO ABAS
-- ==========================================
local TabHome = createTab("Home")
local TabVisuals = createTab("Visuals")
local TabPlayer = createTab("Player")
local TabTeleport = createTab("Teleport")
local TabMisc = createTab("Misc")
local TabSettings = createTab("Settings")

-- HOME
local homeLabel = Instance.new("TextLabel")
homeLabel.Size = UDim2.new(1, 0, 0, 50); homeLabel.BackgroundTransparency = 1
homeLabel.Text = "Bem-vindo ao L HUB Nexus. Selecione uma aba ao lado."
homeLabel.TextColor3 = SECONDARY; homeLabel.Font = Enum.Font.Gotham; homeLabel.TextSize = 14; homeLabel.TextXAlignment = Enum.TextXAlignment.Left
homeLabel.Parent = TabHome

-- VISUALS (ESP)
local toggleESPPlant = createCard("ESP Rokakaka Plant", "Destaca plantas no mapa.", Config.espRokaPlant, function(s) Config.espRokaPlant = s; SaveConfig(); cleanESP() end)
toggleESPPlant.frame = Tabs["Visuals"] -- Necessário para o layout
toggleESPPlant.frame.Parent = TabVisuals

local toggleESPFruit = createCard("ESP Rokakaka Fruit", "Destaca frutas no mapa.", Config.espRokaFruit, function(s) Config.espRokaFruit = s; SaveConfig(); cleanESP() end)
toggleESPFruit.frame = Tabs["Visuals"]
toggleESPFruit.frame.Parent = TabVisuals

local toggleESPArrow = createCard("ESP Arrow", "Destaca flechas normais.", Config.espArrow, function(s) Config.espArrow = s; SaveConfig(); cleanESP() end)
toggleESPArrow.frame = Tabs["Visuals"]
toggleESPArrow.frame.Parent = TabVisuals

local toggleESPShiny = createCard("ESP Arrow Shiny", "Destaca flechas brilhantes.", Config.espShiny, function(s) Config.espShiny = s; SaveConfig(); cleanESP() end)
toggleESPShiny.frame = Tabs["Visuals"]
toggleESPShiny.frame.Parent = TabVisuals

-- PLAYER (Aimbot)
local toggleAimbot = createCard("Enable Aimbot", "Ativa a mira automática.", Config.aimbotEnabled, function(s)
    Config.aimbotEnabled = s; SaveConfig()
    if not s then
        local cam = Workspace.CurrentCamera
        if cam then cam.CameraType = Enum.CameraType.Custom end
        aimbotHighlight.Enabled = false
    end
end)
toggleAimbot.frame = Tabs["Player"]
toggleAimbot.frame.Parent = TabPlayer

local toggleFOV = createCard("FOV Circle", "Mostra o círculo de alcance.", Config.fovCircleOn, function(s) Config.fovCircleOn = s; SaveConfig(); if fovCircle then fovCircle.Visible = s end end)
toggleFOV.frame = Tabs["Player"]
toggleFOV.frame.Parent = TabPlayer

-- TELETRANSPORTE
local btnTP1 = Instance.new("TextButton")
btnTP1.Size = UDim2.new(1, 0, 0, 45); btnTP1.BackgroundColor3 = CARDS
btnTP1.Text = "TP Stage 1"; btnTP1.TextColor3 = TEXT; btnTP1.Font = Enum.Font.GothamBold; btnTP1.TextSize = 13
btnTP1.Parent = TabTeleport; Instance.new("UICorner", btnTP1).CornerRadius = UDim.new(0, 8)
btnTP1.MouseButton1Click:Connect(function() safeTweenTeleport(Vector3.new(3269, -239, 2052)) end)

local btnTP2 = Instance.new("TextButton")
btnTP2.Size = UDim2.new(1, 0, 0, 45); btnTP2.BackgroundColor3 = CARDS
btnTP2.Text = "TP Stage 2"; btnTP2.TextColor3 = TEXT; btnTP2.Font = Enum.Font.GothamBold; btnTP2.TextSize = 13
btnTP2.Parent = TabTeleport; Instance.new("UICorner", btnTP2).CornerRadius = UDim.new(0, 8)
btnTP2.MouseButton1Click:Connect(function() safeTweenTeleport(Vector3.new(8541, -166, -1274)) end)

-- MISC (Coleta)
local toggleCollect = createCard("Auto Collect", "Coleta Rokakaka automaticamente.", Config.autoCollect, function(s) Config.autoCollect = s; SaveConfig() end)
toggleCollect.frame = Tabs["Misc"]
toggleCollect.frame.Parent = TabMisc

-- SETTINGS
local btnSave = Instance.new("TextButton")
btnSave.Size = UDim2.new(1, 0, 0, 45); btnSave.BackgroundColor3 = PRIMARY
btnSave.Text = "Apply Changes"; btnSave.TextColor3 = TEXT; btnSave.Font = Enum.Font.GothamBold; btnSave.TextSize = 13
btnSave.Parent = TabSettings; Instance.new("UICorner", btnSave).CornerRadius = UDim.new(0, 8)
btnSave.MouseButton1Click:Connect(function() SaveConfig() end)

-- Default Tab
TabButtons["Home"].BackgroundColor3 = CARDS
TabButtons["Home"].BackgroundTransparency = 0.5
TabButtons["Home"].TextColor3 = TEXT
TabButtons["Home"]:FindFirstChildWhichIsA("Frame").Visible = true
Tabs["Home"].Visible = true

-- Drag Main Frame
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

floatBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)

warn("[L HUB v85] Premium UI Loaded.")state) end
    end
    
    ConnectionManager:Add(track.MouseButton1Click:Connect(function()
        setState(not state, true)
    end))
    
    toggleObj = { frame = frame, track = track, thumb = thumb, setState = setState }
    return toggleObj
end

local Tabs = {}
local TabButtons = {}

local function createTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 36)
    btn.BackgroundColor3 = NEON_PURPLE
    btn.BackgroundTransparency = 1
    btn.Text = "  " .. icon .. "  " .. name
    btn.TextColor3 = TEXT_GRAY
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(0, 6)
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = scrollContent
    local tLayout = Instance.new("UIListLayout", frame); tLayout.Padding = UDim.new(0, 10); tLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    TabButtons[name] = btn
    Tabs[name] = frame
    
    ConnectionManager:Add(btn.MouseButton1Click:Connect(function()
        for _, f in pairs(Tabs) do f.Visible = false end
        for _, b in pairs(TabButtons) do 
            TweenService:Create(b, TweenInfo.new(0.2), { BackgroundTransparency = 1, TextColor3 = TEXT_GRAY }):Play() 
        end
        frame.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = NEON_PURPLE, BackgroundTransparency = 0.2, TextColor3 = TEXT_WHITE }):Play()
    end))
    return frame
end

-- ==========================================
-- 9. TABS & FEATURES INITIALIZATION
-- ==========================================
local TabHome = createTab("Home", "🏠")
local SectHome = createSection(TabHome, "DASHBOARD", "📊")
SectHome.LayoutOrder = 1
createLabel(SectHome, "Bem-vindo ao L HUB Nexus.")
createLabel(SectHome, "Selecione uma aba ao lado.")

local TabESP = createTab("Visuals", "👁️")
local SectESP = createSection(TabESP, "ITEM ESP", "✨")
SectESP.LayoutOrder = 1
local ESPPlantToggle = createToggle(SectESP, "ESP Rokakaka Plant", Config.espRokaPlant, function(state) Config.espRokaPlant = state; SaveConfig(true); cleanESP() end)
local ESPFruitToggle = createToggle(SectESP, "ESP Rokakaka Fruit", Config.espRokaFruit, function(state) Config.espRokaFruit = state; SaveConfig(true); cleanESP() end)
local ESPArrowToggle = createToggle(SectESP, "ESP Arrow", Config.espArrow, function(state) Config.espArrow = state; SaveConfig(true); cleanESP() end)
local ESPShinyToggle = createToggle(SectESP, "ESP Arrow Shiny", Config.espShiny, function(state) Config.espShiny = state; SaveConfig(true); cleanESP() end)

local TabCollect = createTab("Coleta", "💰")
local SectCollect = createSection(TabCollect, "AUTO COLLECT", "🪙")
SectCollect.LayoutOrder = 1
local CollectToggle = createToggle(SectCollect, "Enable Auto Collect", Config.autoCollect, function(state)
    Config.autoCollect = state
    SaveConfig(true)
end)

local TabAim = createTab("Aimbot", "🎯")
local SectAimMain = createSection(TabAim, "AIMBOT SETTINGS", "⚙️")
SectAimMain.LayoutOrder = 1
local AimbotToggle = createToggle(SectAimMain, "Enable Aimbot", Config.aimbotEnabled, function(state)
    Config.aimbotEnabled = state
    if not state then
        local cam = Workspace.CurrentCamera
        if cam then cam.CameraType = Enum.CameraType.Custom end
        aimbotHighlight.Enabled = false
    end
    SaveConfig(true)
end)
local FOVToggle = createToggle(SectAimMain, "FOV Circle", Config.fovCircleOn, function(state) Config.fovCircleOn = state; if fovCircle then fovCircle.Visible = state end; SaveConfig(true) end)
local TurnCharToggle = createToggle(SectAimMain, "Turn Character", Config.aimbotTurnChar, function(state) Config.aimbotTurnChar = state; SaveConfig(true) end)
local DashToggle = createToggle(SectAimMain, "Strong Dash", Config.dashStrong, function(state) Config.dashStrong = state; SaveConfig(true) end)

local TabConfig = createTab("Config", "⚙️")
local SectConfig = createSection(TabConfig, "SYSTEM SETTINGS", "💾")
SectConfig.LayoutOrder = 1
createButton(SectConfig, "Save Settings", function() SaveConfig(false); showToast("Saved Successfully!", NEON_PURPLE) end)

-- Default Tab Selection
TabButtons["Home"].BackgroundColor3 = NEON_PURPLE
TabButtons["Home"].BackgroundTransparency = 0.2
TabButtons["Home"].TextColor3 = TEXT_WHITE
Tabs["Home"].Visible = true

ConnectionManager:Add(floatBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end))

-- DRAG MAIN FRAME
local dragging, dragInput, dragStart, startPos
ConnectionManager:Add(topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position
        ConnectionManager:Add(input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end))
    end
end))
ConnectionManager:Add(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

warn("[L HUB v84] UI Premium Carregada com Sucesso.")CornerRadius = UDim.new(1, 0)
ConnectionManager:Add(closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end))

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 150, 1, -40)
sidebar.Position = UDim2.new(0, 0, 0, 40)
sidebar.BackgroundColor3 = SIDEBAR_COLOR
sidebar.BackgroundTransparency = 0.4
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
local sList = Instance.new("UIListLayout", sidebar); sList.Padding = UDim.new(0, 8); sList.SortOrder = Enum.SortOrder.LayoutOrder; sList.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", sidebar).PaddingTop = UDim.new(0, 15)

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -160, 1, -60)
contentArea.Position = UDim2.new(0, 155, 0, 50)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local scrollContent = Instance.new("ScrollingFrame")
scrollContent.Size = UDim2.new(1, 0, 1, 0)
scrollContent.BackgroundTransparency = 1
scrollContent.ScrollBarThickness = 2
scrollContent.ScrollBarImageColor3 = GOLD
scrollContent.ScrollBarImageTransparency = 0.3
scrollContent.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollContent.Parent = contentArea
local cList = Instance.new("UIListLayout", scrollContent); cList.Padding = UDim.new(0, 10); cList.SortOrder = Enum.SortOrder.LayoutOrder
ConnectionManager:Add(cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scrollContent.CanvasSize = UDim2.new(0, 0, 0, cList.AbsoluteContentSize.Y + 20) end))

local function createSection(parent, titleText, icon)
    local frame = Instance.new("Frame")
    frame.Name = "SEC_" .. titleText
    frame.Size = UDim2.new(1, -10, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundColor3 = ELEMENT_BG
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = parent
    frame.ClipsDescendants = true
    
    local c = Instance.new("UICorner", frame); c.CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", frame); s.Color = Color3.fromRGB(50, 50, 70); s.Transparency = 0.5
    
    local pad = Instance.new("UIPadding", frame)
    pad.PaddingTop = UDim.new(0, 12); pad.PaddingBottom = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)
    
    local layout = Instance.new("UIListLayout", frame); layout.Padding = UDim.new(0, 10); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local topRow = Instance.new("Frame", frame)
    topRow.Size = UDim2.new(1, 0, 0, 18); topRow.BackgroundTransparency = 1; topRow.LayoutOrder = 1
    
    local accent = Instance.new("Frame", topRow)
    accent.Size = UDim2.new(0, 20, 0, 3); accent.Position = UDim2.new(0, 0, 0.5, -1.5)
    accent.BackgroundColor3 = Color3.fromRGB(130, 80, 255); accent.BorderSizePixel = 0
    
    local lbl = Instance.new("TextLabel", topRow)
    lbl.Size = UDim2.new(1, -25, 1, 0); lbl.Position = UDim2.new(0, 25, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = icon .. " " .. titleText
    lbl.TextColor3 = Color3.fromRGB(130, 80, 255); lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    return frame
end

local function createButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Name = text
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    btn.BackgroundTransparency = 0.2
    btn.Text = text
    btn.TextColor3 = TEXT_WHITE
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = parent
    
    local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", btn); s.Color = Color3.fromRGB(50, 50, 70); s.Transparency = 0.2
    
    ConnectionManager:Add(btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(30, 30, 45) }):Play()
        s.Color = Color3.fromRGB(130, 80, 255); btn.TextColor3 = Color3.fromRGB(130, 80, 255)
    end))
    ConnectionManager:Add(btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(20, 20, 28) }):Play()
        s.Color = Color3.fromRGB(50, 50, 70); btn.TextColor3 = TEXT_WHITE
    end))
    ConnectionManager:Add(btn.MouseButton1Click:Connect(function()
        local success, err = pcall(callback)
        if not success then Logger("UI", "Erro no botão " .. text .. ": " .. tostring(err)) end
    end))
    return btn
end

local function createToggle(parent, text, initialState, callback)
    local frame = Instance.new("Frame")
    frame.Name = text
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    
    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(1, -50, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = text; lbl.TextColor3 = TEXT_WHITE; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local track = Instance.new("TextButton", frame)
    track.Name = "TrackBtn"
    track.Size = UDim2.new(0, 40, 0, 20); track.Position = UDim2.new(1, -40, 0.5, -10)
    track.BackgroundColor3 = initialState and Color3.fromRGB(130, 80, 255) or Color3.fromRGB(50, 50, 60); track.Text = ""
    
    local tC = Instance.new("UICorner", track); tC.CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = initialState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    
    local thC = Instance.new("UICorner", thumb); thC.CornerRadius = UDim.new(1, 0)
    
    local state = initialState
    local toggleObj
    
    local function setState(s, fire)
        state = (type(s) == "boolean") and s or false
        track.BackgroundColor3 = state and Color3.fromRGB(130, 80, 255) or Color3.fromRGB(50, 50, 60)
        TweenService:Create(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
        if fire then pcall(callback, state) end
    end
    
    ConnectionManager:Add(track.MouseButton1Click:Connect(function()
        state = not state
        track.BackgroundColor3 = state and Color3.fromRGB(130, 80, 255) or Color3.fromRGB(50, 50, 60)
        TweenService:Create(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
        
        task.spawn(function()
            pcall(callback, state)
        end)
    end))
    
    toggleObj = { frame = frame, track = track, thumb = thumb, setState = setState }
    return toggleObj
end

local function createSlider(parent, labelText, min, max, step, currentValue, callback)
    local row = Instance.new("Frame")
    row.Name = labelText
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    row.BackgroundTransparency = 0.2
    row.Parent = parent
    
    local rC = Instance.new("UICorner", row); rC.CornerRadius = UDim.new(0, 6)
    local rS = Instance.new("UIStroke", row); rS.Color = Color3.fromRGB(50, 50, 70); rS.Transparency = 0.2
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -80, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText .. ": " .. currentValue
    lbl.TextColor3 = TEXT_WHITE; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local btnContainer = Instance.new("Frame", row)
    btnContainer.Size = UDim2.new(0, 64, 1, 0); btnContainer.Position = UDim2.new(1, -70, 0, 0)
    btnContainer.BackgroundTransparency = 1
    
    local minusBtn = Instance.new("TextButton", btnContainer)
    minusBtn.Size = UDim2.new(0, 28, 0, 24); minusBtn.Position = UDim2.new(0, 0, 0.5, -12)
    minusBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20); minusBtn.Text = "-"; minusBtn.TextColor3 = TEXT_WHITE; minusBtn.Font = Enum.Font.GothamBold; minusBtn.TextSize = 14
    local mc = Instance.new("UICorner", minusBtn); mc.CornerRadius = UDim.new(0, 4)
    local ms = Instance.new("UIStroke", minusBtn); ms.Color = Color3.fromRGB(50, 50, 70)
    
    local plusBtn = Instance.new("TextButton", btnContainer)
    plusBtn.Size = UDim2.new(0, 28, 0, 24); plusBtn.Position = UDim2.new(1, -28, 0.5, -12)
    plusBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 20); plusBtn.Text = "+"; plusBtn.TextColor3 = TEXT_WHITE; plusBtn.Font = Enum.Font.GothamBold; plusBtn.TextSize = 14
    local pc = Instance.new("UICorner", plusBtn); pc.CornerRadius = UDim.new(0, 4)
    local ps = Instance.new("UIStroke", plusBtn); ps.Color = Color3.fromRGB(50, 50, 70)
    
    local val = currentValue
    local function update(newVal, fire)
        if type(newVal) ~= "number" then return end
        val = math.clamp(newVal, min, max)
        val = math.round(val * 100) / 100
        lbl.Text = labelText .. ": " .. val
        if fire then pcall(callback, val) end
    end
    
    ConnectionManager:Add(minusBtn.MouseButton1Click:Connect(function() update(val - step, true) end))
    ConnectionManager:Add(plusBtn.MouseButton1Click:Connect(function() update(val + step, true) end))
    ConnectionManager:Add(minusBtn.MouseEnter:Connect(function() ms.Color = Color3.fromRGB(130, 80, 255) end))
    ConnectionManager:Add(minusBtn.MouseLeave:Connect(function() ms.Color = Color3.fromRGB(50, 50, 70) end))
    ConnectionManager:Add(plusBtn.MouseEnter:Connect(function() ps.Color = Color3.fromRGB(130, 80, 255) end))
    ConnectionManager:Add(plusBtn.MouseLeave:Connect(function() ps.Color = Color3.fromRGB(50, 50, 70) end))
    
    return { row = row, lbl = lbl, update = update }
end

local Tabs = {}
local TabButtons = {}

local function createTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 130, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    btn.BackgroundTransparency = 1
    btn.Text = "  " .. icon .. "  " .. name
    btn.TextColor3 = TEXT_GRAY
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(0, 6)
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = scrollContent
    local tLayout = Instance.new("UIListLayout", frame); tLayout.Padding = UDim.new(0, 10); tLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    TabButtons[name] = btn
    Tabs[name] = frame
    
    ConnectionManager:Add(btn.MouseButton1Click:Connect(function()
        for _, f in pairs(Tabs) do f.Visible = false end
        for _, b in pairs(TabButtons) do TweenService:Create(b, TweenInfo.new(0.2), { BackgroundTransparency = 1, TextColor3 = TEXT_GRAY }):Play() end
        frame.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(130, 80, 255), BackgroundTransparency = 0.1, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    end))
    return frame
end

local function filterSearch()
    local q = string.lower(searchBox.Text)
    for _, tab in pairs(Tabs) do
        for _, child in ipairs(tab:GetChildren()) do
            if child:IsA("Frame") and string.find(child.Name, "SEC_") then
                local allHidden = true
                for _, subChild in ipairs(child:GetChildren()) do
                    if subChild:IsA("Frame") or subChild:IsA("TextButton") then
                        if subChild.Name ~= "UIListLayout" and subChild.Name ~= "UIPadding" and subChild.Name ~= "UICorner" and subChild.Name ~= "UIStroke" then
                            if q == "" or string.find(string.lower(subChild.Name), q) or (subChild.Name == "TrackBtn" and string.find(string.lower(subChild.Parent.Name), q)) then
                                subChild.Visible = true; allHidden = false
                            else
                                subChild.Visible = false
                            end
                        end
                    end
                end
                child.Visible = not allHidden
            end
        end
    end
end
ConnectionManager:Add(searchBox:GetPropertyChangedSignal("Text"):Connect(filterSearch))

-- ==========================================
-- 9. TABS & FEATURES INITIALIZATION
-- ==========================================
local TabRace = createTab("Auto Race", "🏎️")
local SectRace = createSection(TabRace, "AUTO RACE UNIVERSAL", "🏁")
SectRace.LayoutOrder = 1
raceToggle = createToggle(SectRace, "Enable Auto Race (Anti-Cheat)", false, function(state) 
    if state then 
        startAutoRace() 
    else 
        stopAutoRace() 
    end 
end)

local TabWin = createTab("Teletransporte", "⚔️")
local SectWinS1 = createSection(TabWin, "TELEPORTES MANUAIS", "🏁")
SectWinS1.LayoutOrder = 1
createButton(SectWinS1, "TP Stage 1", function() safeTweenTeleport(STAGE1_WIN_POS) end)
createButton(SectWinS1, "TP Checkpoint 1 (S2)", function() safeTweenTeleport(STAGE2_CP1_POS) end)
createButton(SectWinS1, "TP Checkpoint 2 (S2)", function() safeTweenTeleport(STAGE2_CP2_POS) end)
createButton(SectWinS1, "TP Stage 2", function() safeTweenTeleport(STAGE2_WIN_POS) end)

local TabCollect = createTab("Coleta", "💰")
local SectCollect = createSection(TabCollect, "AUTO COLLECT", "🪙")
SectCollect.LayoutOrder = 1
local CollectToggle = createToggle(SectCollect, "Enable Auto Collect", Config.autoCollect, function(state)
    Config.autoCollect = state
    SaveConfig(true)
end)

local TabESP = createTab("ESPs", "👁️")
local SectESP = createSection(TabESP, "ITEM ESP", "✨")
SectESP.LayoutOrder = 1
local ESPPlantToggle = createToggle(SectESP, "ESP Rokakaka Plant", Config.espRokaPlant, function(state) Config.espRokaPlant = state; SaveConfig(true); cleanESP() end)
local ESPFruitToggle = createToggle(SectESP, "ESP Rokakaka Fruit", Config.espRokaFruit, function(state) Config.espRokaFruit = state; SaveConfig(true); cleanESP() end)
local ESPArrowToggle = createToggle(SectESP, "ESP Arrow", Config.espArrow, function(state) Config.espArrow = state; SaveConfig(true); cleanESP() end)
local ESPShinyToggle = createToggle(SectESP, "ESP Arrow Shiny", Config.espShiny, function(state) Config.espShiny = state; SaveConfig(true); cleanESP() end)

local TabAim = createTab("Aimbot", "🎯")
local SectAimMain = createSection(TabAim, "MAIN SETTINGS", "⚙️")
SectAimMain.LayoutOrder = 1
local AimbotToggle = createToggle(SectAimMain, "Enable Aimbot", Config.aimbotEnabled, function(state)
    Config.aimbotEnabled = state
    if not state then
        local cam = Workspace.CurrentCamera
        if cam then cam.CameraType = Enum.CameraType.Custom end
        aimbotHighlight.Enabled = false
    end
    SaveConfig(true)
end)
local FOVToggle = createToggle(SectAimMain, "FOV Circle", Config.fovCircleOn, function(state) Config.fovCircleOn = state; if fovCircle then fovCircle.Visible = state end; SaveConfig(true) end)
local TurnCharToggle = createToggle(SectAimMain, "Turn Character", Config.aimbotTurnChar, function(state) Config.aimbotTurnChar = state; SaveConfig(true) end)
local DashToggle = createToggle(SectAimMain, "Strong Dash", Config.dashStrong, function(state) Config.dashStrong = state; SaveConfig(true) end)

local SectAimConfig = createSection(TabAim, "AIMBOT CONFIG", "🔧")
SectAimConfig.LayoutOrder = 2
local FOVRow = createSlider(SectAimConfig, "FOV Size", 30, 500, 15, Config.aimbotFov, function(val) Config.aimbotFov = val; if fovCircle then fovCircle.Radius = Config.aimbotFov end; SaveConfig(true) end)
FOVRow.row.LayoutOrder = 2
local CamHRow = createSlider(SectAimConfig, "Height", -6, 30, 2, Config.aimCamHeight, function(val) Config.aimCamHeight = val; SaveConfig(true) end)
CamHRow.row.LayoutOrder = 3
local LatRow = createSlider(SectAimConfig, "Side (Yaw)", -10, 10, 0.25, Config.aimYawOff, function(val) Config.aimYawOff = val; SaveConfig(true) end)
LatRow.row.LayoutOrder = 4
local VertRow = createSlider(SectAimConfig, "Vertical (Pitch)", -10, 10, 0.25, Config.aimPitchOff, function(val) Config.aimPitchOff = val; SaveConfig(true) end)
VertRow.row.LayoutOrder = 5

local TargetLabel = Instance.new("TextLabel", SectAimConfig)
TargetLabel.Size = UDim2.new(1, 0, 0, 20); TargetLabel.BackgroundTransparency = 1
TargetLabel.Text = "Target: none"; TargetLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
TargetLabel.Font = Enum.Font.GothamBold; TargetLabel.TextSize = 11; TargetLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetLabel.LayoutOrder = 6
TaskManager:Add(task.spawn(function()
    while true do
        task.wait(0.5)
        if aimbotTarget and aimbotTarget.Parent then
            TargetLabel.Text = "Target: " .. aimbotTarget.Name
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character == aimbotTarget then TargetLabel.Text = "Target: " .. plr.DisplayName; break end
            end
        else
            TargetLabel.Text = "Target: none"
        end
    end
end))

-- TP KILL
local TabTPKill = createTab("TP Kill", "💀")
local SectTPKill = createSection(TabTPKill, "PLAYER LIST", "👤")
SectTPKill.LayoutOrder = 1

local SearchBoxTP = Instance.new("TextBox")
SearchBoxTP.Size = UDim2.new(1, 0, 0, 30); SearchBoxTP.BackgroundColor3 = Color3.fromRGB(20, 20, 28); SearchBoxTP.BackgroundTransparency = 0.2
SearchBoxTP.TextColor3 = TEXT_WHITE; SearchBoxTP.PlaceholderText = "🔍 Buscar jogador..."; SearchBoxTP.PlaceholderColor3 = TEXT_GRAY; SearchBoxTP.Font = Enum.Font.Gotham; SearchBoxTP.TextSize = 12; SearchBoxTP.Parent = SectTPKill
local sbCTP = Instance.new("UICorner", SearchBoxTP); sbCTP.CornerRadius = UDim.new(0, 6)
local sbSTP = Instance.new("UIStroke", SearchBoxTP); sbSTP.Color = Color3.fromRGB(50, 50, 70)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, 0, 0, 120); ScrollFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20); ScrollFrame.BackgroundTransparency = 0.4
ScrollFrame.BorderSizePixel = 0; ScrollFrame.ScrollBarThickness = 2; ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(130, 80, 255)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0); ScrollFrame.Parent = SectTPKill
local sfC = Instance.new("UICorner", ScrollFrame); sfC.CornerRadius = UDim.new(0, 6)
local listLayout = Instance.new("UIListLayout", ScrollFrame); listLayout.Padding = UDim.new(0, 4)
ConnectionManager:Add(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 4) end))

local selectedPlayer = nil
local function updatePlayerList()
    for _, child in ipairs(ScrollFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 34); btn.BackgroundColor3 = ELEMENT_BG; btn.BackgroundTransparency = 0.5
            btn.Text = ""; btn.Name = plr.Name; btn.Parent = ScrollFrame
            local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(0, 6)
            local s = Instance.new("UIStroke", btn); s.Color = Color3.fromRGB(50, 50, 70)
            
            local img = Instance.new("ImageLabel", btn)
            img.Size = UDim2.new(0, 26, 0, 26); img.Position = UDim2.new(0, 4, 0.5, -13); img.BackgroundColor3 = BG_COLOR
            img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=48&h=48"
            local iC = Instance.new("UICorner", img); iC.CornerRadius = UDim.new(1, 0)
            
            local txt = Instance.new("TextLabel", btn)
            txt.Size = UDim2.new(1, -35, 1, 0); txt.Position = UDim2.new(0, 34, 0, 0)
            txt.BackgroundTransparency = 1; txt.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
            txt.TextColor3 = TEXT_WHITE; txt.Font = Enum.Font.Gotham; txt.TextSize = 12; txt.TextXAlignment = Enum.TextXAlignment.Left
            
            ConnectionManager:Add(btn.MouseButton1Click:Connect(function()
                for _, other in ipairs(ScrollFrame:GetChildren()) do
                    if other:IsA("TextButton") then other.BackgroundColor3 = ELEMENT_BG; other.UIStroke.Color = Color3.fromRGB(50, 50, 70) end
                end
                btn.BackgroundColor3 = Color3.fromRGB(130, 80, 255); txt.TextColor3 = BG_COLOR; selectedPlayer = plr
            end))
        end
    end
end

updatePlayerList()
ConnectionManager:Add(Players.PlayerAdded:Connect(updatePlayerList))
ConnectionManager:Add(Players.PlayerRemoving:Connect(function(plr)
    if selectedPlayer == plr then selectedPlayer = nil end
    task.defer(updatePlayerList)
end))

ConnectionManager:Add(SearchBoxTP:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(SearchBoxTP.Text)
    for _, child in ipairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            local plr = Players:FindFirstChild(child.Name)
            if plr then
                local username = string.lower(plr.Name)
                local display = string.lower(plr.DisplayName)
                if query == "" or string.find(username, query) or string.find(display, query) then
                    child.Visible = true
                else
                    child.Visible = false
                end
            end
        end
    end
end))

local TPHeightRow = createSlider(SectTPKill, "Offset (Studs)", -20, 20, 1, Config.tpKillHeight, function(val) Config.tpKillHeight = val; SaveConfig(true) end)
TPHeightRow.row.LayoutOrder = 2

local tpKill = { active = false, savedCF = nil, savedWalk = nil, savedJump = nil, savedRot = nil, tween = nil, followConn = nil }
local KillBtn

local function setKillBtn(active)
    if not KillBtn then return end
    local s = KillBtn:FindFirstChildOfClass("UIStroke")
    if active then
        KillBtn.Text = "STOP KILL (ACTIVE)"; KillBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        if s then s.Color = Color3.fromRGB(255, 80, 80) end
    else
        KillBtn.Text = "Kill Player (Toggle)"; KillBtn.TextColor3 = TEXT_WHITE
        if s then s.Color = Color3.fromRGB(50, 50, 70) end
    end
end

local function stopTpKill()
    if not tpKill.active then return end
    tpKill.active = false
    if tpKill.followConn then pcall(function() tpKill.followConn:Disconnect() end) tpKill.followConn = nil end
    if tpKill.tween then pcall(function() tpKill.tween:Cancel() end) tpKill.tween = nil end
    
    local char = LocalPlayer.Character
    if char and char.Parent then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = tpKill.savedWalk or 16; hum.JumpPower = tpKill.savedJump or 50; hum.AutoRotate = (tpKill.savedRot ~= false) end
        if hrp and tpKill.savedCF then
            hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
            local back = TweenService:Create(hrp, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = tpKill.savedCF })
            back:Play(); back.Completed:Wait()
            hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
    tpKill.savedCF = nil; tpKill.savedWalk = nil; tpKill.savedJump = nil; tpKill.savedRot = nil
    setKillBtn(false)
end

local function startTpKill()
    if tpKill.active then return end
    if not selectedPlayer or not selectedPlayer.Character then return showToast("Selecione um jogador!", Color3.fromRGB(255, 50, 50)) end
    local targetHRP = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return showToast("Alvo inválido!", Color3.fromRGB(255, 50, 50)) end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    
    tpKill.active = true
    tpKill.savedCF = hrp.CFrame; tpKill.savedWalk = hum.WalkSpeed; tpKill.savedJump = hum.JumpPower; tpKill.savedRot = hum.AutoRotate
    hum.WalkSpeed = 0; hum.JumpPower = 0; hum.AutoRotate = false
    hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
    
    local targetCF = targetHRP.CFrame * CFrame.new(0, -Config.tpKillHeight, 0) * CFrame.Angles(math.rad(90), 0, 0)
    tpKill.tween = TweenService:Create(hrp, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = targetCF })
    tpKill.tween:Play(); setKillBtn(true)
    
    local thisTween = tpKill.tween
    TaskManager:Add(task.spawn(function()
        thisTween.Completed:Wait()
        if not tpKill.active then return end
        tpKill.followConn = RunService.Heartbeat:Connect(function()
            if not tpKill.active then return end
            if not selectedPlayer or not selectedPlayer.Character then task.defer(stopTpKill); return end
            local cTHRP = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not cTHRP then return end
            hrp.CFrame = cTHRP.CFrame * CFrame.new(0, -Config.tpKillHeight, 0) * CFrame.Angles(math.rad(90), 0, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end))
end

KillBtn = createButton(SectTPKill, "Kill Player (Toggle)", function() if tpKill.active then stopTpKill() else startTpKill() end end)
KillBtn.LayoutOrder = 3

local TabConfig = createTab("Config", "⚙️")
local SectConfig = createSection(TabConfig, "SYSTEM SETTINGS", "💾")
SectConfig.LayoutOrder = 1
createButton(SectConfig, "Save Settings", function() SaveConfig(false); showToast("Saved Successfully!", Color3.fromRGB(130, 80, 255)) end)

local ResetBtn = createButton(SectConfig, "Reset to Default", function()
    if Environment.HasWriteFile then pcall(function() delfile(CONFIG_FILE) end) end
    for k, v in pairs(DefaultConfig) do Config[k] = v end
    pcall(stopTpKill); pcall(stopAutoRace)
    CollectToggle.setState(false, true); AimbotToggle.setState(false, true); FOVToggle.setState(false, true)
    TurnCharToggle.setState(true, true); DashToggle.setState(true, true)
    ESPPlantToggle.setState(false, true); ESPFruitToggle.setState(false, true); ESPArrowToggle.setState(false, true); ESPShinyToggle.setState(false, true)
    cleanESP()
    FOVRow.update(120, true); CamHRow.update(8, true); LatRow.update(0, true); VertRow.update(0, true); TPHeightRow.update(6, true)
    if fovCircle then fovCircle.Visible = false; fovCircle.Radius = 120 end
    aimbotFloatBtn.Position = UDim2.new(0.85, 0, 0.55, 0)
    
    local char = LocalPlayer.Character
    if char and char.Parent then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50; hum.PlatformStand = false; hum.AutoRotate = true end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero end
    end
    local cam = Workspace.CurrentCamera
    if cam then cam.CameraType = Enum.CameraType.Custom end
    SaveConfig(false); showToast("Settings Reset!", Color3.fromRGB(255, 100, 100))
end)

TabButtons["Auto Race"].BackgroundColor3 = Color3.fromRGB(130, 80, 255)
TabButtons["Auto Race"].BackgroundTransparency = 0.1
TabButtons["Auto Race"].TextColor3 = Color3.fromRGB(255, 255, 255)
Tabs["Auto Race"].Visible = true

ConnectionManager:Add(floatBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end))

-- DRAG MAIN FRAME
local dragging, dragInput, dragStart, startPos
ConnectionManager:Add(topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position
        ConnectionManager:Add(input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end))
    end
end))
ConnectionManager:Add(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

-- AIMBOT FLOAT BUTTON
aimbotFloatBtn = Instance.new("Frame")
aimbotFloatBtn.Size = UDim2.new(0, 60, 0, 60)
aimbotFloatBtn.Position = UDim2.new(Config.floatBtnPosXScale, Config.floatBtnPosXOffset, Config.floatBtnPosYScale, Config.floatBtnPosYOffset)
aimbotFloatBtn.BackgroundColor3 = ELEMENT_BG
aimbotFloatBtn.BackgroundTransparency = 0.2
aimbotFloatBtn.Parent = screenGui
local afC = Instance.new("UICorner", aimbotFloatBtn); afC.CornerRadius = UDim.new(1, 0)
local afS = Instance.new("UIStroke", aimbotFloatBtn); afS.Color = Color3.fromRGB(130, 80, 255); afS.Thickness = 2

local aimIcon = Instance.new("TextLabel", aimbotFloatBtn)
aimIcon.Size = UDim2.new(1, 0, 1, 0); aimIcon.BackgroundTransparency = 1
aimIcon.Text = "⊕"; aimIcon.TextColor3 = Color3.fromRGB(130, 80, 255); aimIcon.Font = Enum.Font.GothamBold
aimIcon.TextSize = 28; aimIcon.Parent = aimbotFloatBtn

TaskManager:Add(task.spawn(function()
    local t = 0
    while true do
        t += 0.05
        local s = 1 + math.sin(t) * (Config.aimbotEnabled and 0.05 or 0.02)
        aimbotFloatBtn.Size = UDim2.new(0, math.round(60 * s), 0, math.round(60 * s))
        task.wait(0.03)
    end
end))

local aimActiveInput = nil
local aimDragging = false
local aimDragStart, aimStartPos

ConnectionManager:Add(aimbotFloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if aimActiveInput ~= nil then return end
        aimActiveInput = input; aimDragging = false
        aimDragStart = input.Position; aimStartPos = aimbotFloatBtn.Position
    end
end))

ConnectionManager:Add(UserInputService.InputChanged:Connect(function(input)
    if input ~= aimActiveInput then return end
    local d = input.Position - aimDragStart
    if d.Magnitude > 6 then aimDragging = true end
    if aimDragging then
        aimbotFloatBtn.Position = UDim2.new(aimStartPos.X.Scale, aimStartPos.X.Offset + d.X, aimStartPos.Y.Scale, aimStartPos.Y.Offset + d.Y)
    end
end))

ConnectionManager:Add(aimbotFloatBtn.InputEnded:Connect(function(input)
    if input ~= aimActiveInput then return end
    aimActiveInput = nil
    if not aimDragging then
        Config.aimbotEnabled = not Config.aimbotEnabled
        AimbotToggle.setState(Config.aimbotEnabled)
        afS.Color = Config.aimbotEnabled and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(130, 80, 255)
        SaveConfig(true)
    else
        SaveConfig(true)
    end
    aimDragging = false; aimDragStart = nil
end))


Logger("System", "L HUB v86 carregado.")
