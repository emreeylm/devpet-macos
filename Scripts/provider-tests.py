#!/usr/bin/env python3
"""Exercise the actual process adapter using fake local app-server executables."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
app = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='devpet-providers-') as folder:
    folder = Path(folder)
    def run(name, script, expected, windows=None):
        path = folder/name
        path.write_text('#!/usr/bin/env python3\n'+script)
        path.chmod(0o700)
        proc = subprocess.run([str(app), '--check-codex', str(path)], capture_output=True, text=True, timeout=25)
        assert proc.stdout.strip(), (name, proc.returncode, proc.stderr)
        result = json.loads(proc.stdout.strip())
        assert result['connection'] == expected, (name, result, proc.stderr)
        if windows is not None: assert result['windows'] == windows, result
        assert 'private raw error' not in proc.stdout
        print(f'PASS {name}: {result["connection"]}')
    run('success', '''import json,sys
for line in sys.stdin:
    request=json.loads(line)
    if request.get('id') == 1:
        print(json.dumps({'id':1,'result':{'userAgent':'fixture'}}),flush=True)
    elif request.get('id') == 2:
        print(json.dumps({'method':'unrelated/notification','params':{}}),flush=True)
        print(json.dumps({'id':2,'result':{'rateLimits':{'primary':{'usedPercent':53,'windowDurationMins':300,'resetsAt':2000000000},'secondary':{'usedPercent':79,'windowDurationMins':10080,'resetsAt':2000100000}}}}),flush=True)
''', 'connected', [{'kind':'fiveHour','remaining':47},{'kind':'weekly','remaining':21}])
    run('auth-failure', '''import json,sys
for line in sys.stdin:
    r=json.loads(line)
    if r.get('id') == 1: print('{"id":1,"result":{}}',flush=True)
    elif r.get('id') == 2: print('{"id":2,"error":{"code":-32000,"message":"private raw error"}}',flush=True)
''', 'failed', [])
    run('broken-protocol', '''import sys
sys.stdin.readline()
print('{"id":1,"error":{"code":-1}}',flush=True)
''', 'failed', [])
    run('malformed', '''import json,sys
for line in sys.stdin:
    r=json.loads(line)
    if r.get('id') == 1: print('{"id":1,"result":{}}',flush=True)
    elif r.get('id') == 2: print('{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":110,"windowDurationMins":300}}}}',flush=True)
''', 'failed', [])
    run('no-output', '''import sys
sys.stdin.readline()
''', 'failed', [])
    run('timeout', '''import time
time.sleep(40)
''', 'failed', [])
    proc = subprocess.run([str(app), '--check-codex', str(folder/'missing')], capture_output=True, text=True, timeout=25)
    assert json.loads(proc.stdout)['connection'] == 'failed'
    print('PASS missing-executable: failed')
