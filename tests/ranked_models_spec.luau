restart(false)
local rankedPlayers=table.clone(players.list)
local rankedModel,rankedPart,rankedHuman
local rankedTime=100
local function rankedFixture()
    if rankedModel then rankedModel:Destroy() end
    players.list=table.clone(rankedPlayers)
    prepareStructure(aSide)
    matchOne.GameModeAttribute=nil
    targetPlayer.Character.Parent=nil
    otherPlayer.Character.Parent=nil
    players.list={lp}
    rankedModel=Instance.new('Model');rankedModel.Name='ghostspy097';rankedModel.Parent=aSide
    rankedPart=Instance.new('Part');rankedPart.Name='HumanoidRootPart'
    rankedPart.Position=vec(550,400,10);rankedPart.Parent=rankedModel
    rankedHuman=Instance.new('Humanoid');rankedHuman.Health=100;rankedHuman.Parent=rankedModel
    rankedTime+=10
    api.refreshTeamCache()
    hub.Target=nil
end
test('reported ranked layout works with only the local Player replicated',function()
    rankedFixture()
    assert(#players:GetPlayers()==1 and hub.GetMatchMode()=='unknown')
    assert(api.findTarget()==rankedPart)
    step()
    assert(hub.Target==rankedPart and objects.aimWrites==1)
    api.updateBackground(rankedTime)
    assert(hub.Highlights[rankedModel].Adornee==rankedModel)
    local report=hub.GetDiagnostics()
    assert(report:find('Jogadores disponiveis: 1') and report:find('A/ghostspy097'))
    assert(report:find('ESTRUTURA INCLUIDA') and report:find('amizade indisponivel'))
end)
test('ranked model discovery does not require legacy ForceFFA',function()
    rankedFixture();settings.ForceFFA=false
    assert(selected()==rankedPart and api.updateHighlight(rankedModel))
end)
test('ranked models exclude same side and other arenas despite manual FFA flag',function()
    rankedFixture();rankedModel.Parent=bSide
    assert(selected()==nil and not api.updateHighlight(rankedModel))
    rankedModel.Parent=otherSide
    assert(selected()==nil and not api.updateHighlight(rankedModel))
end)
test('ranked model can share side only in confirmed FFA mode',function()
    rankedFixture();rankedModel.Parent=bSide
    assert(selected()==nil)
    hub.SetMatchMode('ffa')
    assert(selected()==rankedPart)
    hub.SetMatchMode('teams')
    assert(selected()==nil and not api.updateHighlight(rankedModel))
end)
test('ranked model death immediately releases aim and highlight with stale health',function()
    rankedFixture();api.findTarget();hub.Target=rankedPart
    api.updateHighlight(rankedModel)
    rankedHuman.Died:Fire()
    assert(hub.Target==nil and hub.Highlights[rankedModel]==nil)
    assert(api.findTarget()==nil and not api.updateHighlight(rankedModel))
    rankedHuman.HealthChanged:Fire(100)
    assert(api.findTarget()==rankedPart)
end)
test('ranked model movement to ally side or dead storage invalidates tracked target',function()
    rankedFixture();api.findTarget();hub.Target=rankedPart
    rankedModel.Parent=bSide
    assert(api.targetInfo(camera,rankedPart)==nil)
    local deadStorage=Instance.new('Folder');deadStorage.Name='_DEAD_CHARACTERS'
    rankedModel.Parent=deadStorage
    assert(api.targetInfo(camera,rankedPart)==nil)
    api.updateBackground(rankedTime)
    assert(hub.Target==nil and hub.Highlights[rankedModel]==nil)
    for _,connection in ipairs(rankedHuman.Died.connections) do assert(not connection.Connected) end
end)
test('ranked model still obeys wall, FOV, distance and life checks',function()
    rankedFixture();workspace.Blocked=true
    assert(selected()==nil)
    workspace.Blocked=false;rankedPart.Position=vec(900,400,10)
    assert(selected()==nil)
    rankedPart.Position=vec(550,400,10);settings.MaxDistance=10
    assert(selected()==nil)
    settings.MaxDistance=10000;rankedModel.AliveAttribute=false
    assert(selected()==nil and not api.updateHighlight(rankedModel))
end)
test('ranked model discovery is scoped to Sniper Duels and the local match',function()
    rankedFixture();game.GameId=42
    assert(selected()==nil and not api.updateHighlight(rankedModel))
    game.GameId=7264587281;lp.Character.Parent=otherSide
    assert(selected()==nil and not api.updateHighlight(rankedModel))
end)
test('late humanoid and part replication becomes usable without restarting',function()
    rankedFixture();rankedHuman.Parent=nil;rankedPart.Parent=nil
    assert(api.findTarget()==nil)
    rankedHuman.Parent=rankedModel;rankedPart.Parent=rankedModel
    assert(api.findTarget()==rankedPart)
end)
test('Player association replaces model path and restores friendship filtering',function()
    rankedFixture();api.findTarget();api.updateHighlight(rankedModel)
    players.list=table.clone(rankedPlayers)
    targetPlayer.Character=rankedModel
    targetPlayer.CharacterAdded:Fire(rankedModel)
    hub.Relations[targetPlayer.UserId]=nil;hub.Friends[targetPlayer.UserId]='friend'
    settings.IgnoreFriends=true
    assert(selected()==nil)
    api.updateBackground(rankedTime)
    assert(hub.Highlights[rankedModel]==nil and hub.Highlights[targetPlayer]==nil)
    hub.Relations[targetPlayer.UserId]='enemy'
    assert(selected()==rankedPart)
    assert(api.updateHighlight(targetPlayer))
end)
test('old known Player character is not recycled into a ranked model target',function()
    rankedFixture()
    players.list=table.clone(rankedPlayers)
    targetPlayer.Character=rankedModel;targetPlayer.CharacterAdded:Fire(rankedModel)
    targetPlayer.Character=nil
    players.list={lp}
    assert(selected()==nil and not api.updateHighlight(rankedModel))
    hub.Stop()
    for _,connection in ipairs(rankedHuman.Died.connections) do assert(not connection.Connected) end
end)
players.list=rankedPlayers
game.GameId=42
rankedModel:Destroy()
print(string.format('%d total behavioral checks passed',passed))
