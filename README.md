-- language: Lua, file: L_hub_v57_invis_bypass.lua, target: Roblox (executor mobile/PC)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ==========================================
-- 0. CONFIG / SAVE SYSTEM
-- ==========================================
local CONFIG_FILE = "LHub_Config.json"

local defaultConfig = {
    aimbotEnabled = false, aimbotFov = 120, aimbotTurnChar = true, dashStrong = true,
    aimCamHeight = 8, aimYawOff = 0, aimPitchOff = 0, isAutoCollectEnabled = false,
    fovCircleOn = false,
    floatBtnPosXScale = 0.85, floatBtnPosXOffset = 0,
    floatBtnPosYScale = 0.55, floatBtnPosYOffset = 0
}

local config = {}
for k, v in pairs(defaultConfig) do config[k] = v end

local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if success and type(data) == "table" then
            for k, v in pairs(data) do
                if config[k] ~= nil then config[k] = v end
            end
        end
    end
end
loadConfig()

-- Loaded Variables
local isAutoCollectEnabled = config.isAutoCollectEnabled
local aimbotEnabled = config.aimbotEnabled
local aimbotFov = config.aimbotFov
local aimbotTurnChar = config.aimbotTurnChar
local dashStrong = config.dashStrong
local aimCamHeight = config.aimCamHeight
local aimYawOff = config.aimYawOff
local aimPitchOff = config.aimPitchOff
local fovCircleOn = config.fovCircleOn

local aimbotFloatBtn = nil 

local function saveConfig(silent)
    if writefile then
        local data = {
            aimbotEnabled = aimbotEnabled, aimbotFov = aimbotFov, aimbotTurnChar = aimbotTurnChar,
            dashStrong = dashStrong, aimCamHeight = aimCamHeight, aimYawOff = aimYawOff,
            aimPitchOff = aimPitchOff, isAutoCollectEnabled = isAutoCollectEnabled,
            fovCircleOn = fovCircleOn,
            floatBtnPosXScale = aimbotFloatBtn and aimbotFloatBtn.Position.X.Scale or 0.85,
            floatBtnPosXOffset = aimbotFloatBtn and aimbotFloatBtn.Position.X.Offset or 0,
            floatBtnPosYScale = aimbotFloatBtn and aimbotFloatBtn.Position.Y.Scale or 0.55,
            floatBtnPosYOffset = aimbotFloatBtn and aimbotFloatBtn.Position.Y.Offset or 0
        }
        local success, err = pcall(function() 
            writefile(CONFIG_FILE, HttpService:JSONEncode(data)) 
        end)
        if not silent then
            if success then
                print("[LHub] Settings saved to file successfully!")
            else
                warn("[LHub] Error saving: " .. tostring(err))
            end
        end
    end
end

-- ==========================================
-- 1. CLEANUP & ANTI-WATCHDOG
-- ==========================================
if _G.LHub then
    pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
    pcall(function() for _, c in ipairs(_G.LHub.Conns or {}) do c:Disconnect() end end)
    pcall(function() if _G.LHub.FovCircle then _G.LHub.FovCircle:Remove() end end)
    pcall(function() if _G.LHub.Highlight then _G.LHub.Highlight:Destroy() end end)
    pcall(function() if _G.LHub.Gui then _G.LHub.Gui:Destroy() end end)
    pcall(function() if _G.LHub.CollectLoop then task.cancel(_G.LHub.CollectLoop) end end)
    pcall(function() if _G.LHub.WatchdogKiller then task.cancel(_G.LHub.WatchdogKiller) end end)
    pcall(function() if _G.LHub.AimbotLoop then task.cancel(_G.LHub.AimbotLoop) end end)
    pcall(function() if _G.LHub.TpKillConn then _G.LHub.TpKillConn:Disconnect() end end)
    pcall(function() if _G.LHub.BypassLoop then task.cancel(_G.LHub.BypassLoop) end end)
    pcall(function() if _G.LHub.FakeCamera then _G.LHub.FakeCamera:Destroy() end end)
end

_G.LHub = { Gui = nil, CollectLoop = nil, WatchdogKiller = nil, AimbotLoop = nil, FovCircle = nil, Highlight = nil, Conns = {}, TpKillConn = nil, BypassLoop = nil, FakeCamera = nil }

_G.LHub.WatchdogKiller = task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if Workspace:FindFirstChild("PHYSICS_WATCHDOG") then Workspace.PHYSICS_WATCHDOG:Destroy() end
            if Workspace:FindFirstChild("NETWORK_WATCHDOG") then Workspace.NETWORK_WATCHDOG:Destroy() end
        end)
    end
end)

local RED = Color3.fromRGB(255, 30, 30)
local BLACK = Color3.fromRGB(15, 15, 15)
local DARK_GRAY = Color3.fromRGB(30, 30, 30)

-- ==========================================
-- 2. BASE FUNCTIONS
-- ==========================================
local STAGE1_WIN_POS = Vector3.new(3407.000, -408.536, 2287.5)
local STAGE2_CP1_POS = Vector3.new(-2805.450, -160.060, -1304.949)
local STAGE2_CP2_POS = Vector3.new(1667.592, -154.669, -1671.076)
local STAGE2_WIN_POS = Vector3.new(8460.426, 61.457, -1291.114)
local ROKA_SPAWNS = {
    Vector3.new(758.075, 200.301, 2071.725), Vector3.new(-722.469, 200.301, 2592.146),
    Vector3.new(-809.457, -38.199, 687.739), Vector3.new(-484.195, 28.807, -640.670),
    Vector3.new(581.779, -160.702, -1142.168), Vector3.new(-7165.460, -160.702, -2034.455)
}

local function getFinishLine(stage)
    local finishFolder = Workspace:FindFirstChild("FinishLine", true)
    if finishFolder then
        for _, child in ipairs(finishFolder:GetDescendants()) do
            if child:IsA("BasePart") and string.find(string.lower(child.Name), "cube") then
                return child.Position + Vector3.new(0, 3, 0)
            end
        end
        for _, child in ipairs(finishFolder:GetDescendants()) do
            if child:IsA("BasePart") then
                return child.Position + Vector3.new(0, 3, 0)
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "cube.") then
            return obj.Position + Vector3.new(0, 3, 0)
        end
    end
    return nil
end

local function nukeTeleportDetectorsOnly()
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if ps then
        for _, d in ipairs(ps:GetDescendants()) do
            if d.Name == "VRCameraTeleportDetector" or string.find(d.Name, "TeleportDetector") then
                pcall(function() d:Destroy() end)
            end
        end
    end
end

local function safeTweenTeleport(targetPos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local isTp = true
    task.spawn(function()
        while isTp do
            pcall(nukeTeleportDetectorsOnly)
            task.wait(0.1)
        end
    end)

    local targetCF = CFrame.new(targetPos)
    local startCF = hrp.CFrame
    
    hrp.Anchored = true
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    local steps = 20
    for i = 1, steps do
        if not hrp.Parent then isTp = false; return end
        hrp.CFrame = startCF:Lerp(targetCF, i / steps)
        task.wait(0.05) 
    end
    
    hrp.CFrame = targetCF
    hrp.Anchored = false
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    isTp = false
    task.wait(0.1)
end

local function fastTweenToItem(targetPos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    local targetModel = hum.SeatPart and hum.SeatPart.Parent or char
    local targetHrp = targetModel:FindFirstChild("HumanoidRootPart") or targetModel.PrimaryPart
    if not targetHrp then return end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {targetModel}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local rayResult = Workspace:Raycast(targetPos + Vector3.new(0, 50, 0), Vector3.new(0, -150, 0), rayParams)
    local finalPos = rayResult and (rayResult.Position + Vector3.new(0, 3.0, 0)) or (targetPos + Vector3.new(0, 3.0, 0))
    targetHrp.Anchored = true
    targetHrp.AssemblyLinearVelocity = Vector3.zero
    targetHrp.AssemblyAngularVelocity = Vector3.zero
    local tween = TweenService:Create(targetHrp, TweenInfo.new(0.15, Enum.EasingStyle.Linear), { CFrame = CFrame.new(finalPos) })
    tween:Play()
    tween.Completed:Wait()
    targetHrp.Anchored = false
    targetHrp.AssemblyLinearVelocity = Vector3.zero
    targetHrp.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.3)
end

local isCollecting = false
local function executeCollect()
    if not isAutoCollectEnabled or isCollecting then return end
    isCollecting = true
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local targets = {}
        local mapEvents = Workspace:FindFirstChild("MapEvents")
        local arrowsFolder = mapEvents and mapEvents:FindFirstChild("Arrows") and mapEvents.Arrows:FindFirstChild("Spawned")
        if arrowsFolder then
            for _, arrow in ipairs(arrowsFolder:GetChildren()) do
                local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and prompt.Parent then
                    table.insert(targets, {model = arrow, prompt = prompt, pos = arrow:IsA("BasePart") and arrow.Position or arrow:GetPivot().Position})
                end
            end
        end
        local map = Workspace:FindFirstChild("Map")
        local gameplay = map and map:FindFirstChild("Gameplay")
        local itemsFolder = gameplay and gameplay:FindFirstChild("Items") and gameplay.Items:FindFirstChild("Spawned")
        if itemsFolder then
            for _, item in ipairs(itemsFolder:GetChildren()) do
                local name = string.lower(item.Name)
                if string.find(name, "roka") or string.find(name, "fruit") or string.find(name, "plant") then
                    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt and prompt.Parent then
                        local p = item:IsA("BasePart") and item.Position or item:GetPivot().Position
                        for _, spawnPos in ipairs(ROKA_SPAWNS) do
                            if (p - spawnPos).Magnitude < 50 then
                                table.insert(targets, {model = item, prompt = prompt, pos = p})
                                break
                            end
                        end
                    end
                end
            end
        end
        if #targets == 0 then return end
        table.sort(targets, function(a, b) return (a.pos - hrp.Position).Magnitude < (b.pos - hrp.Position).Magnitude end)
        if hum.SeatPart then hum.Sit = false; task.wait(0.5) end
        for i, target in ipairs(targets) do
            if not isAutoCollectEnabled then break end
            fastTweenToItem(target.pos)
            task.wait(0.2)
            pcall(function() target.prompt:InputHoldBegin() end)
            local holdTimeout = 0
            while target.model.Parent ~= nil and holdTimeout < 5 do task.wait(0.1) holdTimeout = holdTimeout + 0.1 end
            pcall(function() target.prompt:InputHoldEnd() end)
            task.wait(0.5)
        end
    end)
    isCollecting = false
end

-- ==========================================
-- 3. AIMBOT
-- ==========================================
local aimbotTarget = nil
local aimbotHighlight = Instance.new("Highlight")
aimbotHighlight.FillColor       = Color3.fromRGB(255, 0, 0)
aimbotHighlight.OutlineColor    = Color3.fromRGB(255, 255, 0)
aimbotHighlight.FillTransparency    = 0.4
aimbotHighlight.OutlineTransparency = 0
aimbotHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
aimbotHighlight.Enabled = false
aimbotHighlight.Parent = CoreGui
_G.LHub.Highlight = aimbotHighlight

local fovCircle = Drawing.new("Circle")
fovCircle.Visible   = fovCircleOn
fovCircle.Radius    = aimbotFov
fovCircle.Color     = Color3.fromRGB(255, 0, 0)
fovCircle.Thickness = 1.5
fovCircle.Filled    = false
fovCircle.Transparency = 1
_G.LHub.FovCircle = fovCircle

local function isDamageable(model)
    if model == LocalPlayer.Character then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health > 0 end
    local hp = model:FindFirstChild("Health") or model:FindFirstChild("HP") or model:FindFirstChild("HealthValue")
    if hp and ((hp:IsA("NumberValue") or hp:IsA("IntValue")) and hp.Value > 0) then return true end
    local attrHp = model:GetAttribute("Health") or model:GetAttribute("HP") or model:GetAttribute("MaxHealth")
    if attrHp and type(attrHp) == "number" and attrHp > 0 then return true end
    return false
end

local function pickAimPart(model)
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") then return head, Vector3.zero end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp, Vector3.new(0, 1.5, 0) end
    local pp = model.PrimaryPart
    if pp then return pp, Vector3.new(0, 1, 0) end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then return p, Vector3.zero end
    end
    return nil, nil
end

local entryCache = setmetatable({}, {__mode = "k"})
local function getEntry(model)
    local e = entryCache[model]
    if e and e.part and e.part.Parent then return e end
    local part, off = pickAimPart(model)
    if not part then entryCache[model] = nil; return nil end
    e = { model = model, hum = model:FindFirstChildOfClass("Humanoid"), part = part, off = off }
    entryCache[model] = e
    return e
end

local function entryAlive(e)
    if not e.model.Parent then return false end
    if e.hum then return e.hum.Parent ~= nil and e.hum.Health > 0 end
    return isDamageable(e.model)
end

local function entryPoint(e)
    local p = e.part
    if p and p.Parent then return p.Position + e.off end
    return nil
end

local npcCache = {}
local lastScan = 0

local function refreshNPCs()
    local list = {}
    local myChar = LocalPlayer.Character
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        n += 1
        if n % 2500 == 0 then task.wait() end
        if d:IsA("Model") and d ~= myChar and not Players:GetPlayerFromCharacter(d) then
            if not (myChar and d:IsDescendantOf(myChar)) and isDamageable(d) then
                list[#list + 1] = d
            end
        end
    end
    npcCache = list
end

_G.LHub.AimbotLoop = task.spawn(function()
    while true do
        task.wait(0.25)
        if aimbotEnabled and os.clock() - lastScan >= 2 then
            lastScan = os.clock()
            pcall(refreshNPCs)
        end
    end
end)

local aimbotLocked = nil
local lastCenter = nil
local acquireTimer = 0

local function releaseLock()
    aimbotLocked = nil
    aimbotTarget = nil
    aimbotHighlight.Enabled = false
    aimbotHighlight.Adornee = nil
end

local function acquire(cam, center, char)
    local best, bestD
    local function try(model)
        if model == char or not model.Parent then return end
        local e = getEntry(model)
        if not e or not entryAlive(e) then return end
        local p = entryPoint(e)
        if not p then return end
        local sp, onScreen = cam:WorldToViewportPoint(p)
        if not onScreen then return end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d <= aimbotFov and (not bestD or d < bestD) then
            best, bestD = e, d
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then try(plr.Character) end
    end
    for _, m in ipairs(npcCache) do try(m) end
    if best then
        aimbotLocked = best
        aimbotTarget = best.model
    end
end

local function aimbotStep(dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    if center ~= lastCenter then
        fovCircle.Position = center
        lastCenter = center
    end
    if not aimbotEnabled then
        if aimbotLocked then releaseLock() end
        return
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if aimbotLocked and not entryAlive(aimbotLocked) then
        releaseLock()
    end
    if not aimbotLocked then
        acquireTimer += dt
        if acquireTimer >= 0.05 then
            acquireTimer = 0
            acquire(cam, center, char)
        end
        if not aimbotLocked then return end
    end
    local aimPoint = entryPoint(aimbotLocked)
    if not aimPoint then
        releaseLock()
        return
    end
    local okv, tv = pcall(function() return aimbotLocked.part.AssemblyLinearVelocity end)
    if okv and tv then
        aimPoint = aimPoint + tv * math.min(dt or 0.016, 0.05)
    end
    if aimbotHighlight.Adornee ~= aimbotLocked.model then
        aimbotHighlight.Adornee = aimbotLocked.model
    end
    aimbotHighlight.Enabled = true
    local focus = cam.Focus.Position
    local dist = (cam.CFrame.Position - focus).Magnitude
    local toAim = aimPoint - focus
    if toAim.Magnitude > 0.5 then
        local dir = toAim.Unit
        local h = aimCamHeight
        if dist < 2 then h = 0 end
        local newPos = focus - dir * dist + Vector3.new(0, h, 0)
        if (aimPoint - newPos).Magnitude > 0.1 then
            local cf = CFrame.lookAt(newPos, aimPoint)
            if aimYawOff ~= 0 or aimPitchOff ~= 0 then
                cf = cf * CFrame.Angles(math.rad(aimPitchOff), math.rad(-aimYawOff), 0)
            end
            cam.CFrame = cf
        end
    end
    if aimbotTurnChar then
        local flat = Vector3.new(aimPoint.X - hrp.Position.X, 0, aimPoint.Z - hrp.Position.Z)
        if flat.Magnitude > 0.1 and hrp.CFrame.LookVector:Dot(flat.Unit) < 0.9999 then
            hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat)
        end
    end
end

pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
RunService:BindToRenderStep("LHubAimbot", Enum.RenderPriority.Last.Value, function(dt)
    pcall(aimbotStep, dt)
end)

-- ==========================================
-- 4. INTERFACE (UI)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LHub_AutoWin"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end
_G.LHub.Gui = screenGui

local function showToast(msg, color)
    local toast = Instance.new("TextLabel")
    toast.Size = UDim2.new(0, 200, 0, 40)
    toast.Position = UDim2.new(0.5, -100, 0.1, 0)
    toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    toast.BackgroundTransparency = 0.2
    toast.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    toast.Text = msg
    toast.Font = Enum.Font.GothamBold
    toast.TextSize = 14
    toast.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = toast
    
    task.delay(2.5, function() 
        if toast and toast.Parent then toast:Destroy() end 
    end)
end

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 50, 0, 50)
floatBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
floatBtn.BackgroundColor3 = RED
floatBtn.Text = "L"
floatBtn.TextColor3 = BLACK
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 28
floatBtn.Active = true
floatBtn.Parent = screenGui
Instance.new("UICorner").Parent = floatBtn
Instance.new("UIStroke").Parent = floatBtn

local floatActiveInput = nil
local draggingFloat = false
local floatDragStart, floatStartPos

floatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if floatActiveInput ~= nil then return end
        floatActiveInput = input
        draggingFloat = false
        floatDragStart = input.Position
        floatStartPos = floatBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input ~= floatActiveInput then return end
    local delta = input.Position - floatDragStart
    if delta.Magnitude > 6 then draggingFloat = true end
    if draggingFloat then
        floatBtn.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
    end
end)

floatBtn.InputEnded:Connect(function(input)
    if input ~= floatActiveInput then return end
    floatActiveInput = nil
    if not draggingFloat then mainFrame.Visible = not mainFrame.Visible end
    draggingFloat = false
    floatDragStart = nil
end)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 280, 0, 380)
mainFrame.Position = UDim2.new(0.5, -140, 0.5, -190)
mainFrame.BackgroundColor3 = BLACK
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = false
mainFrame.Parent = screenGui
Instance.new("UICorner").Parent = mainFrame
Instance.new("UIStroke").Parent = mainFrame

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 30)
topBar.BackgroundColor3 = RED
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
Instance.new("UICorner").Parent = topBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "L HUB"
title.TextColor3 = BLACK
title.Font = Enum.Font.GothamBlack
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = BLACK
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 16
closeBtn.Parent = topBar

local TAB_W = 0.166
local tabDefs = {
    { name = "S1", offset = 0 }, { name = "S2", offset = 1 },
    { name = "Collect", offset = 2 }, { name = "Aimbot", offset = 3 },
    { name = "TP Kill", offset = 4 }, { name = "Config", offset = 5 }
}
local tabBtns = {}
for i, def in ipairs(tabDefs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(TAB_W, -2, 0, 24)
    btn.Position = UDim2.new(TAB_W * def.offset, 2, 0, 34)
    btn.BackgroundColor3 = i == 1 and RED or DARK_GRAY
    btn.Text = def.name
    btn.TextColor3 = i == 1 and BLACK or RED
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = mainFrame
    Instance.new("UICorner").Parent = btn
    tabBtns[i] = btn
end

local function makeTab()
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -10, 1, -65)
    f.Position = UDim2.new(0, 5, 0, 63)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = mainFrame
    return f
end

-- S1
local stage1Tab = makeTab()
stage1Tab.Visible = true
local tpS1Btn = Instance.new("TextButton")
tpS1Btn.Size = UDim2.new(1, 0, 0, 45)
tpS1Btn.Position = UDim2.new(0, 0, 0, 10)
tpS1Btn.BackgroundColor3 = RED
tpS1Btn.Text = "Auto Win (Stage 1)"
tpS1Btn.TextColor3 = BLACK
tpS1Btn.Font = Enum.Font.GothamBold
tpS1Btn.TextSize = 15
tpS1Btn.Parent = stage1Tab
Instance.new("UICorner").Parent = tpS1Btn

tpS1Btn.MouseButton1Click:Connect(function() 
    local finishPos = getFinishLine(1)
    if finishPos then safeTweenTeleport(finishPos) else safeTweenTeleport(STAGE1_WIN_POS) end
end)

-- S2
local stage2Tab = makeTab()
local function makeS2Btn(txt, yOff, isMain)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 35)
    b.Position = UDim2.new(0, 0, 0, yOff)
    b.BackgroundColor3 = isMain and RED or DARK_GRAY
    b.Text = txt
    b.TextColor3 = isMain and BLACK or RED
    b.Font = Enum.Font.GothamBold
    b.Parent = stage2Tab
    Instance.new("UICorner").Parent = b
    return b
end
local tpS2_1Btn = makeS2Btn("TP Checkpoint 1", 10, false)
local tpS2_2Btn = makeS2Btn("TP Checkpoint 2", 55, false)
local tpS2_3Btn = makeS2Btn("Auto Win (Stage 2)", 100, true)

tpS2_1Btn.MouseButton1Click:Connect(function() safeTweenTeleport(STAGE2_CP1_POS) end)
tpS2_2Btn.MouseButton1Click:Connect(function() safeTweenTeleport(STAGE2_CP2_POS) end)
tpS2_3Btn.MouseButton1Click:Connect(function() 
    local finishPos = getFinishLine(2)
    if finishPos then safeTweenTeleport(finishPos) else safeTweenTeleport(STAGE2_WIN_POS) end
end)

-- COLLECT
local collectTab = makeTab()
local toggleCollectBtn = Instance.new("TextButton")
toggleCollectBtn.Size = UDim2.new(1, 0, 0, 40)
toggleCollectBtn.Position = UDim2.new(0, 0, 0, 15)
toggleCollectBtn.BackgroundColor3 = isAutoCollectEnabled and RED or DARK_GRAY
toggleCollectBtn.Text = isAutoCollectEnabled and "Auto Collect: ON" or "Auto Collect: OFF"
toggleCollectBtn.TextColor3 = isAutoCollectEnabled and BLACK or RED
toggleCollectBtn.Font = Enum.Font.GothamBold
toggleCollectBtn.TextSize = 14
toggleCollectBtn.Parent = collectTab
Instance.new("UICorner").Parent = toggleCollectBtn
toggleCollectBtn.MouseButton1Click:Connect(function()
    isAutoCollectEnabled = not isAutoCollectEnabled
    toggleCollectBtn.Text = isAutoCollectEnabled and "Auto Collect: ON" or "Auto Collect: OFF"
    toggleCollectBtn.BackgroundColor3 = isAutoCollectEnabled and RED or DARK_GRAY
    toggleCollectBtn.TextColor3 = isAutoCollectEnabled and BLACK or RED
    saveConfig(true)
end)

-- AIMBOT
local aimbotTab = makeTab()
local function makeAimBtn(text, x, y, w, h, textSize)
    local b = Instance.new("TextButton")
    b.Size = w
    b.Position = UDim2.new(x.Scale, x.Offset, 0, y)
    b.BackgroundColor3 = DARK_GRAY
    b.Text = text
    b.TextColor3 = RED
    b.Font = Enum.Font.GothamBold
    b.TextSize = textSize
    b.Parent = aimbotTab
    Instance.new("UICorner").Parent = b
    return b
end
local function makeAimLabel(text, x, y, w, h, color)
    local l = Instance.new("TextLabel")
    l.Size = w
    l.Position = UDim2.new(x.Scale, x.Offset, 0, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.Parent = aimbotTab
    return l
end

local aimbotToggleBtn = makeAimBtn(aimbotEnabled and "Aimbot: ON" or "Aimbot: OFF", UDim.new(0, 0), 4, UDim2.new(1, 0, 0, 34), 34, 14)
aimbotToggleBtn.BackgroundColor3 = aimbotEnabled and RED or DARK_GRAY
aimbotToggleBtn.TextColor3 = aimbotEnabled and BLACK or RED

local fovToggleBtn = makeAimBtn(fovCircleOn and "FOV Circle: ON" or "FOV Circle: OFF", UDim.new(0, 0), 42, UDim2.new(1, 0, 0, 28), 28, 13)
fovToggleBtn.BackgroundColor3 = fovCircleOn and RED or DARK_GRAY
fovToggleBtn.TextColor3 = fovCircleOn and BLACK or RED

local fovMinus = makeAimBtn("-", UDim.new(0, 0), 76, UDim2.new(0.25, -3, 0, 26), 26, 15)
local fovLabel = makeAimLabel("FOV: " .. aimbotFov .. "px", UDim.new(0.25, 0), 76, UDim2.new(0.5, 0, 0, 26), 26)
local fovPlus = makeAimBtn("+", UDim.new(0.75, 3), 76, UDim2.new(0.25, -3, 0, 26), 26, 15)
local camHMinus = makeAimBtn("-", UDim.new(0, 0), 108, UDim2.new(0.25, -3, 0, 26), 26, 15)
local camHLabel = makeAimLabel("Height: " .. aimCamHeight, UDim.new(0.25, 0), 108, UDim2.new(0.5, 0, 0, 26), 26)
local camHPlus = makeAimBtn("+", UDim.new(0.75, 3), 108, UDim2.new(0.25, -3, 0, 26), 26, 15)
local targetLabel = makeAimLabel("Target: none", UDim.new(0, 0), 138, UDim2.new(1, 0, 0, 18), 18, Color3.fromRGB(255, 100, 100))

local turnCharBtn = makeAimBtn(aimbotTurnChar and "Turn Character: ON" or "Turn Character: OFF", UDim.new(0, 0), 160, UDim2.new(1, 0, 0, 26), 26, 12)
turnCharBtn.BackgroundColor3 = aimbotTurnChar and RED or DARK_GRAY
turnCharBtn.TextColor3 = aimbotTurnChar and BLACK or RED

local dashBtn = makeAimBtn(dashStrong and "Strong Dash: ON" or "Strong Dash: OFF", UDim.new(0, 0), 192, UDim2.new(1, 0, 0, 26), 26, 12)
dashBtn.BackgroundColor3 = dashStrong and RED or DARK_GRAY
dashBtn.TextColor3 = dashStrong and BLACK or RED

local latMinus = makeAimBtn("◄", UDim.new(0, 0), 224, UDim2.new(0.25, -3, 0, 26), 26, 14)
local latLabel = makeAimLabel(string.format("Side: %.2f°", aimYawOff), UDim.new(0.25, 0), 224, UDim2.new(0.5, 0, 0, 26), 26)
local latPlus = makeAimBtn("►", UDim.new(0.75, 3), 224, UDim2.new(0.25, -3, 0, 26), 26, 14)
local vertMinus = makeAimBtn("▼", UDim.new(0, 0), 254, UDim2.new(0.25, -3, 0, 26), 26, 14)
local vertLabel = makeAimLabel(string.format("Vertical: %.2f°", aimPitchOff), UDim.new(0.25, 0), 254, UDim2.new(0.5, 0, 0, 26), 26)
local vertPlus = makeAimBtn("▲", UDim.new(0.75, 3), 254, UDim2.new(0.25, -3, 0, 26), 26, 14)

latMinus.MouseButton1Click:Connect(function() aimYawOff = math.max(-10, aimYawOff - 0.25); latLabel.Text = string.format("Side: %.2f°", aimYawOff); saveConfig(true) end)
latPlus.MouseButton1Click:Connect(function() aimYawOff = math.min(10, aimYawOff + 0.25); latLabel.Text = string.format("Side: %.2f°", aimYawOff); saveConfig(true) end)
vertMinus.MouseButton1Click:Connect(function() aimPitchOff = math.max(-10, aimPitchOff - 0.25); vertLabel.Text = string.format("Vertical: %.2f°", aimPitchOff); saveConfig(true) end)
vertPlus.MouseButton1Click:Connect(function() aimPitchOff = math.min(10, aimPitchOff + 0.25); vertLabel.Text = string.format("Vertical: %.2f°", aimPitchOff); saveConfig(true) end)

turnCharBtn.MouseButton1Click:Connect(function()
    aimbotTurnChar = not aimbotTurnChar
    turnCharBtn.Text = aimbotTurnChar and "Turn Character: ON" or "Turn Character: OFF"
    turnCharBtn.BackgroundColor3 = aimbotTurnChar and RED or DARK_GRAY
    turnCharBtn.TextColor3 = aimbotTurnChar and BLACK or RED
    saveConfig(true)
end)

dashBtn.MouseButton1Click:Connect(function()
    dashStrong = not dashStrong
    dashBtn.Text = dashStrong and "Strong Dash: ON" or "Strong Dash: OFF"
    dashBtn.BackgroundColor3 = dashStrong and RED or DARK_GRAY
    dashBtn.TextColor3 = dashStrong and BLACK or RED
    saveConfig(true)
end)

aimbotToggleBtn.MouseButton1Click:Connect(function()
    aimbotEnabled = not aimbotEnabled
    aimbotToggleBtn.Text = aimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
    aimbotToggleBtn.BackgroundColor3 = aimbotEnabled and RED or DARK_GRAY
    aimbotToggleBtn.TextColor3 = aimbotEnabled and BLACK or RED
    if not aimbotEnabled then
        local cam = Workspace.CurrentCamera
        if cam then cam.CameraType = Enum.CameraType.Custom end
        aimbotHighlight.Enabled = false
    end
    saveConfig(true)
end)

fovToggleBtn.MouseButton1Click:Connect(function()
    fovCircleOn = not fovCircleOn
    fovCircle.Visible = fovCircleOn
    fovToggleBtn.Text = fovCircleOn and "FOV Circle: ON" or "FOV Circle: OFF"
    fovToggleBtn.BackgroundColor3 = fovCircleOn and RED or DARK_GRAY
    fovToggleBtn.TextColor3 = fovCircleOn and BLACK or RED
    saveConfig(true)
end)

fovMinus.MouseButton1Click:Connect(function() aimbotFov = math.max(30, aimbotFov - 15); fovCircle.Radius = aimbotFov; fovLabel.Text = "FOV: " .. aimbotFov .. "px"; saveConfig(true) end)
fovPlus.MouseButton1Click:Connect(function() aimbotFov = math.min(500, aimbotFov + 15); fovCircle.Radius = aimbotFov; fovLabel.Text = "FOV: " .. aimbotFov .. "px"; saveConfig(true) end)
camHMinus.MouseButton1Click:Connect(function() aimCamHeight = math.max(-6, aimCamHeight - 2); camHLabel.Text = "Height: " .. aimCamHeight; saveConfig(true) end)
camHPlus.MouseButton1Click:Connect(function() aimCamHeight = math.min(30, aimCamHeight + 2); camHLabel.Text = "Height: " .. aimCamHeight; saveConfig(true) end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if aimbotTarget and aimbotTarget.Parent then
            targetLabel.Text = "Target: " .. aimbotTarget.Name
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character == aimbotTarget then targetLabel.Text = "Target: " .. plr.DisplayName; break end
            end
        else
            targetLabel.Text = "Target: none"
        end
    end
end)

-- TP KILL
local tpKillTab = makeTab()
local selectedPlayer = nil
local isTpKilling = false
local originalPosition = nil
local tpPartsOffset = {}

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, 0, 0, 30)
searchBox.Position = UDim2.new(0, 0, 0, 0)
searchBox.BackgroundColor3 = DARK_GRAY
searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.PlaceholderText = "Search player..."
searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 14
searchBox.Text = ""
searchBox.Parent = tpKillTab
Instance.new("UICorner").Parent = searchBox

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -80)
scrollFrame.Position = UDim2.new(0, 0, 0, 35)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = RED
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = tpKillTab

local listLayout = Instance.new("UIListLayout")
listLayout.Parent = scrollFrame
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end)

local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(1, 0, 0, 35)
killBtn.Position = UDim2.new(0, 0, 1, -35)
killBtn.BackgroundColor3 = DARK_GRAY
killBtn.Text = "Kill Player (Fake Cam)"
killBtn.TextColor3 = RED
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 14
killBtn.Parent = tpKillTab
Instance.new("UICorner").Parent = killBtn

local function updatePlayerList()
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for i, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local frame = Instance.new("Frame")
            frame.Name = plr.Name -- Username
            frame.Size = UDim2.new(1, -5, 0, 40)
            frame.BackgroundColor3 = DARK_GRAY
            frame.BorderSizePixel = 0
            frame.Parent = scrollFrame
            Instance.new("UICorner").Parent = frame
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0, 30, 0, 30)
            img.Position = UDim2.new(0, 5, 0.5, -15)
            img.BackgroundColor3 = BLACK
            img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=48&h=48"
            img.Parent = frame
            Instance.new("UICorner").Parent = img
            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, -45, 1, 0)
            txt.Position = UDim2.new(0, 40, 0, 0)
            txt.BackgroundTransparency = 1
            txt.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
            txt.TextColor3 = Color3.fromRGB(255, 255, 255)
            txt.TextXAlignment = Enum.TextXAlignment.Left
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = 12
            txt.Parent = frame
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundTransparency = 1
            btn.Text = ""
            btn.Parent = frame
            btn.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                for _, other in ipairs(scrollFrame:GetChildren()) do
                    if other:IsA("Frame") then other.BackgroundColor3 = DARK_GRAY end
                end
                frame.BackgroundColor3 = RED
            end)
        end
    end
end

updatePlayerList()
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(function(plr)
    if selectedPlayer == plr then selectedPlayer = nil end
    task.defer(updatePlayerList)
end)

-- Search logic: detects both DisplayName and Username (@)
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = string.lower(searchBox.Text)
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
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
end)

local function stopTpKill()
    isTpKilling = false
    if _G.LHub.TpKillConn then _G.LHub.TpKillConn:Disconnect() _G.LHub.TpKillConn = nil end
    
    if _G.LHub.BypassLoop then
        pcall(function() task.cancel(_G.LHub.BypassLoop) end)
        _G.LHub.BypassLoop = nil
    end
    
    killBtn.Text = "Kill Player (Fake Cam)"
    killBtn.BackgroundColor3 = DARK_GRAY
    killBtn.TextColor3 = RED
    
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local cam = Workspace.CurrentCamera
        if cam and hum then cam.CameraSubject = hum end
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
                part.CanQuery = true
                part.CanTouch = true
                part.CanCollide = true
            end
        end
    end

    if _G.LHub.FakeCamera then
        _G.LHub.FakeCamera:Destroy()
        _G.LHub.FakeCamera = nil
    end

    if originalPosition then
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = true
            local tween = TweenService:Create(hrp, TweenInfo.new(0.2, Enum.EasingStyle.Linear), { CFrame = originalPosition })
            tween:Play()
            tween.Completed:Wait()
            hrp.Anchored = false
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        originalPosition = nil
    end
end

killBtn.MouseButton1Click:Connect(function()
    if not selectedPlayer then return end
    if not isTpKilling then
        isTpKilling = true
        
        if _G.LHub.BypassLoop then task.cancel(_G.LHub.BypassLoop) end
        _G.LHub.BypassLoop = task.spawn(function()
            while isTpKilling do
                pcall(nukeTeleportDetectorsOnly)
                task.wait(1)
            end
        end)

        local char = LocalPlayer.Character
        local myHRP = char and char:FindFirstChild("HumanoidRootPart")
        if myHRP then 
            originalPosition = myHRP.CFrame 
            tpPartsOffset = {}
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if part ~= myHRP then
                        tpPartsOffset[part] = myHRP.CFrame:ToObjectSpace(part.CFrame)
                    end
                    part.CanQuery = false
                    part.CanTouch = false
                    part.CanCollide = false
                    part.Transparency = 1
                end
            end
        end
        
        if _G.LHub.FakeCamera then _G.LHub.FakeCamera:Destroy() end
        local fakeCam = Instance.new("Part")
        fakeCam.Name = "FakeCamera"
        fakeCam.Size = Vector3.new(0.1, 0.1, 0.1)
        fakeCam.Transparency = 1
        fakeCam.CanCollide = false
        fakeCam.CanQuery = false
        fakeCam.CanTouch = false
        fakeCam.Anchored = true
        fakeCam.Parent = Workspace
        _G.LHub.FakeCamera = fakeCam
        
        local cam = Workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = fakeCam
        end

        killBtn.Text = "Stopping... (Click to turn off)"
        killBtn.BackgroundColor3 = RED
        killBtn.TextColor3 = BLACK
        
        if _G.LHub.TpKillConn then _G.LHub.TpKillConn:Disconnect() end
        _G.LHub.TpKillConn = RunService.Heartbeat:Connect(function()
            if not isTpKilling then return end
            if not selectedPlayer or not selectedPlayer.Character then stopTpKill(); return end
            local targetHum = selectedPlayer.Character:FindFirstChildOfClass("Humanoid")
            if not targetHum or targetHum.Health <= 0 then stopTpKill(); return end
            
            local targetHRP = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
            local myHRP2 = char and char:FindFirstChild("HumanoidRootPart")
            
            if targetHRP and myHRP2 and _G.LHub.FakeCamera then
                if myHRP2.Anchored then myHRP2.Anchored = false end
                
                myHRP2.CFrame = targetHRP.CFrame * CFrame.new(0, 1.5, -1.5)
                _G.LHub.FakeCamera.CFrame = targetHRP.CFrame * CFrame.new(0, 4, 0)
                
                for part, offset in pairs(tpPartsOffset) do
                    if part.Parent then
                        local undergroundPos = myHRP2.CFrame * offset
                        part.CFrame = CFrame.new(undergroundPos.Position) * CFrame.Angles(math.rad(90), 0, 0) - Vector3.new(0, 10, 0)
                    end
                end
                
                myHRP2.AssemblyLinearVelocity = Vector3.zero
                myHRP2.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    else
        stopTpKill()
    end
end)

-- CONFIG / SAVE TAB
local configTab = makeTab()

local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, 0, 0, 45)
saveBtn.Position = UDim2.new(0, 0, 0, 15)
saveBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
saveBtn.Text = "Save Settings"
saveBtn.TextColor3 = BLACK
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 15
saveBtn.Parent = configTab
Instance.new("UICorner").Parent = saveBtn

saveBtn.MouseButton1Click:Connect(function()
    saveConfig(false)
    showToast("Saved Successfully!", Color3.fromRGB(50, 200, 50))
end)

local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(1, 0, 0, 45)
resetBtn.Position = UDim2.new(0, 0, 0, 70)
resetBtn.BackgroundColor3 = RED
resetBtn.Text = "Reset to Default"
resetBtn.TextColor3 = BLACK
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 15
resetBtn.Parent = configTab
Instance.new("UICorner").Parent = resetBtn

resetBtn.MouseButton1Click:Connect(function()
    if delfile then pcall(function() delfile(CONFIG_FILE) end) end
    
    aimbotEnabled = false
    aimbotFov = 120
    aimbotTurnChar = true
    dashStrong = true
    aimCamHeight = 8
    aimYawOff = 0
    aimPitchOff = 0
    isAutoCollectEnabled = false
    fovCircleOn = false
    
    fovCircle.Visible = false
    fovCircle.Radius = 120
    aimbotFloatBtn.Position = UDim2.new(0.85, 0, 0.55, 0)
    
    aimbotToggleBtn.Text = "Aimbot: OFF"
    aimbotToggleBtn.BackgroundColor3 = DARK_GRAY
    aimbotToggleBtn.TextColor3 = RED
    
    fovToggleBtn.Text = "FOV Circle: OFF"
    fovToggleBtn.BackgroundColor3 = DARK_GRAY
    fovToggleBtn.TextColor3 = RED
    
    fovLabel.Text = "FOV: 120px"
    camHLabel.Text = "Height: 8"
    latLabel.Text = string.format("Side: %.2f°", 0)
    vertLabel.Text = string.format("Vertical: %.2f°", 0)
    
    turnCharBtn.Text = "Turn Character: ON"
    turnCharBtn.BackgroundColor3 = RED
    turnCharBtn.TextColor3 = BLACK
    
    dashBtn.Text = "Strong Dash: ON"
    dashBtn.BackgroundColor3 = RED
    dashBtn.TextColor3 = BLACK
    
    toggleCollectBtn.Text = "Auto Collect: OFF"
    toggleCollectBtn.BackgroundColor3 = DARK_GRAY
    toggleCollectBtn.TextColor3 = RED
    
    showToast("Settings Reset!", Color3.fromRGB(255, 100, 100))
end)

-- ==========================================
-- 5. TAB LOGIC & FINAL UI
-- ==========================================
local tabs = {stage1Tab, stage2Tab, collectTab, aimbotTab, tpKillTab, configTab}
local function resetTabs()
    for i, tab in ipairs(tabs) do
        tab.Visible = false
        tabBtns[i].BackgroundColor3 = DARK_GRAY
        tabBtns[i].TextColor3 = RED
    end
end

local function selectTab(idx)
    resetTabs()
    tabs[idx].Visible = true
    tabBtns[idx].BackgroundColor3 = RED
    tabBtns[idx].TextColor3 = BLACK
end

selectTab(1)
for i, btn in ipairs(tabBtns) do
    btn.MouseButton1Click:Connect(function() selectTab(i) end)
end

_G.LHub.CollectLoop = task.spawn(function()
    while _G.LHub.Gui.Parent do
        if isAutoCollectEnabled and not isCollecting then executeCollect() end
        task.wait(1)
    end
end)

-- Aimbot Floating Button
aimbotFloatBtn = Instance.new("Frame")
aimbotFloatBtn.Size = UDim2.new(0, 72, 0, 72)
aimbotFloatBtn.Position = UDim2.new(config.floatBtnPosXScale, config.floatBtnPosXOffset, config.floatBtnPosYScale, config.floatBtnPosYOffset)
aimbotFloatBtn.BackgroundColor3 = aimbotEnabled and Color3.fromRGB(40, 10, 10) or Color3.fromRGB(18, 18, 18)
aimbotFloatBtn.BorderSizePixel = 0
aimbotFloatBtn.Active = true
aimbotFloatBtn.Parent = screenGui
Instance.new("UICorner", aimbotFloatBtn).CornerRadius = UDim.new(1, 0)

local aimbotRing = Instance.new("UIStroke", aimbotFloatBtn)
aimbotRing.Color = aimbotEnabled and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(90, 90, 90)
aimbotRing.Thickness = 3

local aimbotIcon = Instance.new("TextLabel", aimbotFloatBtn)
aimbotIcon.Size = UDim2.new(1, 0, 0.55, 0)
aimbotIcon.Position = UDim2.new(0, 0, 0.04, 0)
aimbotIcon.BackgroundTransparency = 1
aimbotIcon.Text = "⊕"
aimbotIcon.TextColor3 = aimbotEnabled and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(220, 220, 220)
aimbotIcon.Font = Enum.Font.GothamBlack
aimbotIcon.TextSize = 26
aimbotIcon.TextScaled = false

local aimbotLabel = Instance.new("TextLabel", aimbotFloatBtn)
aimbotLabel.Size = UDim2.new(1, 0, 0.35, 0)
aimbotLabel.Position = UDim2.new(0, 0, 0.63, 0)
aimbotLabel.BackgroundTransparency = 1
aimbotLabel.Text = "AIM"
aimbotLabel.TextColor3 = aimbotEnabled and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(180, 180, 180)
aimbotLabel.Font = Enum.Font.GothamBlack
aimbotLabel.TextSize = 11

task.spawn(function()
    local t = 0
    while true do
        t += 0.05
        local s = 1 + math.sin(t) * (aimbotEnabled and 0.07 or 0.03)
        local base = 72
        aimbotFloatBtn.Size = UDim2.new(0, math.round(base * s), 0, math.round(base * s))
        task.wait(0.03)
    end
end)

local aimActiveInput = nil
local aimDragging = false
local aimDragStart, aimStartPos

aimbotFloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if aimActiveInput ~= nil then return end
        aimActiveInput = input
        aimDragging = false
        aimDragStart = input.Position
        aimStartPos = aimbotFloatBtn.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input ~= aimActiveInput then return end
    local d = input.Position - aimDragStart
    if d.Magnitude > 6 then aimDragging = true end
    if aimDragging then
        aimbotFloatBtn.Position = UDim2.new(
            aimStartPos.X.Scale, aimStartPos.X.Offset + d.X,
            aimStartPos.Y.Scale, aimStartPos.Y.Offset + d.Y
        )
    end
end)

aimbotFloatBtn.InputEnded:Connect(function(input)
    if input ~= aimActiveInput then return end
    aimActiveInput = nil
    if not aimDragging then
        aimbotEnabled = not aimbotEnabled
        aimbotToggleBtn.Text = aimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
        aimbotToggleBtn.BackgroundColor3 = aimbotEnabled and RED or DARK_GRAY
        aimbotToggleBtn.TextColor3 = aimbotEnabled and BLACK or RED
        if not aimbotEnabled then
            local cam = Workspace.CurrentCamera
            if cam then cam.CameraType = Enum.CameraType.Custom end
            aimbotHighlight.Enabled = false
        end
        aimbotRing.Color = aimbotEnabled and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(90, 90, 90)
        aimbotIcon.TextColor3 = aimbotEnabled and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(220, 220, 220)
        aimbotLabel.TextColor3 = aimbotEnabled and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(180, 180, 180)
        aimbotFloatBtn.BackgroundColor3 = aimbotEnabled and Color3.fromRGB(40, 10, 10) or Color3.fromRGB(18, 18, 18)
        saveConfig(true)
    else
        saveConfig(true)
    end
    aimDragging = false
    aimDragStart = nil
end)

aimbotToggleBtn.MouseButton1Click:Connect(function()
    aimbotRing.Color = aimbotEnabled and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(90, 90, 90)
    aimbotIcon.TextColor3 = aimbotEnabled and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(220, 220, 220)
    aimbotLabel.TextColor3 = aimbotEnabled and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(180, 180, 180)
    aimbotFloatBtn.BackgroundColor3 = aimbotEnabled and Color3.fromRGB(40, 10, 10) or Color3.fromRGB(18, 18, 18)
    saveConfig(true)
end)

floatBtn.MouseButton1Click:Connect(function() mainFrame.Visible = not mainFrame.Visible end)
closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end)

local dragging, dragInput, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = mainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
