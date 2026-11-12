-- language: Lua, file: LHub_v72.lua, target: Roblox (Delta Executor)
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
local CONFIG_FILE = "LHub_Config_v72.json"

local function Logger(module, msg)
    warn(string.format("[L HUB v72] [%s] %s", module, msg))
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

-- MATA OS SCRIPTS LOCAIS DE DETECÇÃO
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

-- TELEPORTE RÁPIDO: Atravessa tudo em pequenos pulos por frame
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
    
    -- Divide a distância em pequenos passos para enganar o anti-cheat (parece velocidade alta)
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
        task.wait() -- 1 frame por passo
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
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then 
            hum.WalkSpeed = origWalk or 16
            hum.JumpPower = origJump or 50
            hum.PlatformStand = false
            hum.AutoRotate = true 
        end
        if hrp then 
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero 
        end
        setNoclip(char, false)
    end
    if raceToggle then raceToggle.setState(false) end
end

local function startAutoRace()
    if autoRaceActive then return end
    autoRaceActive = true
    
    bypassAntiCheat() 
    
    TaskManager:Add(task.spawn(function()
        while autoRaceActive do
            local char = LocalPlayer.Character
            if not char or not char.Parent then task.wait(1); continue end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then task.wait(1); continue end
            
            if not origWalk then origWalk = hum.WalkSpeed; origJump = hum.JumpPower end
            
            hum.WalkSpeed = 0
            hum.PlatformStand = true
            hum.AutoRotate = false
            
            -- Pega todos os itens logo de início
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
            local mapEvents = Workspace:FindFirstChild("MapEvents")
            local arrowsFolder = mapEvents and mapEvents:FindFirstChild("Arrows") and mapEvents.Arrows:FindFirstChild("Spawned")
            if arrowsFolder then
                for _, arrow in ipairs(arrowsFolder:GetChildren()) do
                    local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt and prompt.Parent then
                        table.insert(items, {model = arrow, prompt = prompt, pos = arrow:IsA("BasePart") and arrow.Position or arrow:GetPivot().Position})
                    end
                end
            end

            -- 1. PASSAR PELOS CHECKPOINTS (Voando alto e coletando)
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
                    if not autoRaceActive then break end
                    
                    -- Sobe MUITO alto (Y + 150) para ir pela reta sem esbarrar
                    local highPos = cp.Position + Vector3.new(0, 150, 0)
                    fastTeleport(highPos, function() return autoRaceActive end)
                    
                    -- Desce no checkpoint
                    local cpPos = cp.Position + Vector3.new(0, 3, 0)
                    fastTeleport(cpPos, function() return autoRaceActive end)
                    task.wait(0.2)
                    
                    -- Verifica se tem item perto do checkpoint (Raio de 250 studs)
                    local nearbyItems = {}
                    for i = #items, 1, -1 do
                        local item = items[i]
                        if item.model.Parent then
                            if (item.pos - cp.Position).Magnitude < 250 then
                                table.insert(nearbyItems, item)
                                table.remove(items, i)
                            end
                        end
                    end
                    
                    -- Coleta os itens próximos
                    for _, t in ipairs(nearbyItems) do
                        if not autoRaceActive then break end
                        if t.model.Parent then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterDescendantsInstances = { char, t.model }
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            local rayResult = Workspace:Raycast(t.pos + Vector3.new(0, 50, 0), Vector3.new(0, -150, 0), rayParams)
                            local standPos = Vector3.new(t.pos.X, (rayResult and rayResult.Position.Y or t.pos.Y) + 3, t.pos.Z)
                            
                            fastTeleport(standPos, function() return autoRaceActive end)
                            holdPromptInfinitely(t, function() return autoRaceActive end)
                        end
                    end
                end
            end
            
            -- 2. PEGAR ITENS RESTANTES (que não estavam perto de nenhum checkpoint)
            if autoRaceActive and #items > 0 then
                table.sort(items, function(a, b) return (a.pos - hrp.Position).Magnitude < (b.pos - hrp.Position).Magnitude end)
                for _, t in ipairs(items) do
                    if not autoRaceActive then break end
                    if t.model.Parent ~= nil then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = { char, t.model }
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local rayResult = Workspace:Raycast(t.pos + Vector3.new(0, 50, 0), Vector3.new(0, -150, 0), rayParams)
                        local standPos = Vector3.new(t.pos.X, (rayResult and rayResult.Position.Y or t.pos.Y) + 3, t.pos.Z)
                        
                        fastTeleport(standPos, function() return autoRaceActive and t.model.Parent ~= nil end)
                        holdPromptInfinitely(t, function() return autoRaceActive end)
                    end
                end
            end
            
            -- 3. IR PARA A LINHA DE CHEGADA
            if autoRaceActive then
                local f = getFinishLine()
                if f then 
                    fastTeleport(f, function() return autoRaceActive end) 
                end
                task.wait(3) 
            end
        end
    end))
end

-- ==========================================
-- 8. USER INTERFACE (LUXURY)
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

local function showToast(msg, color)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 200, 0, 35)
    toast.Position = UDim2.new(1, 10, 0.1, 0)
    toast.BackgroundColor3 = ELEMENT_BG
    toast.BackgroundTransparency = 0.1
    toast.Parent = screenGui
    local c = Instance.new("UICorner", toast); c.CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", toast); s.Color = color or GOLD; s.Thickness = 1
    local lbl = Instance.new("TextLabel", toast)
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = msg; lbl.TextColor3 = color or GOLD; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
    TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(1, -210, 0.1, 0) }):Play()
    task.delay(2.5, function()
        if toast and toast.Parent then
            local tOut = TweenService:Create(toast, TweenInfo.new(0.3), { Position = UDim2.new(1, 10, 0.1, 0) })
            tOut:Play(); tOut.Completed:Wait(); toast:Destroy()
        end
    end)
end

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
title.Text = "L HUB | NEXUS v72"
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
        setState(not state, true)
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
raceToggle = createToggle(SectRace, "Enable Auto Race (Anti-Cheat)", false, function(state) if state then startAutoRace() else stopAutoRace() end end)

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

Logger("System", "L HUB v72 Inicializado com sucesso.")
