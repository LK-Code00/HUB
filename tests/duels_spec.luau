restart(false)
local function prepareClassification()
    prepareAim()
    for _,p in ipairs({lp,targetPlayer}) do
        for key in pairs(p:GetAttributes()) do p[key..'Attribute']=nil end
        p.Team='Lobby'; p.TeamColor='Blue'; p.Neutral=false
    end
    for key in pairs(workspace:GetAttributes()) do workspace[key..'Attribute']=nil end
    hub.Relations[targetPlayer.UserId]=nil
    hub.Friends[targetPlayer.UserId]='other'
    settings.IgnoreTeam=true;settings.ForceFFA=false;settings.TeamMarker='';settings.MatchMarker=''
    hub.Target=nil
end
local function selected()
    api.refreshTeamCache()
    hub.Target=nil
    return api.findTarget()
end
test('round teams override a shared lobby team, including numeric team zero',function()
    prepareClassification()
    lp.MatchTeamAttribute=0; targetPlayer.MatchTeamAttribute=1
    lp.MatchIdAttribute='ranked-a';targetPlayer.MatchIdAttribute='ranked-a'
    assert(selected()==targetHead)
    targetPlayer.MatchTeamAttribute=0
    assert(selected()==nil)
end)
test('shared match IDs survive incomplete secondary aliases, but conflicts reject',function()
    prepareClassification()
    lp.MatchTeamAttribute='red'; targetPlayer.MatchTeamAttribute='blue'
    lp.MatchIdAttribute=0;targetPlayer.MatchIdAttribute=0
    lp.DuelIdAttribute=7
    assert(selected()==targetHead)
    targetPlayer.DuelIdAttribute=8
    assert(selected()==nil)
    lp.MatchIdAttribute=nil;targetPlayer.MatchIdAttribute=nil;targetPlayer.DuelIdAttribute=nil
    assert(selected()==nil)
end)
test('ranked queue label does not mask a recognized FFA mode',function()
    prepareClassification()
    lp.GameModeAttribute='Ranked';lp.RoundModeAttribute='Free_For_All'
    assert(selected()==targetHead)
    lp.RoundModeAttribute='2v2';workspace.GameModeAttribute='FFA'
    assert(selected()==nil) -- local team mode takes priority over global FFA label
end)
test('nested round ValueBases and case variants are read without world scans',function()
    prepareClassification()
    local a=Instance.new('Folder');a.Name='RankedData';a.Parent=lp.Character
    local b=Instance.new('Folder');b.Name='RankedData';b.Parent=targetPlayer.Character
    local va=Instance.new('IntValue');va.Name='TEAM_ID';va.Value=0;va.Parent=a
    local vb=Instance.new('IntValue');vb.Name='teamId';vb.Value=1;vb.Parent=b
    assert(selected()==targetHead)
    va.Value=1
    assert(selected()==nil)
end)
test('unknown teams remain unknown; explicit manual fallback remains usable',function()
    prepareClassification()
    lp.Team=nil;targetPlayer.Team=nil;lp.Neutral=true;targetPlayer.Neutral=true
    assert(selected()==nil)
    assert(hub.Decisions[targetPlayer.UserId].reason=='equipe desconhecida')
    hub.Relations[targetPlayer.UserId]='enemy'
    assert(selected()==targetHead)
    targetPlayer.IsSpectatingAttribute=true
    assert(selected()==nil)
end)
test('custom observed keys persist and diagnostic explains classification',function()
    prepareClassification()
    lp.SideCodeAttribute=0;targetPlayer.SideCodeAttribute=1
    lp.SessionCodeAttribute=55;targetPlayer.SessionCodeAttribute=55
    local teamField=named('TeamMarkerInput');teamField.Text='SideCode';teamField.FocusLost:Fire()
    local matchField=named('MatchMarkerInput');matchField.Text='SessionCode';matchField.FocusLost:Fire()
    assert(selected()==targetHead)
    press(byText('GERAR DIAGNOSTICO'))
    local report=named('MatchDiagnostics').Text
    assert(report:find('SideCode') and report:find('INCLUIDO') and report:find('Health=100'))
    teamField.Text='bad.path!';teamField.FocusLost:Fire()
    assert(settings.TeamMarker=='SideCode')
    hub.SaveConfig();restart(true)
    assert(settings.TeamMarker=='SideCode' and settings.MatchMarker=='SessionCode')
    settings.TeamMarker='';settings.MatchMarker=''
end)
test('mode switches and respawns rebuild decisions without retaining stale teams',function()
    prepareClassification()
    lp.MatchTeamAttribute=0;targetPlayer.MatchTeamAttribute=1
    assert(selected()==targetHead)
    targetPlayer.MatchTeamAttribute=0
    assert(selected()==nil)
    targetPlayer.MatchTeamAttribute=nil
    local char,head=makeCharacter(targetPlayer,vec(550,400,10))
    char.MatchTeamAttribute=1
    targetPlayer.CharacterAdded:Fire(char)
    assert(selected()==head)
    hub.Stop()
end)
restart(false)
test('revive on the same character requires a live health or state transition',function()
    prepareClassification()
    hub.Relations[targetPlayer.UserId]='enemy'
    selected()
    targetHumanoid.Died:Fire()
    assert(api.livingCharacter(targetPlayer)==nil)
    targetHumanoid.State=Enum.HumanoidStateType.Dead
    targetHumanoid.HealthChanged:Fire(100)
    assert(api.livingCharacter(targetPlayer)==nil)
    targetHumanoid.State=Enum.HumanoidStateType.Running
    targetHumanoid.StateChanged:Fire(Enum.HumanoidStateType.Dead,Enum.HumanoidStateType.Running)
    assert(selected()==targetHead)
    targetHumanoid.Health=0
    targetHumanoid.HealthChanged:Fire(0)
    assert(selected()==nil)
    targetHumanoid.Health=50
    targetHumanoid.HealthChanged:Fire(50)
    assert(selected()==targetHead)
end)
test('R6 torso fallback works while head and root are absent',function()
    prepareClassification()
    hub.Relations[targetPlayer.UserId]='enemy'
    targetHead.Name='Torso'
    assert(selected()==targetHead)
    hub.Stop()
end)
print(string.format('%d behavioral checks passed',passed))
