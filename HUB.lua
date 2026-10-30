
--[[
    ZYON ESP HUB v2
    Mobile | Enemy ESP | Smooth Aim
    Team Filter | Friends Filter
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local ENV = (type(getgenv) == "function"
    and getgenv()) or _G

-- Desativa instâncias anteriores do mesmo Hub
if ENV.ZyonHub and ENV.ZyonHub.Stop then
    ENV.ZyonHub.Stop()
end

local SETTINGS = {
    ESP = true,
    Aim = true,

    -- Intensidade do acompanhamento
    Smoothness = 9,

    -- Percentual da menor dimensão da tela
    FOV = 0.23,

    -- Alcance máximo em studs
    MaxDistance = 350,

    -- Intervalos de atualização
    ESPInterval = 0.25,
    TargetInterval = 0.10,

    -- Verificar obstáculos antes de mirar
    VisibleOnly = true,

    -- Excluir amigos do Roblox
    IgnoreFriends = true,

    -- Excluir companheiros de equipe
    IgnoreTeam = true
}

local C = {
    BG = Color3.fromRGB(15, 17, 25),
    Panel = Color3.fromRGB(29, 30, 43),
    Purple = Color3.fromRGB(151, 99, 255),
    Green = Color3.fromRGB(40, 210, 126),
    Red = Color3.fromRGB(255, 54, 72),
    White = Color3.fromRGB(242, 241, 252),
    Muted = Color3.fromRGB(160, 160, 178)
}

local Hub = {
    Running = true,
    Minimized = false,
    HoldingAim = false,
    Target = nil,
    Highlights = {},
    Friends = {},
    Connections = {}
}

ENV.ZyonHub = Hub

local function Connect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(Hub.Connections, conn)
    return conn
end

local function New(class, props, parent)
    local obj = Instance.new(class)

    for k, v in pairs(props) do
        obj[k] = v
    end

    obj.Parent = parent
    return obj
end

local function Round(obj, radius)
    New("UICorner", {
        CornerRadius = UDim.new(0, radius)
    }, obj)
end

local function Border(obj, color)
    New("UIStroke", {
        Color = color,
        Thickness = 1.5,
        Transparency = 0.3
    }, obj)
end

local function Label(parent, text, x, y, w, h, size, color)
    return New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h),
        Text = text,
        TextSize = size,
        TextColor3 = color,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left
    }, parent)
end

-- =========================================
-- FILTRO DE AMIGOS E INIMIGOS
-- =========================================

local function RegisterPlayer(player)
    if player == LP then return end

    local id = player.UserId

    if not SETTINGS.IgnoreFriends then
        Hub.Friends[id] = "other"
        return
    end

    if Hub.Friends[id] ~= nil then
        return
    end

    -- Enquanto verifica, não mostra o jogador
    Hub.Friends[id] = "pending"

    task.spawn(function()
        local ok, isFriend = pcall(function()
            return LP:IsFriendsWithAsync(id)
        end)

        if not Hub.Running then return end

        if ok then
            Hub.Friends[id] =
                isFriend and "friend" or "other"
        else
            -- Falha: não exibir por precaução
            Hub.Friends[id] = "unknown"
        end
    end)
end

local function IsEnemy(player)
    if player == LP then
        return false
    end

    if player.Parent ~= Players then
        return false
    end

    if SETTINGS.IgnoreFriends then
        if Hub.Friends[player.UserId] ~= "other" then
            return false
        end
    end

    if SETTINGS.IgnoreTeam then
        if not LP.Neutral and not player.Neutral then
            if LP.Team and player.Team then
                if LP.Team == player.Team then
                    return false
                end
            end
        end
    end

    return true
end

-- =========================================
-- ENEMY ESP
-- =========================================

local function RemoveESP(player)
    local esp = Hub.Highlights[player]

    if esp then
        esp:Destroy()
        Hub.Highlights[player] = nil
    end
end

local function UpdateESP(player)
    if not SETTINGS.ESP or not IsEnemy(player) then
        RemoveESP(player)
        return false
    end

    local character = player.Character
    local humanoid = character
        and character:FindFirstChildOfClass("Humanoid")

    if not character or not humanoid
        or humanoid.Health <= 0 then
        RemoveESP(player)
        return false
    end

    local highlight = Hub.Highlights[player]

    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "Zyon_RedEnemy"
        highlight.FillColor = C.Red
        highlight.OutlineColor = C.Red
        highlight.FillTransparency = 0.55
        highlight.OutlineTransparency = 0
        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop

        highlight.Parent = PlayerGui
        Hub.Highlights[player] = highlight
    end

    highlight.Adornee = character
    highlight.Enabled = true

    return true
end

-- =========================================
-- TARGET SELECTOR
-- =========================================

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

local function GetAimPart(player)
    if not IsEnemy(player) then
        return nil
    end

    local char = player.Character
    if not char then return nil end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil
    end

    return char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
end

local function HasLineOfSight(camera, part)
    if not SETTINGS.VisibleOnly then
        return true
    end

    local origin = camera.CFrame.Position
    local direction = part.Position - origin

    local exclusions = {}

    if LP.Character then
        table.insert(exclusions, LP.Character)
    end

    RayParams.FilterDescendantsInstances = exclusions

    local hit = Workspace:Raycast(
        origin,
        direction,
        RayParams
    )

    return hit == nil
        or hit.Instance:IsDescendantOf(part.Parent)
end

local function FindTarget()
    local camera = Workspace.CurrentCamera
    if not camera then return nil end

    local viewport = camera.ViewportSize
    local center = viewport * 0.5

    local radius = math.min(
        viewport.X,
        viewport.Y
    ) * SETTINGS.FOV

    local bestPart = nil
    local bestDist = radius * radius

    local cameraPos = camera.CFrame.Position

    for _, player in ipairs(Players:GetPlayers()) do
        local part = GetAimPart(player)

        if part then
            local worldDist =
                (part.Position - cameraPos).Magnitude

            if worldDist <= SETTINGS.MaxDistance then
                local screenPos, onScreen =
                    camera:WorldToViewportPoint(part.Position)

                if onScreen and screenPos.Z > 0 then
                    local dx = screenPos.X - center.X
                    local dy = screenPos.Y - center.Y
                    local dist2 = dx * dx + dy * dy

                    if dist2 < bestDist then
                        if HasLineOfSight(camera, part) then
                            bestDist = dist2
                            bestPart = part
                        end
                    end
                end
            end
        end
    end

    return bestPart
end

-- =========================================
-- INTERFACE
-- =========================================

local Screen = New("ScreenGui", {
    Name = "ZYON_ESP_HUB_V2",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    DisplayOrder = 1000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
}, PlayerGui)

Hub.Screen = Screen

local WIDTH = 344
local HEIGHT = 316

local Main = New("Frame", {
    Name = "MainHub",
    BackgroundColor3 = C.BG,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(WIDTH, HEIGHT),
    Position = UDim2.fromOffset(20, 70),
    Active = true
}, Screen)

Round(Main, 19)
Border(Main, C.Purple)

local MainScale = New("UIScale", {
    Scale = 1
}, Main)

local Header = New("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 54),
    Active = true
}, Main)

local Title = Label(
    Header, "ZYON HUB",
    17, 9, 185, 34, 21, C.Purple
)
Title.Font = Enum.Font.GothamBold

local MinButton = New("TextButton", {
    Text = "−",
    TextSize = 24,
    Font = Enum.Font.GothamBold,
    TextColor3 = C.White,
    BackgroundColor3 = C.Panel,
    Position = UDim2.new(1, -84, 0, 10),
    Size = UDim2.fromOffset(34, 34)
}, Header)
Round(MinButton, 10)

local CloseButton = New("TextButton", {
    Text = "×",
    TextSize = 23,
    Font = Enum.Font.GothamBold,
    TextColor3 = C.Red,
    BackgroundColor3 = C.Panel,
    Position = UDim2.new(1, -44, 0, 10),
    Size = UDim2.fromOffset(34, 34)
}, Header)
Round(CloseButton, 10)

local Line = New("Frame", {
    BackgroundColor3 = C.Purple,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(15, 55),
    Size = UDim2.new(1, -30, 0, 1)
}, Main)

local function CreateSwitch(text, desc, y, default)
    local panel = New("Frame", {
        BackgroundColor3 = C.Panel,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, y),
        Size = UDim2.new(1, -28, 0, 66)
    }, Main)

    Round(panel, 12)

    local heading = Label(
        panel, text,
        12, 6, 200, 26, 15, C.White
    )
    heading.Font = Enum.Font.GothamBold

    Label(
        panel, desc,
        12, 36, 270, 18, 11, C.Muted
    )

    local btn = New("TextButton", {
        Text = default and "ON" or "OFF",
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextColor3 = C.BG,
        BackgroundColor3 =
            default and C.Green or C.Red,
        Position = UDim2.new(1, -61, 0, 8),
        Size = UDim2.fromOffset(49, 27)
    }, panel)

    Round(btn, 12)
    return btn
end

local ESPToggle = CreateSwitch(
    "ENEMY ESP",
    "Apenas inimigos em vermelho",
    67,
    SETTINGS.ESP
)

local AimToggle = CreateSwitch(
    "SMOOTH AIM",
    "Segure o botão AIM para mirar",
    142,
    SETTINGS.Aim
)

local StatusPanel = New("Frame", {
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(14, 219),
    Size = UDim2.new(1, -28, 0, 51)
}, Main)
Round(StatusPanel, 12)

local Status = Label(
    StatusPanel,
    "ESP: ATIVO | AIM: ATIVO",
    12, 5, 280, 20, 12, C.Green
)

local Count = Label(
    StatusPanel,
    "Adversarios: 0",
    12, 27, 280, 18, 12, C.White
)

local Footer = Label(
    Main,
    "ZYON  •  MOBILE  •  DRAG TO MOVE",
    15, 282, 313, 20, 11, C.Purple
)
Footer.TextXAlignment = Enum.TextXAlignment.Center

-- ÍCONE FLUTUANTE DO HUB
local Bubble = New("TextButton", {
    Name = "MiniHub",
    Text = "◈",
    TextSize = 31,
    TextColor3 = C.White,
    Font = Enum.Font.GothamBold,
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(12, 135),
    Size = UDim2.fromOffset(58, 58),
    Visible = false,
    Active = true
}, Screen)

Round(Bubble, 21)
Border(Bubble, C.Purple)

local BubbleScale = New("UIScale", {
    Scale = 1
}, Bubble)

-- BOTÃO DE MIRA PARA CELULAR
local AimButton = New("TextButton", {
    Name = "MobileAim",
    Text = "AIM",
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    TextColor3 = C.White,
    BackgroundColor3 = C.Panel,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(68, 68),
    Position = UDim2.fromOffset(100, 100),
    Active = true,
    Visible = SETTINGS.Aim
}, Screen)

Round(AimButton, 34)
Border(AimButton, C.Purple)

local AimScale = New("UIScale", {
    Scale = 1
}, AimButton)

-- =========================================
-- RESPONSIVIDADE
-- =========================================

local Initialized = false
local CameraConn

local function Viewport()
    local camera = Workspace.CurrentCamera
    return camera and camera.ViewportSize
        or Vector2.new(800, 600)
end

local function ClampGUI(gui, w, h)
    local vp = Viewport()

    local x = math.clamp(
        gui.Position.X.Offset,
        0,
        math.max(0, vp.X - w)
    )

    local y = math.clamp(
        gui.Position.Y.Offset,
        0,
        math.max(0, vp.Y - h)
    )

    gui.Position = UDim2.fromOffset(x, y)
end

local function ResizeHub()
    if not Hub.Running then return end

    local vp = Viewport()

    local scale = math.min(
        1,
        math.max(0.1, (vp.X - 24) / WIDTH),
        math.max(0.1, (vp.Y - 24) / HEIGHT)
    )

    MainScale.Scale = scale

    if not Initialized then
        Main.Position = UDim2.fromOffset(
            math.floor((vp.X - WIDTH * scale) / 2),
            math.floor((vp.Y - HEIGHT * scale) / 2)
        )

        Initialized = true
    end

    ClampGUI(Main, WIDTH * scale, HEIGHT * scale)

    local miniScale = math.min(
        1,
        math.max(0.1, math.min(vp.X, vp.Y) / 250)
    )

    BubbleScale.Scale = miniScale
    AimScale.Scale = miniScale

    local miniSize = 58 * miniScale
    local aimSize = 68 * miniScale

    ClampGUI(Bubble, miniSize, miniSize)

    AimButton.Position = UDim2.fromOffset(
        math.max(0, vp.X - aimSize - 20),
        math.max(0, vp.Y * 0.55 - aimSize / 2)
    )
end

local function WatchCamera()
    if CameraConn then
        CameraConn:Disconnect()
        CameraConn = nil
    end

    local camera = Workspace.CurrentCamera

    if camera then
        CameraConn = Connect(
            camera:GetPropertyChangedSignal("ViewportSize"),
            ResizeHub
        )
    end

    ResizeHub()
end

Connect(
    Workspace:GetPropertyChangedSignal("CurrentCamera"),
    WatchCamera
)

WatchCamera()

-- =========================================
-- ARRASTAR COM TOQUE OU MOUSE
-- =========================================

local function Draggable(handle, gui, afterDrag)
    local dragging = false
    local inputStart
    local positionStart
    local activeInput
    local moved = false

    Connect(handle.InputBegan, function(input)
        local kind = input.UserInputType

        if kind ~= Enum.UserInputType.Touch
            and kind ~= Enum.UserInputType.MouseButton1 then
            return
        end

        dragging = true
        activeInput = input
        inputStart = input.Position
        positionStart = gui.Position
        moved = false
    end)

    Connect(UIS.InputChanged, function(input)
        if not dragging or not activeInput then
            return
        end

        if activeInput.UserInputType ==
            Enum.UserInputType.Touch then
            if input ~= activeInput then return end
        elseif input.UserInputType ~=
            Enum.UserInputType.MouseMovement then
            return
        end

        local delta = input.Position - inputStart

        if delta.Magnitude > 7 then
            moved = true
        end

        if not moved then return end

        local vp = Viewport()
        local size = gui.AbsoluteSize

        local x = math.clamp(
            positionStart.X.Offset + delta.X,
            0,
            math.max(0, vp.X - size.X)
        )

        local y = math.clamp(
            positionStart.Y.Offset + delta.Y,
            0,
            math.max(0, vp.Y - size.Y)
        )

        gui.Position = UDim2.fromOffset(x, y)
    end)

    Connect(UIS.InputEnded, function(input)
        if not dragging then return end

        local match = input == activeInput

        if activeInput and
            activeInput.UserInputType ==
            Enum.UserInputType.MouseButton1 then
            match = input.UserInputType ==
                Enum.UserInputType.MouseButton1
        end

        if match then
            dragging = false
            activeInput = nil

            if moved and afterDrag then
                afterDrag()
            end
        end
    end)
end

Draggable(Header, Main)

local LastBubbleDrag = -math.huge

Draggable(Bubble, Bubble, function()
    LastBubbleDrag = os.clock()
end)

-- =========================================
-- MINIMIZAR
-- =========================================

local function SetMinimized(value)
    Hub.Minimized = value

    if value then
        Bubble.Position = Main.Position
        Main.Visible = false
        Bubble.Visible = true
    else
        Main.Position = Bubble.Position
        Main.Visible = true
        Bubble.Visible = false
    end

    ResizeHub()
end

Connect(MinButton.Activated, function()
    SetMinimized(true)
end)

Connect(Bubble.Activated, function()
    if os.clock() - LastBubbleDrag < 0.25 then
        return
    end

    SetMinimized(false)
end)

-- =========================================
-- BOTÕES
-- =========================================

local function RefreshStatus()
    ESPToggle.Text = SETTINGS.ESP and "ON" or "OFF"
    ESPToggle.BackgroundColor3 =
        SETTINGS.ESP and C.Green or C.Red

    AimToggle.Text = SETTINGS.Aim and "ON" or "OFF"
    AimToggle.BackgroundColor3 =
        SETTINGS.Aim and C.Green or C.Red

    AimButton.Visible = SETTINGS.Aim

    Status.Text =
        "ESP: " .. (SETTINGS.ESP and "ON" or "OFF")
        .. "  |  AIM: "
        .. (SETTINGS.Aim and "ON" or "OFF")

    Status.TextColor3 =
        (SETTINGS.ESP or SETTINGS.Aim)
        and C.Green or C.Muted
end

Connect(ESPToggle.Activated, function()
    SETTINGS.ESP = not SETTINGS.ESP

    if not SETTINGS.ESP then
        for player in pairs(Hub.Highlights) do
            RemoveESP(player)
        end
    end

    RefreshStatus()
end)

Connect(AimToggle.Activated, function()
    SETTINGS.Aim = not SETTINGS.Aim

    if not SETTINGS.Aim then
        Hub.HoldingAim = false
        Hub.Target = nil
    end

    RefreshStatus()
end)

-- =========================================
-- CONTROLE DE AIM POR TOQUE
-- =========================================

local AimInput

Connect(AimButton.InputBegan, function(input)
    local kind = input.UserInputType

    if kind ~= Enum.UserInputType.Touch
        and kind ~= Enum.UserInputType.MouseButton1 then
        return
    end

    if not SETTINGS.Aim then return end

    AimInput = input
    Hub.HoldingAim = true
    Hub.Target = nil

    AimButton.BackgroundColor3 = C.Purple
    AimButton.Text = "LOCK"
end)

Connect(UIS.InputEnded, function(input)
    if not AimInput then return end

    local released = input == AimInput

    if AimInput.UserInputType ==
        Enum.UserInputType.MouseButton1 then
        released = input.UserInputType ==
            Enum.UserInputType.MouseButton1
    end

    if released then
        AimInput = nil
        Hub.HoldingAim = false
        Hub.Target = nil

        AimButton.BackgroundColor3 = C.Panel
        AimButton.Text = "AIM"
    end
end)

-- =========================================
-- AIMBOT SUAVE
-- =========================================

local RENDER_NAME = "ZYON_SMOOTH_AIM_V2"
local scanElapsed = SETTINGS.TargetInterval

RunService:BindToRenderStep(
    RENDER_NAME,
    Enum.RenderPriority.Camera.Value + 1,
    function(dt)
        if not Hub.Running then return end
        if not SETTINGS.Aim then return end
        if not Hub.HoldingAim then return end

        local camera = Workspace.CurrentCamera
        if not camera then return end

        scanElapsed += dt

        if scanElapsed >= SETTINGS.TargetInterval then
            scanElapsed = 0
            Hub.Target = FindTarget()
        end

        local target = Hub.Target
        if not target or not target.Parent then
            return
        end

        local char = target.Parent
        local hum = char:FindFirstChildOfClass("Humanoid")

        if not hum or hum.Health <= 0 then
            Hub.Target = nil
            return
        end

        local targetPlayer =
            Player
