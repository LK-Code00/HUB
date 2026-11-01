-- Persistence: drive actual UI events, restart without the session cache,
-- and inspect the resulting controls and settings loaded from the file API.
local function restart(clearCache)
    if hub and hub.Running then hub.Stop() end
    if clearCache then environment.ZyonHubProfiles=nil end
    api=startHub(); hub=environment.ZyonHub; settings=api.settings
end
local function slide(title,fraction)
    local target=control(title)
    local event=pointer('MouseButton1',target.AbsolutePosition.X+target.AbsoluteSize.X*fraction,0)
    target.InputBegan:Fire(event); input.InputEnded:Fire(event)
end
local function drag(object,dx,dy)
    local event=pointer('MouseButton1',0,0)
    object.InputBegan:Fire(event)
    input.InputChanged:Fire(pointer('MouseMovement',dx,dy))
    input.InputEnded:Fire(event)
end
restart(false)
test('save all UI preferences and restore from disk without session cache',function()
    press(byText('ROSA'))
    slide('TRANSPARENCIA DO HUB',0.4)
    slide('TRANSPARENCIA DO ESP',0.6)
    slide('SENSIBILIDADE',0.7)
    if settings.FOVLocked then press(control('Travar posicao')) end
    slide('POSICAO HORIZONTAL · X',0.65)
    slide('POSICAO VERTICAL · Y',0.32)
    slide('RAIO DO FOV',0.4)
    press(control('Travar posicao'))
    press(control('ESP de inimigos'))
    press(control('Priorizar camera manual'))
    press(control('Forcar modo FFA'))
    press(byText('JOGADORES'))
    -- Existing enemy -> ally; this mutation must be saved without a settings edit.
    local relationButton=byText('Opponent2').Parent:FindFirstChildOfClass('TextButton')
    press(relationButton)
    assert(hub.Relations[2]=='ally')
    drag(named('DragHeader'),-10,20)
    press(byText('−'))
    drag(named('CollapsedHub'),40,60)
    local expected={}
    for _,key in ipairs({'ESP','Aim','RespectManualInput','ForceFFA','Smoothness','FOV','FOVX','FOVY',
        'FOVLocked','ShowFOV','Accent','ActiveTab','HubTransparency','FillTransparency','WindowX','WindowY',
        'BubbleX','BubbleY','BubbleMoved','Minimized'}) do expected[key]=settings[key] end
    task.runDelays()
    assert(disk.files['ZyonHub_1.json'])
    local before=disk.writes
    restart(true)
    for key,value in pairs(expected) do
        assert(settings[key]==value,'Not restored: '..key)
    end
    assert(hub.Relations[2]=='ally')
    assert(named('playersPage').Visible and named('CollapsedHub').Visible and not named('Hub').Visible)
    assert(disk.writes==before,'Startup should not rewrite an unchanged profile')
end)
test('slider changes are batched and close flushes pending edits',function()
    task.runDelays()
    local before=disk.writes
    for i=1,10 do slide('SENSIBILIDADE',i/10) end
    assert(disk.writes==before)
    task.runDelays()
    assert(disk.writes==before+1)
    settings.FOVX=0.73
    hub.Stop()
    local saved=http:JSONDecode(disk.files['ZyonHub_1.json'])
    near(saved.Settings.FOVX,0.73)
    restart(true)
end)
test('failed writes retain session preferences and can be retried',function()
    disk.fail=true
    settings.FOV=0.33
    task.runDelays()
    assert(hub.SaveStatus:find('Falha'))
    restart(false)
    near(settings.FOV,0.33)
    disk.fail=false
    press(byText('SALVAR AGORA'))
    assert(hub.SaveStatus:find('Salvo neste dispositivo'))
    restart(true)
    near(settings.FOV,0.33)
end)
test('corrupt and invalid saved values do not break startup',function()
    hub.Stop()
    disk.files['ZyonHub_1.json']='broken JSON'
    restart(true)
    assert(hub.SaveStatus:find('invalido'))
    near(settings.FOVX,0.5)
    hub.Stop()
    disk.files['ZyonHub_1.json']=http:JSONEncode({Version=1,Settings={
        FOVX=math.huge,FOVY=-2,Smoothness='oops',Accent=99,ActiveTab='bad',ESP='false',
    },Relations={['42']={['2']='invalid',['not-an-id']='enemy'}}})
    restart(true)
    near(settings.FOVX,0.5); near(settings.FOVY,0)
    assert(settings.Smoothness==9 and settings.Accent==4 and settings.ActiveTab=='aim' and settings.ESP)
    assert(next(hub.Relations)==nil)
end)
test('manual relations persist per game and profiles are separate per account',function()
    hub.Relations[2]='ally'
    hub.SaveConfig()
    hub.Stop()
    game.GameId=99
    restart(true)
    assert(hub.Relations[2]==nil)
    hub.Relations[3]='enemy'
    hub.SaveConfig()
    hub.Stop()
    game.GameId=42
    restart(true)
    assert(hub.Relations[2]=='ally' and hub.Relations[3]==nil)
    hub.Stop()
    lp.UserId=7
    restart(true)
    assert(settings.Accent==1 and next(hub.Relations)==nil)
    settings.Smoothness=17
    hub.Stop()
    assert(disk.files['ZyonHub_7.json'])
    lp.UserId=1
    restart(true)
    assert(settings.Smoothness==9)
end)
test('environments without file APIs truthfully keep session-only settings',function()
    hub.Stop()
    local oldRead,oldWrite=readfile,writefile
    readfile,writefile=nil,nil
    restart(true)
    settings.Smoothness=16
    task.runDelays()
    assert(hub.SaveStatus:find('sem acesso a arquivos'))
    restart(false)
    assert(settings.Smoothness==16)
    hub.Stop()
    readfile,writefile=oldRead,oldWrite
    restart(true)
end)

local targetPlayer=players.list[2]
local otherPlayer=players.list[3]
local targetHead,targetHumanoid,targetCharacter
local function step(dt) runService.bindings.ZYON_SMOOTH_AIM_V9(dt or 1/60) end
local function prepareAim()
    settings.Aim=true; settings.RespectManualInput=true; settings.FOVLocked=true
    settings.FOVX=0.5; settings.FOVY=0.5; settings.FOV=0.25; settings.MaxDistance=10000
    hub.Interacting=0
    objects.viewport=vec(1000,800); camera.ViewportSize=objects.viewport
    camera.CFrame=frame(vec(0,0,0)); camera.CameraType=Enum.CameraType.Custom
    function camera:WorldToViewportPoint(position) return position,not self.Offscreen end
    camera.Offscreen=false
    workspace.Blocked=false
    workspace.RayCount=0
    function workspace:Raycast(origin,direction)
        self.RayCount+=1
        self.LastRayOrigin=origin; self.LastRayDirection=direction
        if self.Blocked then return {Instance=Instance.new('Part')} end
        return nil
    end
    local localChar=makeCharacter(lp,vec(0,0,0))
    lp.CharacterAdded:Fire(localChar)
    targetCharacter,targetHead,targetHumanoid=makeCharacter(targetPlayer,vec(550,400,10))
    targetPlayer.CharacterAdded:Fire(targetCharacter)
    otherPlayer.Character:FindFirstChildOfClass('Humanoid').Health=0
    hub.Relations[targetPlayer.UserId]='enemy'; hub.Friends[targetPlayer.UserId]='other'
    hub.Relations[otherPlayer.UserId]='ally'
    targetPlayer.DeadAttribute=nil; targetPlayer.AliveAttribute=nil
    api.refreshTeamCache()
    input.WindowFocused:Fire()
    hub.ManualUntil=0
    hub.Target=nil
    objects.aimWrites=0
    settings.Aim=false
    step()
    settings.Aim=true
end
test('visible living target is tracked normally',function()
    prepareAim(); step()
    assert(hub.Target==targetHead and objects.aimWrites==1)
end)
test('wall appearing after acquisition prevents the very next camera write',function()
    prepareAim(); step()
    local writes=objects.aimWrites
    workspace.Blocked=true
    step()
    assert(hub.Target==nil and objects.aimWrites==writes)
    assert(api.findTarget()==nil)
end)
test('blocked targets do not trigger a full player scan every frame',function()
    prepareAim()
    workspace.Blocked=true
    step()
    local rays=workspace.RayCount
    for _=1,5 do step(0.01) end
    assert(workspace.RayCount==rays and hub.Target==nil)
    step(settings.TargetInterval)
    assert(workspace.RayCount>rays)
end)
test('death event releases target even before replicated health changes',function()
    prepareAim(); step()
    targetHumanoid.Died:Fire()
    assert(hub.Target==nil)
    local writes=objects.aimWrites
    step()
    assert(objects.aimWrites==writes and api.findTarget()==nil)
end)
test('dead state, zero health, and replicated death markers reject stale targets',function()
    prepareAim(); step()
    targetHumanoid.State=Enum.HumanoidStateType.Dead
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
    prepareAim(); step()
    targetHumanoid.Health=0
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
    prepareAim(); step()
    targetPlayer.DeadAttribute=true
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
    targetPlayer.DeadAttribute=nil
    targetCharacter.AliveAttribute=false
    assert(api.findTarget()==nil)
end)
test('old corpse and removed character cannot continue tracking',function()
    prepareAim(); step()
    local old=targetCharacter
    makeCharacter(targetPlayer,vec(2000,400,10))
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
    assert(api.targetInfo(camera,old:FindFirstChild('Head'))==nil)
    prepareAim(); step()
    targetCharacter.Parent=nil
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
end)
test('FOV, range and screen checks are enforced between acquisition ticks',function()
    prepareAim(); step()
    targetHead.Position=vec(900,400,10)
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
    prepareAim(); step()
    settings.MaxDistance=10
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
    prepareAim(); step()
    camera.Offscreen=true
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
end)
test('line of sight tests the exact aim offset on the root part',function()
    prepareAim()
    targetHead.Name='HumanoidRootPart'
    step()
    near(workspace.LastRayDirection.Y,401.1)
    assert(objects.aimWrites==1)
end)
test('local death and script-controlled cameras do not get overridden',function()
    prepareAim(); step()
    lp.Character:FindFirstChildOfClass('Humanoid').Health=0
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
    prepareAim(); step()
    camera.CameraType=Enum.CameraType.Scriptable
    step()
    assert(hub.Target==nil and objects.aimWrites==1)
end)
test('mouse movement releases aim until the manual-input cooldown expires',function()
    prepareAim(); step()
    local move=pointer('MouseMovement',600,400); move.Delta=vec(5,0)
    input.InputChanged:Fire(move)
    assert(hub.Target==nil)
    step()
    assert(objects.aimWrites==1)
    hub.ManualUntil=0
    step()
    assert(objects.aimWrites==2)
end)
test('camera touch holds manual priority until released',function()
    prepareAim(); step()
    local touch=pointer('Touch',700,400)
    input.InputBegan:Fire(touch,false)
    touch.Position=vec(750,420)
    input.InputChanged:Fire(touch)
    hub.ManualUntil=0 -- stationary held finger must still retain control
    step()
    assert(objects.aimWrites==1 and hub.Target==nil)
    input.InputEnded:Fire(touch)
    step()
    assert(objects.aimWrites==1)
    hub.ManualUntil=0
    step()
    assert(objects.aimWrites==2)
end)
test('left joystick and processed touches do not steal camera aim',function()
    prepareAim(); step()
    local left=pointer('Touch',100,400)
    input.InputBegan:Fire(left,false)
    left.Position=vec(120,420)
    input.InputChanged:Fire(left)
    step()
    assert(objects.aimWrites==2)
    local uiTouch=pointer('Touch',700,400)
    input.InputBegan:Fire(uiTouch,true)
    uiTouch.Position=vec(750,420)
    input.InputChanged:Fire(uiTouch)
    step()
    assert(objects.aimWrites==3)
    input.InputEnded:Fire(left); input.InputEnded:Fire(uiTouch)
end)
test('held right stick and window focus pause tracking',function()
    prepareAim(); step()
    local stick=pointer('Gamepad1',0.7,0); stick.KeyCode=Enum.KeyCode.Thumbstick2
    input.InputChanged:Fire(stick)
    hub.ManualUntil=0
    step()
    assert(objects.aimWrites==1)
    stick.Position=vec(0,0)
    input.InputChanged:Fire(stick)
    hub.ManualUntil=0
    step()
    assert(objects.aimWrites==2)
    input.WindowFocusReleased:Fire()
    step()
    assert(objects.aimWrites==2 and hub.Target==nil)
end)
test('new character can be acquired after death and old listeners are disconnected',function()
    prepareAim(); step()
    local dead=targetHumanoid
    dead.Died:Fire()
    local character,head=makeCharacter(targetPlayer,vec(560,400,10))
    targetPlayer.CharacterAdded:Fire(character)
    step(settings.TargetInterval)
    assert(hub.Target==head and objects.aimWrites==2)
    for _,connection in ipairs(dead.Died.connections) do assert(not connection.Connected) end
    hub.Stop()
end)
print(string.format('%d behavioral checks passed',passed))
