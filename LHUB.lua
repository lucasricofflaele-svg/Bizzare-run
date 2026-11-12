local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local CONFIG_FILE = "LHub_Config.json"

local defaultConfig = {
    aimbotEnabled = false, aimbotFov = 120, aimbotTurnChar = true,
    dashStrong = true, aimCamHeight = 8, aimYawOff = 0, aimPitchOff = 0,
    isAutoCollectEnabled = false, fovCircleOn = false, tpKillHeight = 6,
    floatBtnPosXScale = 0.85, floatBtnPosXOffset = 0,
    floatBtnPosYScale = 0.55, floatBtnPosYOffset = 0,
    espRokaPlant = false, espRokaFruit = false, espArrow = false, espShiny = false
}

local config = {}
for k, v in pairs(defaultConfig) do config[k] = v end

local function loadConfig()
    if isfile and isfile(CONFIG_FILE) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if success and type(data) == "table" then
            for k, v in pairs(data) do
                if config[k] ~= nil and type(v) == type(defaultConfig[k]) then
                    if type(v) == "number" then
                        if k == "aimbotFov" then config[k] = math.clamp(v, 30, 500)
                        elseif k == "aimCamHeight" then config[k] = math.clamp(v, -6, 30)
                        elseif k == "aimYawOff" or k == "aimPitchOff" then config[k] = math.clamp(v, -10, 10)
                        elseif k == "tpKillHeight" then config[k] = math.clamp(v, -20, 20)
                        else config[k] = v end
                    else
                        config[k] = v
                    end
                end
            end
        end
    end
end
loadConfig()

local isAutoCollectEnabled = config.isAutoCollectEnabled
local aimbotEnabled = config.aimbotEnabled
local aimbotFov = config.aimbotFov
local aimbotTurnChar = config.aimbotTurnChar
local dashStrong = config.dashStrong
local aimCamHeight = config.aimCamHeight
local aimYawOff = config.aimYawOff
local aimPitchOff = config.aimPitchOff
local fovCircleOn = config.fovCircleOn
local tpKillHeight = config.tpKillHeight
local espRokaPlantActive = config.espRokaPlant
local espRokaFruitActive = config.espRokaFruit
local espArrowActive = config.espArrow
local espShinyActive = config.espShiny

local aimbotFloatBtn = nil

local function saveConfig(silent)
    if writefile then
        local data = {
            aimbotEnabled = aimbotEnabled, aimbotFov = aimbotFov, aimbotTurnChar = aimbotTurnChar,
            dashStrong = dashStrong, aimCamHeight = aimCamHeight, aimYawOff = aimYawOff,
            aimPitchOff = aimPitchOff, isAutoCollectEnabled = isAutoCollectEnabled,
            fovCircleOn = fovCircleOn, tpKillHeight = tpKillHeight,
            floatBtnPosXScale = aimbotFloatBtn and aimbotFloatBtn.Position.X.Scale or 0.85,
            floatBtnPosXOffset = aimbotFloatBtn and aimbotFloatBtn.Position.X.Offset or 0,
            floatBtnPosYScale = aimbotFloatBtn and aimbotFloatBtn.Position.Y.Scale or 0.55,
            floatBtnPosYOffset = aimbotFloatBtn and aimbotFloatBtn.Position.Y.Offset or 0,
            espRokaPlant = espRokaPlantActive, espRokaFruit = espRokaFruitActive,
            espArrow = espArrowActive, espShiny = espShinyActive
        }
        local ok, err = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
        if not ok and not silent then warn("Erro ao salvar config:", err) end
    end
end

if _G.LHub then
    if _G.LHub.Tasks then
        for _, t in pairs(_G.LHub.Tasks) do
            if type(t) == "thread" and coroutine.status(t) ~= "dead" then pcall(task.cancel, t) end
        end
    end
    if _G.LHub.Conns then
        for _, c in pairs(_G.LHub.Conns) do pcall(function() c:Disconnect() end) end
    end
    if _G.LHub.Objs then
        for _, o in pairs(_G.LHub.Objs) do pcall(function() o:Destroy() end) end
    end
    pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
    pcall(function() if _G.LHub.FovCircle then _G.LHub.FovCircle:Remove() end end)
    pcall(function() if _G.LHub.Highlight then _G.LHub.Highlight:Destroy() end end)
    pcall(function() if _G.LHub.Gui then _G.LHub.Gui:Destroy() end end)
    if _G.LHub.ESPObjects then
        for _, d in pairs(_G.LHub.ESPObjects) do
            if d.highlight then d.highlight:Destroy() end
            if d.billboard then d.billboard:Destroy() end
        end
    end
end

_G.LHub = { Gui = nil, FovCircle = nil, Highlight = nil, ESPObjects = {}, Tasks = {}, Conns = {}, Objs = {} }

local function addTask(t)
    for i = #_G.LHub.Tasks, 1, -1 do
        if coroutine.status(_G.LHub.Tasks[i]) == "dead" then table.remove(_G.LHub.Tasks, i) end
    end
    table.insert(_G.LHub.Tasks, t)
    return t
end

local function addConn(c)
    table.insert(_G.LHub.Conns, c)
    return c
end

addTask(task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if Workspace:FindFirstChild("PHYSICS_WATCHDOG") then Workspace.PHYSICS_WATCHDOG:Destroy() end
            if Workspace:FindFirstChild("NETWORK_WATCHDOG") then Workspace.NETWORK_WATCHDOG:Destroy() end
        end)
    end
end))

local STAGE1_WIN_POS = Vector3.new(3407.000, -408.536, 2287.5)
local STAGE2_CP1_POS = Vector3.new(-2805.450, -160.060, -1304.949)
local STAGE2_CP2_POS = Vector3.new(1667.592, -154.669, -1671.076)
local STAGE2_WIN_POS = Vector3.new(8460.426, 61.457, -1291.114)
local LOBBY_POS = Vector3.new(-524, 26.250, -476)

local ROKA_SPAWNS_S1 = {
    Vector3.new(758.075, 200.301, 2071.725), Vector3.new(-722.469, 200.301, 2592.146),
    Vector3.new(-809.457, -38.199, 687.739), Vector3.new(-484.195, 28.807, -640.670),
    Vector3.new(581.779, -160.702, -1142.168), Vector3.new(-7165.460, -160.702, -2034.455)
}
local ROKA_SPAWNS_S2 = {
    Vector3.new(581.779, -160.702, -1142.168), Vector3.new(6223.698, 23.416, -1723.463),
    Vector3.new(-4507.980, -160.702, -1349.381)
}

local function getMapName()
    local gc = game:GetService("ReplicatedStorage"):FindFirstChild("GameConfig")
    if gc then
        local m = gc:GetAttribute("Map")
        return type(m) == "string" and m or ""
    end
    return ""
end

local function getFinishLine(stage)
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if not h then return nil end
    local cp, md = nil, 99999
    local f = Workspace:FindFirstChild("FinishLine", true)
    if f then
        for _, ch in ipairs(f:GetDescendants()) do
            if ch:IsA("BasePart") then
                local d = (ch.Position - h.Position).Magnitude
                if d < md then md = d; cp = ch end
            end
        end
    end
    if not cp then
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("BasePart") and string.find(string.lower(o.Name), "cube.") then
                local d = (o.Position - h.Position).Magnitude
                if d < md then md = d; cp = o end
            end
        end
    end
    if cp then
        local dir = Vector3.new(cp.Position.X - h.Position.X, 0, cp.Position.Z - h.Position.Z)
        if dir.Magnitude > 0.1 then
            return cp.Position + (dir.Unit * 100) + Vector3.new(0, 3, 0)
        end
        return cp.Position + Vector3.new(0, 3, 0)
    end
    return nil
end

local function isOnTrain()
    local m = getMapName()
    if string.find(string.lower(m), "train") or string.find(string.lower(m), "end") then return true end
    return false
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

local function holdPromptInfinitely(target, checkActive)
    local p, m = target.prompt, target.model
    if not p or not p.Parent or not m or not m.Parent then return end
    local c = LocalPlayer.Character
    if not c or not c.Parent then return end
    local h = c:FindFirstChild("HumanoidRootPart")
    local hu = c:FindFirstChildOfClass("Humanoid")
    if not h or not hu or hu.Health <= 0 then return end
    
    local f = h.CFrame
    local ow, oj, op = hu.WalkSpeed, hu.JumpPower, hu.PlatformStand
    
    pcall(function()
        hu.PlatformStand = false
        hu.WalkSpeed = 0
        hu.JumpPower = 0
    end)
    
    local ht = p.HoldDuration > 0 and p.HoldDuration or 0.5
    local s = false
    
    pcall(function()
        while checkActive() and m.Parent ~= nil and p.Parent ~= nil do
            h.CFrame = f
            h.AssemblyLinearVelocity = Vector3.zero
            h.AssemblyAngularVelocity = Vector3.zero
            pcall(function() p:InputHoldBegin() end)
            local t = tick()
            while tick() - t < ht do
                if not checkActive() then break end
                if m.Parent == nil or p.Parent == nil then break end
                h.CFrame = f
                h.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.05)
            end
            if m.Parent == nil or p.Parent == nil then s = true; break end
            pcall(function() p:InputHoldEnd() end)
            task.wait(0.1)
        end
    end)
    
    if hu and hu.Parent then
        pcall(function()
            hu.WalkSpeed = ow
            hu.JumpPower = oj
            hu.PlatformStand = op
        end)
    end
    return s
end

local function safeTweenTeleport(targetPos)
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if not h then return end
    
    local i = true
    addTask(task.spawn(function()
        while i do pcall(nukeTeleportDetectorsOnly); task.wait(0.1) end
    end))
    
    local t = CFrame.new(targetPos)
    local s = h.CFrame
    h.Anchored = true
    h.AssemblyLinearVelocity = Vector3.zero
    h.AssemblyAngularVelocity = Vector3.zero
    
    pcall(function()
        for j = 1, 20 do
            if not h.Parent then break end
            h.CFrame = s:Lerp(t, j / 20)
            task.wait(0.05)
        end
        h.CFrame = t
    end)
    
    h.Anchored = false
    h.AssemblyLinearVelocity = Vector3.zero
    h.AssemblyAngularVelocity = Vector3.zero
    i = false
    task.wait(0.1)
end

local function fastTweenToItem(targetPos, targetModel)
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    local hu = c and c:FindFirstChildOfClass("Humanoid")
    if not h or not hu or hu.Health <= 0 then return end
    
    local r = RaycastParams.new()
    r.FilterDescendantsInstances = { c, targetModel }
    r.FilterType = Enum.RaycastFilterType.Exclude
    local rr = Workspace:Raycast(targetPos + Vector3.new(0, 50, 0), Vector3.new(0, -150, 0), r)
    local f = rr and (rr.Position + Vector3.new(0, 3, 0)) or (targetPos + Vector3.new(0, 3, 0))
    
    h.Anchored = true
    h.AssemblyLinearVelocity = Vector3.zero
    h.AssemblyAngularVelocity = Vector3.zero
    
    local s = pcall(function()
        local t = TweenService:Create(h, TweenInfo.new(0.15, Enum.EasingStyle.Linear), { CFrame = CFrame.new(f) })
        t:Play()
        t.Completed:Wait()
    end)
    
    h.Anchored = false
    h.AssemblyLinearVelocity = Vector3.zero
    h.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.3)
    return s
end

local isColl = false
local function executeCollect()
    if not isAutoCollectEnabled or isColl then return end
    isColl = true
    pcall(function()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local hu = c and c:FindFirstChildOfClass("Humanoid")
        if not h or not hu or hu.Health <= 0 then return end
        
        local tg = {}
        local me = Workspace:FindFirstChild("MapEvents")
        local af = me and me:FindFirstChild("Arrows") and me.Arrows:FindFirstChild("Spawned")
        
        if af then
            for _, a in ipairs(af:GetChildren()) do
                local p = a:FindFirstChildWhichIsA("ProximityPrompt", true)
                if p and p.Parent then
                    table.insert(tg, { model = a, prompt = p, pos = a:IsA("BasePart") and a.Position or a:GetPivot().Position })
                end
            end
        end
        
        local m = Workspace:FindFirstChild("Map")
        local g = m and m:FindFirstChild("Gameplay")
        local it = g and g:FindFirstChild("Items") and g.Items:FindFirstChild("Spawned")
        local isS2 = string.find(string.lower(getMapName()), "2") or string.find(string.lower(getMapName()), "stage 2")
        local sp = isS2 and ROKA_SPAWNS_S2 or ROKA_SPAWNS_S1
        
        if it then
            for _, i in ipairs(it:GetChildren()) do
                local n = string.lower(i.Name)
                if string.find(n, "roka") or string.find(n, "fruit") or string.find(n, "plant") then
                    local p = i:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if p and p.Parent then
                        local pos = i:IsA("BasePart") and i.Position or i:GetPivot().Position
                        for _, s in ipairs(sp) do
                            if (pos - s).Magnitude < 50 then
                                table.insert(tg, { model = i, prompt = p, pos = pos })
                                break
                            end
                        end
                    end
                end
            end
        end
        
        if #tg == 0 then return end
        table.sort(tg, function(a, b) return (a.pos - h.Position).Magnitude < (b.pos - h.Position).Magnitude end)
        if hu.SeatPart then hu.Sit = false; task.wait(0.5) end
        
        for _, t in ipairs(tg) do
            if not isAutoCollectEnabled then break end
            fastTweenToItem(t.pos, t.model)
            task.wait(0.2)
            holdPromptInfinitely(t, function() return isAutoCollectEnabled end)
            task.wait(0.5)
        end
    end)
    isColl = false
end

local function createESP(m, t, c)
    if _G.LHub.ESPObjects[m] then return end
    local h = Instance.new("Highlight")
    h.Adornee = m
    h.FillColor = c
    h.OutlineColor = Color3.fromRGB(212, 175, 55)
    h.FillTransparency = 0.6
    h.OutlineTransparency = 0.2
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = m
    
    local b = Instance.new("BillboardGui")
    b.Name = "LHubESP"
    b.Adornee = m:IsA("Model") and (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")) or m
    b.Size = UDim2.new(0, 200, 0, 20)
    b.StudsOffset = Vector3.new(0, 3.5, 0)
    b.AlwaysOnTop = true
    b.Parent = m
    
    local tl = Instance.new("TextLabel")
    tl.Parent = b
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1
    tl.RichText = true
    tl.Text = string.format("<b><font color='rgb(%d,%d,%d)'>%s</font></b> <font color='#DDDDDD'>[0m]</font>", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), t)
    tl.TextColor3 = Color3.new(1, 1, 1)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 13
    tl.TextStrokeTransparency = 0
    
    _G.LHub.ESPObjects[m] = { highlight = h, billboard = b, textLbl = tl, title = t, color = c }
end

local function cleanESP()
    for m, d in pairs(_G.LHub.ESPObjects) do
        local de = false
        if not m.Parent then
            de = true
        else
            local n = string.lower(m.Name)
            local isP = string.find(n, "plant") or string.find(n, "caule")
            local isR = string.find(n, "roka") or string.find(n, "fruit") or string.find(n, "plant")
            local isS = string.find(n, "shiny")
            local isA = string.find(n, "arrow") or m:FindFirstAncestor("Arrows")
            
            if isR then
                if isP and not espRokaPlantActive then de = true
                elseif not isP and not espRokaFruitActive then de = true end
            elseif isS then
                if not espShinyActive then de = true end
            elseif isA then
                if not espArrowActive then de = true end
            end
        end
        
        if de then
            if d.highlight then d.highlight:Destroy() end
            if d.billboard then d.billboard:Destroy() end
            _G.LHub.ESPObjects[m] = nil
        end
    end
end

addTask(task.spawn(function()
    while task.wait(0.2) do
        cleanESP()
        local m = Workspace:FindFirstChild("Map")
        local g = m and m:FindFirstChild("Gameplay")
        local it = g and g:FindFirstChild("Items") and g.Items:FindFirstChild("Spawned")
        if it then
            for _, i in ipairs(it:GetChildren()) do
                local n = string.lower(i.Name)
                local isP = string.find(n, "plant") or string.find(n, "caule")
                local isF = string.find(n, "roka") or string.find(n, "fruit")
                if isP and espRokaPlantActive then
                    createESP(i, "Roka Plant", Color3.fromRGB(50, 255, 100))
                elseif isF and espRokaFruitActive and not isP then
                    createESP(i, "Roka Fruit", Color3.fromRGB(255, 105, 180))
                end
            end
        end
        
        local me = Workspace:FindFirstChild("MapEvents")
        local af = me and me:FindFirstChild("Arrows") and me.Arrows:FindFirstChild("Spawned")
        if af then
            for _, a in ipairs(af:GetChildren()) do
                local n = string.lower(a.Name)
                local isS = string.find(n, "shiny")
                if isS and espShinyActive then
                    createESP(a, "Arrow Shiny", Color3.fromRGB(255, 215, 0))
                elseif not isS and espArrowActive then
                    createESP(a, "Arrow", Color3.fromRGB(255, 255, 255))
                end
            end
        end
    end
end))

addTask(task.spawn(function()
    while task.wait(0.1) do
        local c = LocalPlayer.Character
        if not c or not c.Parent then task.wait(0.5); continue end
        local h = c:FindFirstChild("HumanoidRootPart")
        if h then
            for m, d in pairs(_G.LHub.ESPObjects) do
                if m.Parent and d.textLbl then
                    local p = m:IsA("BasePart") and m.Position or m:GetPivot().Position
                    local di = math.floor((p - h.Position).Magnitude)
                    d.textLbl.Text = string.format("<b><font color='rgb(%d,%d,%d)'>%s</font></b> <font color='#DDDDDD'>[%dm]</font>", math.floor(d.color.R * 255), math.floor(d.color.G * 255), math.floor(d.color.B * 255), d.title, di)
                end
            end
        end
    end
end))

local aTg = nil
local aHl = Instance.new("Highlight")
aHl.FillColor = Color3.fromRGB(212, 175, 55)
aHl.OutlineColor = Color3.fromRGB(255, 255, 255)
aHl.FillTransparency = 0.4
aHl.OutlineTransparency = 0
aHl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
aHl.Enabled = false
aHl.Parent = CoreGui
_G.LHub.Highlight = aHl

local fC = Drawing.new("Circle")
fC.Visible = fovCircleOn
fC.Radius = aimbotFov
fC.Color = Color3.fromRGB(212, 175, 55)
fC.Thickness = 1.5
fC.Filled = false
fC.Transparency = 1
_G.LHub.FovCircle = fC

local function isDmg(m)
    if m == LocalPlayer.Character then return false end
    local hu = m:FindFirstChildOfClass("Humanoid")
    if hu then return hu.Health > 0 end
    local hp = m:FindFirstChild("Health") or m:FindFirstChild("HP") or m:FindFirstChild("HealthValue")
    if hp and ((hp:IsA("NumberValue") or hp:IsA("IntValue")) and hp.Value > 0) then return true end
    local ah = m:GetAttribute("Health") or m:GetAttribute("HP")
    if ah and type(ah) == "number" and ah > 0 then return true end
    return false
end

local function pickAim(m)
    local h = m:FindFirstChild("Head")
    if h and h:IsA("BasePart") then return h, Vector3.zero end
    local h = m:FindFirstChild("HumanoidRootPart")
    if h and h:IsA("BasePart") then return h, Vector3.new(0, 1.5, 0) end
    local pp = m.PrimaryPart
    if pp then return pp, Vector3.new(0, 1, 0) end
    for _, p in ipairs(m:GetDescendants()) do
        if p:IsA("BasePart") then return p, Vector3.zero end
    end
    return nil, nil
end

local eC = setmetatable({}, { __mode = "k" })
local function getEntry(m)
    local e = eC[m]
    if e and e.model and e.model.Parent and e.part and e.part.Parent and (not e.hum or (e.hum.Parent and e.hum.Health > 0)) then return e end
    local p, o = pickAim(m)
    if not p then eC[m] = nil; return nil end
    e = { model = m, hum = m:FindFirstChildOfClass("Humanoid"), part = p, off = o }
    eC[m] = e
    return e
end

local function eAlive(e)
    if not e.model or not e.model.Parent then return false end
    if e.hum then return e.hum.Parent ~= nil and e.hum.Health > 0 end
    return isDmg(e.model)
end

local function ePoint(e)
    local p = e.part
    if p and p.Parent then return p.Position + e.off end
    return nil
end

local nC = {}
local lS = 0
local function refreshN()
    local l = {}
    local mc = LocalPlayer.Character
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        n += 1
        if n % 2500 == 0 then task.wait() end
        if d:IsA("Model") and d ~= mc and not Players:GetPlayerFromCharacter(d) then
            if not (mc and d:IsDescendantOf(mc)) and d:FindFirstChildOfClass("Humanoid") then
                l[#l + 1] = d
            end
        end
    end
    nC = l
end

addTask(task.spawn(function()
    while true do
        task.wait(0.25)
        if aimbotEnabled and os.clock() - lS >= 2 then
            lS = os.clock()
            pcall(refreshN)
        end
    end
end))

local aL = nil
local lCen = nil
local aT = 0
local function relL()
    aL = nil
    aTg = nil
    aHl.Enabled = false
    aHl.Adornee = nil
end

local function acq(cam, center, char)
    local b, bD
    local function try(m)
        if m == char or not m.Parent then return end
        local e = getEntry(m)
        if not e or not eAlive(e) then return end
        local p = ePoint(e)
        if not p then return end
        local sp, os = cam:WorldToViewportPoint(p)
        if not os then return end
        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d <= aimbotFov and (not bD or d < bD) then b, bD = e, d end
    end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then try(pl.Character) end
    end
    for _, m in ipairs(nC) do try(m) end
    if b then aL = b; aTg = b.model end
end

local function aStep(dt)
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local c = Vector2.new(vp.X / 2, vp.Y / 2)
    if c ~= lCen then fC.Position = c; lCen = c end
    if not aimbotEnabled then
        if aL then relL() end
        return
    end
    local ch = LocalPlayer.Character
    if not ch or not ch.Parent then relL(); return end
    local h = ch:FindFirstChild("HumanoidRootPart")
    local hu = ch:FindFirstChildOfClass("Humanoid")
    if not h or not hu or hu.Health <= 0 then relL(); return end
    if aL and not eAlive(aL) then relL() end
    if not aL then
        aT += dt
        if aT >= 0.05 then aT = 0; acq(cam, c, ch) end
        if not aL then return end
    end
    local ap = ePoint(aL)
    if not ap then relL(); return end
    local ok, tv = pcall(function() return aL.part.AssemblyLinearVelocity end)
    if ok and tv then ap = ap + tv * math.min(dt or 0.016, 0.05) end
    if aHl.Adornee ~= aL.model then aHl.Adornee = aL.model end
    aHl.Enabled = true
    local fo = cam.Focus.Position
    local di = (cam.CFrame.Position - fo).Magnitude
    local ta = ap - fo
    if ta.Magnitude > 0.5 then
        local dir = ta.Unit
        local hh = aimCamHeight
        if di < 2 then hh = 0 end
        local np = fo - dir * di + Vector3.new(0, hh, 0)
        if (ap - np).Magnitude > 0.1 then
            local cf = CFrame.lookAt(np, ap)
            if aimYawOff ~= 0 or aimPitchOff ~= 0 then cf = cf * CFrame.Angles(math.rad(aimPitchOff), math.rad(-aimYawOff), 0) end
            cam.CFrame = cf
        end
    end
    if aimbotTurnChar then
        local fl = Vector3.new(ap.X - h.Position.X, 0, ap.Z - h.Position.Z)
        if fl.Magnitude > 0.1 and h.CFrame.LookVector:Dot(fl.Unit) < 0.9999 then
            h.CFrame = CFrame.lookAt(h.Position, h.Position + fl)
        end
    end
end

pcall(function() RunService:UnbindFromRenderStep("LHubAimbot") end)
RunService:BindToRenderStep("LHubAimbot", Enum.RenderPriority.Last.Value, function(dt) pcall(aStep, dt) end)

addTask(task.spawn(function()
    while true do
        task.wait(0.5)
        local c = LocalPlayer.Character
        if c and c.Parent then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                if dashStrong and h.WalkSpeed == 16 then h.WalkSpeed = 50
                elseif not dashStrong and h.WalkSpeed == 50 then h.WalkSpeed = 16 end
            end
        end
    end
end))

local sg = Instance.new("ScreenGui")
sg.Name = "LHub_Luxury"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999999
pcall(function() sg.Parent = CoreGui end)
if not sg.Parent then sg.Parent = PlayerGui end
_G.LHub.Gui = sg

local BGC = Color3.fromRGB(15, 15, 22)
local SBC = Color3.fromRGB(20, 20, 28)
local EBC = Color3.fromRGB(28, 28, 38)
local GD = Color3.fromRGB(212, 175, 55)
local GDB = Color3.fromRGB(255, 215, 0)
local TW = Color3.fromRGB(240, 240, 240)
local TGR = Color3.fromRGB(140, 140, 150)

local function toast(m, c)
    local t = Instance.new("Frame")
    t.Size = UDim2.new(0, 200, 0, 35)
    t.Position = UDim2.new(1, 10, 0.1, 0)
    t.BackgroundColor3 = EBC
    t.BackgroundTransparency = 0.1
    t.Parent = sg
    local co = Instance.new("UICorner", t); co.CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", t); s.Color = c or GD; s.Thickness = 1
    local l = Instance.new("TextLabel", t); l.Size = UDim2.new(1, 0, 1, 0); l.BackgroundTransparency = 1; l.Text = m; l.TextColor3 = c or GD; l.Font = Enum.Font.GothamBold; l.TextSize = 11
    TweenService:Create(t, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(1, -210, 0.1, 0) }):Play()
    task.delay(2.5, function()
        if t and t.Parent then
            local to = TweenService:Create(t, TweenInfo.new(0.3), { Position = UDim2.new(1, 10, 0.1, 0) })
            to:Play(); to.Completed:Wait(); t:Destroy()
        end
    end)
end

local fb = Instance.new("TextButton")
fb.Size = UDim2.new(0, 45, 0, 45)
fb.Position = UDim2.new(0.05, 0, 0.4, 0)
fb.BackgroundColor3 = BGC
fb.BackgroundTransparency = 0.2
fb.Text = "L"
fb.TextColor3 = GD
fb.Font = Enum.Font.GothamBlack
fb.TextSize = 24
fb.Active = true
fb.Parent = sg
local fbc = Instance.new("UICorner", fb); fbc.CornerRadius = UDim.new(1, 0)
local fbs = Instance.new("UIStroke", fb); fbs.Color = GD; fbs.Thickness = 2

local mf = Instance.new("Frame")
mf.Size = UDim2.new(0, 600, 0, 400)
mf.Position = UDim2.new(0.5, -300, 0.5, -200)
mf.BackgroundColor3 = BGC
mf.BackgroundTransparency = 0.1
mf.BorderSizePixel = 0
mf.Active = true
mf.Visible = false
mf.Parent = sg
local mfc = Instance.new("UICorner", mf); mfc.CornerRadius = UDim.new(0, 12)
local mfs = Instance.new("UIStroke", mf); mfs.Color = Color3.fromRGB(60, 60, 80); mfs.Thickness = 1.5; mfs.Transparency = 0.2

local us = Instance.new("UIScale")
us.Scale = 0.8
us.Parent = mf

local function upScale()
    local c = Workspace.CurrentCamera
    if not c then return end
    local vp = c.ViewportSize
    if vp.X < 700 or vp.Y < 500 then us.Scale = 0.5
    elseif vp.X < 1000 or vp.Y < 700 then us.Scale = 0.65
    else us.Scale = 0.8 end
end
upScale()
addConn(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.wait(1)
    local c = Workspace.CurrentCamera
    if c then addConn(c:GetPropertyChangedSignal("ViewportSize"):Connect(upScale)) end
    upScale()
end))

local tb = Instance.new("Frame")
tb.Size = UDim2.new(1, 0, 0, 40)
tb.BackgroundColor3 = SBC
tb.BackgroundTransparency = 0.2
tb.BorderSizePixel = 0
tb.Parent = mf
local tbc = Instance.new("UICorner", tb); tbc.CornerRadius = UDim.new(0, 12)

local tt = Instance.new("TextLabel")
tt.Size = UDim2.new(0, 200, 1, 0)
tt.Position = UDim2.new(0, 20, 0, 0)
tt.BackgroundTransparency = 1
tt.Text = "L HUB | NEXUS"
tt.TextColor3 = GDB
tt.Font = Enum.Font.GothamBlack
tt.TextSize = 16
tt.TextXAlignment = Enum.TextXAlignment.Left
tt.Parent = tb

local sb = Instance.new("TextBox")
sb.Size = UDim2.new(0, 200, 0, 28)
sb.Position = UDim2.new(0.5, -100, 0.5, -14)
sb.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
sb.PlaceholderText = "🔍 Buscar função..."
sb.PlaceholderColor3 = TGR
sb.TextColor3 = TW
sb.Font = Enum.Font.Gotham
sb.TextSize = 12
sb.Parent = tb
local sbc = Instance.new("UICorner", sb); sbc.CornerRadius = UDim.new(1, 0)
local sbs = Instance.new("UIStroke", sb); sbs.Color = Color3.fromRGB(60, 60, 80)

local cb = Instance.new("TextButton")
cb.Size = UDim2.new(0, 30, 0, 30)
cb.Position = UDim2.new(1, -40, 0.5, -15)
cb.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
cb.Text = "X"
cb.TextColor3 = Color3.fromRGB(255, 100, 100)
cb.Font = Enum.Font.GothamBold
cb.TextSize = 14
cb.Parent = tb
local cbc = Instance.new("UICorner", cb); cbc.CornerRadius = UDim.new(1, 0)
addConn(cb.MouseButton1Click:Connect(function() mf.Visible = false end))

local sdB = Instance.new("Frame")
sdB.Size = UDim2.new(0, 150, 1, -40)
sdB.Position = UDim2.new(0, 0, 0, 40)
sdB.BackgroundColor3 = SBC
sdB.BackgroundTransparency = 0.4
sdB.BorderSizePixel = 0
sdB.Parent = mf
local sdl = Instance.new("UIListLayout", sdB); sdl.Padding = UDim.new(0, 8); sdl.SortOrder = Enum.SortOrder.LayoutOrder; sdl.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", sdB).PaddingTop = UDim.new(0, 15)

local ca = Instance.new("Frame")
ca.Size = UDim2.new(1, -160, 1, -60)
ca.Position = UDim2.new(0, 155, 0, 50)
ca.BackgroundTransparency = 1
ca.Parent = mf

local sc = Instance.new("ScrollingFrame")
sc.Size = UDim2.new(1, 0, 1, 0)
sc.BackgroundTransparency = 1
sc.ScrollBarThickness = 2
sc.ScrollBarImageColor3 = GD
sc.ScrollBarImageTransparency = 0.3
sc.CanvasSize = UDim2.new(0, 0, 0, 0)
sc.Parent = ca
local scl = Instance.new("UIListLayout", sc); scl.Padding = UDim.new(0, 10); scl.SortOrder = Enum.SortOrder.LayoutOrder
addConn(scl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sc.CanvasSize = UDim2.new(0, 0, 0, scl.AbsoluteContentSize.Y + 20) end))

local function sec(p, t, i)
    local f = Instance.new("Frame")
    f.Name = "SEC_" .. t
    f.Size = UDim2.new(1, -10, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.BackgroundColor3 = EBC
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel = 0
    f.Parent = p
    f.ClipsDescendants = true
    local c = Instance.new("UICorner", f); c.CornerRadius = UDim.new(0, 8)
    local s = Instance.new("UIStroke", f); s.Color = Color3.fromRGB(50, 50, 70); s.Transparency = 0.5
    local pd = Instance.new("UIPadding", f); pd.PaddingTop = UDim.new(0, 12); pd.PaddingBottom = UDim.new(0, 12); pd.PaddingLeft = UDim.new(0, 12); pd.PaddingRight = UDim.new(0, 12)
    local l = Instance.new("UIListLayout", f); l.Padding = UDim.new(0, 10); l.SortOrder = Enum.SortOrder.LayoutOrder; l.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local tr = Instance.new("Frame", f)
    tr.Size = UDim2.new(1, 0, 0, 18)
    tr.BackgroundTransparency = 1
    tr.LayoutOrder = 1
    local a = Instance.new("Frame", tr); a.Size = UDim2.new(0, 20, 0, 3); a.Position = UDim2.new(0, 0, 0.5, -1.5); a.BackgroundColor3 = Color3.fromRGB(130, 80, 255); a.BorderSizePixel = 0
    local tl = Instance.new("TextLabel", tr); tl.Size = UDim2.new(1, -25, 1, 0); tl.Position = UDim2.new(0, 25, 0, 0); tl.BackgroundTransparency = 1; tl.Text = i .. " " .. t; tl.TextColor3 = Color3.fromRGB(130, 80, 255); tl.Font = Enum.Font.GothamBold; tl.TextSize = 12; tl.TextXAlignment = Enum.TextXAlignment.Left
    return f
end

local function btn(p, t, cbFunc)
    local b = Instance.new("TextButton")
    b.Name = t
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    b.BackgroundTransparency = 0.2
    b.Text = t
    b.TextColor3 = TW
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = p
    local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", b); s.Color = Color3.fromRGB(50, 50, 70); s.Transparency = 0.2
    addConn(b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(30, 30, 45) }):Play()
        s.Color = Color3.fromRGB(130, 80, 255); b.TextColor3 = Color3.fromRGB(130, 80, 255)
    end))
    addConn(b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(20, 20, 28) }):Play()
        s.Color = Color3.fromRGB(50, 50, 70); b.TextColor3 = TW
    end))
    addConn(b.MouseButton1Click:Connect(function() pcall(cbFunc) end))
    return b
end

local function row(p, lt, mn, mx, st, cv, cbFunc)
    local r = Instance.new("Frame")
    r.Name = lt
    r.Size = UDim2.new(1, 0, 0, 38)
    r.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    r.BackgroundTransparency = 0.2
    r.Parent = p
    local rc = Instance.new("UICorner", r); rc.CornerRadius = UDim.new(0, 6)
    local rs = Instance.new("UIStroke", r); rs.Color = Color3.fromRGB(50, 50, 70); rs.Transparency = 0.2
    local l = Instance.new("TextLabel", r); l.Size = UDim2.new(1, -80, 1, 0); l.Position = UDim2.new(0, 12, 0, 0); l.BackgroundTransparency = 1; l.Text = lt .. ": " .. cv; l.TextColor3 = TW; l.Font = Enum.Font.GothamBold; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left
    local bc = Instance.new("Frame", r); bc.Size = UDim2.new(0, 64, 1, 0); bc.Position = UDim2.new(1, -70, 0, 0); bc.BackgroundTransparency = 1
    local mb = Instance.new("TextButton", bc); mb.Size = UDim2.new(0, 28, 0, 24); mb.Position = UDim2.new(0, 0, 0.5, -12); mb.BackgroundColor3 = Color3.fromRGB(15, 15, 20); mb.Text = "-"; mb.TextColor3 = TW; mb.Font = Enum.Font.GothamBold; mb.TextSize = 14
    local mc = Instance.new("UICorner", mb); mc.CornerRadius = UDim.new(0, 4); local ms = Instance.new("UIStroke", mb); ms.Color = Color3.fromRGB(50, 50, 70)
    local pb = Instance.new("TextButton", bc); pb.Size = UDim2.new(0, 28, 0, 24); pb.Position = UDim2.new(1, -28, 0.5, -12); pb.BackgroundColor3 = Color3.fromRGB(15, 15, 20); pb.Text = "+"; pb.TextColor3 = TW; pb.Font = Enum.Font.GothamBold; pb.TextSize = 14
    local pc = Instance.new("UICorner", pb); pc.CornerRadius = UDim.new(0, 4); local ps = Instance.new("UIStroke", pb); ps.Color = Color3.fromRGB(50, 50, 70)
    
    local v = cv
    local function up(nv)
        if type(nv) ~= "number" then return end
        v = math.clamp(nv, mn, mx)
        v = math.round(v * 100) / 100
        l.Text = lt .. ": " .. v
        cbFunc(v)
    end
    addConn(mb.MouseButton1Click:Connect(function() up(v - st) end))
    addConn(pb.MouseButton1Click:Connect(function() up(v + st) end))
    addConn(mb.MouseEnter:Connect(function() ms.Color = Color3.fromRGB(130, 80, 255) end))
    addConn(mb.MouseLeave:Connect(function() ms.Color = Color3.fromRGB(50, 50, 70) end))
    addConn(pb.MouseEnter:Connect(function() ps.Color = Color3.fromRGB(130, 80, 255) end))
    addConn(pb.MouseLeave:Connect(function() ps.Color = Color3.fromRGB(50, 50, 70) end))
    return { row = r, lbl = l, update = up }
end

local function tgl(p, t, is, cbFunc)
    local f = Instance.new("Frame")
    f.Name = t
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundTransparency = 1
    f.Parent = p
    local l = Instance.new("TextLabel", f); l.Size = UDim2.new(1, -50, 1, 0); l.BackgroundTransparency = 1; l.Text = t; l.TextColor3 = TW; l.Font = Enum.Font.Gotham; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left
    local tr = Instance.new("TextButton", f); tr.Name = "TrackBtn"; tr.Size = UDim2.new(0, 40, 0, 20); tr.Position = UDim2.new(1, -40, 0.5, -10); tr.BackgroundColor3 = is and Color3.fromRGB(130, 80, 255) or Color3.fromRGB(50, 50, 60); tr.Text = ""
    local tc = Instance.new("UICorner", tr); tc.CornerRadius = UDim.new(1, 0)
    local th = Instance.new("Frame", tr); th.Size = UDim2.new(0, 16, 0, 16); th.Position = is and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8); th.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    local thc = Instance.new("UICorner", th); thc.CornerRadius = UDim.new(1, 0)
    
    local st = is
    addConn(tr.MouseButton1Click:Connect(function()
        st = not st
        tr.BackgroundColor3 = st and Color3.fromRGB(130, 80, 255) or Color3.fromRGB(50, 50, 60)
        TweenService:Create(th, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = st and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
        pcall(cbFunc, st)
    end))
    return { frame = f, track = tr, thumb = th, setState = function(s, fire)
        st = (type(s) == "boolean") and s or false
        tr.BackgroundColor3 = st and Color3.fromRGB(130, 80, 255) or Color3.fromRGB(50, 50, 60)
        TweenService:Create(th, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = st and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8) }):Play()
        if fire then pcall(cbFunc, st) end
    end }
end

local T = {}
local TB = {}
local function tab(n, i)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 130, 0, 36)
    b.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    b.BackgroundTransparency = 1
    b.Text = "  " .. i .. "  " .. n
    b.TextColor3 = TGR
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Parent = sdB
    local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0, 6)
    
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = sc
    local tl = Instance.new("UIListLayout", f); tl.Padding = UDim.new(0, 10); tl.SortOrder = Enum.SortOrder.LayoutOrder
    
    TB[n] = b; T[n] = f
    addConn(b.MouseButton1Click:Connect(function()
        for _, x in pairs(T) do x.Visible = false end
        for _, x in pairs(TB) do TweenService:Create(x, TweenInfo.new(0.2), { BackgroundTransparency = 1, TextColor3 = TGR }):Play() end
        f.Visible = true
        TweenService:Create(b, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(130, 80, 255), BackgroundTransparency = 0.1, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    end))
    return f
end

local function search()
    local q = string.lower(sb.Text)
    for _, t in pairs(T) do
        for _, c in ipairs(t:GetChildren()) do
            if c:IsA("Frame") and string.find(c.Name, "SEC_") then
                local ah = true
                for _, sc2 in ipairs(c:GetChildren()) do
                    if sc2:IsA("Frame") or sc2:IsA("TextButton") then
                        if sc2.Name ~= "UIListLayout" and sc2.Name ~= "UIPadding" and sc2.Name ~= "UICorner" and sc2.Name ~= "UIStroke" then
                            if q == "" or string.find(string.lower(sc2.Name), q) or (sc2.Name == "TrackBtn" and string.find(string.lower(sc2.Parent.Name), q)) then
                                sc2.Visible = true; ah = false
                            else sc2.Visible = false end
                        end
                    end
                end
                c.Visible = not ah
            end
        end
    end
end
addConn(sb:GetPropertyChangedSignal("Text"):Connect(search))

-- CRIANDO ABAS
local tW = tab("Stage 1", "⚔️")
local sW = sec(tW, "AUTO WIN S1", "🏁")
sW.LayoutOrder = 1
btn(sW, "Auto Win (Stage 1)", function()
    local p = getFinishLine(1)
    if p then safeTweenTeleport(p) else safeTweenTeleport(STAGE1_WIN_POS) end
end)

local tW2 = tab("Stage 2", "🛡️")
local sW2 = sec(tW2, "STAGE 2 TELEPORTS", "🏁")
sW2.LayoutOrder = 1
btn(sW2, "TP Checkpoint 1", function() safeTweenTeleport(STAGE2_CP1_POS) end)
btn(sW2, "TP Checkpoint 2", function() safeTweenTeleport(STAGE2_CP2_POS) end)
btn(sW2, "Auto Win (Stage 2)", function()
    local p = getFinishLine(2)
    if p then safeTweenTeleport(p) else safeTweenTeleport(STAGE2_WIN_POS) end
end)

local tC = tab("Coleta", "💰")
local sC = sec(tC, "AUTO COLLECT", "🪙")
sC.LayoutOrder = 1
local cT = tgl(sC, "Enable Auto Collect", isAutoCollectEnabled, function(s)
    isAutoCollectEnabled = s
    if isAutoCollectEnabled then
        addTask(task.spawn(function()
            while isAutoCollectEnabled do executeCollect(); task.wait(1) end
        end))
    end
    saveConfig(true)
end)

local tE = tab("ESPs", "👁️")
local sE = sec(tE, "ITEM ESP", "✨")
sE.LayoutOrder = 1
local ePT = tgl(sE, "ESP Rokakaka Plant", espRokaPlantActive, function(s) espRokaPlantActive = s; saveConfig(true); cleanESP() end)
local eFT = tgl(sE, "ESP Rokakaka Fruit", espRokaFruitActive, function(s) espRokaFruitActive = s; saveConfig(true); cleanESP() end)
local eAT = tgl(sE, "ESP Arrow", espArrowActive, function(s) espArrowActive = s; saveConfig(true); cleanESP() end)
local eST = tgl(sE, "ESP Arrow Shiny", espShinyActive, function(s) espShinyActive = s; saveConfig(true); cleanESP() end)

local tR = tab("Auto Race", "🏎️")
local sR = sec(tR, "AUTO RACE STAGE 1", "🏁")
sR.LayoutOrder = 1
local aR1 = false
local rT1 = nil
local oW1, oJ1
local rTg1

local function setNoclip(c, s)
    if not c then return end
    if s then
        if not _G.LHub.NoclipStates then _G.LHub.NoclipStates = {} end
        if _G.LHub.NoclipStates[c] then return end
        _G.LHub.NoclipStates[c] = {}
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then _G.LHub.NoclipStates[c][p] = p.CanCollide; p.CanCollide = false end
        end
    else
        if _G.LHub.NoclipStates and _G.LHub.NoclipStates[c] then
            for p, cc in pairs(_G.LHub.NoclipStates[c]) do
                if p and p.Parent then p.CanCollide = cc end
            end
            _G.LHub.NoclipStates[c] = nil
        end
    end
end

local function twn(p, sp, ca, sn)
    local c = LocalPlayer.Character
    if not c or not c.Parent then return false end
    local h = c:FindFirstChild("HumanoidRootPart")
    local hu = c:FindFirstChildOfClass("Humanoid")
    if not h or not hu or hu.Health <= 0 then return false end
    setNoclip(c, true)
    local d = (p - h.Position).Magnitude
    local t = d / sp
    if t < 0.1 then t = 0.1 end
    local tw = TweenService:Create(h, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.new(p) })
    if sn == 1 then rT1 = tw else rT2 = tw end
    tw:Play()
    while tw.PlaybackState == Enum.PlaybackState.Playing do
        if not ca() then
            tw:Cancel()
            setNoclip(c, false)
            if sn == 1 then rT1 = nil else rT2 = nil end
            return false
        end
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
        task.wait()
    end
    if sn == 1 then rT1 = nil else rT2 = nil end
    setNoclip(c, false)
    return true
end

local function sA1()
    if aR1 then return end
    aR1 = true
    addTask(task.spawn(function()
        while aR1 do
            local c = LocalPlayer.Character
            if not c or not c.Parent then task.wait(1); continue end
            local h = c:FindFirstChild("HumanoidRootPart")
            local hu = c:FindFirstChildOfClass("Humanoid")
            if not h or not hu or hu.Health <= 0 then task.wait(1); continue end
            if not oW1 then oW1 = hu.WalkSpeed; oJ1 = hu.JumpPower end
            if Workspace:GetAttribute("MatchStartCutscene") then
                task.wait(1)
            else
                local m = getMapName()
                if isOnTrain() then
                    task.wait(1)
                elseif string.find(string.lower(m), "lobby") then
                    hu.WalkSpeed = 16; hu.PlatformStand = false
                    if (h.Position - LOBBY_POS).Magnitude > 20 then twn(LOBBY_POS, 200, function() return aR1 end, 1) end
                    task.wait(0.5)
                elseif string.find(string.lower(m), "1") or string.find(string.lower(m), "stage 1") then
                    hu.WalkSpeed = 0; hu.PlatformStand = true; hu.AutoRotate = false
                    local tg = {}
                    local mp = Workspace:FindFirstChild("Map")
                    local g = mp and mp:FindFirstChild("Gameplay")
                    local it = g and g:FindFirstChild("Items") and g.Items:FindFirstChild("Spawned")
                    if it then
                        for _, sp in ipairs(ROKA_SPAWNS_S1) do
                            local bi, bp, md = nil, nil, 50
                            for _, i in ipairs(it:GetChildren()) do
                                local n = string.lower(i.Name)
                                if string.find(n, "roka") or string.find(n, "fruit") or string.find(n, "plant") then
                                    local p = i:IsA("BasePart") and i.Position or i:GetPivot().Position
                                    local d = (p - sp).Magnitude
                                    if d < md then md = d; bi = i; bp = i:FindFirstChildWhichIsA("ProximityPrompt", true) end
                                end
                            end
                            if bi and bp and bp.Parent then
                                table.insert(tg, { model = bi, prompt = bp, pos = bi:IsA("BasePart") and bi.Position or bi:GetPivot().Position })
                            end
                        end
                    end
                    table.sort(tg, function(a, b) return (a.pos - h.Position).Magnitude < (b.pos - h.Position).Magnitude end)
                    for _, t in ipairs(tg) do
                        if not aR1 then break end
                        if t.model.Parent ~= nil then
                            local r = RaycastParams.new(); r.FilterDescendantsInstances = { c, t.model }; r.FilterType = Enum.RaycastFilterType.Exclude
                            local rr = Workspace:Raycast(t.pos + Vector3.new(0, 50, 0), Vector3.new(0, -150, 0), r)
                            local s = Vector3.new(t.pos.X, (rr and rr.Position.Y or t.pos.Y) + 3, t.pos.Z)
                            local su = twn(s, 200, function() return aR1 and t.model.Parent ~= nil end, 1)
                            if su then holdPromptInfinitely(t, function() return aR1 end) end
                        end
                    end
                    if aR1 then
                        local f = getFinishLine(1)
                        if f then twn(f, 200, function() return aR1 end, 1) end
                    end
                else
                    task.wait(1)
                end
            end
        end
    end))
end

local function stA1()
    if not aR1 then return end
    aR1 = false
    if rT1 then pcall(function() rT1:Cancel() end) rT1 = nil end
    local c = LocalPlayer.Character
    if c then
        local hu = c:FindFirstChildOfClass("Humanoid")
        local h = c:FindFirstChild("HumanoidRootPart")
        if hu then hu.WalkSpeed = oW1 or 16; hu.JumpPower = oJ1 or 50; hu.PlatformStand = false; hu.AutoRotate = true end
        if h then h.AssemblyLinearVelocity = Vector3.zero; h.AssemblyAngularVelocity = Vector3.zero end
        setNoclip(c, false)
    end
    if rTg1 then rTg1.setState(false) end
end

rTg1 = tgl(sR, "Enable Auto Race (Stage 1)", false, function(s) if s then sA1() else stA1() end end)

local sR2 = sec(tR, "AUTO RACE STAGE 2", "🏁")
sR2.LayoutOrder = 2
local aR2 = false
local rT2 = nil
local oW2, oJ2
local rTg2

local function sA2()
    if aR2 then return end
    aR2 = true
    addTask(task.spawn(function()
        while aR2 do
            local c = LocalPlayer.Character
            if not c or not c.Parent then task.wait(1); continue end
            local h = c:FindFirstChild("HumanoidRootPart")
            local hu = c:FindFirstChildOfClass("Humanoid")
            if not h or not hu or hu.Health <= 0 then task.wait(1); continue end
            if not oW2 then oW2 = hu.WalkSpeed; oJ2 = hu.JumpPower end
            if Workspace:GetAttribute("MatchStartCutscene") then
                task.wait(1)
            else
                local m = getMapName()
                if isOnTrain() then
                    task.wait(1)
                elseif string.find(string.lower(m), "lobby") then
                    task.wait(1)
                elseif string.find(string.lower(m), "2") or string.find(string.lower(m), "stage 2") then
                    hu.WalkSpeed = 0; hu.PlatformStand = true; hu.AutoRotate = false
                    local tg = {}
                    local mp = Workspace:FindFirstChild("Map")
                    local g = mp and mp:FindFirstChild("Gameplay")
                    local it = g and g:FindFirstChild("Items") and g.Items:FindFirstChild("Spawned")
                    if it then
                        for _, sp in ipairs(ROKA_SPAWNS_S2) do
                            local bi, bp, md = nil, nil, 50
                            for _, i in ipairs(it:GetChildren()) do
                                local n = string.lower(i.Name)
                                if string.find(n, "roka") or string.find(n, "fruit") or string.find(n, "plant") then
                                    local p = i:IsA("BasePart") and i.Position or i:GetPivot().Position
                                    local d = (p - sp).Magnitude
                                    if d < md then md = d; bi = i; bp = i:FindFirstChildWhichIsA("ProximityPrompt", true) end
                                end
                            end
                            if bi and bp and bp.Parent then
                                table.insert(tg, { model = bi, prompt = bp, pos = bi:IsA("BasePart") and bi.Position or bi:GetPivot().Position })
                            end
                        end
                    end
                    table.sort(tg, function(a, b) return (a.pos - h.Position).Magnitude < (b.pos - h.Position).Magnitude end)
                    for _, t in ipairs(tg) do
                        if not aR2 then break end
                        if t.model.Parent ~= nil then
                            local r = RaycastParams.new(); r.FilterDescendantsInstances = { c, t.model }; r.FilterType = Enum.RaycastFilterType.Exclude
                            local rr = Workspace:Raycast(t.pos + Vector3.new(0, 50, 0), Vector3.new(0, -150, 0), r)
                            local s = Vector3.new(t.pos.X, (rr and rr.Position.Y or t.pos.Y) + 3, t.pos.Z)
                            local su = twn(s, 400, function() return aR2 and t.model.Parent ~= nil end, 2)
                            if su then holdPromptInfinitely(t, function() return aR2 end) end
                        end
                    end
                    if aR2 then
                        local f = getFinishLine(2)
                        if f then twn(f, 400, function() return aR2 end, 2) end
                    end
                else
                    task.wait(1)
                end
            end
        end
    end))
end

local function stA2()
    if not aR2 then return end
    aR2 = false
    if rT2 then pcall(function() rT2:Cancel() end) rT2 = nil end
    local c = LocalPlayer.Character
    if c then
        local hu = c:FindFirstChildOfClass("Humanoid")
        local h = c:FindFirstChild("HumanoidRootPart")
        if hu then hu.WalkSpeed = oW2 or 16; hu.JumpPower = oJ2 or 50; hu.PlatformStand = false; hu.AutoRotate = true end
        if h then h.AssemblyLinearVelocity = Vector3.zero; h.AssemblyAngularVelocity = Vector3.zero end
        setNoclip(c, false)
    end
    if rTg2 then rTg2.setState(false) end
end

rTg2 = tgl(sR2, "Enable Auto Race (Stage 2)", false, function(s) if s then sA2() else stA2() end end)

local tA = tab("Aimbot", "🎯")
local sA = sec(tA, "MAIN SETTINGS", "⚙️")
sA.LayoutOrder = 1
local aTgT = tgl(sA, "Enable Aimbot", aimbotEnabled, function(s)
    aimbotEnabled = s
    if not s then
        local cam = Workspace.CurrentCamera
        if cam then cam.CameraType = Enum.CameraType.Custom end
        aHl.Enabled = false
    end
    saveConfig(true)
end)
local fT = tgl(sA, "FOV Circle", fovCircleOn, function(s) fovCircleOn = s; fC.Visible = s; saveConfig(true) end)
local tT = tgl(sA, "Turn Character", aimbotTurnChar, function(s) aimbotTurnChar = s; saveConfig(true) end)
local dT = tgl(sA, "Strong Dash", dashStrong, function(s) dashStrong = s; saveConfig(true) end)

local sAC = sec(tA, "AIMBOT CONFIG", "🔧")
sAC.LayoutOrder = 2
local fR = row(sAC, "FOV Size", 30, 500, 15, aimbotFov, function(v) aimbotFov = v; fC.Radius = aimbotFov; saveConfig(true) end)
fR.row.LayoutOrder = 2
local cR = row(sAC, "Height", -6, 30, 2, aimCamHeight, function(v) aimCamHeight = v; saveConfig(true) end)
cR.row.LayoutOrder = 3
local lR = row(sAC, "Side (Yaw)", -10, 10, 0.25, aimYawOff, function(v) aimYawOff = v; saveConfig(true) end)
lR.row.LayoutOrder = 4
local vR = row(sAC, "Vertical (Pitch)", -10, 10, 0.25, aimPitchOff, function(v) aimPitchOff = v; saveConfig(true) end)
vR.row.LayoutOrder = 5

local tgL = Instance.new("TextLabel", sAC)
tgL.Size = UDim2.new(1, 0, 0, 20); tgL.BackgroundTransparency = 1; tgL.Text = "Target: none"; tgL.TextColor3 = Color3.fromRGB(255, 100, 100); tgL.Font = Enum.Font.GothamBold; tgL.TextSize = 11; tgL.TextXAlignment = Enum.TextXAlignment.Left; tgL.LayoutOrder = 6
addTask(task.spawn(function()
    while true do
        task.wait(0.5)
        if aTg and aTg.Parent then
            tgL.Text = "Target: " .. aTg.Name
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Character == aTg then tgL.Text = "Target: " .. pl.DisplayName; break end
            end
        else
            tgL.Text = "Target: none"
        end
    end
end))

local tK = tab("TP Kill", "💀")
local sK = sec(tK, "PLAYER LIST", "👤")
sK.LayoutOrder = 1

local sbK = Instance.new("TextBox")
sbK.Size = UDim2.new(1, 0, 0, 30); sbK.BackgroundColor3 = Color3.fromRGB(20, 20, 28); sbK.BackgroundTransparency = 0.2
sbK.TextColor3 = TW; sbK.PlaceholderText = "🔍 Buscar jogador..."; sbK.PlaceholderColor3 = TGR; sbK.Font = Enum.Font.Gotham; sbK.TextSize = 12; sbK.Parent = sK
local sbKc = Instance.new("UICorner", sbK); sbKc.CornerRadius = UDim.new(0, 6)
local sbKs = Instance.new("UIStroke", sbK); sbKs.Color = Color3.fromRGB(50, 50, 70)

local sf = Instance.new("ScrollingFrame")
sf.Size = UDim2.new(1, 0, 0, 120); sf.BackgroundColor3 = Color3.fromRGB(15, 15, 20); sf.BackgroundTransparency = 0.4
sf.BorderSizePixel = 0; sf.ScrollBarThickness = 2; sf.ScrollBarImageColor3 = Color3.fromRGB(130, 80, 255); sf.CanvasSize = UDim2.new(0, 0, 0, 0); sf.Parent = sK
local sfc = Instance.new("UICorner", sf); sfc.CornerRadius = UDim.new(0, 6)
local sfl = Instance.new("UIListLayout", sf); sfl.Padding = UDim.new(0, 4)
addConn(sfl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sf.CanvasSize = UDim2.new(0, 0, 0, sfl.AbsoluteContentSize.Y + 4) end))

local sP = nil
local function upL()
    for _, c in ipairs(sf:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -4, 0, 34); b.BackgroundColor3 = EBC; b.BackgroundTransparency = 0.5; b.Text = ""; b.Name = pl.Name; b.Parent = sf
            local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0, 6)
            local s = Instance.new("UIStroke", b); s.Color = Color3.fromRGB(50, 50, 70)
            
            local i = Instance.new("ImageLabel", b)
            i.Size = UDim2.new(0, 26, 0, 26); i.Position = UDim2.new(0, 4, 0.5, -13); i.BackgroundColor3 = BGC
            i.Image = "rbxthumb://type=AvatarHeadShot&id=" .. pl.UserId .. "&w=48&h=48"
            local ic = Instance.new("UICorner", i); ic.CornerRadius = UDim.new(1, 0)
            
            local t = Instance.new("TextLabel", b)
            t.Size = UDim2.new(1, -35, 1, 0); t.Position = UDim2.new(0, 34, 0, 0); t.BackgroundTransparency = 1
            t.Text = pl.DisplayName .. " (@" .. pl.Name .. ")"; t.TextColor3 = TW; t.Font = Enum.Font.Gotham; t.TextSize = 12; t.TextXAlignment = Enum.TextXAlignment.Left
            
            addConn(b.MouseButton1Click:Connect(function()
                for _, o in ipairs(sf:GetChildren()) do
                    if o:IsA("TextButton") then o.BackgroundColor3 = EBC; o.UIStroke.Color = Color3.fromRGB(50, 50, 70) end
                end
                b.BackgroundColor3 = Color3.fromRGB(130, 80, 255); t.TextColor3 = BGC; sP = pl
            end))
        end
    end
end

upL()
addConn(Players.PlayerAdded:Connect(upL))
addConn(Players.PlayerRemoving:Connect(function(pl)
    if sP == pl then sP = nil end
    task.defer(upL)
end))

addConn(sbK:GetPropertyChangedSignal("Text"):Connect(function()
    local q = string.lower(sbK.Text)
    for _, c in ipairs(sf:GetChildren()) do
        if c:IsA("TextButton") then
            local pl = Players:FindFirstChild(c.Name)
            if pl then
                local un = string.lower(pl.Name); local di = string.lower(pl.DisplayName)
                if q == "" or string.find(un, q) or string.find(di, q) then c.Visible = true else c.Visible = false end
            end
        end
    end
end))

local tKR = row(sK, "Offset (Studs)", -20, 20, 1, tpKillHeight, function(v) tpKillHeight = v; saveConfig(true) end)
tKR.row.LayoutOrder = 2

local tp = { active = false, sCF = nil, sW = nil, sJ = nil, sR = nil, tween = nil, fC = nil }
local kBtn

local function setKB(a)
    if not kBtn then return end
    local s = kBtn:FindFirstChildOfClass("UIStroke")
    if a then
        kBtn.Text = "STOP KILL (ACTIVE)"; kBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        if s then s.Color = Color3.fromRGB(255, 80, 80) end
    else
        kBtn.Text = "Kill Player (Toggle)"; kBtn.TextColor3 = TW
        if s then s.Color = Color3.fromRGB(50, 50, 70) end
    end
end

local function stK()
    if not tp.active then return end
    tp.active = false
    if tp.fC then pcall(function() tp.fC:Disconnect() end) tp.fC = nil end
    if tp.tween then pcall(function() tp.tween:Cancel() end) tp.tween = nil end
    local c = LocalPlayer.Character
    if c and c.Parent then
        local h = c:FindFirstChild("HumanoidRootPart")
        local hu = c:FindFirstChildOfClass("Humanoid")
        if hu then hu.WalkSpeed = tp.sW or 16; hu.JumpPower = tp.sJ or 50; hu.AutoRotate = (tp.sR ~= false) end
        if h and tp.sCF then
            h.AssemblyLinearVelocity = Vector3.zero; h.AssemblyAngularVelocity = Vector3.zero
            local b = TweenService:Create(h, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = tp.sCF })
            b:Play(); b.Completed:Wait()
            h.AssemblyLinearVelocity = Vector3.zero; h.AssemblyAngularVelocity = Vector3.zero
        end
    end
    tp.sCF = nil; tp.sW = nil; tp.sJ = nil; tp.sR = nil
    setKB(false)
end

local function sK()
    if tp.active then return end
    if not sP or not sP.Character then return toast("Selecione um jogador!", Color3.fromRGB(255, 50, 50)) end
    local th = sP.Character:FindFirstChild("HumanoidRootPart")
    if not th then return toast("Alvo inválido!", Color3.fromRGB(255, 50, 50)) end
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    local hu = c and c:FindFirstChildOfClass("Humanoid")
    if not h or not hu or hu.Health <= 0 then return end
    
    tp.active = true
    tp.sCF = h.CFrame; tp.sW = hu.WalkSpeed; tp.sJ = hu.JumpPower; tp.sR = hu.AutoRotate
    hu.WalkSpeed = 0; hu.JumpPower = 0; hu.AutoRotate = false
    h.AssemblyLinearVelocity = Vector3.zero; h.AssemblyAngularVelocity = Vector3.zero
    
    local tc = th.CFrame * CFrame.new(0, -tpKillHeight, 0) * CFrame.Angles(math.rad(90), 0, 0)
    tp.tween = TweenService:Create(h, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = tc })
    tp.tween:Play(); setKB(true)
    
    local tt = tp.tween
    addTask(task.spawn(function()
        tt.Completed:Wait()
        if not tp.active then return end
        tp.fC = RunService.Heartbeat:Connect(function()
            if not tp.active then return end
            if not sP or not sP.Character then task.defer(stK); return end
            local cth = sP.Character:FindFirstChild("HumanoidRootPart")
            if not cth then return end
            h.CFrame = cth.CFrame * CFrame.new(0, -tpKillHeight, 0) * CFrame.Angles(math.rad(90), 0, 0)
            h.AssemblyLinearVelocity = Vector3.zero; h.AssemblyAngularVelocity = Vector3.zero
        end)
    end))
end

kBtn = btn(sK, "Kill Player (Toggle)", function() if tp.active then stK() else sK() end end)
kBtn.LayoutOrder = 3

local tCfg = tab("Config", "⚙️")
local sCfg = sec(tCfg, "SYSTEM SETTINGS", "💾")
sCfg.LayoutOrder = 1
btn(sCfg, "Save Settings", function() saveConfig(false); toast("Saved Successfully!", Color3.fromRGB(130, 80, 255)) end)

local rBtn = btn(sCfg, "Reset to Default", function()
    if delfile then pcall(function() delfile(CONFIG_FILE) end) end
    aimbotEnabled = false; aimbotFov = 120; aimbotTurnChar = true; dashStrong = true; aimCamHeight = 8; aimYawOff = 0; aimPitchOff = 0
    isAutoCollectEnabled = false; fovCircleOn = false; tpKillHeight = 6
    pcall(stK); pcall(stA1); pcall(stA2)
    cT.setState(false, true); aTgT.setState(false, true); fT.setState(false, true); tT.setState(true, true); dT.setState(true, true)
    ePT.setState(false, true); eFT.setState(false, true); eAT.setState(false, true); eST.setState(false, true)
    espRokaPlantActive = false; espRokaFruitActive = false; espArrowActive = false; espShinyActive = false
    cleanESP()
    fR.update(120); cR.update(8); lR.update(0); vR.update(0); tKR.update(6)
    fC.Visible = false; fC.Radius = 120
    aimbotFloatBtn.Position = UDim2.new(0.85, 0, 0.55, 0)
    local c = LocalPlayer.Character
    if c and c.Parent then
        local h = c:FindFirstChild("HumanoidRootPart")
        local hu = c:FindFirstChildOfClass("Humanoid")
        if hu then hu.WalkSpeed = 16; hu.JumpPower = 50; hu.PlatformStand = false; hu.AutoRotate = true end
        if h then h.AssemblyLinearVelocity = Vector3.zero; h.AssemblyAngularVelocity = Vector3.zero end
    end
    local cam = Workspace.CurrentCamera
    if cam then cam.CameraType = Enum.CameraType.Custom end
    saveConfig(false); toast("Settings Reset!", Color3.fromRGB(255, 100, 100))
end)

TB["Stage 1"].BackgroundColor3 = Color3.fromRGB(130, 80, 255)
TB["Stage 1"].BackgroundTransparency = 0.1
TB["Stage 1"].TextColor3 = Color3.fromRGB(255, 255, 255)
T["Stage 1"].Visible = true

addConn(fb.MouseButton1Click:Connect(function() mf.Visible = not mf.Visible end))

local dr, di, ds, sp
local function updDrag(i)
    if dr and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - ds
        mf.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
    end
end
addConn(tb.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dr = true; ds = i.Position; sp = mf.Position
        addConn(i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dr = false end end))
    end
end))
addConn(UserInputService.InputChanged:Connect(updDrag))

aimbotFloatBtn = Instance.new("Frame")
aimbotFloatBtn.Size = UDim2.new(0, 60, 0, 60)
aimbotFloatBtn.Position = UDim2.new(config.floatBtnPosXScale, config.floatBtnPosXOffset, config.floatBtnPosYScale, config.floatBtnPosYOffset)
aimbotFloatBtn.BackgroundColor3 = EBC
aimbotFloatBtn.BackgroundTransparency = 0.2
aimbotFloatBtn.Parent = sg
local aIc = Instance.new("UICorner", aimbotFloatBtn); aIc.CornerRadius = UDim.new(1, 0)
local aIs = Instance.new("UIStroke", aimbotFloatBtn); aIs.Color = Color3.fromRGB(130, 80, 255); aIs.Thickness = 2

local aIt = Instance.new("TextLabel", aimbotFloatBtn)
aIt.Size = UDim2.new(1, 0, 1, 0); aIt.BackgroundTransparency = 1; aIt.Text = "⊕"; aIt.TextColor3 = Color3.fromRGB(130, 80, 255); aIt.Font = Enum.Font.GothamBold; aIt.TextSize = 28
aIt.Parent = aimbotFloatBtn

addTask(task.spawn(function()
    local t = 0
    while true do
        t += 0.05
        local s = 1 + math.sin(t) * (aimbotEnabled and 0.05 or 0.02)
        aimbotFloatBtn.Size = UDim2.new(0, math.round(60 * s), 0, math.round(60 * s))
        task.wait(0.03)
    end
end))

local aI = nil
local aD = false
local aDs, aSp
addConn(aimbotFloatBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        if aI ~= nil then return end
        aI = i; aD = false; aDs = i.Position; aSp = aimbotFloatBtn.Position
    end
end))
addConn(UserInputService.InputChanged:Connect(function(i)
    if i ~= aI then return end
    local d = i.Position - aDs
    if d.Magnitude > 6 then aD = true end
    if aD then aimbotFloatBtn.Position = UDim2.new(aSp.X.Scale, aSp.X.Offset + d.X, aSp.Y.Scale, aSp.Y.Offset + d.Y) end
end))
addConn(aimbotFloatBtn.InputEnded:Connect(function(i)
    if i ~= aI then return end
    aI = nil
    if not aD then
        aimbotEnabled = not aimbotEnabled
        aTgT.setState(aimbotEnabled)
        aIs.Color = aimbotEnabled and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(130, 80, 255)
        saveConfig(true)
    else
        saveConfig(true)
    end
    aD = false; aDs = nil
end))
