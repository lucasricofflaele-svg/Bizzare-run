-- L HUB v88 | Mobile UI shell (visual-only)
-- LocalScript / executor-compatible Roblox Luau UI example.
-- This file contains presentation, navigation and demo controls only.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("LHub_v88_UI")
if old then old:Destroy() end

local C = {
    bg = Color3.fromRGB(12, 12, 19), panel = Color3.fromRGB(20, 19, 31),
    card = Color3.fromRGB(28, 26, 42), card2 = Color3.fromRGB(34, 30, 52),
    purple = Color3.fromRGB(151, 91, 255), purple2 = Color3.fromRGB(104, 64, 205),
    white = Color3.fromRGB(244, 241, 255), muted = Color3.fromRGB(154, 148, 177),
    green = Color3.fromRGB(91, 220, 157), line = Color3.fromRGB(65, 54, 91), red = Color3.fromRGB(255, 105, 125)
}
local function make(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function corner(parent, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, parent)
end
local function stroke(parent, color, transparency, thickness)
    make("UIStroke", {Color = color or C.line, Transparency = transparency or 0.35, Thickness = thickness or 1}, parent)
end
local function label(parent, text, size, color, font)
    return make("TextLabel", {BackgroundTransparency = 1, Text = text, TextColor3 = color or C.white,
        TextSize = size or 14, Font = font or Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true}, parent)
end

local gui = make("ScreenGui", {Name = "LHub_v88_UI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
local shade = make("Frame", {Name="Backdrop", Size=UDim2.fromScale(1,1), BackgroundColor3=Color3.new(0,0,0), BackgroundTransparency=0.42, BorderSizePixel=0}, gui)
local main = make("Frame", {Name="Main", AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), Size=UDim2.fromScale(.92,.78), BackgroundColor3=C.bg, BorderSizePixel=0, ClipsDescendants=true}, shade)
corner(main, 18); stroke(main, C.purple, .18, 1.4)
local sizeConstraint = make("UISizeConstraint", {MinSize=Vector2.new(290,350), MaxSize=Vector2.new(760,650)}, main)
local scale = make("UIScale", {Scale=1}, main)

local top = make("Frame", {Size=UDim2.new(1,0,0,58), BackgroundColor3=C.panel, BorderSizePixel=0}, main)
local brandMark = make("Frame", {Position=UDim2.new(0,14,0,13), Size=UDim2.fromOffset(32,32), BackgroundColor3=C.purple, BorderSizePixel=0}, top)
corner(brandMark, 10)
label(brandMark, "L", 19, C.white, Enum.Font.GothamBlack).Size=UDim2.fromScale(1,1)
local title = label(top, "L HUB", 17, C.white, Enum.Font.GothamBold)
title.Position=UDim2.new(0,56,0,7); title.Size=UDim2.new(1,-116,0,23)
local subtitle = label(top, "MOBILE INTERFACE  •  v88", 9, C.muted, Enum.Font.GothamMedium)
subtitle.Position=UDim2.new(0,57,0,31); subtitle.Size=UDim2.new(1,-120,0,15)
local close = make("TextButton", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-12,.5,0), Size=UDim2.fromOffset(34,34), BackgroundColor3=C.card2, Text="×", TextColor3=C.white, TextSize=23, Font=Enum.Font.Gotham, AutoButtonColor=true}, top)
corner(close, 10)

local tabsBar = make("ScrollingFrame", {Name="Tabs", Position=UDim2.new(0,10,0,66), Size=UDim2.new(1,-20,0,42), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=0, ScrollingDirection=Enum.ScrollingDirection.X, CanvasSize=UDim2.new(0,0,0,0)}, main)
local tabLayout = make("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,7), SortOrder=Enum.SortOrder.LayoutOrder}, tabsBar)
local tabPad = make("UIPadding", {PaddingLeft=UDim.new(0,1), PaddingRight=UDim.new(0,1)}, tabsBar)

local content = make("ScrollingFrame", {Name="Content", Position=UDim2.new(0,12,0,116), Size=UDim2.new(1,-24,1,-128), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=3, ScrollBarImageColor3=C.purple, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y}, main)
make("UIPadding", {PaddingBottom=UDim.new(0,12), PaddingTop=UDim.new(0,2), PaddingLeft=UDim.new(0,1), PaddingRight=UDim.new(0,5)}, content)
local contentLayout = make("UIListLayout", {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder}, content)

local function clearContent()
    for _, child in ipairs(content:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
    end
end
local function sectionHeader(text)
    local wrap = make("Frame", {Size=UDim2.new(1,0,0,28), BackgroundTransparency=1}, content)
    local accent = make("Frame", {Size=UDim2.fromOffset(4,18), Position=UDim2.new(0,0,.5,-9), BackgroundColor3=C.purple, BorderSizePixel=0}, wrap); corner(accent,3)
    local t = label(wrap, text, 14, C.white, Enum.Font.GothamBold); t.Position=UDim2.new(0,13,0,0); t.Size=UDim2.new(1,-13,1,0)
end
local function infoCard(titleText, desc, tag)
    local card = make("Frame", {Size=UDim2.new(1,0,0,76), BackgroundColor3=C.card, BorderSizePixel=0}, content)
    corner(card, 13); stroke(card, C.line, .55, 1)
    local icon = make("Frame", {Position=UDim2.new(0,11,0,13), Size=UDim2.fromOffset(38,38), BackgroundColor3=C.card2, BorderSizePixel=0}, card); corner(icon, 11)
    label(icon, "✦", 19, C.purple).Size=UDim2.fromScale(1,1)
    local t = label(card, titleText, 13, C.white, Enum.Font.GothamBold); t.Position=UDim2.new(0,59,0,10); t.Size=UDim2.new(1,-72,0,21)
    local d = label(card, desc, 10, C.muted); d.Position=UDim2.new(0,59,0,33); d.Size=UDim2.new(1,-72,0,30); d.TextYAlignment=Enum.TextYAlignment.Top
    if tag then
        local badge = make("TextLabel", {AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-10,0,10), Size=UDim2.fromOffset(58,19), BackgroundColor3=C.purple2, BackgroundTransparency=.35, Text=tag, TextColor3=C.white, TextSize=9, Font=Enum.Font.GothamBold}, card)
        corner(badge, 7)
        t.Size=UDim2.new(1,-140,0,21)
    end
end
local function demoToggle(titleText, description)
    local row = make("Frame", {Size=UDim2.new(1,0,0,66), BackgroundColor3=C.card, BorderSizePixel=0}, content)
    corner(row, 12); stroke(row, C.line, .65, 1)
    local t=label(row,titleText,12,C.white,Enum.Font.GothamBold); t.Position=UDim2.new(0,12,0,8); t.Size=UDim2.new(1,-82,0,20)
    local d=label(row,description,9,C.muted); d.Position=UDim2.new(0,12,0,30); d.Size=UDim2.new(1,-82,0,25); d.TextYAlignment=Enum.TextYAlignment.Top
    local pill=make("TextButton", {AnchorPoint=Vector2.new(1,.5), Position=UDim2.new(1,-12,.5,0), Size=UDim2.fromOffset(48,27), BackgroundColor3=C.card2, Text="OFF", TextColor3=C.muted, TextSize=9, Font=Enum.Font.GothamBold}, row)
    corner(pill, 14)
    local enabled=false
    pill.Activated:Connect(function()
        enabled=not enabled
        pill.Text=enabled and "ON" or "OFF"
        pill.BackgroundColor3=enabled and C.purple2 or C.card2
        pill.TextColor3=enabled and C.white or C.muted
    end)
end

local pages = {
    Home = function()
        sectionHeader("WELCOME BACK")
        local hero=make("Frame", {Size=UDim2.new(1,0,0,112), BackgroundColor3=C.card2, BorderSizePixel=0}, content); corner(hero,15); stroke(hero,C.purple,.45,1)
        local h=label(hero,"L HUB",22,C.white,Enum.Font.GothamBlack); h.Position=UDim2.new(0,15,0,13); h.Size=UDim2.new(1,-30,0,30)
        local p=label(hero,"Uma interface reorganizada para telas touch.",11,C.muted); p.Position=UDim2.new(0,16,0,47); p.Size=UDim2.new(1,-32,0,24)
        local status=make("TextLabel", {Position=UDim2.new(0,15,0,79), Size=UDim2.fromOffset(100,21), BackgroundColor3=Color3.fromRGB(30,78,62), Text="●  INTERFACE OK", TextColor3=C.green, TextSize=9, Font=Enum.Font.GothamBold}, hero); corner(status,7)
        sectionHeader("QUICK OVERVIEW")
        infoCard("Touch layout","Botões e abas dimensionados para toque.","MOBILE")
        infoCard("Clean design","Cartões, espaçamento e hierarquia visual consistentes.","UI")
        infoCard("Navigation","Abas horizontais com rolagem lateral.","READY")
    end,
    Visual = function()
        sectionHeader("VISUAL PREFERENCES")
        infoCard("Purple neon","Paleta escura com detalhes roxos e contraste suave.","THEME")
        infoCard("Compact cards","Cartões adaptados à largura disponível.","LAYOUT")
        demoToggle("Exemplo de alternância","Controle demonstrativo, sem ação no jogo.")
    end,
    Settings = function()
        sectionHeader("INTERFACE SETTINGS")
        demoToggle("Animações da interface","Demonstração visual de um controle touch.")
        demoToggle("Compact mode","Exemplo de opção visual local.")
        infoCard("Dica mobile","Use o botão × para fechar e o botão L para reabrir.","TIP")
    end,
    About = function()
        sectionHeader("ABOUT L HUB")
        infoCard("L HUB v88","Shell visual independente, focado em celulares.","VERSION")
        infoCard("Compatibility","Usa ScreenGui, botões Activated e layout responsivo.","TOUCH")
    end
}
local tabButtons={}
local activeTab
local function showPage(name)
    if not pages[name] then return end
    activeTab=name; clearContent(); pages[name]()
    for tabName, button in pairs(tabButtons) do
        local selected=tabName==name
        button.BackgroundColor3=selected and C.purple2 or C.card
        button.TextColor3=selected and C.white or C.muted
        button.BackgroundTransparency=selected and .05 or .1
    end
    content.CanvasPosition=Vector2.zero
end
for i,name in ipairs({"Home","Visual","Settings","About"}) do
    local b=make("TextButton", {Name=name, Size=UDim2.fromOffset(94,36), BackgroundColor3=C.card, BackgroundTransparency=.1, BorderSizePixel=0, Text=name, TextColor3=C.muted, TextSize=11, Font=Enum.Font.GothamBold, LayoutOrder=i, AutoButtonColor=true}, tabsBar)
    corner(b,10); tabButtons[name]=b
    b.Activated:Connect(function() showPage(name) end)
end
local function updateLayout()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local v=camera.ViewportSize
    local short=math.min(v.X,v.Y)
    if short < 500 then scale.Scale=.82 elseif short < 700 then scale.Scale=.92 else scale.Scale=1 end
    if v.X < v.Y then
        main.Size=UDim2.fromScale(.94,.82)
    else
        main.Size=UDim2.fromScale(.78,.88)
    end
    sizeConstraint.MinSize=Vector2.new(280,330)
end
updateLayout()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout) end
local function closeUI() shade.Visible=false end
close.Activated:Connect(closeUI)

-- Small floating reopen button, movable by touch or mouse.
local reopen=make("TextButton", {Name="LHubReopen", AnchorPoint=Vector2.new(0,0), Position=UDim2.new(.04,0,.42,0), Size=UDim2.fromOffset(48,48), BackgroundColor3=C.purple2, Text="L", TextColor3=C.white, TextSize=22, Font=Enum.Font.GothamBlack, Visible=true}, gui)
corner(reopen,16); stroke(reopen,C.white,.65,1)
reopen.Activated:Connect(function() shade.Visible=not shade.Visible end)
local dragging=false; local dragStart; local startPosition
reopen.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true; dragStart=input.Position; startPosition=reopen.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
        local delta=input.Position-dragStart
        reopen.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+delta.X,startPosition.Y.Scale,startPosition.Y.Offset+delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
showPage("Home")
print("[L HUB v88] Mobile UI loaded")
