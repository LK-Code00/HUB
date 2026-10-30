-- ZYON HUB v8 | Roblox Luau | Desktop + Mobile
-- Responsive cards, dedicated FOV controls, movable and lockable acquisition area.

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
    ShowFOV = true, HubTransparency = 0.06, FillTransparency = 0.55,
    FOVX = 0.5, FOVY = 0.5, FOVLocked = true,
    MaxDistance = 350, ESPInterval = 0.3, TargetInterval = 0.12,
}
local color = {
    bg = Color3.fromRGB(16,18,27), panel = Color3.fromRGB(26,29,41),
    purple = Color3.fromRGB(165,132,255), green = Color3.fromRGB(74,222,151),
    red = Color3.fromRGB(255,105,124), white = Color3.fromRGB(240,242,250),
    muted = Color3.fromRGB(162,172,195), line = Color3.fromRGB(49,55,74)
}
local hub = {Running=true, Minimized=false, Target=nil,
    Friends={}, Highlights={}, Relations={}, Connections={}}
settings.ForceFFA = false
env.ZyonHub = hub

-- ScreenInsets.None and WorldToViewportPoint share the viewport origin.
-- Store a fraction so the chosen position survives window/orientation changes.
local function fovCenter(viewport)
    return Vector2.new(viewport.X * settings.FOVX, viewport.Y * settings.FOVY)
end

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
    local center=fovCenter(viewport)
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

-- UI stays scoped so the standalone script remains below Luau's local limit.
do
    local W, H = 368, 540
    local ui, accentText, accentFill, accentStroke, surfaces = {}, {}, {}, {}, {}
    local activeTab = 'aim'
    local rebuildRoster, refresh, setLocked, refreshFov, resize
    local screen = create('ScreenGui', {
        Name='ZyonHubV8', ResetOnSpawn=false, IgnoreGuiInset=true,
        ScreenInsets=Enum.ScreenInsets.None, DisplayOrder=1000,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    }, PlayerGui)
    hub.Screen = screen

    local function stroke(object, hue, transparency)
        return create('UIStroke', {Color=hue, Thickness=1,
            Transparency=transparency or 0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, object)
    end
    local function surface(object, radius)
        corner(object, radius or 14)
        stroke(object, color.line, 0.25)
        table.insert(surfaces, object)
        object.BackgroundTransparency = settings.HubTransparency
        return object
    end
    local function text(parent, value, x, y, width, height, size, hue, bold)
        local result = label(parent, value, x, y, width, height, size, hue or color.white)
        if bold then result.Font = Enum.Font.GothamBold end
        return result
    end
    local function accentLabel(...)
        local result = text(...)
        result.TextColor3 = color.purple
        table.insert(accentText, result)
        return result
    end
    local function button(parent, value, x, y, width, height)
        local result = create('TextButton', {
            Text=value, Font=Enum.Font.GothamBold, TextSize=12,
            TextColor3=color.white, BackgroundColor3=color.panel,
            Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(width,height),
            BorderSizePixel=0, Active=true, AutoButtonColor=true,
        }, parent)
        corner(result, 10)
        return result
    end
    local function viewport()
        local camera = Workspace.CurrentCamera
        return camera and camera.ViewportSize or Vector2.new(800,600)
    end
    local function clampWindow(gui)
        local v, size = viewport(), gui.AbsoluteSize
        gui.Position = UDim2.fromOffset(
            math.clamp(gui.Position.X.Offset, 0, math.max(0,v.X-size.X)),
            math.clamp(gui.Position.Y.Offset, 0, math.max(0,v.Y-size.Y)))
    end

    -- One owning pointer per gesture; a second finger never steals a drag.
    local function gesture(handle, begin, move, finish)
        local active
        local function cancel()
            if not active then return end
            active = nil
            if finish then finish() end
        end
        bind(handle.InputBegan, function(input)
            if active or (input.UserInputType ~= Enum.UserInputType.Touch
                and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
            if begin(input.Position) == false then return end
            active = input
        end)
        bind(UIS.InputChanged, function(input)
            if not active then return end
            if active.UserInputType == Enum.UserInputType.Touch then
                if input ~= active then return end
            elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            move(input.Position)
        end)
        bind(UIS.InputEnded, function(input)
            if active and (input == active or
                (active.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1)) then cancel() end
        end)
        bind(UIS.WindowFocusReleased, cancel)
        return cancel
    end

    local main = surface(create('Frame', {
        Name='Hub', Active=true, BackgroundColor3=color.bg, BorderSizePixel=0,
        Size=UDim2.fromOffset(W,H), Position=UDim2.fromOffset(18,65), ZIndex=10,
    }, screen), 18)
    local scale = create('UIScale', {Scale=1}, main)
    local header = create('Frame', {BackgroundTransparency=1, Size=UDim2.new(1,0,0,72)}, main)
    accentLabel(header, 'ZYON', 18,10,145,28,23,color.purple,true)
    text(header, 'HUB  /  CONTROLE EM TEMPO REAL', 19,40,245,18,9,color.muted)
    local version = text(header, 'V8', 169,15,36,21,10,color.muted,true)
    version.TextXAlignment = Enum.TextXAlignment.Center
    version.BackgroundColor3 = color.panel
    version.BackgroundTransparency = 0
    corner(version, 6)
    local minimize = button(header, '−', W-96,16,36,36)
    local close = button(header, '×', W-54,16,36,36)
    minimize.TextSize, close.TextSize = 23, 23
    close.TextColor3 = color.red
    local dragArea = button(header, '', 0,0,W-108,68)
    dragArea.Name = 'DragHeader'
    dragArea.BackgroundTransparency = 1
    create('Frame', {BackgroundColor3=color.line, BorderSizePixel=0,
        Position=UDim2.fromOffset(18,69), Size=UDim2.new(1,-36,0,1)}, main)
    local tabs = surface(create('Frame', {Name='Tabs', BackgroundColor3=color.bg,
        BorderSizePixel=0, Position=UDim2.fromOffset(14,80), Size=UDim2.new(1,-28,0,44)}, main), 12)
    local pages, tabButtons = {}, {}
    local definitions = {{'aim','GERAL'}, {'fov','FOV'}, {'players','JOGADORES'}, {'appearance','VISUAL'}}
    for index, definition in ipairs(definitions) do
        local tab = button(tabs, definition[2], 4+(index-1)*83,4,83,36)
        tab.TextSize = 10
        tabButtons[definition[1]] = tab
    end
    local footer = text(main, 'ESP ON  ·  AIM ON', 18,H-25,W-36,17,10,color.muted)
    footer.Position = UDim2.new(0,18,1,-25)
    local function page(key)
        local result = create('ScrollingFrame', {
            Name=key..'Page', BackgroundTransparency=1, BorderSizePixel=0,
            Position=UDim2.fromOffset(0,136), Size=UDim2.new(1,0,1,-171),
            CanvasSize=UDim2.fromOffset(0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y,
            ScrollBarThickness=3, ScrollBarImageColor3=color.purple,
            ScrollingDirection=Enum.ScrollingDirection.Y, Active=true,
            Visible=key==activeTab, ClipsDescendants=true,
        }, main)
        create('UIPadding', {PaddingLeft=UDim.new(0,14), PaddingRight=UDim.new(0,14),
            PaddingTop=UDim.new(0,2), PaddingBottom=UDim.new(0,10)}, result)
        create('UIListLayout', {Padding=UDim.new(0,10), SortOrder=Enum.SortOrder.LayoutOrder}, result)
        pages[key] = result
        return result
    end
    local orders = {}
    local function card(parent, height, plain)
        orders[parent] = (orders[parent] or 0)+1
        local result = create('Frame', {BackgroundColor3=color.panel, BorderSizePixel=0,
            Size=UDim2.new(1,0,0,height), LayoutOrder=orders[parent]}, parent)
        if plain then result.BackgroundTransparency=1 else surface(result) end
        return result
    end
    local function intro(parent, title, description)
        local block = card(parent, 46, true)
        text(block,title,2,0,W-34,23,16,color.white,true)
        text(block,description,2,26,W-34,18,10,color.muted)
    end
    local function toggle(parent, title, description, initial, callback)
        local block = card(parent, 78)
        text(block,title,14,10,230,23,13,color.white,true)
        local detail = text(block,description,14,37,238,30,10,color.muted)
        detail.TextWrapped = true
        local control = button(block,'',W-106,19,64,40)
        local state = initial
        local function set(value)
            state = value
            control.Text = value and 'ON' or 'OFF'
            control.TextColor3 = value and color.bg or color.muted
            control.BackgroundColor3 = value and color.green or color.bg
        end
        bind(control.Activated, function() callback(not state) end)
        set(initial)
        return {set=set,button=control,detail=detail}
    end
    local function slider(parent, title, low, high, initial, format, callback)
        local block = card(parent, 100)
        text(block,title,14,9,220,23,12,color.white,true)
        local indicator = accentLabel(block,'',W-124,9,82,23,12,color.purple,true)
        indicator.TextXAlignment = Enum.TextXAlignment.Right
        -- The rail is thin, but its actual mouse/touch target is 38 px tall.
        local hit = button(block,'',16,34,W-60,38)
        hit.BackgroundTransparency = 1
        hit.AutoButtonColor = false
        local rail = create('Frame', {BackgroundColor3=color.bg,BorderSizePixel=0,
            Position=UDim2.new(0,0,0.5,-3),Size=UDim2.new(1,0,0,6)}, hit)
        corner(rail,3)
        local fill = create('Frame', {BackgroundColor3=color.purple,BorderSizePixel=0,
            Size=UDim2.fromScale(0,1)},rail)
        corner(fill,3)
        table.insert(accentFill,fill)
        local knob = create('Frame', {BackgroundColor3=color.white,BorderSizePixel=0,
            AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(18,18)},rail)
        corner(knob,9)
        text(block,format(low),16,75,90,15,9,color.muted)
        local maximum = text(block,format(high),W-134,75,90,15,9,color.muted)
        maximum.TextXAlignment = Enum.TextXAlignment.Right
        local enabled = true
        local function set(value)
            local fraction = math.clamp((value-low)/(high-low),0,1)
            fill.Size = UDim2.fromScale(fraction,1)
            knob.Position = UDim2.fromScale(fraction,0.5)
            indicator.Text = format(value)
        end
        local function fromX(position)
            if not enabled or hit.AbsoluteSize.X <= 0 then return end
            local fraction = math.clamp((position.X-hit.AbsolutePosition.X)/hit.AbsoluteSize.X,0,1)
            local value = math.floor(low+fraction*(high-low)+0.5)
            set(value)
            callback(value)
        end
        local cancel = gesture(hit, function(position)
            if not enabled then return false end
            parent.ScrollingEnabled = false
            fromX(position)
            return true
        end, fromX, function() parent.ScrollingEnabled=true end)
        set(initial)
        return {set=set, enable=function(value)
            enabled=value
            if not value then cancel() end
            indicator.TextTransparency=value and 0 or 0.55
            knob.BackgroundTransparency=value and 0 or 0.55
            fill.BackgroundTransparency=value and 0 or 0.55
            hit.Active=value
        end}
    end
    local function percent(value) return string.format('%.0f%%',value) end
    local function clearTarget() hub.Target=nil end

    local aimPage = page('aim')
    intro(aimPage,'Visao geral','Acesso rapido aos controles principais.')
    ui.esp = toggle(aimPage,'ESP de inimigos','Destaca adversarios; respeita os filtros atuais.',settings.ESP,function(value)
        settings.ESP=value
        if not value then
            for player in pairs(hub.Highlights) do clearHighlight(player) end
        end
        refresh()
    end)
    ui.aim = toggle(aimPage,'Aimbot','Acompanhamento continuo quando ativado.',settings.Aim,function(value)
        settings.Aim=value
        clearTarget()
        refresh()
    end)
    slider(aimPage,'SENSIBILIDADE',1,20,settings.Smoothness,
        function(value) return string.format('%.0f / 20',value) end,
        function(value) settings.Smoothness=value end)
    local statusCard = card(aimPage,78)
    accentLabel(statusCard,'STATUS DA PARTIDA',14,9,260,20,10,color.purple,true)
    local count = text(statusCard,'Buscando jogadores...',14,34,W-56,32,11,color.muted)
    count.TextWrapped=true
    hub.UpdateStatus = function(n, source)
        count.Text = source=='unknown' and 'Equipe nao detectada. Ajuste na aba Jogadores.'
            or ('Adversarios: '..n..'  ·  Equipe: '..source)
    end

    local fovPage = page('fov')
    intro(fovPage,'Area do FOV','Posicione a area de selecao e trave quando terminar.')
    ui.lock = toggle(fovPage,'Travar posicao','Desative para arrastar o ponto ou ajustar X / Y.',settings.FOVLocked,
        function(value) setLocked(value) end)
    ui.show = toggle(fovPage,'Mostrar circulo','Exibe o limite da area de selecao.',settings.ShowFOV,function(value)
        settings.ShowFOV=value
        if not value then setLocked(true) end
        refresh()
    end)
    slider(fovPage,'RAIO DO FOV',5,50,settings.FOV*100,percent,function(value)
        settings.FOV=value/100
        clearTarget()
        refreshFov()
    end)
    ui.x = slider(fovPage,'POSICAO HORIZONTAL · X',0,100,settings.FOVX*100,percent,function(value)
        settings.FOVX=value/100
        clearTarget()
        refreshFov()
    end)
    ui.y = slider(fovPage,'POSICAO VERTICAL · Y',0,100,settings.FOVY*100,percent,function(value)
        settings.FOVY=value/100
        clearTarget()
        refreshFov()
    end)
    local resetCard = card(fovPage,100)
    ui.center = button(resetCard,'CENTRALIZAR FOV',14,12,W-56,38)
    local positionHint = text(resetCard,'Destrave a posicao para editar.\nA posicao acompanha o tamanho da tela.',14,57,W-56,32,10,color.muted)
    positionHint.TextWrapped=true
    bind(ui.center.Activated,function()
        if settings.FOVLocked then return end
        settings.FOVX,settings.FOVY=0.5,0.5
        clearTarget()
        refreshFov()
    end)

    local playersPage = page('players')
    intro(playersPage,'Jogadores e equipes','Toque no estado: Auto > Inimigo > Aliado.')
    ui.ffa = toggle(playersPage,'Forcar modo FFA','Use quando a partida nao tiver equipes.',settings.ForceFFA,function(value)
        settings.ForceFFA=value
        refreshTeamCache()
        clearTarget()
        for player in pairs(hub.Highlights) do
            if not enemy(player) then clearHighlight(player) end
        end
        refresh()
        rebuildRoster()
    end)
    local roster = card(playersPage,0,true)
    roster.AutomaticSize=Enum.AutomaticSize.Y
    create('UIListLayout',{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},roster)
    rebuildRoster = function()
        for _,child in ipairs(roster:GetChildren()) do
            if child:IsA('GuiObject') then child:Destroy() end
        end
        local people={}
        for _,player in ipairs(Players:GetPlayers()) do
            if player~=LP then table.insert(people,player) end
        end
        table.sort(people,function(a,b) return a.Name:lower()<b.Name:lower() end)
        if #people==0 then
            local empty=text(roster,'Nenhum outro jogador nesta partida.',14,0,W-56,44,11,color.muted)
            empty.TextWrapped=true
        end
        for index,player in ipairs(people) do
            -- Dynamic rows are deliberately not retained in the surface registry.
            local row=create('Frame',{BackgroundColor3=color.panel,
                BackgroundTransparency=settings.HubTransparency,BorderSizePixel=0,
                Size=UDim2.new(1,0,0,66),LayoutOrder=index},roster)
            corner(row,12); stroke(row,color.line,0.25)
            local name=text(row,player.DisplayName,12,9,W-160,23,12,color.white,true)
            name.TextTruncate=Enum.TextTruncate.AtEnd
            local username=text(row,'@'..player.Name,12,34,W-160,18,10,color.muted)
            username.TextTruncate=Enum.TextTruncate.AtEnd
            local relation=hub.Relations[player.UserId]
            local control=button(row,relation=='enemy' and 'INIMIGO' or relation=='ally' and 'ALIADO' or 'AUTO',W-132,13,92,40)
            control.BackgroundColor3=color.bg
            control.TextColor3=relation=='enemy' and color.red or relation=='ally' and color.green or color.muted
            control.Activated:Connect(function()
                if not hub.Running or player.Parent~=Players then return end
                local old=hub.Relations[player.UserId]
                hub.Relations[player.UserId]=old==nil and 'enemy' or old=='enemy' and 'ally' or nil
                refreshTeamCache()
                clearTarget()
                for who in pairs(hub.Highlights) do
                    if not enemy(who) then clearHighlight(who) end
                end
                rebuildRoster()
            end)
        end
    end
    bind(Players.PlayerAdded,function()
        if activeTab=='players' then rebuildRoster() end
    end)
    bind(Players.PlayerRemoving,function()
        task.defer(function()
            if hub.Running and activeTab=='players' then rebuildRoster() end
        end)
    end)

    local appearancePage=page('appearance')
    intro(appearancePage,'Do seu jeito','Cores e transparencias em um so lugar.')
    local palette=card(appearancePage,91)
    text(palette,'COR DE DESTAQUE',14,9,260,23,12,color.white,true)
    local themes={
        {'ROXO',Color3.fromRGB(165,132,255)}, {'VERDE',Color3.fromRGB(74,222,151)},
        {'AZUL',Color3.fromRGB(83,185,255)}, {'ROSA',Color3.fromRGB(255,128,190)},
    }
    local themeButtons={}
    local function applyTabs()
        for key,tab in pairs(tabButtons) do
            tab.BackgroundColor3=key==activeTab and color.purple or color.bg
            tab.TextColor3=key==activeTab and color.bg or color.muted
        end
    end
    local function setAccent(chosen)
        color.purple=chosen
        for _,object in ipairs(accentText) do object.TextColor3=chosen end
        for _,object in ipairs(accentFill) do object.BackgroundColor3=chosen end
        for _,object in ipairs(accentStroke) do object.Color=chosen end
        for _,object in pairs(pages) do object.ScrollBarImageColor3=chosen end
        for index,entry in ipairs(themeButtons) do
            entry.mark.Transparency=themes[index][2]==chosen and 0 or 1
            entry.button.Text=themes[index][2]==chosen and ('• '..themes[index][1]) or themes[index][1]
        end
        applyTabs()
    end
    for index,theme in ipairs(themes) do
        local control=button(palette,theme[1],14+(index-1)*79,40,75,38)
        control.BackgroundColor3=theme[2]
        control.TextColor3=color.bg
        control.TextSize=10
        themeButtons[index]={button=control,mark=stroke(control,color.white,1)}
        bind(control.Activated,function() setAccent(theme[2]) end)
    end
    local function applyTransparency()
        for _,object in ipairs(surfaces) do object.BackgroundTransparency=settings.HubTransparency end
        for _,object in ipairs(roster:GetChildren()) do
            if object:IsA('Frame') then object.BackgroundTransparency=settings.HubTransparency end
        end
    end
    slider(appearancePage,'TRANSPARENCIA DO HUB',0,85,settings.HubTransparency*100,percent,function(value)
        settings.HubTransparency=value/100
        applyTransparency()
    end)
    slider(appearancePage,'TRANSPARENCIA DO ESP',0,95,settings.FillTransparency*100,percent,function(value)
        settings.FillTransparency=value/100
        for _,highlight in pairs(hub.Highlights) do highlight.FillTransparency=settings.FillTransparency end
    end)
    local tip=card(appearancePage,65,true)
    local tipText=text(tip,'Arraste o cabecalho para mover o Hub.\nUse − para recolher e toque em Z para reabrir.\nShift direito: recolher / abrir. Esc: travar FOV.',2,0,W-34,65,10,color.muted)
    tipText.TextWrapped=true

    -- The guide never captures gameplay input. Only the edit handle does.
    local circle=create('Frame',{Name='FovGuide',BackgroundTransparency=1,
        BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0.5),Active=false,ZIndex=2},screen)
    corner(circle,10000)
    local circleStroke=stroke(circle,color.purple,0.25)
    circleStroke.Thickness=1.5
    table.insert(accentStroke,circleStroke)
    local handle=button(screen,'+',0,0,48,48)
    handle.Name='FovDragHandle'
    handle.TextSize=28
    handle.BackgroundColor3=color.bg
    handle.BackgroundTransparency=0.1
    handle.ZIndex=5
    corner(handle,24)
    table.insert(accentStroke,stroke(handle,color.purple,0))
    table.insert(accentText,handle)
    local editBar=surface(create('Frame',{Name='FovEditBar',BackgroundColor3=color.bg,
        BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-12),
        Size=UDim2.fromOffset(308,48),ZIndex=40},screen),12)
    local editScale=create('UIScale',{Scale=1},editBar)
    text(editBar,'FOV LIVRE',12,5,182,18,11,color.white,true)
    text(editBar,'Arraste o + · a mira esta pausada',12,25,190,15,9,color.muted)
    local lockNow=button(editBar,'TRAVAR',216,6,84,36)
    lockNow.BackgroundColor3=color.green
    lockNow.TextColor3=color.bg
    bind(lockNow.Activated,function() setLocked(true) end)

    local bubble=button(screen,'Z',16,130,52,52)
    bubble.Name='CollapsedHub'
    bubble.TextSize=22
    bubble.ZIndex=30
    bubble.Visible=false
    surface(bubble,18)
    table.insert(accentText,bubble)
    table.insert(accentStroke,stroke(bubble,color.purple,0.25))
    local bubbleScale=create('UIScale',{Scale=1},bubble)
    refreshFov=function()
        local v=viewport()
        local center=fovCenter(v)
        local diameter=math.min(v.X,v.Y)*settings.FOV*2
        local editing=not settings.FOVLocked
        circle.Size=UDim2.fromOffset(diameter,diameter)
        circle.Position=UDim2.fromOffset(center.X,center.Y)
        circle.Visible=editing or (settings.Aim and settings.ShowFOV)
        circleStroke.Transparency=editing and 0 or 0.25
        -- Keep the handle reachable even when the center is on a screen edge.
        handle.Position=UDim2.fromOffset(math.clamp(center.X-24,0,math.max(0,v.X-48)),
            math.clamp(center.Y-24,0,math.max(0,v.Y-48)))
        handle.Visible=editing
        editBar.Visible=editing
        ui.x.set(settings.FOVX*100)
        ui.y.set(settings.FOVY*100)
    end
    local cancelFovDrag
    setLocked=function(value)
        if cancelFovDrag then cancelFovDrag() end
        settings.FOVLocked=value
        if not value then settings.ShowFOV=true end
        clearTarget()
        ui.lock.set(value)
        ui.lock.detail.Text=value and 'Desative para arrastar o ponto ou ajustar X / Y.'
            or 'Posicao livre. A mira fica pausada durante o ajuste.'
        ui.x.enable(not value)
        ui.y.enable(not value)
        ui.center.Active=not value
        ui.center.AutoButtonColor=not value
        ui.center.TextTransparency=value and 0.55 or 0
        positionHint.Text=value and 'Destrave a posicao para editar.\nA posicao acompanha o tamanho da tela.'
            or '0% = esquerda / topo; 100% = direita / base.\nUse TRAVAR ao terminar o ajuste.'
        refresh()
    end
    local startPointer,startCenter
    cancelFovDrag=gesture(handle,function(position)
        if settings.FOVLocked then return false end
        startPointer=Vector2.new(position.X,position.Y)
        startCenter=fovCenter(viewport())
        return true
    end,function(position)
        if settings.FOVLocked then return end
        local v=viewport()
        if v.X<=0 or v.Y<=0 then return end
        local moved=startCenter+Vector2.new(position.X,position.Y)-startPointer
        settings.FOVX=math.clamp(moved.X/v.X,0,1)
        settings.FOVY=math.clamp(moved.Y/v.Y,0,1)
        clearTarget()
        refreshFov()
    end)
    refresh=function()
        ui.esp.set(settings.ESP)
        ui.aim.set(settings.Aim)
        ui.show.set(settings.ShowFOV)
        ui.ffa.set(settings.ForceFFA)
        footer.Text='ESP '..(settings.ESP and 'ON' or 'OFF')..'  ·  AIM '..
            (not settings.FOVLocked and 'PAUSADO' or settings.Aim and 'ON' or 'OFF')..
            '  ·  FOV '..(settings.FOVLocked and 'TRAVADO' or 'LIVRE')
        refreshFov()
    end
    for _,definition in ipairs(definitions) do
        local key=definition[1]
        bind(tabButtons[key].Activated,function()
            activeTab=key
            for name,object in pairs(pages) do object.Visible=name==key end
            applyTabs()
            if key=='players' then rebuildRoster() end
        end)
    end

    local firstLayout=true
    resize=function()
        if not hub.Running then return end
        cancelFovDrag()
        local v=viewport()
        -- Keep readable text in landscape: shorten the scrolling window first.
        local factor=math.max(0.1,math.min(1,(v.X-24)/W,(v.Y-24)/300))
        H=math.clamp((v.Y-24)/factor,300,540)
        scale.Scale=factor
        main.Size=UDim2.fromOffset(W,H)
        editScale.Scale=math.max(0.1,math.min(1,(v.X-16)/308))
        bubbleScale.Scale=math.max(0.1,math.min(1,math.min(v.X,v.Y)/100))
        if firstLayout then
            main.Position=UDim2.fromOffset(math.max(0,(v.X-W*factor)*0.5),
                math.max(0,(v.Y-H*factor)*0.5))
            firstLayout=false
        end
        clampWindow(main)
        clampWindow(bubble)
        refreshFov()
    end
    local viewportConnection
    local function watchCamera()
        if viewportConnection then viewportConnection:Disconnect() end
        local camera=Workspace.CurrentCamera
        if camera then viewportConnection=bind(camera:GetPropertyChangedSignal('ViewportSize'),resize) end
        resize()
    end
    bind(Workspace:GetPropertyChangedSignal('CurrentCamera'),watchCamera)
    local function draggable(control,window,onMoved)
        local pointer,origin,moved
        gesture(control,function(position)
            pointer=position
            origin=window.Position
            moved=false
        end,function(position)
            local delta=position-pointer
            if delta.Magnitude>7 then moved=true end
            if not moved then return end
            window.Position=UDim2.fromOffset(origin.X.Offset+delta.X,origin.Y.Offset+delta.Y)
            clampWindow(window)
            if onMoved then onMoved() end
        end)
    end
    draggable(dragArea,main)
    local lastBubbleDrag=-math.huge
    local bubblePositionSaved=false
    draggable(bubble,bubble,function()
        lastBubbleDrag=os.clock()
        bubblePositionSaved=true
    end)
    local function minimizeHub(value)
        hub.Minimized=value
        if value and not bubblePositionSaved then bubble.Position=main.Position end
        main.Visible=not value
        bubble.Visible=value
        resize()
    end
    bind(minimize.Activated,function() minimizeHub(true) end)
    bind(bubble.Activated,function()
        if os.clock()-lastBubbleDrag>=0.25 then minimizeHub(false) end
    end)
    bind(close.Activated,function() hub.Stop() end)
    bind(UIS.InputBegan,function(input,processed)
        if processed or UIS:GetFocusedTextBox() then return end
        if input.KeyCode==Enum.KeyCode.RightShift then minimizeHub(not hub.Minimized)
        elseif input.KeyCode==Enum.KeyCode.Escape and not settings.FOVLocked then setLocked(true) end
    end)
    bind(UIS.WindowFocusReleased,function()
        if not settings.FOVLocked then setLocked(true) end
    end)
    setAccent(color.purple)
    setLocked(settings.FOVLocked)
    watchCamera()
end

local elapsed=settings.TargetInterval
local renderKey='ZYON_SMOOTH_AIM_V8'
RunService:BindToRenderStep(renderKey,Enum.RenderPriority.Camera.Value+1,function(dt)
    if not hub.Running or not settings.Aim or not settings.FOVLocked then return end
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
            hub.UpdateStatus(n,teamSource)
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
    hub.Screen:Destroy()
    if env.ZyonHub==hub then env.ZyonHub=nil end
end
print('[ZYON] Hub v8 | interface responsiva, FOV movel e trava de posicao')
