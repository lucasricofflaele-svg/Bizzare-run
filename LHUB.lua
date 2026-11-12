-- language: Lua, file: LHub_v75.lua, target: Roblox (Delta Executor)
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
local CONFIG_FILE = "LHub_Config_v75.json"

local function Logger(module, msg)
    warn(string.format("[L HUB v75] [%s] %s", module, msg))
end

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

local function ValidateConfig(data)
    if type(data) ~= "table" then return end
    for k, defaultVal in pairs(DefaultConfig) do
        local val = data[k]
        if val ~= nil and type(val) == type(defaultVal) then
            if type(val) == "number" then
                if k == "aimbotFov" then Config[k] = math.clamp(val, 30, 500)
                elseif k == "aimCamHeight" then Config[k] = math.clamp(val, -6, 30)
                elseif k == "aimYawOff" or k == "aimPitchOff" then Config[k] = math.clamp(val, -10, 10)
                elseif k == "tpKillHeight" then Config[k] = math.clamp(val, -20, 20)
                else Config[k] = val end
            else
                Config[k] = val
            end
        end
    end
end

local function LoadConfig()
    if Environment.HasIsFile and Environment.HasReadFile and isfile(CONFIG_FILE) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if success then ValidateConfig(data) end
    end
end
LoadConfig()

local function SaveConfig(silent)
    if Environment.HasWriteFile then
        local data = {}
        for k, v in pairs(Config) do data[k] = v end
        local ok, err = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
        if not ok and not silent then Logger("Config", "Falha ao salvar: " .. tostring(err)) end
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
function TaskManager:Clear()
    for _, t in pairs(self.Tasks) do
        if type(t) == "thread" and coroutine.status(t) ~= "dead" then pcall(task.cancel, t) end
    end
    self.Tasks = {}
end

local ConnectionManager = { Conns = {} }
function ConnectionManager:Add(conn)
    table.insert(self.Conns, conn)
    return conn
end
function ConnectionManager:Clear()
    for _, c in pairs(self.Conns) do pcall(function() c:Disconnect() end) end
    self.Conns = {}
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

local STAGE2_CP1_POS = Vector3.new(-2805.450, -160.060, -1304.949)
local STAGE2_CP2_POS = Vector3.new(1667.592, -154.669, -1671.076)

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
    
    pcall(function()
        local ps = LocalPlayer:FindFirstChild("PlayerScripts")
        if ps and ps:FindFirstChild("VRCameraTeleportDetector") then ps.VRCameraTeleportDetector:Destroy() end
    end)
end

-- ==========================================
-- 4. CORE MECHANICS (Teleporte Instantâneo)
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
    
    bypassAntiCheat()
    setNoclip(char, true)
    
    local targetCF = CFrame.new(targetPos)
    local startCF = hrp.CFrame
    
    hrp.Anchored = true
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    pcall(function()
        for i = 1, 10 do
            if not hrp.Parent then break end
            hrp.CFrame = startCF:Lerp(targetCF, i / 10)
            task.wait(0.01)
        end
        hrp.CFrame = targetCF
    end)
    
    hrp.Anchored = false
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    setNoclip(char, false)
    task.wait(0.1)
end

local function fastTeleport(targetPos, checkActive)
    local char = LocalPlayer.Character
    if not char or not char.Parent then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end
    
    bypassAntiCheat()
    setNoclip(char, true)
    
    local startCF = hrp.CFrame
    local targetCF = CFrame.new(targetPos)
    
    local dist = (targetPos - hrp.Position).Magnitude
    local steps = math.clamp(math.floor(dist / 30), 3, 15) 
    
    for i = 1, steps do
        if not checkActive() then
            setNoclip(char, false)
            return false
        end
        hrp.CFrame = startCF:Lerp(targetCF, i / steps)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait() 
    end
    
    hrp.CFrame = targetCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
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
-- 6. AIMBOT SYSTEM
-- ==========================================
local aimbotTarget = nil
local aimbotHighlight = Instance.new("Highlight")
aimbotHighlight.FillColor = Color3.fromRGB(212, 175, 55)
aimbotHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
aimbotHighlight.FillTransparency = 0.4
aimbotHighlight.OutlineTransparency = 0
aimbotHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
aimbotHighlight.Enabled = false
aimbotHighlight.Parent = CoreGui
_G.LHub.Highlight = aimbotHighlight

local fovCircle = nil
if Environment.HasDrawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Visible = Config.fovCircleOn
    fovCircle.Radius = Config.aimbotFov
    fovCircle.Color = Color3.fromRGB(212, 175, 55)
    fovCircle.Thickness = 1.5
    fovCircle.Filled = false
    fovCircle.Transparency = 1
    _G.LHub.FovCircle = fovCircle
end

local function isDamageable(model)
    if model == LocalPlayer.Character then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health > 0 end
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

local entryCache = setmetatable({}, { __mode = "k" })
local function getEntry(model)
    local e = entryCache[model]
    if e and e.model and e.model.Parent and e.part and e.part.Parent and (not e.hum or (e.hum.Parent and e.hum.Health > 0)) then return e end
    local p, o = pickAimPart(model)
    if not p then entryCache[model] = nil; return nil end
    e = { model = model, hum = model:FindFirstChildOfClass("Humanoid"), part = p, off = o }
    entryCache[model] = e
    return e
end

local function entryAlive(e)
    if not e.model or not e.model.Parent then return false end
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
    for _, d in ipairs(Workspace:GetChildren()) do
        if d:IsA("Model") and d ~= myChar and not Players:GetPlayerFromCharacter(d) then
            if not (myChar and d:IsDescendantOf(myChar)) and d:FindFirstChildOfClass("Humanoid") then
                list[#list + 1] = d
            end
        end
    end
    npcCache = list
end

TaskManager:Add(task.spawn(function()
    while true do
        task.wait(0.5)
        if Config.aimbotEnabled and os.clock() - lastScan >= 2 then
            lastScan = os.clock()
            pcall(refreshNPCs)
        end
    end
end))

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
    local function try(m)
        if m == char or not m.Parent then return end
        local e = getEntry(m)
        if not e or not entryAlive(e) then return end
        local p = entryPoint(e)
        if not p then return end
        local sp, os = cam:WorldToViewportPoint(p)
        if not os then return end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d <= Config.aimbotFov and (not bestD or d < bestD) then best, bestD = e, d end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then try(pl.Character) end
    end
    for _, m in ipairs(npcCache) do try(m) end
    if best then aimbotLocked = best; aimbotTarget = best.model end
end

local function aimbotStep(dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local c = Vector2.new(vp.X / 2, vp.Y / 2)
    if c ~= lastCenter and fovCircle then fovCircle.Position = c; lastCenter = c end
    
    if not Config.aimbotEnabled then
        if aimbotLocked then releaseLock() end
        return
    end
    
    local ch = LocalPlayer.Character
    if not ch or not ch.Parent then releaseLock(); return end
    local h = ch:FindFirstChild("HumanoidRootPart")
    local hu = ch:FindFirstChildOfClass("Humanoid")
    if not h or not hu or hu.Health <= 0 then releaseLock(); return end
    if aimbotLocked and not entryAlive(aimbotLocked) then releaseLock() end
    
    if not aimbotLocked then
        acquireTimer += dt
        if acquireTimer >= 0.05 then acquireTimer = 0; acquire(cam, c, ch) end
        if not aimbotLocked then return end
    end
    
    local ap = entryPoint(aimbotLocked)
    if not ap then releaseLock(); return end
    local ok, tv = pcall(function() return aimbotLocked.part.AssemblyLinearVelocity end)
    if ok and tv then ap = ap + tv * math.min(dt or 0.016, 0.05) end
    if aimbotHighlight.Adornee ~= aimbotLocked.model then aimbotHighlight.Adornee = aimbotLocked.model end
    aimbotHighlight.Enabled = true
    
    local fo = cam.Focus.Position
    local di = (cam.CFrame.Position - fo).Magnitude
    local ta = ap - fo
    if ta.Magnitude > 0.5 then
        local dir = ta.Unit
        local hh = Config.aimCamHeight
        if di < 2 then hh = 0 end
        local np = fo - dir * di + Vector3.new(0, hh, 0)
        if (ap - np).Magnitude > 0.1 then
            local cf = CFrame.lookAt(np, ap)
            if Config.aimYawOff ~= 0 or Config.aimPitchOff ~= 0 then cf = cf * CFrame.Angles(math.rad(Config.aimPitchOff), math.rad(-Config.aimYawOff), 0) end
            cam.CFrame = cf
        end
    end
    
    if Config.aimbotTurnChar then
        local fl = Vector3.new(ap.X - h.Position.X, 0, ap.Z - h.Position.Z)
        if fl.Magnitude > 0.1 and h.CFrame.LookVector:Dot(fl.Unit) < 0.9999 then
            h.CFrame = CFrame.lookAt(h.Position, h.Position + fl)
        end
    end
end

pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
RunService:BindToRenderStep("LHubAimbot", Enum.RenderPriority.Last.Value, function(dt) pcall(aimbotStep, dt) end)

TaskManager:Add(task.spawn(function()
    while true do
        task.wait(0.5)
        local c = LocalPlayer.Character
        if c and c.Parent then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                if Config.dashStrong and h.WalkSpeed == 16 then h.WalkSpeed = 50
                elseif not Config.dashStrong and h.WalkSpeed == 50 then h.WalkSpeed = 16 end
            end
        end
    end
end))

-- ==========================================
-- 7. AUTO COLLECT & AUTO RACE UNIVERSAL
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
            
            local success = fastTeleport(standPos, function() return Config.autoCollect and t.model.Parent ~= nil end)
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

local autoRaceActive = false
local origWalk, origJump
local raceToggle

local function stopAutoRace()
    if not autoRaceActive then return end
    autoRaceActive = false
    
    local char = LocalPlayer.Character
    if char then
        setNoclip(char, false) -- Apenas remove o noclip
    end
    if raceToggle then raceToggle.setState(false) end
end

local function startAutoRace()
    if autoRaceActive then return end
    autoRaceActive = true
    
    bypassAntiCheat() 
    
    TaskManager:Add(task.spawn(function()
        while autoRaceActive do
            -- CHECAGEM DE FIM DE PARTIDA (RaceEnded e Rig.Finished)
            local raceEndedGui = PlayerGui:FindFirstChild("RaceEnded")
            local raceOverGui = PlayerGui:FindFirstChild("RaceOver")
            local rigsFolder = Workspace:FindFirstChild("Rigs")
            local myRig = rigsFolder and rigsFolder:FindFirstChild(LocalPlayer.Name)
            
            local isFinished = false
            if myRig and myRig:GetAttribute("Finished") == true then
                isFinished = true
            end
            
            if (raceEndedGui and raceEndedGui:IsA("ScreenGui")) or (raceOverGui and raceOverGui:IsA("ScreenGui")) or isFinished then
                stopAutoRace()
                break
            end

            local char = LocalPlayer.Character
            if not char or not char.Parent then task.wait(1); continue end
            local hr
