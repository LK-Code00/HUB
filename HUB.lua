-- ZYON HUB v4 | Roblox Luau | Mobile
-- Enemy ESP, friend/team filter, always-on smooth aim, adjustable sensitivity

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local Workspace = game:GetService('Workspace')
local LP = Players.LocalPlayer
assert(LP, 'This script must run on the client')
local PlayerGui = LP:WaitForChild('PlayerGui')
local env = (type(getgenv) == 'function' and getgenv()) or _G
if env.ZyonHub and type(env.ZyonHub.Stop) == 'function' then
    pcall(env.ZyonHub.Stop)
end

local settings = {
    ESP = true, Aim = true, IgnoreFriends = true, IgnoreTeam = true,
    VisibleOnly = true, Smoothness = 9, FOV = 0.23,
    MaxDistance = 350, ESPInterval = 0.3, TargetInterval = 0.12,
}
local color = {
    bg = Color3.fromRGB(15,17,25), panel = Color3.fromRGB(29,30,43),
    purple = Color3.fromRGB(151,99,255), green = Color3.fromRGB(40,210,126),
    red = Color3.fromRGB(255,54,72), white = Color3.fromRGB(242,241,252),
    muted = Color3.fromRGB(160,160,178)
}
local hub = {Running=true, Minimized=false, Target=nil,
    Friends={}, Highlights={}, Connections={}}
env.ZyonHub = hub

local function bind(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(hub.Connections, connection)
    return connection
end
local function create(class, props, parent)
    local obj = Instance.new(class)
    for property, value in pairs(props) do obj[property] = value end
    obj.Parent = parent
    return obj
end
local function corner(obj, radius)
    create('UICorner', {CornerRadius=UDim.new(0,radius)}, obj)
end
local function outline(obj)
    create('UIStroke', {Color=color.purple, Transparency=0.3, Thickness=1.5}, obj)
end
local function label(parent, text, x,y,w,h,size, hue)
    return create('TextLabel', {Text=text, BackgroundTransparency=1,
        Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
        TextColor3=hue, TextSize=size, Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left}, parent)
end

local function registerFriend(player)
    if player == LP then return end
    local id = player.UserId
    if hub.Friends[id] ~= nil then return end
    if not settings.IgnoreFriends then hub.Friends[id]='other'; return end
    hub.Friends[id]='pending'
    task.spawn(function()
        local ok, value = pcall(function()
            return LP:IsFriendsWithAsync(id)
        end)
        if hub.Running and player.Parent==Players then
            hub.Friends[id] = ok and (value and 'friend' or 'other') or 'unknown'
        end
    end)
end
local function enemy(player)
    if player == LP or player.Parent ~= Players then return false end
    if settings.IgnoreFriends and hub.Friends[player.UserId] ~= 'other' then
        return false
    end
    if settings.IgnoreTeam and not LP.Neutral and not player.Neutral
        and LP.Team ~= nil and LP.Team == player.Team then
        return false
    end
    return true
end
local function clearHighlight(player)
    local highlight=hub.Highlights[player]
    if highlight then highlight:Destroy(); hub.Highlights[player]=nil end
end
local function updateHighlight(player)
    if not settings.ESP or not enemy(player) then
        clearHighlight(player); return false
    end
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass('Humanoid')
    if not char or not humanoid or humanoid.Health <= 0 then
        clearHighlight(player); return false
    end
    local highlight=hub.Highlights[player]
    if not highlight then
        highlight=create('Highlight', {
            Name='ZyonEnemyRed', FillColor=color.red,
            OutlineColor=color.red, FillTransparency=0.55,
            OutlineTransparency=0, DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        }, PlayerGui)
        hub.Highlights[player]=highlight
    end
    highlight.Adornee=char
    highlight.Enabled=true
    return true
end

local rayParams=RaycastParams.new()
rayParams.FilterType=Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater=true
local function visible(camera, part)
    if not settings.VisibleOnly then return true end
    rayParams.FilterDescendantsInstances = LP.Character and {LP.Character} or {}
    local origin=camera.CFrame.Position
    local result=Workspace:Raycast(origin,part.Position-origin,rayParams)
    return result == nil or result.Instance:IsDescendantOf(part.Parent)
end
local function aimPart(player)
    if not enemy(player) then return nil end
    local char=player.Character
    local humanoid=char and char:FindFirstChildOfClass('Humanoid')
    if not humanoid or humanoid.Health <= 0 then return nil end
    return char:FindFirstChild('Head') or char:FindFirstChild('HumanoidRootPart')
end
local function findTarget()
    local camera=Workspace.CurrentCamera
    if not camera then return nil end
    local viewport=camera.ViewportSize
    local mid=viewport*0.5
    local radius=math.min(viewport.X,viewport.Y)*settings.FOV
    local best=radius*radius
    local closest=nil
    for _, player in ipairs(Players:GetPlayers()) do
        local part=aimPart(player)
        if part and (part.Position-camera.CFrame.Position).Magnitude <= settings.MaxDistance then
            local screen, onScreen=camera:WorldToViewportPoint(part.Position)
            if onScreen and screen.Z > 0 then
                local dx,dy=screen.X-mid.X,screen.Y-mid.Y
                local distanceSquared=dx*dx+dy*dy
                if distanceSquared<best and visible(camera,part) then
                    best=distanceSquared
                    closest=part
                end
            end
        end
    end
    return closest
end

-- Screen and hub panel
local screen=create('ScreenGui', {Name='ZyonHubV4', ResetOnSpawn=false,
    IgnoreGuiInset=false, DisplayOrder=1000,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, PlayerGui)
hub.Screen=screen
local W,H=344,388
local main=create('Frame',{Name='Hub',Active=true,BackgroundColor3=color.bg,
    BorderSizePixel=0,Size=UDim2.fromOffset(W,H),Position=UDim2.fromOffset(18,65)},screen)
corner(main,19); outline(main)
local mainScale=create('UIScale',{Scale=1},main)
local header=create('Frame',{Active=true,BackgroundTransparency=1,
    Size=UDim2.new(1,0,0,55)},main)
local heading=label(header,'ZYON HUB',17,9,188,35,21,color.purple)
heading.Font=Enum.Font.GothamBold
local function button(parent,text,x,y,w,h,hue)
    local btn=create('TextButton',{Text=text,Font=Enum.Font.GothamBold,
        TextSize=18,TextColor3=color.white,BackgroundColor3=hue,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BorderSizePixel=0,Active=true},parent)
    corner(btn,10)
    return btn
end
local minus=button(header,'−',W-84,10,34,34,color.panel)
local close=button(header,'×',W-44,10,34,34,color.panel)
close.TextColor3=color.red
create('Frame',{BackgroundColor3=color.purple,BackgroundTransparency=0.5,
    BorderSizePixel=0,Position=UDim2.fromOffset(15,55),
    Size=UDim2.new(1,-30,0,1)},main)
local function switch(text,desc,y,active)
    local card=create('Frame',{BackgroundColor3=color.panel,BorderSizePixel=0,
        Position=UDim2.fromOffset(14,y),Size=UDim2.new(1,-28,0,67)},main)
    corner(card,12)
    local title=label(card,text,12,6,200,25,15,color.white)
    title.Font=Enum.Font.GothamBold
    label(card,desc,12,38,280,18,11,color.muted)
    local toggle=button(card,active and 'ON' or 'OFF',W-89,9,49,28,
        active and color.green or color.red)
    toggle.TextSize=13; toggle.TextColor3=color.bg
    return toggle
end
local espSwitch=switch('ENEMY ESP','Inimigos em vermelho; amigos ocultos',67,settings.ESP)
local aimSwitch=switch('AUTO AIM','Ativo continuamente quando ligado',143,settings.Aim)
-- Sensibilidade da mira: 1 = lento/suave, 20 = rapido
local sensitivityCard=create('Frame',{
    BackgroundColor3=color.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(14,218),Size=UDim2.new(1,-28,0,88)
},main)
corner(sensitivityCard,12)
local sensitivityTitle=label(sensitivityCard,'SENSIBILIDADE',12,7,210,24,14,color.white)
sensitivityTitle.Font=Enum.Font.GothamBold
local sensitivityValue=label(sensitivityCard,tostring(settings.Smoothness),261,7,41,24,14,color.purple)
sensitivityValue.Font=Enum.Font.GothamBold
sensitivityValue.TextXAlignment=Enum.TextXAlignment.Right
local sensitivityTrack=create('TextButton',{
    Text='',AutoButtonColor=false,Active=true,
    BackgroundColor3=color.bg,BorderSizePixel=0,
    Position=UDim2.fromOffset(17,44),Size=UDim2.new(1,-34,0,13)
},sensitivityCard)
corner(sensitivityTrack,7)
local sensitivityFill=create('Frame',{
    Active=false,BackgroundColor3=color.purple,BorderSizePixel=0,
    Size=UDim2.fromScale(0,1)
},sensitivityTrack)
corner(sensitivityFill,7)
local sensitivityKnob=create('Frame',{
    Active=false,BackgroundColor3=color.white,BorderSizePixel=0,
    AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(19,19),
    Position=UDim2.fromScale(0,0.5)
},sensitivityTrack)
corner(sensitivityKnob,10)
label(sensitivityCard,'SUAVE',17,63,80,17,10,color.muted)
local fastLabel=label(sensitivityCard,'RAPIDO',220,63,80,17,10,color.muted)
fastLabel.TextXAlignment=Enum.TextXAlignment.Right

local function setSensitivity(value)
    settings.Smoothness=math.clamp(math.floor(value+0.5),1,20)
    local fraction=(settings.Smoothness-1)/19
    sensitivityFill.Size=UDim2.fromScale(fraction,1)
    sensitivityKnob.Position=UDim2.fromScale(fraction,0.5)
    sensitivityValue.Text=tostring(settings.Smoothness)..'/20'
end
setSensitivity(settings.Smoothness)

local sensitivityInput=nil
local function updateSensitivityFromX(x)
    local width=sensitivityTrack.AbsoluteSize.X
    if width<=0 then return end
    local fraction=math.clamp((x-sensitivityTrack.AbsolutePosition.X)/width,0,1)
    setSensitivity(1+fraction*19)
end
bind(sensitivityTrack.InputBegan,function(input)
    if input.UserInputType~=Enum.UserInputType.Touch
        and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    sensitivityInput=input
    updateSensitivityFromX(input.Position.X)
end)
bind(UIS.InputChanged,function(input)
    if not sensitivityInput then return end
    if sensitivityInput.UserInputType==Enum.UserInputType.Touch then
        if input~=sensitivityInput then return end
    elseif input.UserInputType~=Enum.UserInputType.MouseMovement then
        return
    end
    updateSensitivityFromX(input.Position.X)
end)
bind(UIS.InputEnded,function(input)
    if not sensitivityInput then return end
    local same=input==sensitivityInput
    if sensitivityInput.UserInputType==Enum.UserInputType.MouseButton1 then
        same=input.UserInputType==Enum.UserInputType.MouseButton1
    end
    if same then sensitivityInput=nil end
end)

local statusPanel=create('Frame',{BackgroundColor3=color.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(14,314),Size=UDim2.new(1,-28,0,49)},main)
corner(statusPanel,12)
local status=label(statusPanel,'ESP: ON  |  AIM: ON',12,5,280,21,12,color.green)
local count=label(statusPanel,'Adversarios: 0',12,27,280,18,12,color.white)
local footer=label(main,'ZYON  •  MOBILE  •  V4',15,367,314,17,11,color.purple)
footer.TextXAlignment=Enum.TextXAlignment.Center

local bubble=button(screen,'◈',12,130,58,58,color.panel)
bubble.Name='CollapsedHub'; bubble.TextSize=30; bubble.Visible=false
corner(bubble,21); outline(bubble)
local bubbleScale=create('UIScale',{Scale=1},bubble)
local viewportConnection
local firstLayout=true
local function viewport()
    local cam=Workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(800,600)
end
local function clampPosition(gui,ww,hh)
    local v=viewport()
    gui.Position=UDim2.fromOffset(
        math.clamp(gui.Position.X.Offset,0,math.max(0,v.X-ww)),
        math.clamp(gui.Position.Y.Offset,0,math.max(0,v.Y-hh)))
end
local function resize()
    if not hub.Running then return end
    local v=viewport()
    local scale=math.min(1,(v.X-24)/W,(v.Y-24)/H)
    scale=math.max(0.1,scale)
    mainScale.Scale=scale
    if firstLayout then
        main.Position=UDim2.fromOffset(math.max(0,(v.X-W*scale)*0.5),
            math.max(0,(v.Y-H*scale)*0.5))
        firstLayout=false
    end
    clampPosition(main,W*scale,H*scale)
    local mini=math.min(1,math.max(0.1,math.min(v.X,v.Y)/250))
    bubbleScale.Scale=mini
    clampPosition(bubble,58*mini,58*mini)
end
local function watchCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    local camera=Workspace.CurrentCamera
    if camera then
        viewportConnection=bind(camera:GetPropertyChangedSignal('ViewportSize'),resize)
    end
    resize()
end
bind(Workspace:GetPropertyChangedSignal('CurrentCamera'),watchCamera)
watchCamera()

local function draggable(handle, gui, afterMove)
    local inputStart, positionStart, activeInput
    local dragging,moved=false,false
    bind(handle.InputBegan,function(input)
        if input.UserInputType~=Enum.UserInputType.Touch and
            input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        activeInput=input; inputStart=input.Position
        positionStart=gui.Position; dragging=true; moved=false
    end)
    bind(UIS.InputChanged,function(input)
        if not dragging or not activeInput then return end
        if activeInput.UserInputType==Enum.UserInputType.Touch then
            if input~=activeInput then return end
        elseif input.UserInputType~=Enum.UserInputType.MouseMovement then
            return
        end
        local delta=input.Position-inputStart
        if delta.Magnitude>7 then moved=true end
        if not moved then return end
        gui.Position=UDim2.fromOffset(
            positionStart.X.Offset+delta.X,positionStart.Y.Offset+delta.Y)
        clampPosition(gui,gui.AbsoluteSize.X,gui.AbsoluteSize.Y)
    end)
    bind(UIS.InputEnded,function(input)
        if not dragging or not activeInput then return end
        local match=input==activeInput
        if activeInput.UserInputType==Enum.UserInputType.MouseButton1 then
            match=input.UserInputType==Enum.UserInputType.MouseButton1
        end
        if match then
            dragging=false; activeInput=nil
            if moved and afterMove then afterMove() end
        end
    end)
end
draggable(header,main)
local lastDrag=-math.huge
draggable(bubble,bubble,function() lastDrag=os.clock() end)
local function minimized(value)
    hub.Minimized=value
    if value then
        bubble.Position=main.Position; main.Visible=false; bubble.Visible=true
    else
        main.Position=bubble.Position; main.Visible=true; bubble.Visible=false
    end
    resize()
end
bind(minus.Activated,function() minimized(true) end)
bind(bubble.Activated,function()
    if os.clock()-lastDrag>=0.25 then minimized(false) end
end)

local elapsed=settings.TargetInterval
local function refresh()
    espSwitch.Text=settings.ESP and 'ON' or 'OFF'
    espSwitch.BackgroundColor3=settings.ESP and color.green or color.red
    aimSwitch.Text=settings.Aim and 'ON' or 'OFF'
    aimSwitch.BackgroundColor3=settings.Aim and color.green or color.red
    status.Text='ESP: '..(settings.ESP and 'ON' or 'OFF')..
        '  |  AIM: '..(settings.Aim and 'ON' or 'OFF')
    status.TextColor3=(settings.ESP or settings.Aim) and color.green or color.muted
end
bind(espSwitch.Activated,function()
    settings.ESP=not settings.ESP
    if not settings.ESP then
        for player in pairs(hub.Highlights) do clearHighlight(player) end
    end
    refresh()
end)
bind(aimSwitch.Activated,function()
    settings.Aim=not settings.Aim
    hub.Target=nil
    elapsed=settings.TargetInterval
    refresh()
end)
local renderKey='ZYON_SMOOTH_AIM_V4'
RunService:BindToRenderStep(renderKey,Enum.RenderPriority.Camera.Value+1,function(dt)
    if not hub.Running or not settings.Aim then return end
    local camera=Workspace.CurrentCamera
    if not camera then return end
    elapsed=elapsed+dt
    if elapsed>=settings.TargetInterval then
        elapsed=0
        hub.Target=findTarget()
    end
    local part=hub.Target
    if not part or not part.Parent then return end
    local char=part.Parent
    local humanoid=char:FindFirstChildOfClass('Humanoid')
    local player=Players:GetPlayerFromCharacter(char)
    if not humanoid or humanoid.Health<=0 or not player or not enemy(player) then
        hub.Target=nil; return
    end
    local origin=camera.CFrame.Position
    if (part.Position-origin).Magnitude<0.01 then return end
    local alpha=1-math.exp(-settings.Smoothness*math.min(dt,0.1))
    camera.CFrame=camera.CFrame:Lerp(CFrame.lookAt(origin,part.Position),alpha)
end)

bind(Players.PlayerAdded,registerFriend)
bind(Players.PlayerRemoving,function(player)
    clearHighlight(player)
    hub.Friends[player.UserId]=nil
    if hub.Target and player.Character and
        hub.Target:IsDescendantOf(player.Character) then
        hub.Target=nil
    end
end)
for _,player in ipairs(Players:GetPlayers()) do registerFriend(player) end

task.spawn(function()
    while hub.Running do
        local n=0
        for _,player in ipairs(Players:GetPlayers()) do
            if not hub.Running then break end
            if updateHighlight(player) then n=n+1 end
        end
        if hub.Running then count.Text='Adversarios: '..n end
        task.wait(settings.ESPInterval)
    end
end)

function hub.Stop()
    if not hub.Running then return end
    hub.Running=false; hub.Target=nil
    RunService:UnbindFromRenderStep(renderKey)
    for _,connection in ipairs(hub.Connections) do
        connection:Disconnect()
    end
    for player in pairs(hub.Highlights) do clearHighlight(player) end
    screen:Destroy()
    if env.ZyonHub==hub then env.ZyonHub=nil end
end
bind(close.Activated,hub.Stop)
refresh()
print('[ZYON] Hub v4 carregado | auto aim + sensibilidade')
