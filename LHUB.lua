-- language: Lua, file: LHub_v83.lua, target: Roblox (Delta Executor)
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
local CONFIG_FILE = "LHub_Config_v83.json"

local Environment = {
    HasDrawing = type(Drawing) == "table" or type(Drawing) == "userdata",
    HasWriteFile = type(writefile) == "function",
    HasReadFile = type(readfile) == "function",
    HasIsFile = type(isfile) == "function",
    HasTask = type(task) == "table"
}

local DefaultConfig = {
    aimbotEnabled = false, aimbotFov = 120, aimbotTurnChar = true,
    dashStrong = true, aimCamHeight = 8, aimYawOff = 0, aimPitchOff = 0,
    autoCollect = false, fovCircleOn = false, tpKillHeight = 6,
    floatBtnPosXScale = 0.85, floatBtnPosXOffset = 0,
    floatBtnPosYScale = 0.55, floatBtnPosYOffset = 0,
    espRokaPlant = false, espRokaFruit = false, espArrow = false, espShiny = false
}

local Config = {}
for k, v in pairs(DefaultConfig) do Config[k] = v end

local function LoadConfig()
    if Environment.HasIsFile and Environment.HasReadFile and isfile(CONFIG_FILE) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if success and type(data) == "table" then
            for k, v in pairs(data) do if Config[k] ~= nil then Config[k] = v end end
        end
    end
end
LoadConfig()

local function SaveConfig(silent)
    if Environment.HasWriteFile then
        local data = {}
        for k, v in pairs(Config) do data[k] = v end
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
    end
end

-- ==========================================
-- 2. TASK & CONNECTION MANAGERS
-- ==========================================
local TaskManager = { Tasks = {} }
function TaskManager:Add(thread)
    table.insert(self.Tasks, thread)
    return thread
end

local ConnectionManager = { Conns = {} }
function ConnectionManager:Add(conn)
    table.insert(self.Conns, conn)
    return conn
end

if _G.LHub then
    pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
    if _G.LHub.Tasks then for _, t in pairs(_G.LHub.Tasks) do if coroutine.status(t) ~= "dead" then pcall(task.cancel, t) end end end
    if _G.LHub.Conns then for _, c in pairs(_G.LHub.Conns) do pcall(function() c:Disconnect() end) end end
    if _G.LHub.Gui then pcall(function() _G.LHub.Gui:Destroy() end) end
    if _G.LHub.ESPObjects then for _, d in pairs(_G.LHub.ESPObjects) do if d.hl then d.hl:Destroy() end if d.bb then d.bb:Destroy() end end end
    if _G.LHub.FovCircle then pcall(function() _G.LHub.FovCircle:Remove() end) end
    if _G.LHub.Highlight then pcall(function() _G.LHub.Highlight:Destroy() end) end
end

_G.LHub = { Gui = nil, FovCircle = nil, Highlight = nil, ESPObjects = {}, Tasks = TaskManager.Tasks, Conns = ConnectionManager.Conns, NoclipStates = {} }

TaskManager:Add(task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if Workspace:FindFirstChild("PHYSICS_WATCHDOG") then Workspace.PHYSICS_WATCHDOG:Destroy() end
            if Workspace:FindFirstChild("NETWORK_WATCHDOG") then Workspace.NETWORK_WATCHDOG:Destroy() end
        end)
    end
end))

-- ==========================================
-- 3. MAP & UTILITIES + BYPASS ANTI-CHEAT
-- ==========================================
local STAGE1_WIN_POS = Vector3.new(3269.18408, -239.665649, 2052.78711)
local STAGE2_WIN_POS = Vector3.new(8541.87793, -166.666595, -1274.94568)

local function getFinishLine()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local finishFolder = Workspace:FindFirstChild("FinishLine", true)
    local targetPart = nil
    
    if finishFolder then
        for _, child in ipairs(finishFolder:GetDescendants()) do
            if child:IsA("BasePart") and string.find(string.lower(child.Name), "cube") then
                targetPart = child; break
            end
        end
        if not targetPart then
            for _, child in ipairs(finishFolder:GetDescendants()) do
                if child:IsA("BasePart") then targetPart = child; break end
            end
        end
    end
    
    if not targetPart then
        local d1 = (hrp.Position - STAGE1_WIN_POS).Magnitude
        local d2 = (hrp.Position - STAGE2_WIN_POS).Magnitude
        return (d1 < d2) and STAGE1_WIN_POS or STAGE2_WIN_POS
    end
    
    local dir = (targetPart.Position - hrp.Position)
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude > 0.1 then
        return targetPart.Position + (dir.Unit * 100) + Vector3.new(0, 3, 0)
    end
    return targetPart.Position + Vector3.new(0, 3, 0)
end

local function bypassAntiCheat()
    local char = LocalPlayer.Character
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    
    local function killScripts(parent)
        if not parent then return end
        for _, v in ipairs(parent:GetDescendants()) do
            local n = string.lower(v.Name)
            if v:IsA("LocalScript") or v:IsA("Script") then
                if n:find("detector") or n:find("anticheat") or n:find("vr") or n:find("teleport") or n:find("speed") then
                    pcall(function() 
                        if v:IsA("LocalScript") then v.Disabled = true end 
                        v:Destroy() 
                    end)
                end
            end
        end
    end

    if ps then killScripts(ps) end
    if char then killScripts(char) end
end

-- ==========================================
-- 4. CORE MECHANICS (Tween Rápido + Noclip)
-- ==========================================
local function setNoclip(char, state)
    if not char then return end
    if state then
        if _G.LHub.NoclipStates[char] then return end
        _G.LHub.NoclipStates[char] = {}
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                _G.LHub.NoclipStates[char][part] = part.CanCollide
                part.CanCollide = false
            end
        end
    else
        if _G.LHub.NoclipStates[char] then
            for part, cc in pairs(_G.LHub.NoclipStates[char]) do
                if part and part.Parent then part.CanCollide = cc end
            end
            _G.LHub.NoclipStates[char] = nil
        end
    end
end

local function safeTweenTeleport(targetPos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    pcall(bypassAntiCheat)
    setNoclip(char, true)
    
    local targetCF = CFrame.new(targetPos)
    local startCF = hrp.CFrame
    
    hrp.Anchored = true
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    pcall(function()
        for i = 1, 20 do
            if not hrp.Parent then break end
            hrp.CFrame = startCF:Lerp(targetCF, i / 20)
            task.wait(0.05)
        end
        hrp.CFrame = targetCF
    end)
    
    hrp.Anchored = false
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    setNoclip(char, false)
    task.wait(0.1)
end

local function tweenWithNoclip(targetPos, checkActive)
    local char = LocalPlayer.Character
    if not char or not char.Parent then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end
    
    pcall(bypassAntiCheat)
    setNoclip(char, true)
    
    local dist = (targetPos - hrp.Position).Magnitude
    local speed = 1500 
    local t = dist / speed
    if t < 0.2 then t = 0.2 end
    
    local tween = TweenService:Create(hrp, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.new(targetPos) })
    tween:Play()
    
    while tween.PlaybackState == Enum.PlaybackState.Playing do
        if not checkActive() then
            tween:Cancel()
            setNoclip(char, false)
            return false
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait()
    end
    
    setNoclip(char, false)
    return true
end

local function holdPromptInfinitely(target, checkActive)
    local p, m = target.prompt, target.model
    if not p or not p.Parent or not m or not m.Parent then return end
    local char = LocalPlayer.Character
    if not char or not char.Parent then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    
    local freezeCF = hrp.CFrame
    local ow, oj, op = hum.WalkSpeed, hum.JumpPower, hum.PlatformStand
    
    pcall(function()
        hum.PlatformStand = false
        hum.WalkSpeed = 0
        hum.JumpPower = 0
    end)
    
    local holdTime = p.HoldDuration > 0 and p.HoldDuration or 0.5
    
    pcall(function()
        while checkActive() and m.Parent ~= nil and p.Parent ~= nil do
            hrp.CFrame = freezeCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            pcall(function() p:InputHoldBegin() end)
            local t = tick()
            while tick() - t < holdTime do
                if not checkActive() then break end
                if m.Parent == nil or p.Parent == nil then break end
                hrp.CFrame = freezeCF
                hrp.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.05)
            end
            if m.Parent == nil or p.Parent == nil then break end
            pcall(function() p:InputHoldEnd() end)
            task.wait(0.1)
        end
    end)
    
    if hum and hum.Parent then
        pcall(function()
            hum.WalkSpeed = ow
            hum.JumpPower = oj
            hum.PlatformStand = op
        end)
    end
end

-- ==========================================
-- 5. ESP SYSTEM
-- ==========================================
local function createESP(model, title, color)
    if _G.LHub.ESPObjects[model] then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = model
    hl.FillColor = color
    hl.OutlineColor = Color3.fromRGB(212, 175, 55)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = model
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "LHubESP"
    bb.Adornee = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")) or model
    bb.Size = UDim2.new(0, 200, 0, 20)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = model
    
    local textLbl = Instance.new("TextLabel")
    textLbl.Parent = bb
    textLbl.Size = UDim2.new(1, 0, 1, 0)
    textLbl.BackgroundTransparency = 1
    textLbl.RichText = true
    textLbl.TextColor3 = Color3.new(1, 1, 1)
    textLbl.Font = Enum.Font.GothamBold
    textLbl.TextSize = 13
    textLbl.TextStrokeTransparency = 0
    textLbl.Text = string.format("<b><font color='rgb(%d,%d,%d)'>%s</font></b> <font color='#DDDDDD'>[0m]</font>", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255), title)
    
    _G.LHub.ESPObjects[model] = { hl = hl, bb = bb, textLbl = textLbl, title = title, color = color }
end

local function cleanESP()
    for model, data in pairs(_G.LHub.ESPObjects) do
        local destroy = false
        if not model.Parent then
            destroy = true
        else
            local name = string.lower(model.Name)
            local isPlant = string.find(name, "plant") or string.find(name, "caule")
            local isRoka = string.find(name, "roka") or string.find(name, "fruit") or string.find(name, "plant")
            local isShiny = string.find(name, "shiny")
            local isArrow = string.find(name, "arrow") or model:FindFirstAncestor("Arrows")
            
            if isRoka then
                if isPlant and not Config.espRokaPlant then destroy = true
                elseif not isPlant and not Config.espRokaFruit then destroy = true end
            elseif isShiny then
                if not Config.espShiny then destroy = true end
            elseif isArrow then
                if not Config.espArrow then destroy = true end
            end
        end
        
        if destroy then
            if data.hl then data.hl:Destroy() end
            if data.bb then data.bb:Destroy() end
            _G.LHub.ESPObjects[model] = nil
        end
    end
end

local function scanItems()
    local itemsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Items") and Workspace.Map.Gameplay.Items:FindFirstChild("Spawned")
    if itemsFolder then
        for _, item in ipairs(itemsFolder:GetChildren()) do
            local name = string.lower(item.Name)
            local isPlant = string.find(name, "plant") or string.find(name, "caule")
            local isFruit = string.find(name, "roka") or string.find(name, "fruit")
            if isPlant and Config.espRokaPlant then
                createESP(item, "Roka Plant", Color3.fromRGB(50, 255, 100))
            elseif isFruit and Config.espRokaFruit and not isPlant then
                createESP(item, "Roka Fruit", Color3.fromRGB(255, 105, 180))
            end
        end
    end
    
    local mapEvents = Workspace:FindFirstChild("MapEvents")
    local arrowsFolder = mapEvents and mapEvents:FindFirstChild("Arrows") and mapEvents.Arrows:FindFirstChild("Spawned")
    if arrowsFolder then
        for _, arrow in ipairs(arrowsFolder:GetChildren()) do
            local name = string.lower(arrow.Name)
            local isShiny = string.find(name, "shiny")
            if isShiny and Config.espShiny then
                createESP(arrow, "Arrow Shiny", Color3.fromRGB(255, 215, 0))
            elseif not isShiny and Config.espArrow then
                createESP(arrow, "Arrow", Color3.fromRGB(255, 255, 255))
            end
        end
    end
    cleanESP()
end

TaskManager:Add(task.spawn(function()
    while task.wait(0.2) do
        scanItems()
        local char = LocalPlayer.Character
        if not char or not char.Parent then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            for model, data in pairs(_G.LHub.ESPObjects) do
                if model.Parent and data.textLbl then
                    local pos = model:IsA("BasePart") and model.Position or model:GetPivot().Position
                    local dist = math.floor((pos - hrp.Position).Magnitude)
                    data.textLbl.Text = string.format("<b><font color='rgb(%d,%d,%d)'>%s</font></b> <font color='#DDDDDD'>[%dm]</font>", math.floor(data.color.R * 255), math.floor(data.color.G * 255), math.floor(data.color.B * 255), data.title, dist)
                end
            end
        end
    end
end))

-- ==========================================
-- 6. AUTO COLLECT (Independente)
-- ==========================================
local isCollecting = false
local function executeCollect()
    if not Config.autoCollect or isCollecting then return end
    isCollecting = true
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        
        local targets = {}
        local itemsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Items") and Workspace.Map.Gameplay.Items:FindFirstChild("Spawned")
        if itemsFolder then
            for _, item in ipairs(itemsFolder:GetChildren()) do
                local name = string.lower(item.Name)
                if string.find(name, "roka") or string.find(name, "fruit") or string.find(name, "plant") then
                    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt and prompt.Parent then
                        table.insert(targets, { model = item, prompt = prompt, pos = item:IsA("BasePart") and item.Position or item:GetPivot().Position })
                    end
                end
            end
        end
        
        if #targets == 0 then return end
        table.sort(targets, function(a, b) return (a.pos - hrp.Position).Magnitude < (b.pos - hrp.Position).Magnitude end)
        
        if hum.SeatPart then hum.Sit = false; task.wait(0.5) end
        
        for _, t in ipairs(targets) do
            if not Config.autoCollect then break end
            
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = { char, t.model }
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local rayResult = Workspace:Raycast(t.pos + Vector3.new(0, 50, 0), Vector3.new(0, -150, 0), rayParams)
            local standPos = Vector3.new(t.pos.X, (rayResult and rayResult.Position.Y or t.pos.Y) + 3, t.pos.Z)
            
            local success = tweenWithNoclip(standPos, function() return Config.autoCollect and t.model.Parent ~= nil end)
            if success then
                holdPromptInfinitely(t, function() return Config.autoCollect end)
            end
            task.wait(0.2)
        end
    end)
    isCollecting = false
end

TaskManager:Add(task.spawn(function()
    while true do
        task.wait(1)
        if Config.autoCollect then executeCollect() end
    end
end))

-- ==========================================
-- 7. AUTO RACE (State Machine via Placement)
-- ==========================================
local autoRaceEnabled = false
local raceToggle
local lastState = "WAITING"

local function stopRaceMovement()
    local char = LocalPlayer.Character
    if char then setNoclip(char, false) end
end

local function toggleAutoRace(state)
    autoRaceEnabled = state
    if raceToggle then raceToggle.setState(state) end
    
    if not state then
        stopRaceMovement()
        lastState = "WAITING"
    else
        pcall(bypassAntiCheat)
    end
end

TaskManager:Add(task.spawn(function()
    while true do
        task.wait(0.5)
        
        if not autoRaceEnabled then
            lastState = "WAITING"
            continue 
        end

        local char = LocalPlayer.Character
        if not char or not char.Parent then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end

        -- MÁGICA AQUI: Lendo os Atributos do Rig
        local rigs = Workspace:FindFirstChild("Rigs")
        local myRig = rigs and (rigs:FindFirstChild(LocalPlayer.Name) or rigs:FindFirstChild(LocalPlayer.DisplayName))
        
        local placement = 0
        local isFinished = false
        
        if myRig then
            local pAttr = myRig:GetAttribute("Placement")
            if type(pAttr) == "number" then placement = pAttr end
            
            if myRig:GetAttribute("Finished") == true then isFinished = true end
        end

        local raceEndedGui = PlayerGui:FindFirstChild("RaceEnded")
        local raceOverGui = PlayerGui:FindFirstChild("RaceOver")
        local raceOverScreen = (raceEndedGui and raceEndedGui.Enabled) or (raceOverGui and raceOverGui.Enabled)

        -- LÓGICA DE ESTADOS BASEADA NO PLACEMENT
        if raceOverScreen or isFinished then
            if lastState ~= "FINISHED" then
                lastState = "FINISHED"
                stopRaceMovement()
            end
            task.wait(1)
            
        elseif placement == 0 or placement == nil then
            -- Se o Placement for 0, a corrida não começou.
            if lastState ~= "WAITING" then
                lastState = "WAITING"
                stopRaceMovement()
            end
            task.wait(1)
            
        else
            -- PLACEMENT > 0. A CORRIDA ESTÁ ROLANDO!
            if lastState ~= "RUNNING" then
                lastState = "RUNNING"
            end
            
            -- Executa Movimento da Corrida
            local items = {}
            local itemsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Items") and Workspace.Map.Gameplay.Items:FindFirstChild("Spawned")
            if itemsFolder then
                for _, item in ipairs(itemsFolder:GetChildren()) do
                    local name = string.lower(item.Name)
                    if string.find(name, "roka") or string.find(name, "fruit") or string.find(name, "plant") then
                        local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt and prompt.Parent then
                            local p = item:IsA("BasePart") and item.Position or item:GetPivot().Position
                            table.insert(items, {model = item, prompt = prompt, pos = p})
                        end
                    end
                end
            end
            
            local checkpointsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Gameplay") and Workspace.Map.Gameplay:FindFirstChild("Checkpoints")
            if checkpointsFolder then
                local checkpoints = {}
                for _, cp in ipairs(checkpointsFolder:GetChildren()) do
                    table.insert(checkpoints, cp)
                end
                table.sort(checkpoints, function(a, b)
                    local numA = tonumber(a.Name:match("%d+")) or 0
                    local numB = tonumber(b.Name:match("%d+")) or 0
                    return numA < numB
                end)
                
                for _, cp in ipairs(checkpoints) do
                    if not autoRaceEnabled or lastState ~= "RUNNING" then break end
                    local highPos = cp.Position + Vector3.new(0, 150, 0)
                    tweenWithNoclip(highPos, function() return autoRaceEnabled and lastState == "RUNNING" end)
                    local cpPos = cp.Position + Vector3.new(0, 3, 0)
                    tweenWithNoclip(cpPos, function() return autoRaceEnabled and lastState == "RUNNING" end)
                    task.wait(0.2)
                end
            end
            
            if autoRaceEnabled and lastState == "RUNNING" then
                local f = getFinishLine()
                if f then 
                    tweenWithNoclip(f, function() return autoRaceEnabled and lastState == "RUNNING" end) 
                end
                task.wait(1) 
            end
        end
    end
end))

-- ==========================================
-- 8. USER INTERFACE (LUXURY v70)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LHub_Luxury"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end
_G.LHub.Gui = screenGui

local BG_COLOR = Color3.fromRGB(15, 15, 22)
local SIDEBAR_COLOR = Color3.fromRGB(20, 20, 28)
local ELEMENT_BG = Color3.fromRGB(28, 28, 38)
local GOLD = Color3.fromRGB(212, 175, 55)
local GOLD_BRIGHT = Color3.fromRGB(255, 215, 0)
local TEXT_WHITE = Color3.fromRGB(240, 240, 240)
local TEXT_GRAY = Color3.fromRGB(140, 140, 150)

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 45, 0, 45)
floatBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
floatBtn.BackgroundColor3 = BG_COLOR
floatBtn.BackgroundTransparency = 0.2
floatBtn.Text = "L"
floatBtn.TextColor3 = GOLD
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 24
floatBtn.Active = true
floatBtn.Parent = screenGui
local fC = Instance.new("UICorner", floatBtn); fC.CornerRadius = UDim.new(1, 0)
local fS = Instance.new("UIStroke", floatBtn); fS.Color = GOLD; fS.Thickness = 2

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 400)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
mainFrame.BackgroundColor3 = BG_COLOR
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = false
mainFrame.Parent = screenGui
local mC = Instance.new("UICorner", mainFrame); mC.CornerRadius = UDim.new(0, 12)
local mS = Instance.new("UIStroke", mainFrame); mS.Color = Color3.fromRGB(60, 60, 80); mS.Thickness = 1.5; mS.Transparency = 0.2

local uiScale = Instance.new("UIScale")
uiScale.Scale = 0.8
uiScale.Parent = mainFrame

local function updateScale()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    if vp.X < 700 or vp.Y < 500 then uiScale.Scale = 0.5
    elseif vp.X < 1000 or vp.Y < 700 then uiScale.Scale = 0.65
    else uiScale.Scale = 0.8 end
end
updateScale()
ConnectionManager:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.wait(1)
    local c = Workspace.CurrentCamera
    if c then ConnectionManager:Add(c:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)) end
    updateScale()
end))

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = SIDEBAR_COLOR
topBar.BackgroundTransparency = 0.2
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
local tC = Instance.new("UICorner", topBar); tC.CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 200, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "L HUB | NEXUS v83"
title.TextColor3 = GOLD_BRIGHT
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(0, 200, 0, 28)
searchBox.Position = UDim2.new(0.5, -100, 0.5, -14)
searchBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
searchBox.PlaceholderText = "🔍 Buscar função..."
searchBox.PlaceholderColor3 = TEXT_GRAY
searchBox.TextColor3 = TEXT_WHITE
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 12
searchBox.Parent = topBar
local sbC = Instance.new("UICorner", searchBox); sbC.CornerRadius = UDim.new(1, 0)
local sbS = Instance.new("UIStroke", searchBox); sbS.Color = Color3.fromRGB(60, 60, 80)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = topBar
local cBtnC = Instance.new("UICorner", closeBtn); cBtnC.CornerRadius = UDim.new(1, 0)
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
        if not success then warn("Erro UI: " .. tostring(err)) end
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
raceToggle = createToggle(SectRace, "Enable Auto Race (Placement)", false, function(state) 
    toggleAutoRace(state)
end)

local TabWin = createTab("Teletransporte", "⚔️")
local SectWinS1 = createSection(TabWin, "TELEPORTES MANUAIS", "🏁")
SectWinS1.LayoutOrder = 1
createButton(SectWinS1, "TP Stage 1", function() safeTweenTeleport(STAGE1_WIN_POS) end)
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
