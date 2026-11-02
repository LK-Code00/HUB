restart(false)
local function ffaFixture()
    prepareStructure(aSide)
    lp.Character.Parent=aSide
    settings.ForceFFA=false
    matchOne.GameModeAttribute=nil
    lp.LastModesSelectedAttribute='FFA_Standard,_LTM'
    targetPlayer.LastModesSelectedAttribute='_LTM'
    hub.SetMatchMode('auto')
end
test('single-A layout and queue preferences do not falsely prove teams or FFA',function()
    ffaFixture()
    assert(selected()==nil)
    local mode=hub.GetMatchMode()
    assert(mode=='unknown')
    assert(hub.Decisions[targetPlayer.UserId].reason:find('modo desconhecido'))
end)
test('explicit current-match FFA enables same-group aim and ESP with legacy FFA off',function()
    ffaFixture()
    press(byText('FFA'))
    assert(settings.ForceFFA==false)
    assert(selected()==targetHead)
    assert(api.updateHighlight(targetPlayer))
    assert(hub.Decisions[targetPlayer.UserId].reason=='Sniper Duels: FFA na mesma partida')
end)
test('current-match FFA still excludes other matches and dead storage characters',function()
    ffaFixture();hub.SetMatchMode('ffa')
    targetPlayer.Character.Parent=otherSide
    assert(selected()==nil)
    local storage=Instance.new('Folder');storage.Name='_DEAD_CHARACTERS'
    targetPlayer.Character.Parent=storage
    targetHumanoid.Health=25
    assert(selected()==nil and not api.updateHighlight(targetPlayer))
    assert(api.livingCharacter(targetPlayer)==nil)
end)
test('current FFA_Standard metadata works automatically without trusting queue history',function()
    ffaFixture()
    lp.LastModesSelectedAttribute='2v2,4v4'
    matchOne.GameModeAttribute='FFA_Standard'
    assert(selected()==targetHead)
    local mode,_,override=hub.GetMatchMode()
    assert(mode=='ffa' and override==nil)
end)
test('FFA override expires on a different match before cached targeting can run',function()
    ffaFixture();hub.SetMatchMode('ffa');selected()
    lp.Character.Parent=otherSide;targetPlayer.Character.Parent=otherSide
    assert(api.targetInfo(camera,targetHead)==nil)
    assert(selected()==nil)
    local _,_,override=hub.GetMatchMode()
    assert(override==nil)
end)
test('changing actual mode in a reused arena invalidates a manual FFA override',function()
    ffaFixture();hub.SetMatchMode('ffa');selected()
    matchOne.GameModeAttribute='2v2'
    assert(selected()==nil)
    local mode,_,override=hub.GetMatchMode()
    assert(mode=='teams' and override==nil)
end)
test('manual teams and auto immediately release inappropriate target and highlights',function()
    ffaFixture();hub.SetMatchMode('ffa');selected();api.updateHighlight(targetPlayer)
    hub.Target=targetHead
    press(byText('EQUIPES'))
    assert(hub.Target==nil and hub.Highlights[targetPlayer]==nil and selected()==nil)
    hub.SetMatchMode('ffa')
    hub.SetMatchMode('auto')
    assert(selected()==nil)
end)
test('FFA does not bypass visibility, FOV, range or explicit ally filters',function()
    ffaFixture();hub.SetMatchMode('ffa')
    assert(selected()==targetHead)
    workspace.Blocked=true
    assert(selected()==nil)
    workspace.Blocked=false
    targetHead.Position=vec(900,400,10)
    assert(selected()==nil)
    targetHead.Position=vec(550,400,10)
    settings.MaxDistance=10
    assert(selected()==nil)
    settings.MaxDistance=10000
    hub.Relations[targetPlayer.UserId]='ally'
    assert(selected()==nil and not api.updateHighlight(targetPlayer))
end)
test('FFA selection is not carried into another client execution by saved preferences',function()
    ffaFixture();hub.SetMatchMode('ffa')
    hub.SaveConfig();restart(true)
    api.refreshTeamCache()
    local mode,_,override=hub.GetMatchMode()
    assert(mode=='unknown' and override==nil)
    hub.Stop()
    game.GameId=42
end)
print(string.format('%d behavioral checks passed',passed))
