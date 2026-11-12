-- language: Lua, file: LHub_v76.lua, target: Roblox (Delta Executor)
-- ==========================================
-- L HUB v76 - Mobile Optimized
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
local CONFIG_FILE = "LHub_Config_v76.json"

local Config = {
    aimbotEnabled = false, aimbotFov = 120, autoCollect = false,
    espRokaPlant = false, espRokaFruit = false, espArrow = false
}

if isfile and isfile(CONFIG_FILE) then
    local s, d = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if s and type(d) == "table" then
        for k, v in pairs(d) do if Config[k] ~= nil then Config[k] = v end end
    end
end

local function SaveConfig()
    if writefile then
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end)
    end
end

if _G.LHub then
    pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
    if _G.LHub.Gui then _G.LHub.Gui:Destroy() end
    if _G.LHub.Tasks then for _, t in pairs(_G.LHub.Tasks) do pcall(task.cancel, t) end end
end

local TaskManager = {}
_G.LHub = { Gui = nil, Tasks = TaskManager, NoclipStates = {} }

-- ==========================================
-- 1. INTERFACE GRÁFICA (CARREGA PRIMEIRO)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LHub_Main"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end
_G.LHub.Gui = screenGui

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 45, 0, 45)
floatBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
floatBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
floatBtn.Text = "L"
floatBtn.TextColor3 = Color3.fromRGB(212, 175, 55)
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 24
floatBtn.Parent = screenGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke", floatBtn)
stroke.Color = Color3.fromRGB(212, 175, 55)
stroke.Thickness = 2

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 500, 0, 350)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
mainFrame.Visible = false
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
local mStroke = Instance.new("UIStroke", mainFrame)
mStroke.Color = Color3.fromRGB(60, 60, 80)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
topBar.Parent = mainFrame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "L HUB | NEXUS v76"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -20, 1, -50)
content.Position = UDim2.new(0, 10, 0, 45)
content.BackgroundTransparency = 1
content.ScrollBarThickness = 2
content.Parent = mainFrame
local cLayout = Instance.new("UIListLayout", content)
cLayout.Padding = UDim.new(0, 8)
cLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Drag Logic
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
closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

-- UI Helpers
local function createBtn(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(50, 50, 70)
    btn.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then warn("[LHub] Erro:", err) end
    end)
    return btn
end

local function createToggle(text, state, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundTransparency = 1
    f.Parent = content
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -50, 1, 0); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = Color3.new(1, 1, 1)
    l.Font = Enum.Font.Gotham; l.TextSize = 13; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local t = Instance.new("TextButton")
    t.Size = UDim2.new(0, 40, 0, 20); t.Position = UDim2.new(1, -40, 0.5, -10)
    t.BackgroundColor3 = state and Color3.fromRGB(130, 80, 255) or Color3.fromRGB(50, 50, 60)
    t.Text = ""; t.Parent = f
    Instance.new("UICorner", t).CornerRadius = UDim.new(1, 0)
    local thumb = Instance.new("Frame", t)
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)
    
    t.MouseButton1Click:Connect(function()
        state = not state
        t.BackgroundColor3 = state and Color3.fromRGB(130, 80, 255) or Color3.fromRGB(50, 50, 60)
        TweenService:Create(thumb, TweenInfo.new(0.2), { Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
        pcall(callback, state)
    end)
end

-- ==========================================
-- 2. CORE LOGIC (ANTI-CHEAT E TELEPORTE)
-- ==========================================
local function bypassAntiCheat()
    local char = LocalPlayer.Character
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    local function killScripts(parent)
        if not parent then return end
        for _, v in ipairs(parent:GetDescendants()) do
            local n = string.lower(v.Name)
            if v:IsA("LocalScript") then
                if n:find("detector") or n:find("anticheat") or n:find("vr") or n:find("teleport") or n:find("speed") then
                    pcall(function() v:Destroy() end)
                end
            end
        end
    end
    if ps then killScripts(ps) end
    if char then killScripts(char) end
end

local function setNoclip(char, state)
    if not char then return end
    if state then
        if _G.LHub.NoclipStates[char] then return end
        _G.LHub.NoclipStates[char] = {}
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                _G.LHub.NoclipStates[char][p] = p.CanCollide
                p.CanCollide = false
            end
        end
    else
        if _G.LHub.NoclipStates[char] then
            for p, c in pairs(_G.LHub.NoclipStates[char]) do
                if p and p.Parent then p.CanCollide = c end
            end
            _G.LHub.NoclipStates[char] = nil
        end
    end
end

local function fastTeleport(targetPos, checkActive)
    local char = LocalPlayer.Character
    if not char or not char.Parent then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    bypassAntiCheat()
    setNoclip(char, true)
    
    local startCF = hrp.CFrame
    local targetCF = CFrame.new(targetPos)
    local dist = (targetPos - hrp.Position).Magnitude
    local steps = math.clamp(math.floor(dist / 30), 3, 15) 
    
    for i = 1, steps do
        if not checkActive() then setNoclip(char, false); return false end
        hrp.CFrame = startCF:Lerp(targetCF, i / steps)
        task.wait() 
    end
    
    hrp.CFrame = targetCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    setNoclip(char, false)
    return true
end

-- ==========================================
-- 3. AUTO RACE E COLETA
-- ==========================================
local autoRaceActive = false

local function stopAutoRace()
    if not autoRaceActive then return end
    autoRaceActive = false
    local char = LocalPlayer.Character
    if char then setNoclip(char, false) end
end

local function startAutoRace()
    if autoRaceActive then return end
    autoRaceActive = true
    bypassAntiCheat()
    
    task.spawn(function()
        while autoRaceActive do
            -- Checa se a corrida terminou
            local raceEnded = PlayerGui:FindFirstChild("RaceEnded")
            local rigs = Workspace:FindFirstChild("Rigs")
            local myRig = rigs and (rigs:FindFirstChild(LocalPlayer.Name) or rigs:FindFirstChild(LocalPlayer.DisplayName))
            
            if raceEnded or (myRig and myRig:GetAttribute("Finished") == true) then
                stopAutoRace()
                break
            end

            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then task.wait(1); continue end
            
            local hrp = char.HumanoidRootPart
            
            -- Coleta Rokas
            local itemsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Items") and Workspace.Map.Gameplay.Items:FindFirstChild("Spawned")
            if itemsFolder then
                for _, item in ipairs(itemsFolder:GetChildren()) do
                    if autoRaceActive and string.find(string.lower(item.Name), "roka") then
                        local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt then
                            fastTeleport(item.Position + Vector3.new(0, 3, 0), function() return autoRaceActive end)
                            prompt:InputHoldBegin()
                            task.wait(prompt.HoldDuration)
                            prompt:InputHoldEnd()
                        end
                    end
                end
            end
            
            -- Checkpoints e Linha de Chegada
            local checkpoints = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Checkpoints")
            local finishFolder = Workspace:FindFirstChild("FinishLine", true)
            local targetPos = nil
            
            if finishFolder then
                local base = finishFolder:FindFirstChildWhichIsA("BasePart", true)
                if base then targetPos = base.Position end
            end
            if not targetPos then
                targetPos = Vector3.new(3269, -239, 2052) -- Fallback S1
            end
            
            if checkpoints then
                for _, cp in ipairs(checkpoints:GetChildren()) do
                    if autoRaceActive then
                        fastTeleport(cp.Position + Vector3.new(0, 150, 0), function() return autoRaceActive end)
                        fastTeleport(cp.Position + Vector3.new(0, 3, 0), function() return autoRaceActive end)
                        task.wait(0.2)
                    end
                end
            end
            
            if autoRaceActive then
                fastTeleport(targetPos, function() return autoRaceActive end)
                task.wait(3)
            end
        end
    end)
end

-- ==========================================
-- 4. CONSTRUÇÃO DO MENU
-- ==========================================
local TabRace = Instance.new("TextLabel")
TabRace.Size = UDim2.new(1, 0, 0, 20); TabRace.BackgroundTransparency = 1
TabRace.Text = "AUTO RACE"; TabRace.TextColor3 = Color3.fromRGB(130, 80, 255)
TabRace.Font = Enum.Font.GothamBlack; TabRace.TextSize = 12; TabRace.TextXAlignment = Enum.TextXAlignment.Left
TabRace.Parent = content

createToggle("Enable Auto Race (Universal)", false, function(s) 
    if s then startAutoRace() else stopAutoRace() end 
end)

createBtn("TP Stage 1", function() 
    fastTeleport(Vector3.new(3269.18, -239.66, 2052.78), function() return true end) 
end)
createBtn("TP Stage 2", function() 
    fastTeleport(Vector3.new(8541.87, -166.66, -1274.94), function() return true end) 
end)

local TabMisc = Instance.new("TextLabel")
TabMisc.Size = UDim2.new(1, 0, 0, 20); TabMisc.BackgroundTransparency = 1
TabMisc.Text = "MISC"; TabMisc.TextColor3 = Color3.fromRGB(130, 80, 255)
TabMisc.Font = Enum.Font.GothamBlack; TabMisc.TextSize = 12; TabMisc.TextXAlignment = Enum.TextXAlignment.Left
TabMisc.Parent = content

createToggle("Auto Collect Rokakaka", Config.autoCollect, function(s)
    Config.autoCollect = s; SaveConfig()
    task.spawn(function()
        while Config.autoCollect do
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local itemsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Items") and Workspace.Map.Gameplay.Items:FindFirstChild("Spawned")
                if itemsFolder then
                    for _, item in ipairs(itemsFolder:GetChildren()) do
                        if Config.autoCollect and string.find(string.lower(item.Name), "roka") then
                            local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if prompt then
                                fastTeleport(item.Position + Vector3.new(0, 3, 0), function() return Config.autoCollect end)
                                prompt:InputHoldBegin()
                                task.wait(prompt.HoldDuration)
                                prompt:InputHoldEnd()
                            end
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end)

warn("[L HUB v76] Carregado com sucesso.")
