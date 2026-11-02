"""Run the standalone Hub against a small Roblox API test double.

Usage: python3 tests/run.py /path/to/luau
This checks logic and event wiring, not Roblox rendering or input routing.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'HUB.lua').read_text()
mock = (root / 'tests/roblox_mock.luau').read_text()
spec = (root / 'tests/hub_spec.luau').read_text() + (root / 'tests/regression_spec.luau').read_text() + (root / 'tests/graphics_spec.luau').read_text() + (root / 'tests/duels_spec.luau').read_text() + (root / 'tests/sniper_structure_spec.luau').read_text() + (root / 'tests/ffa_spec.luau').read_text()
# Expose private functions only in the generated test wrapper.
script = mock + '\nlocal function startHub()\n' + source + '''
return {settings=settings, findTarget=findTarget, refreshTeamCache=refreshTeamCache, watchPlayer=watchPlayer, targetInfo=targetInfo, livingCharacter=livingCharacter, updateHighlight=updateHighlight}
end
''' + spec
with tempfile.TemporaryDirectory(prefix='zyon-tests-') as temp:
    runner = Path(temp) / 'suite.luau'
    runner.write_text(script)
    result = subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(runner)])
    sys.exit(result.returncode)
