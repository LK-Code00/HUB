restart(false)
local function folder(parent,name)
    local f=Instance.new('Folder');f.Name=name;f.Parent=parent;return f
end
local root=folder(workspace,'Characters')
local matchOne=folder(root,'{11111111-2222-3333-4444-555555555555}')
local aSide=folder(matchOne,'A')
local bSide=folder(matchOne,'B')
local otherMatch=folder(root,'{aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee}')
local otherSide=folder(otherMatch,'A')
local function prepareStructure(side)
    prepareClassification()
    game.GameId=7264587281
    lp.Team=nil;targetPlayer.Team=nil;lp.Neutral=true;targetPlayer.Neutral=true
    lp.Character.Parent=bSide
    targetPlayer.Character.Parent=side
    settings.ForceFFA=true
end
test('reported same-B teammate is excluded from both aim and ESP with forced FFA',function()
    prepareStructure(bSide)
    assert(selected()==nil)
    assert(not api.updateHighlight(targetPlayer))
    assert(hub.Decisions[targetPlayer.UserId].reason=='Sniper Duels: mesma equipe B')
    assert(hub.GetDiagnostics():find('equipe=B') and hub.GetDiagnostics():find('FFA manual: true'))
end)
test('opposite side in the same match is eligible even with neutral Roblox teams',function()
    prepareStructure(aSide)
    assert(selected()==targetHead)
    assert(api.updateHighlight(targetPlayer))
    assert(hub.Highlights[targetPlayer].Adornee==targetPlayer.Character)
end)
test('different match and incomplete structure cannot be forced into enemies',function()
    prepareStructure(otherSide)
    hub.Relations[targetPlayer.UserId]='enemy'
    assert(selected()==nil)
    targetPlayer.Character.Parent=workspace
    assert(selected()==nil)
end)
test('stale manual enemy and disabled team filter cannot include a structural teammate',function()
    prepareStructure(bSide)
    hub.Relations[targetPlayer.UserId]='enemy'
    settings.IgnoreTeam=false
    assert(selected()==nil)
    assert(not api.updateHighlight(targetPlayer))
end)
test('friend override is retained for actual opponents, and manual allies remain excluded',function()
    prepareStructure(aSide)
    hub.Friends[targetPlayer.UserId]='friend'
    assert(selected()==nil)
    hub.Relations[targetPlayer.UserId]='enemy'
    assert(selected()==targetHead)
    hub.Relations[targetPlayer.UserId]='ally'
    assert(selected()==nil)
end)
test('side swap rejects stale cached target without waiting for metadata refresh',function()
    prepareStructure(aSide)
    assert(selected()==targetHead)
    hub.Target=targetHead
    targetPlayer.Character.Parent=bSide
    assert(api.targetInfo(camera,targetHead)==nil)
    assert(api.findTarget()==nil)
    assert(not api.updateHighlight(targetPlayer))
    assert(hub.Highlights[targetPlayer]==nil)
end)
test('structure loss and local team switch also invalidate cached candidates',function()
    prepareStructure(aSide)
    selected()
    lp.Character.Parent=aSide
    assert(api.targetInfo(camera,targetHead)==nil)
    prepareStructure(aSide)
    selected()
    lp.Character.Parent=workspace;targetPlayer.Character.Parent=workspace
    assert(api.targetInfo(camera,targetHead)==nil)
end)
test('diagnostics show unassociated opponent models without automatically targeting them',function()
    prepareStructure(bSide)
    local model=Instance.new('Model');model.Name='UnassociatedOpponent';model.Parent=aSide
    local human=Instance.new('Humanoid');human.Health=100;human.Parent=model
    local report=hub.GetDiagnostics()
    assert(report:find('A/UnassociatedOpponent') and report:find('sem Character associado'))
    assert(selected()==nil)
end)
test('adapter is scoped to this universe and does not infer teams from queue preferences',function()
    prepareStructure(bSide)
    game.GameId=42
    lp.LastModesSelectedAttribute='1v1,2v2'
    targetPlayer.LastModesSelectedAttribute='1v1,2v2'
    assert(selected()==targetHead) -- generic explicit FFA behavior remains unchanged
    game.GameId=7264587281
    assert(selected()==nil)
    hub.Stop()
    game.GameId=42
end)
print(string.format('%d behavioral checks passed',passed))
