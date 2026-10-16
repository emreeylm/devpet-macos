#!/usr/bin/env python3
"""Verify sanitization and private atomic persistence without touching real Claude settings/data."""
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
app = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='devpet-bridge-') as folder:
    output = Path(folder)/'private'/'claude.json'
    payload = {'rate_limits': {'five_hour': {'used_percentage':35.5,'resets_at':2000000000,'secret':'must-not-save'},'seven_day': {'used_percentage':80,'resets_at':2000100000}},'transcript_path':'private-path','session_id':'private-session','credentials':{'token':'must-not-save'},'prompt':'private-prompt'}
    p=subprocess.run([str(app),'--claude-statusline','--bridge-output',str(output)],input=json.dumps(payload),capture_output=True,text=True,check=True)
    saved=json.loads(output.read_text())
    assert set(saved) == {'observed_at','rate_limits'}
    assert saved['rate_limits']['five_hour'] == {'used_percentage':35.5,'resets_at':2000000000}
    assert 'must-not-save' not in output.read_text()
    assert stat.S_IMODE(output.stat().st_mode) == 0o600
    assert stat.S_IMODE(output.parent.stat().st_mode) == 0o700
    assert '65% left' in p.stdout
    print('PASS whitelist, observation timestamp, private file and directory permissions')
    subprocess.run([str(app),'--claude-statusline','--bridge-output',str(output)],input='{"rate_limits":{}}',capture_output=True,text=True,check=True)
    assert json.loads(output.read_text())['rate_limits'] == {}
    print('PASS missing windows erase old quotas rather than fabricate availability')
    p=subprocess.run([str(app),'--claude-statusline','--bridge-output',str(output)],input='broken',capture_output=True,text=True)
    assert p.returncode == 1
    print('PASS malformed input is rejected')
