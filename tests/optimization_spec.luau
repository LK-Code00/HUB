-- Regressions for resource lifetimes, acquisition work, controls and async queries.
restart(false)
test('respawn and camera replacement keep connection registry bounded',function()
    prepareClassification()
    local before=#hub.Connections
    for _=1,40 do
        local char=makeCharacter(targetPlayer,vec(550,400,10))
        targetPlayer.CharacterAdded:Fire(char)
        workspace:GetPropertyChangedSignal('CurrentCamera'):Fire()
    end
    assert(#hub.Connections==before)
    for _,connection in ipairs(hub.Connections) do assert(connection.Connected) end
end)
test('acquisition and tracking cast one ray per frame for a single candidate',function()
    prepareClassification()
    hub.Relations[targetPlayer.UserId]='enemy'
    api.refreshTeamCache()
    workspace.RayCount=0
    step()
    assert(workspace.RayCount==1 and hub.Target==targetHead)
    step(settings.TargetInterval)
    assert(workspace.RayCount==2 and hub.Target==targetHead)
end)
test('farther candidates skip raycasts without hiding a visible fallback',function()
    prepareClassification()
    local _,otherHead=makeCharacter(otherPlayer,vec(600,400,10))
    hub.Relations[targetPlayer.UserId]='enemy';hub.Relations[otherPlayer.UserId]='enemy'
    api.refreshTeamCache()
    workspace.RayCount=0
    assert(api.findTarget()==targetHead and workspace.RayCount==1)
    local original=workspace.Raycast
    function workspace:Raycast(origin,direction)
        self.RayCount+=1
        if direction.X==550 then return {Instance=Instance.new('Part')} end
        return nil
    end
    hub.Target=nil
    workspace.RayCount=0
    assert(api.findTarget()==otherHead and workspace.RayCount==2)
    workspace.Raycast=original
end)
test('manual enemy never bypasses a conflicting generic match ID',function()
    prepareClassification()
    hub.Relations[targetPlayer.UserId]='enemy'
    lp.MatchIdAttribute='one';targetPlayer.MatchIdAttribute='two'
    assert(selected()==nil)
    assert(hub.Decisions[targetPlayer.UserId].reason:find('outra partida'))
end)
test('new settings controls change behavior and persist',function()
    prepareClassification()
    press(byText('JOGADORES'))
    if settings.IgnoreFriends then press(control('Ignorar amigos')) end
    hub.Friends[targetPlayer.UserId]='friend'
    settings.ForceFFA=true
    assert(selected()==targetHead)
    press(control('Ignorar amigos'))
    assert(selected()==nil)
    hub.Friends[targetPlayer.UserId]='other'; settings.ForceFFA=false
    if settings.IgnoreTeam then press(control('Ignorar equipe')) end
    assert(selected()==targetHead)
    press(control('Ignorar equipe'))
    assert(selected()==nil)
    slide('DISTANCIA MAXIMA',0)
    slide('INTERVALO DE BUSCA',1)
    slide('INTERVALO DO ESP',0)
    slide('PAUSA APOS CONTROLE MANUAL',1)
    hub.SaveConfig();restart(true)
    assert(settings.MaxDistance==1 and settings.TargetInterval==2)
    assert(settings.ESPInterval==0.05 and settings.ManualPause==2)
end)
test('shader slider reuses effects and option changes never rescan map',function()
    local scans=0
    local original=workspace.GetDescendants
    workspace.GetDescendants=function(self) scans+=1; return original(self) end
    press(byText('QUENTE'))
    local effect=lighting:FindFirstChild('ZyonBloom')
    for i=1,10 do slide('INTENSIDADE DOS EFEITOS',i/10) end
    assert(lighting:FindFirstChild('ZyonBloom')==effect)
    press(control('Reduzir particulas'))
    press(control('Modo leve'))
    press(byText('RESTAURAR GRAFICOS DO JOGO'))
    assert(scans==0)
    workspace.GetDescendants=original
end)
test('friendship is queried even with filtering disabled and transient errors retry',function()
    task.queue={};task.delays={}
    settings.IgnoreFriends=false
    hub.Friends[targetPlayer.UserId]=nil
    local original=lp.IsFriendsWithAsync
    local calls=0
    lp.IsFriendsWithAsync=function()
        calls+=1
        if calls<2 then error('temporary failure') end
        return true
    end
    api.registerFriend(targetPlayer)
    assert(hub.Friends[targetPlayer.UserId]=='pending')
    table.remove(task.queue,1)()
    assert(hub.Friends[targetPlayer.UserId]=='unknown')
    task.runDelays()
    assert(calls==2 and hub.Friends[targetPlayer.UserId]=='friend')
    lp.IsFriendsWithAsync=original
end)
test('friendship failures stop after three attempts',function()
    task.queue={};task.delays={}
    hub.Friends[targetPlayer.UserId]=nil
    local original=lp.IsFriendsWithAsync
    local calls=0
    lp.IsFriendsWithAsync=function() calls+=1;error('unavailable') end
    api.registerFriend(targetPlayer)
    table.remove(task.queue,1)()
    for _=1,5 do task.runDelays() end
    assert(calls==3 and hub.Friends[targetPlayer.UserId]=='unknown')
    lp.IsFriendsWithAsync=original
end)
test('slow ESP interval does not delay team classification',function()
    prepareClassification()
    settings.ESPInterval=5
    lp.MatchTeamAttribute=0;targetPlayer.MatchTeamAttribute=1
    api.updateBackground(0)
    assert(hub.Decisions[targetPlayer.UserId].allowed)
    targetPlayer.MatchTeamAttribute=0
    api.updateBackground(1)
    assert(not hub.Decisions[targetPlayer.UserId].allowed)
end)
test('leaving match clears override even when the same arena is reused',function()
    ffaFixture();hub.SetMatchMode('ffa')
    local parent=lp.Character.Parent
    lp.Character.Parent=workspace
    api.refreshTeamCache()
    lp.Character.Parent=parent
    api.refreshTeamCache()
    local mode,_,override=hub.GetMatchMode()
    assert(mode=='unknown' and override==nil)
    game.GameId=42
end)
test('pending friendship requests do not run after shutdown',function()
    task.queue={};task.delays={}
    hub.Friends[targetPlayer.UserId]=nil
    api.registerFriend(targetPlayer)
    local original=lp.IsFriendsWithAsync
    lp.IsFriendsWithAsync=function() error('must not query after Stop') end
    hub.Stop()
    table.remove(task.queue,1)()
    assert(hub.Friends[targetPlayer.UserId]=='pending')
    assert(#hub.Connections==0 and next(hub.Decisions)==nil)
    lp.IsFriendsWithAsync=original
end)
print(string.format('%d total behavioral checks passed',passed))
