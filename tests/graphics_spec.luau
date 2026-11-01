restart(false)
test('explicit enemy overrides every friendship state; auto restores filtering',function()
    prepareAim()
    for _,friendship in ipairs({'friend','pending','unknown','other'}) do
        hub.Friends[targetPlayer.UserId]=friendship
        hub.Relations[targetPlayer.UserId]='enemy'
        api.refreshTeamCache()
        hub.Target=nil
        assert(api.findTarget()==targetHead,friendship)
    end
    hub.Friends[targetPlayer.UserId]='friend'
    hub.Relations[targetPlayer.UserId]=nil
    api.refreshTeamCache()
    hub.Target=nil
    assert(api.findTarget()==nil)
    hub.Relations[targetPlayer.UserId]='ally'
    settings.IgnoreFriends=false
    api.refreshTeamCache()
    assert(api.findTarget()==nil)
    settings.IgnoreFriends=true
end)
local originalBloom=Instance.new('BloomEffect'); originalBloom.Enabled=true; originalBloom.Parent=lighting
local disabledBlur=Instance.new('BlurEffect'); disabledBlur.Enabled=false; disabledBlur.Parent=camera
local emitter=Instance.new('ParticleEmitter'); emitter.Enabled=true; emitter.Parent=workspace
test('light mode disables shadows and existing post effects reversibly',function()
    press(byText('GRAFICOS'))
    assert(named('graphicsPage').Visible)
    press(control('Modo leve'))
    assert(not lighting.GlobalShadows and not originalBloom.Enabled and not disabledBlur.Enabled)
    assert(emitter.Enabled) -- independent particle control
    press(control('Modo leve'))
    assert(lighting.GlobalShadows and originalBloom.Enabled and not disabledBlur.Enabled)
end)
test('particle reduction handles existing and newly spawned effects',function()
    press(control('Reduzir particulas'))
    assert(not emitter.Enabled)
    local trail=Instance.new('Trail'); trail.Enabled=true; trail.Parent=workspace
    workspace.DescendantAdded:Fire(trail)
    assert(not trail.Enabled)
    press(control('Reduzir particulas'))
    assert(emitter.Enabled and trail.Enabled)
end)
test('shader presets, intensity and light mode are coordinated',function()
    press(byText('QUENTE'))
    assert(settings.ShaderPreset==2 and not settings.LowGraphics)
    assert(lighting:FindFirstChild('ZyonColor') and lighting:FindFirstChild('ZyonBloom'))
    slide('INTENSIDADE DOS EFEITOS',0)
    near(lighting:FindFirstChild('ZyonBloom').Intensity,0)
    near(lighting:FindFirstChild('ZyonColor').Contrast,0)
    slide('INTENSIDADE DOS EFEITOS',0.8)
    press(control('Modo leve'))
    assert(settings.ShaderPreset==0 and not lighting:FindFirstChild('ZyonBloom'))
    assert(not originalBloom.Enabled)
    press(byText('FRIO'))
    assert(not settings.LowGraphics and originalBloom.Enabled)
    assert(settings.ShaderPreset==3)
end)
test('graphics preferences restore from disk and closing restores original visuals',function()
    press(control('Reduzir particulas'))
    settings.ActiveTab='graphics'
    hub.SaveConfig()
    hub.Stop()
    assert(emitter.Enabled and lighting.GlobalShadows and originalBloom.Enabled)
    assert(not lighting:FindFirstChild('ZyonColor'))
    restart(true)
    assert(settings.ShaderPreset==3 and settings.ReduceParticles)
    near(settings.ShaderStrength,0.8)
    assert(named('graphicsPage').Visible and not emitter.Enabled)
    assert(lighting:FindFirstChild('ZyonColor'))
    press(byText('RESTAURAR GRAFICOS DO JOGO'))
    assert(emitter.Enabled and originalBloom.Enabled and lighting.GlobalShadows)
    assert(not lighting:FindFirstChild('ZyonBloom'))
end)
test('restoration preserves newer property changes made by the game',function()
    press(control('Modo leve'))
    originalBloom.Enabled=true -- game changed the property after the override
    press(byText('RESTAURAR GRAFICOS DO JOGO'))
    assert(originalBloom.Enabled)
    hub.Stop()
end)
print(string.format('%d behavioral checks passed',passed))
