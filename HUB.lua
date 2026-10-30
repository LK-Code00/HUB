-- ZYON HUB v7 | Roblox Luau | Mobile
-- Separate tabs, aligned FOV, improved tracking, themes, transparency, free dragging

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
    ShowFOV = true, HubTransparency = 0.10, FillTransparency = 0.55,
    MaxDistance = 350, ESPInterval = 0.3, TargetInterval = 0.12,
}
local color = {
    bg = Color3.fromRGB(15,17,25), panel = Color3.fromRGB(29,30,43),
    purple = Color3.fromRGB(151,99,255), green = Color3.fromRGB(40,210,126),
    red = Color3.fromRGB(255,54,72), white = Color3.fromRGB(242,241,252),
    muted = Color3.fromRGB(160,160,178)
}
local hub = {Running=true, Minimized=false, Target=nil,
    Friends={}, Highlights={}, Relations={}, Connections={}}
settings.ForceFFA = false
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
-- Sniper Duels has multiple duels and FFA modes. Public Roblox team
-- properties may be unset during a match; use replicated match/team markers
-- when they exist. Do not assume that neutral players are enemies.
local TEAM_KEYS = {
    'MatchTeam', 'DuelTeam', 'CurrentTeam', 'TeamId', 'TeamID',
    'TeamName', 'TeamNumber', 'Team', 'Side', 'Squad', 'TeamColor',
}
local MATCH_KEYS = {
    'MatchId', 'MatchID', 'CurrentMatchId', 'DuelId', 'DuelID',
    'CurrentDuelId', 'ArenaId', 'ArenaID',
}
local MODE_KEYS = {'GameMode', 'MatchMode', 'Mode', 'CurrentMode'}

local function normalized(value)
    if value == nil or typeof(value) == 'boolean' then return nil end
    if typeof(value) == 'Instance' then
        return string.lower(value:GetFullName())
    end
    local text = string.lower(tostring(value)):gsub('%s+', '')
    if text == '' or text == 'none' or text == 'nil' or text == 'neutral'
        or text == 'lobby' or text == 'spectator' or text == 'waiting'
        or text == '0' or text == '-1' then
        return nil
    end
    return text
end

local function readMarker(player, key)
    -- Read only instances replicated to the client.
    for _, source in ipairs({player, player.Character or player}) do
        local attribute = source:GetAttribute(key)
        local value = normalized(attribute)
        if value then return value end

        local obj = source:FindFirstChild(key)
        if obj and obj:IsA('ValueBase') then
            local ok, result = pcall(function() return obj.Value end)
            if ok then
                value = normalized(result)
                if value then return value end
            end
        end
    end
    return nil
end

local function sharedMarker(other, keys)
    for _, key in ipairs(keys) do
        local mine = readMarker(LP, key)
        local theirs = readMarker(other, key)
        if mine and theirs then return mine, theirs, key end
    end
    return nil, nil, nil
end

local function isFFA()
    for _, source in ipairs({LP, LP.Character or LP, Workspace}) do
        for _, key in ipairs(MODE_KEYS) do
            local value = normalized(source:GetAttribute(key))
            if value then
                if value == 'ffa' or value == 'freeforall' or
                    value == 'free-for-all' then
                    return true
                end
                -- A recognized team match mode is not FFA.
                return false
            end
        end
    end
    return false
end

local function matchVerdict(other)
    local mine, theirs = sharedMarker(other, MATCH_KEYS)
    if mine and theirs and mine ~= theirs then return false end
    -- If one player has a match identifier and the other does not,
    -- treat them as unrelated/unknown, never a confirmed enemy.
    for _, key in ipairs(MATCH_KEYS) do
        local a, b = readMarker(LP, key), readMarker(other, key)
        if (a and not b) or (b and not a) then return false end
    end
    return true
end

local function teamVerdict(other)
    if LP.Team and other.Team and not LP.Neutral and not other.Neutral then
        return LP.Team ~= other.Team, 'Roblox.Team'
    end
    if not LP.Neutral and not other.Neutral
        and LP.TeamColor ~= other.TeamColor then
        return true, 'Roblox.TeamColor'
    end
    local mine, theirs, key = sharedMarker(other, TEAM_KEYS)
    if mine and theirs then
        return mine ~= theirs, 'match.' .. key
    end
    if isFFA() then return true, 'FFA' end
    -- Unknown != enemy: this is necessary in custom-team games.
    return false, 'unknown'
end

-- Cache the verdict; RenderStepped must not scan Attributes/ValueBases.
local verdicts = {}
local teamSource = 'unknown'
local function refreshTeamCache()
    if not hub.Running then return end
    local resolved = 'unknown'
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local relation = hub.Relations[p.UserId]
            local allowed = hub.Friends[p.UserId] == 'other'
                or not settings.IgnoreFriends
            if allowed and relation == 'ally' then
                allowed = false
            elseif allowed and relation == 'enemy' then
                -- Manually selected player: explicit classification wins.
                allowed = true
                resolved = 'manual'
            elseif allowed then
                allowed = matchVerdict(p)
                if allowed and settings.IgnoreTeam then
                    if settings.ForceFFA then
                        resolved = 'FFA manual'
                    else
                        local identified, source = teamVerdict(p)
                        allowed = identified
                        if source ~= 'unknown' then resolved = source end
                    end
                end
            end
            verdicts[p] = allowed
        end
    end
    teamSource = resolved
end

local function enemy(player)
    return player ~= LP
        and player.Parent == Players
        and verdicts[player] == true
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
            OutlineColor=color.red, FillTransparency=settings.FillTransparency,
            OutlineTransparency=0, DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        }, PlayerGui)
        hub.Highlights[player]=highlight
    end
    highlight.Adornee=char
    highlight.FillTransparency=settings.FillTransparency
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
    return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('Head')
end
-- Stable center-mass tracking avoids chasing the head's idle animations.
local function aimPosition(part)
    if part.Name=='HumanoidRootPart' then
        return part.Position+Vector3.new(0,1.1,0)
    end
    return part.Position
end

local function findTarget()
    local camera=Workspace.CurrentCamera
    if not camera then return nil end
    local viewport=camera.ViewportSize
    local center=viewport*0.5
    local radius=math.min(viewport.X,viewport.Y)*settings.FOV
    local best=radius*radius

    -- Keep the previous target while it remains near the selected FOV.
    -- This prevents rapid switching between overlapping players.
    local current=hub.Target
    if current and current.Parent then
        local owner=Players:GetPlayerFromCharacter(current.Parent)
        local humanoid=current.Parent:FindFirstChildOfClass('Humanoid')
        if owner and enemy(owner) and humanoid and humanoid.Health>0
            and (aimPosition(current)-camera.CFrame.Position).Magnitude<=settings.MaxDistance
            and visible(camera,current) then
            local point,onScreen=camera:WorldToViewportPoint(aimPosition(current))
            if onScreen and point.Z>0 then
                local dx,dy=point.X-center.X,point.Y-center.Y
                if dx*dx+dy*dy <= best*1.25 then
                    return current
                end
            end
        end
    end

    local closest=nil
    for _,player in ipairs(Players:GetPlayers()) do
        local part=aimPart(player)
        if part then
            local position=aimPosition(part)
            if (position-camera.CFrame.Position).Magnitude<=settings.MaxDistance then
                local point,onScreen=camera:WorldToViewportPoint(position)
                if onScreen and point.Z>0 then
                    local dx,dy=point.X-center.X,point.Y-center.Y
                    local dist2=dx*dx+dy*dy
                    if dist2<best and visible(camera,part) then
                        best=dist2
                        closest=part
                    end
                end
            end
        end
    end
    return closest
end

-- Screen and hub panel
local screen=create('ScreenGui', {Name='ZyonHubV7', ResetOnSpawn=false,
    IgnoreGuiInset=true, ScreenInsets=Enum.ScreenInsets.None, DisplayOrder=1000,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling}, PlayerGui)
hub.Screen=screen
local W,H=350,410
local main=create('Frame',{Name='Hub',Active=true,BackgroundColor3=color.bg,
    BackgroundTransparency=settings.HubTransparency, ZIndex=5,
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
-- Broad draggable zone covering the header/title, without covering buttons.
local dragArea=create('TextButton',{
    Name='DragHeader',Text='',AutoButtonColor=false,
    BackgroundTransparency=1,BorderSizePixel=0,Active=true,
    Position=UDim2.fromOffset(0,0),
    Size=UDim2.new(1,-104,1,0),ZIndex=4
},header)
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
    return toggle,card
end
local espSwitch,espCard=switch('ENEMY ESP','Inimigos em vermelho; amigos ocultos',67,settings.ESP)
local aimSwitch,aimCard=switch('AUTO AIM','Ativo continuamente quando ligado',143,settings.Aim)
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

-- FOV slider: 5-50% of the shortest screen dimension.
local fovCard=create('Frame',{
    BackgroundColor3=color.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(14,314),Size=UDim2.new(1,-28,0,86)
},main)
corner(fovCard,12)
local fovHeading=label(fovCard,'TAMANHO DO FOV',12,7,210,24,14,color.white)
fovHeading.Font=Enum.Font.GothamBold
local fovValue=label(fovCard,'23%',246,7,56,24,14,color.purple)
fovValue.Font=Enum.Font.GothamBold
fovValue.TextXAlignment=Enum.TextXAlignment.Right
local fovTrack=create('TextButton',{
    Text='',AutoButtonColor=false,Active=true,
    BackgroundColor3=color.bg,BorderSizePixel=0,
    Position=UDim2.fromOffset(17,44),Size=UDim2.new(1,-34,0,13)
},fovCard)
corner(fovTrack,7)
local fovFill=create('Frame',{
    Active=false,BackgroundColor3=color.purple,BorderSizePixel=0,
    Size=UDim2.fromScale(0,1)
},fovTrack)
corner(fovFill,7)
local fovKnob=create('Frame',{
    Active=false,BackgroundColor3=color.white,BorderSizePixel=0,
    AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(19,19),
    Position=UDim2.fromScale(0,0.5)
},fovTrack)
corner(fovKnob,10)
label(fovCard,'MENOR',17,63,80,17,10,color.muted)
local fovMaxLabel=label(fovCard,'MAIOR',220,63,80,17,10,color.muted)
fovMaxLabel.TextXAlignment=Enum.TextXAlignment.Right

-- Draw a lightweight circular guide without third-party Drawing APIs.
local fovCircle=create('Frame',{
    Name='FovGuide',BackgroundTransparency=1,BorderSizePixel=0,
    AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
    Visible=settings.Aim and settings.ShowFOV,Active=false,ZIndex=2,
},screen)
create('UICorner',{CornerRadius=UDim.new(1,0)},fovCircle)
create('UIStroke',{Color=color.purple,Transparency=0.43,Thickness=1.5},fovCircle)
local function refreshFovCircle()
    local camera=Workspace.CurrentCamera
    if not camera then return end
    local v=camera.ViewportSize
    local diameter=math.min(v.X,v.Y)*settings.FOV*2
    fovCircle.Size=UDim2.fromOffset(diameter,diameter)
    -- Both WorldToViewportPoint and ScreenInsets.None use the viewport origin.
    fovCircle.Position=UDim2.fromOffset(v.X/2,v.Y/2)
    fovCircle.Visible=settings.Aim and settings.ShowFOV
end
local function setFOV(fov)
    settings.FOV=math.clamp(math.floor(fov+0.5),5,50)/100
    local percent=math.floor(settings.FOV*100+0.5)
    local frac=(percent-5)/45
    fovFill.Size=UDim2.fromScale(frac,1)
    fovKnob.Position=UDim2.fromScale(frac,0.5)
    fovValue.Text=tostring(percent)..'%'
    refreshFovCircle()
end
setFOV(settings.FOV*100)

local fovInput=nil
local function updateFOVFromX(x)
    local w=fovTrack.AbsoluteSize.X
    if w<=0 then return end
    local fraction=math.clamp((x-fovTrack.AbsolutePosition.X)/w,0,1)
    setFOV(5+fraction*45)
end
bind(fovTrack.InputBegan,function(input)
    if input.UserInputType~=Enum.UserInputType.Touch
        and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    fovInput=input
    updateFOVFromX(input.Position.X)
end)
bind(UIS.InputChanged,function(input)
    if not fovInput then return end
    if fovInput.UserInputType==Enum.UserInputType.Touch then
        if input~=fovInput then return end
    elseif input.UserInputType~=Enum.UserInputType.MouseMovement then
        return
    end
    updateFOVFromX(input.Position.X)
end)
bind(UIS.InputEnded,function(input)
    if not fovInput then return end
    local same=input==fovInput
    if fovInput.UserInputType==Enum.UserInputType.MouseButton1 then
        same=input.UserInputType==Enum.UserInputType.MouseButton1
    end
    if same then fovInput=nil end
end)

local statusPanel=create('Frame',{BackgroundColor3=color.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(14,409),Size=UDim2.new(1,-28,0,49)},main)
corner(statusPanel,12)
local status=label(statusPanel,'ESP: ON  |  AIM: ON',12,3,290,18,12,color.green)
local count=label(statusPanel,'Adversarios: 0',12,24,300,18,12,color.white)
local rosterOpenButton=button(statusPanel,'JOGADORES',200,7,102,31,color.purple)
rosterOpenButton.TextSize=11
local footer=label(main,'ZYON  •  MOBILE  •  V7',15,H-21,W-30,16,10,color.purple)
footer.TextXAlignment=Enum.TextXAlignment.Center

-- Roster: when Sniper Duels does not replicate its custom teams to
-- ordinary player fields, manually classify players in the current duel.
-- No need to restart the script and no extra aim button.
local rosterPanel=create('Frame',{
    Name='PlayerClassifier',BackgroundColor3=color.bg,
    BorderSizePixel=0,Size=UDim2.fromScale(1,1),
    Visible=false,ZIndex=15,Active=true
},main)
corner(rosterPanel,19)
local rosterTitle=label(rosterPanel,'JOGADORES / EQUIPES',17,11,250,32,18,color.purple)
rosterTitle.ZIndex=16
rosterTitle.Font=Enum.Font.GothamBold
local rosterBack=button(rosterPanel,'VOLTAR',W-99,49,84,31,color.panel)
rosterBack.TextSize=12
rosterBack.ZIndex=16
local modeToggle=button(rosterPanel,'MODO: AUTO',15,49,153,31,color.panel)
modeToggle.TextSize=12
modeToggle.ZIndex=16
local rosterHint=label(rosterPanel,'Toque para mudar: AUTO > INIMIGO > ALIADO',15,90,314,36,11,color.muted)
rosterHint.TextWrapped=true
rosterHint.ZIndex=16
local rosterScroll=create('ScrollingFrame',{
    Name='RosterScroll',BackgroundTransparency=1,BorderSizePixel=0,
    Position=UDim2.fromOffset(12,132),
    Size=UDim2.new(1,-24,1,-151),
    CanvasSize=UDim2.fromOffset(0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.None,
    ScrollBarThickness=4,ScrollingDirection=Enum.ScrollingDirection.Y,
    ScrollBarImageColor3=color.purple,ZIndex=16,
},rosterPanel)
local layout=create('UIListLayout',{
    Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder
},rosterScroll)
local function rebuildRoster()
    if not hub.Running then return end
    for _, child in ipairs(rosterScroll:GetChildren()) do
        if child:IsA('Frame') then child:Destroy() end
    end
    local people={}
    for _, player in ipairs(Players:GetPlayers()) do
        if player~=LP then table.insert(people,player) end
    end
    table.sort(people,function(a,b) return a.Name:lower()<b.Name:lower() end)
    for index, player in ipairs(people) do
        local row=create('Frame',{
            BackgroundColor3=color.panel,
            BackgroundTransparency=settings.HubTransparency,
            BorderSizePixel=0,
            Size=UDim2.new(1,-7,0,42),LayoutOrder=index,ZIndex=17,
        },rosterScroll)
        corner(row,9)
        local display=player.DisplayName
        if #display>18 then display=display:sub(1,17)..'...' end
        local nameLabel=label(row,display,9,6,183,30,12,color.white)
        nameLabel.ZIndex=18
        local relation=hub.Relations[player.UserId]
        local relationText=relation=='enemy' and 'INIMIGO'
            or relation=='ally' and 'ALIADO' or 'AUTO'
        local relationColor=relation=='enemy' and color.red
            or relation=='ally' and color.green or color.purple
        local relationButton=button(row,relationText,W-125,5,94,31,relationColor)
        relationButton.TextSize=12
        relationButton.ZIndex=18
        relationButton.Activated:Connect(function()
            if not hub.Running or player.Parent~=Players then return end
            local old=hub.Relations[player.UserId]
            hub.Relations[player.UserId] =
                old==nil and 'enemy' or old=='enemy' and 'ally' or nil
            refreshTeamCache()
            hub.Target=nil
            -- Remove stale highlights immediately before next ESP cycle.
            for who in pairs(hub.Highlights) do
                if not enemy(who) then clearHighlight(who) end
            end
            rebuildRoster()
        end)
    end
    rosterScroll.CanvasSize=UDim2.fromOffset(0,#people*47+4)
end
bind(rosterOpenButton.Activated,function()
    rosterPanel.Visible=true
    rebuildRoster()
end)
bind(rosterBack.Activated,function()
    rosterPanel.Visible=false
end)
bind(modeToggle.Activated,function()
    settings.ForceFFA=not settings.ForceFFA
    modeToggle.Text=settings.ForceFFA and 'MODO: FFA' or 'MODO: AUTO'
    refreshTeamCache()
    hub.Target=nil
    for who in pairs(hub.Highlights) do
        if not enemy(who) then clearHighlight(who) end
    end
    rebuildRoster()
end)
bind(Players.PlayerAdded,function()
    if rosterPanel.Visible then rebuildRoster() end
end)
bind(Players.PlayerRemoving,function()
    if rosterPanel.Visible then rebuildRoster() end
end)

local bubble=button(screen,'◈',12,130,58,58,color.panel)
bubble.Name='CollapsedHub'; bubble.TextSize=30; bubble.Visible=false
bubble.ZIndex=30
corner(bubble,21); outline(bubble)
local bubbleScale=create('UIScale',{Scale=1},bubble)
-- ---------- Three-tab layout ----------
local tabs=create('Frame',{
    Name='TabBar',BackgroundTransparency=1,
    Position=UDim2.fromOffset(13,59),Size=UDim2.new(1,-26,0,36),
    ZIndex=8
},main)
local tabSettings=button(tabs,'ESP / AIM',0,0,102,34,color.purple)
local tabPlayers=button(tabs,'JOGADORES',110,0,102,34,color.panel)
local tabAppearance=button(tabs,'APARENCIA',220,0,104,34,color.panel)
for _,btn in ipairs({tabSettings,tabPlayers,tabAppearance}) do
    btn.TextSize=12
    btn.ZIndex=9
end

local settingsPage=create('ScrollingFrame',{
    Name='SettingsPage',BackgroundTransparency=1,BorderSizePixel=0,
    Position=UDim2.fromOffset(0,100),Size=UDim2.new(1,0,1,-122),
    CanvasSize=UDim2.fromOffset(0,388),
    ScrollBarThickness=3,ScrollBarImageColor3=color.purple,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    Visible=true,Active=true,ZIndex=6
},main)
local function reparentSettings(obj,y)
    obj.Parent=settingsPage
    obj.Position=UDim2.fromOffset(14,y)
end
reparentSettings(espCard,0)
reparentSettings(aimCard,70)
reparentSettings(sensitivityCard,142)
reparentSettings(fovCard,237)
reparentSettings(statusPanel,329)
statusPanel.Size=UDim2.new(1,-28,0,45)
rosterOpenButton:Destroy()
rosterPanel.Position=UDim2.fromOffset(0,100)
rosterPanel.Size=UDim2.new(1,0,1,-122)
rosterPanel.BackgroundTransparency=1
rosterTitle.Position=UDim2.fromOffset(16,3)
rosterTitle.TextSize=16
rosterBack:Destroy()
modeToggle.Position=UDim2.fromOffset(16,40)
rosterHint.Position=UDim2.fromOffset(16,78)
rosterScroll.Position=UDim2.fromOffset(12,116)
rosterScroll.Size=UDim2.new(1,-24,1,-124)
rosterScroll.ScrollBarThickness=4

local appearancePage=create('ScrollingFrame',{
    Name='AppearancePage',BackgroundTransparency=1,BorderSizePixel=0,
    Position=UDim2.fromOffset(0,100),Size=UDim2.new(1,0,1,-122),
    CanvasSize=UDim2.fromOffset(0,435),
    ScrollBarThickness=3,ScrollBarImageColor3=color.purple,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    Visible=false,Active=true,ZIndex=6,
},main)
local colorCard=create('Frame',{
    Name='AccentColors',BackgroundColor3=color.panel,
    BorderSizePixel=0,Position=UDim2.fromOffset(14,3),
    Size=UDim2.new(1,-28,0,94),
},appearancePage)
corner(colorCard,12)
local themeTitle=label(colorCard,'COR DO HUB',12,7,270,26,14,color.white)
themeTitle.Font=Enum.Font.GothamBold
local themeNames={'ROXO','VERDE','AZUL','ROSA'}
local themeColors={
    Color3.fromRGB(151,99,255),
    Color3.fromRGB(40,210,126),
    Color3.fromRGB(42,179,255),
    Color3.fromRGB(255,91,174)
}
local themeButtons={}
for i=1,4 do
    local btn=button(colorCard,themeNames[i],12+(i-1)*76,42,69,34,themeColors[i])
    btn.TextSize=11
    btn.TextColor3=color.bg
    themeButtons[i]=btn
end

local appearanceCards={colorCard}
local function makeAppearanceSlider(title,y,minVal,maxVal,initial,onUpdate)
    local card=create('Frame',{
        BackgroundColor3=color.panel,BorderSizePixel=0,
        Position=UDim2.fromOffset(14,y),
        Size=UDim2.new(1,-28,0,95)
    },appearancePage)
    corner(card,12)
    table.insert(appearanceCards,card)
    local caption=label(card,title,12,7,232,25,13,color.white)
    caption.Font=Enum.Font.GothamBold
    local indicator=label(card,'',246,7,57,25,13,color.purple)
    indicator.Font=Enum.Font.GothamBold
    indicator.TextXAlignment=Enum.TextXAlignment.Right
    local track=create('TextButton',{
        Text='',BackgroundColor3=color.bg,BorderSizePixel=0,
        AutoButtonColor=false,Active=true,
        Position=UDim2.fromOffset(16,43),
        Size=UDim2.new(1,-32,0,12),
    },card)
    corner(track,6)
    local fill=create('Frame',{
        BackgroundColor3=color.purple,BorderSizePixel=0,
        Size=UDim2.fromScale(0,1)
    },track)
    corner(fill,6)
    local knob=create('Frame',{
        BackgroundColor3=color.white,BorderSizePixel=0,
        Size=UDim2.fromOffset(18,18),
        AnchorPoint=Vector2.new(0.5,0.5),
        Position=UDim2.fromScale(0,0.5)
    },track)
    corner(knob,9)
    local left=label(card,'0%',16,65,76,18,10,color.muted)
    local right=label(card,tostring(maxVal)..'%',210,65,90,18,10,color.muted)
    right.TextXAlignment=Enum.TextXAlignment.Right
    local function update(value)
        value=math.clamp(math.floor(value+0.5),minVal,maxVal)
        local fraction=(value-minVal)/(maxVal-minVal)
        fill.Size=UDim2.fromScale(fraction,1)
        knob.Position=UDim2.fromScale(fraction,0.5)
        indicator.Text=tostring(value)..'%'
        onUpdate(value)
    end
    local active=nil
    local function fromX(x)
        local width=track.AbsoluteSize.X
        if width<=0 then return end
        local f=math.clamp((x-track.AbsolutePosition.X)/width,0,1)
        update(minVal+f*(maxVal-minVal))
    end
    bind(track.InputBegan,function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1
            and input.UserInputType~=Enum.UserInputType.Touch then return end
        active=input
        fromX(input.Position.X)
    end)
    bind(UIS.InputChanged,function(input)
        if not active then return end
        if active.UserInputType==Enum.UserInputType.Touch then
            if input~=active then return end
        elseif input.UserInputType~=Enum.UserInputType.MouseMovement then
            return
        end
        fromX(input.Position.X)
    end)
    bind(UIS.InputEnded,function(input)
        if not active then return end
        if input==active or (active.UserInputType==Enum.UserInputType.MouseButton1
            and input.UserInputType==Enum.UserInputType.MouseButton1) then
            active=nil
        end
    end)
    update(initial)
    return {card=card,fill=fill,indicator=indicator}
end

local function applyWindowTransparency()
    for _,object in ipairs({
        main,espCard,aimCard,sensitivityCard,fovCard,statusPanel,
        bubble,colorCard
    }) do
        if object then object.BackgroundTransparency=settings.HubTransparency end
    end
    for _,card in ipairs(appearanceCards) do
        card.BackgroundTransparency=settings.HubTransparency
    end
    for _,object in ipairs(rosterScroll:GetChildren()) do
        if object:IsA('Frame') then
            object.BackgroundTransparency=settings.HubTransparency
        end
    end
end
local opacityControl=makeAppearanceSlider(
    'TRANSPARENCIA DO HUB',109,0,85,
    math.floor(settings.HubTransparency*100+0.5),
    function(value)
        settings.HubTransparency=value/100
        applyWindowTransparency()
    end
)
local espOpacityControl=makeAppearanceSlider(
    'TRANSPARENCIA DO ESP',215,0,95,
    math.floor(settings.FillTransparency*100+0.5),
    function(value)
        settings.FillTransparency=value/100
        for _,highlight in pairs(hub.Highlights) do
            highlight.FillTransparency=settings.FillTransparency
        end
    end
)

local circleCard=create('Frame',{
    BackgroundColor3=color.panel,BorderSizePixel=0,
    Position=UDim2.fromOffset(14,322),
    Size=UDim2.new(1,-28,0,62),
},appearancePage)
corner(circleCard,12)
table.insert(appearanceCards,circleCard)
local circleLabel=label(circleCard,'MOSTRAR CIRCULO FOV',12,13,220,32,13,color.white)
circleLabel.Font=Enum.Font.GothamBold
local circleSwitch=button(circleCard,'ON',W-89,14,49,31,color.green)
circleSwitch.TextSize=12
circleSwitch.TextColor3=color.bg
bind(circleSwitch.Activated,function()
    settings.ShowFOV=not settings.ShowFOV
    circleSwitch.Text=settings.ShowFOV and 'ON' or 'OFF'
    circleSwitch.BackgroundColor3=settings.ShowFOV and color.green or color.red
    refreshFovCircle()
end)

local function setAccent(chosen)
    color.purple=chosen
    for _,textObj in ipairs({heading,footer,sensitivityValue,fovValue,
        opacityControl.indicator,espOpacityControl.indicator}) do
        textObj.TextColor3=chosen
    end
    for _,fill in ipairs({sensitivityFill,fovFill,
        opacityControl.fill,espOpacityControl.fill}) do
        fill.BackgroundColor3=chosen
    end
    local mainStroke=main:FindFirstChildOfClass('UIStroke')
    local bubbleStroke=bubble:FindFirstChildOfClass('UIStroke')
    local circleStroke=fovCircle:FindFirstChildOfClass('UIStroke')
    if mainStroke then mainStroke.Color=chosen end
    if bubbleStroke then bubbleStroke.Color=chosen end
    if circleStroke then circleStroke.Color=chosen end
    tabs.BackgroundColor3=chosen
    settingsPage.ScrollBarImageColor3=chosen
    appearancePage.ScrollBarImageColor3=chosen
    rosterScroll.ScrollBarImageColor3=chosen
    for i,buttonObj in ipairs(themeButtons) do
        local mark=buttonObj:FindFirstChildOfClass('UIStroke')
        if not mark then mark=create('UIStroke',{Thickness=1.5},buttonObj) end
        mark.Color=color.white
        mark.Transparency=(themeColors[i]==chosen) and 0 or 1
    end
    local selected=tabSettings
    if rosterPanel.Visible then selected=tabPlayers end
    if appearancePage.Visible then selected=tabAppearance end
    selected.BackgroundColor3=chosen
end
for i,buttonObj in ipairs(themeButtons) do
    bind(buttonObj.Activated,function() setAccent(themeColors[i]) end)
end

local function showTab(which)
    settingsPage.Visible=which=='settings'
    rosterPanel.Visible=which=='players'
    appearancePage.Visible=which=='appearance'
    for _,entry in ipairs({
        {tabSettings,'settings'},
        {tabPlayers,'players'},
        {tabAppearance,'appearance'}
    }) do
        entry[1].BackgroundColor3=
            entry[2]==which and color.purple or color.panel
    end
    if which=='players' then rebuildRoster() end
    if which=='appearance' then applyWindowTransparency() end
end
bind(tabSettings.Activated,function() showTab('settings') end)
bind(tabPlayers.Activated,function() showTab('players') end)
bind(tabAppearance.Activated,function() showTab('appearance') end)
showTab('settings')
setAccent(color.purple)
applyWindowTransparency()

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
    refreshFovCircle()
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
draggable(dragArea,main)
local lastDrag=-math.huge
local bubblePositionSaved=false
draggable(bubble,bubble,function()
    lastDrag=os.clock()
    bubblePositionSaved=true
end)
local function minimized(value)
    hub.Minimized=value
    if value then
        if not bubblePositionSaved then
            bubble.Position=main.Position
        end
        main.Visible=false
        bubble.Visible=true
    else
        -- The main window keeps its own dragged position.
        main.Visible=true
        bubble.Visible=false
    end
    resize()
end
bind(minus.Activated,function() minimized(true) end)
bind(bubble.Activated,function()
    if os.clock()-lastDrag>=0.25 then minimized(false) end
end)

local elapsed=settings.TargetInterval
local function refresh()
    refreshFovCircle()
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
local renderKey='ZYON_SMOOTH_AIM_V7'
RunService:BindToRenderStep(renderKey,Enum.RenderPriority.Camera.Value+1,function(dt)
    if not hub.Running or not settings.Aim then return end
    local camera=Workspace.CurrentCamera
    if not camera or camera.CameraType==Enum.CameraType.Scriptable then return end
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
    local goal=aimPosition(part)
    if (goal-origin).Magnitude<0.01 then return end
    local point,onScreen=camera:WorldToViewportPoint(goal)
    if onScreen then
        local mid=camera.ViewportSize*0.5
        local dx,dy=point.X-mid.X,point.Y-mid.Y
        -- Two-pixel dead zone prevents constant camera micro-jitter.
        if dx*dx+dy*dy<4 then return end
    end
    local alpha=1-math.exp(-settings.Smoothness*math.min(dt,0.05))
    camera.CFrame=camera.CFrame:Lerp(CFrame.lookAt(origin,goal),alpha)
end)

bind(Players.PlayerAdded,registerFriend)
bind(Players.PlayerRemoving,function(player)
    clearHighlight(player)
    hub.Relations[player.UserId]=nil
    verdicts[player]=nil
    hub.Friends[player.UserId]=nil
    if hub.Target and player.Character and
        hub.Target:IsDescendantOf(player.Character) then
        hub.Target=nil
    end
end)
for _,player in ipairs(Players:GetPlayers()) do registerFriend(player) end

task.spawn(function()
    local lastTeamRefresh=-math.huge
    while hub.Running do
        -- ESP updates more often than custom-team discovery.
        if os.clock()-lastTeamRefresh>=0.9 then
            refreshTeamCache()
            lastTeamRefresh=os.clock()
        end
        local n=0
        for _,player in ipairs(Players:GetPlayers()) do
            if not hub.Running then break end
            if updateHighlight(player) then n=n+1 end
        end
        if hub.Running then
            count.Text='Adversarios: '..n..' | Time: '..teamSource
            if teamSource=='unknown' then
                count.Text='Equipe nao detectada: use JOGADORES'
            end
        end
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
print('[ZYON] Hub v7 | abas, FOV alinhado, aparencia e arraste livre')
