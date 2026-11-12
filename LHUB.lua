-- language: Lua, file: LHub_v84.lua, target: Roblox (Delta Executor)
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
local CONFIG_FILE = "LHub_Config_v84.json"

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
-- 3. MAP & UTILITIES
-- ==========================================
local STAGE1_WIN_POS = Vector3.new(3269.18408, -239.665649, 2052.78711)
local STAGE2_WIN_POS = Vector3.new(8541.87793, -166.666595, -1274.94568)

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
-- 6. AUTO COLLECT
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
-- 7. AIMBOT SYSTEM
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
-- 8. PREMIUM USER INTERFACE (DELTA STYLE)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LHub_Premium"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999999
pcall(function() screenGui.Parent = CoreGui end)
if not screenGui.Parent then screenGui.Parent = PlayerGui end
_G.LHub.Gui = screenGui

-- Cores baseadas na imagem do Delta Hub
local BG_COLOR = Color3.fromRGB(15, 12, 22) -- Fundo super escuro
local SIDEBAR_COLOR = Color3.fromRGB(20, 16, 30) -- Fundo da barra lateral
local ELEMENT_BG = Color3.fromRGB(28, 22, 40) -- Fundo dos botões
local NEON_PURPLE = Color3.fromRGB(160, 80, 255) -- Roxo Neon principal
local NEON_BRIGHT = Color3.fromRGB(190, 120, 255) -- Roxo claro
local TEXT_WHITE = Color3.fromRGB(255, 255, 255)
local TEXT_GRAY = Color3.fromRGB(150, 150, 170)

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 50, 0, 50)
floatBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
floatBtn.BackgroundColor3 = BG_COLOR
floatBtn.BackgroundTransparency = 0.1
floatBtn.Text = "L"
floatBtn.TextColor3 = NEON_BRIGHT
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 26
floatBtn.Active = true
floatBtn.Parent = screenGui
local fC = Instance.new("UICorner", floatBtn); fC.CornerRadius = UDim.new(1, 0)
local fS = Instance.new("UIStroke", floatBtn); fS.Color = NEON_PURPLE; fS.Thickness = 2; fS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 650, 0, 420)
mainFrame.Position = UDim2.new(0.5, -325, 0.5, -210)
mainFrame.BackgroundColor3 = BG_COLOR
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = false
mainFrame.Parent = screenGui
local mC = Instance.new("UICorner", mainFrame); mC.CornerRadius = UDim.new(0, 12)
local mS = Instance.new("UIStroke", mainFrame); mS.Color = NEON_PURPLE; mS.Thickness = 1.5; mS.Transparency = 0.3; mS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Gradient no fundo principal
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 12, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 15, 35))
})
grad.Rotation = 45
grad.Parent = mainFrame

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

-- Top Bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 45)
topBar.BackgroundColor3 = SIDEBAR_COLOR
topBar.BackgroundTransparency = 0.2
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame
local tC = Instance.new("UICorner", topBar); tC.CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 200, 1, 0)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.Text = "L HUB | NEXUS"
title.TextColor3 = NEON_BRIGHT
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 30)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = topBar
local cBtnC = Instance.new("UICorner", closeBtn); cBtnC.CornerRadius = UDim.new(1, 0)
ConnectionManager:Add(closeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false end))

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 150, 1, -55)
sidebar.Position = UDim2.new(0, 10, 0, 50)
sidebar.BackgroundColor3 = SIDEBAR_COLOR
sidebar.BackgroundTransparency = 0.3
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
local sC = Instance.new("UICorner", sidebar); sC.CornerRadius = UDim.new(0, 8)

local sList = Instance.new("UIListLayout", sidebar); sList.Padding = UDim.new(0, 8); sList.SortOrder = Enum.SortOrder.LayoutOrder
Instance.new("UIPadding", sidebar).PaddingTop = UDim.new(0, 15)

-- User Profile na Sidebar
local userProfile = Instance.new("Frame")
userProfile.Size = UDim2.new(1, -20, 0, 60)
userProfile.Position = UDim2.new(0, 10, 1, -70)
userProfile.BackgroundColor3 = ELEMENT_BG
userProfile.BackgroundTransparency = 0.5
userProfile.Parent = sidebar
local upC = Instance.new("UICorner", userProfile); upC.CornerRadius = UDim.new(0, 6)

local userIcon = Instance.new("ImageLabel")
userIcon.Size = UDim2.new(0, 30, 0, 30)
userIcon.Position = UDim2.new(0, 10, 0.5, -15)
userIcon.BackgroundColor3 = NEON_PURPLE
userIcon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=48&h=48"
userIcon.Parent = userProfile
local uIC = Instance.new("UICorner", userIcon); uIC.CornerRadius = UDim.new(1, 0)

local userName = Instance.new("TextLabel")
userName.Size = UDim2.new(1, -50, 0, 20)
userName.Position = UDim2.new(0, 45, 0, 10)
userName.BackgroundTransparency = 1
userName.Text = LocalPlayer.DisplayName
userName.TextColor3 = TEXT_WHITE
userName.Font = Enum.Font.GothamBold
userName.TextSize = 12
userName.TextXAlignment = Enum.TextXAlignment.Left
userName.Parent = userProfile

local userTag = Instance.new("TextLabel")
userTag.Size = UDim2.new(1, -50, 0, 15)
userTag.Position = UDim2.new(0, 45, 0, 30)
userTag.BackgroundTransparency = 1
userTag.Text = "Premium"
userTag.TextColor3 = NEON_BRIGHT
userTag.Font = Enum.Font.Gotham
userTag.TextSize = 10
userTag.TextXAlignment = Enum.TextXAlignment.Left
userTag.Parent = userProfile

-- Content Area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -170, 1, -55)
contentArea.Position = UDim2.new(0, 160, 0, 50)
contentArea.BackgroundTransparency = 1
contentArea.Parent = mainFrame

local scrollContent = Instance.new("ScrollingFrame")
scrollContent.Size = UDim2.new(1, -190, 1, 0)
scrollContent.BackgroundTransparency = 1
scrollContent.ScrollBarThickness = 2
scrollContent.ScrollBarImageColor3 = NEON_PURPLE
scrollContent.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollContent.Parent = contentArea
local cList = Instance.new("UIListLayout", scrollContent); cList.Padding = UDim.new(0, 10); cList.SortOrder = Enum.SortOrder.LayoutOrder
ConnectionManager:Add(cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() scrollContent.CanvasSize = UDim2.new(0, 0, 0, cList.AbsoluteContentSize.Y + 20) end))

-- Preview Panel (Fake, para ficar igual a referencia)
local previewPanel = Instance.new("Frame")
previewPanel.Size = UDim2.new(0, 170, 1, 0)
previewPanel.Position = UDim2.new(1, -180, 0, 0)
previewPanel.BackgroundColor3 = SIDEBAR_COLOR
previewPanel.BackgroundTransparency = 0.3
previewPanel.Parent = contentArea
local pC = Instance.new("UICorner", previewPanel); pC.CornerRadius = UDim.new(0, 8)

local previewTitle = Instance.new("TextLabel")
previewTitle.Size = UDim2.new(1, 0, 0, 30)
previewTitle.BackgroundTransparency = 1
previewTitle.Text = "Visual Preview"
previewTitle.TextColor3 = TEXT_WHITE
previewTitle.Font = Enum.Font.GothamBold
previewTitle.TextSize = 12
previewTitle.Parent = previewPanel

local previewImage = Instance.new("ImageLabel")
previewImage.Size = UDim2.new(0, 120, 0, 120)
previewImage.Position = UDim2.new(0.5, -60, 0.5, -60)
previewImage.BackgroundColor3 = BG_COLOR
previewImage.Image = "rbxassetid://13370245899" -- Exemplo de avatar estático (pode ser mudado)
previewImage.Parent = previewPanel
local piC = Instance.new("UICorner", previewImage); piC.CornerRadius = UDim.new(0, 8)

-- UI Helpers
local function createSection(parent, titleText, icon)
    local frame = Instance.new("Frame")
    frame.Name = "SEC_" .. titleText
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundColor3 = ELEMENT_BG
    frame.BackgroundTransparency = 0.4
    frame.BorderSizePixel = 0
    frame.Parent = parent
    frame.ClipsDescendants = true
    
    local c = Instance.new("UICorner", frame); c.CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", frame); s.Color = NEON_PURPLE; s.Transparency = 0.7
    
    local pad = Instance.new("UIPadding", frame)
    pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)
    
    local layout = Instance.new("UIListLayout", frame); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local topRow = Instance.new("Frame", frame)
    topRow.Size = UDim2.new(1, 0, 0, 20); topRow.BackgroundTransparency = 1; topRow.LayoutOrder = 1
    
    local lbl = Instance.new("TextLabel", topRow)
    lbl.Size = UDim2.new(1, -25, 1, 0); lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = icon .. " " .. titleText
    lbl.TextColor3 = NEON_BRIGHT; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    return frame
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
    track.Size = UDim2.new(0, 36, 0, 18); track.Position = UDim2.new(1, -36, 0.5, -9)
    track.BackgroundColor3 = initialState and NEON_PURPLE or Color3.fromRGB(40, 40, 50); track.Text = ""
    
    local tC = Instance.new("UICorner", track); tC.CornerRadius = UDim.new(1, 0)
    
    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.Position = initialState and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    thumb.BackgroundColor3 = TEXT_WHITE
    local thC = Instance.new("UICorner", thumb); thC.CornerRadius = UDim.new(1, 0)
    
    local state = initialState
    local toggleObj
    
    local function setState(s, fire)
        state = (type(s) == "boolean") and s or false
        track.BackgroundColor3 = state and NEON_PURPLE or Color3.fromRGB(40, 40, 50)
        TweenService:Create(thumb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7) }):Play()
        if fire then pcall(callback, state) end
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

warn("[L HUB v84] UI Premium Carregada com Sucesso.")
