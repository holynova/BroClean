#!/usr/bin/env python3
"""End-to-end CLI tests. Real close commands target only this script's Popen children."""
import json
import pathlib
import signal
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
CLI = ROOT / '.build/debug/broclean'
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

def run(*args, expected=0):
    result = subprocess.run([str(CLI), *map(str,args)], stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=20)
    assert result.returncode == expected, (args,result.returncode,result.stdout,result.stderr)
    return json.loads(result.stdout) if result.stdout.strip() else None

with tempfile.TemporaryDirectory(prefix='browser-scope-test-cli-', dir='/tmp') as first, tempfile.TemporaryDirectory(prefix='browser-scope-test-cli-', dir='/tmp') as second:
    children = []
    try:
        for profile in [first,second]:
            child=subprocess.Popen([CHROME,'--headless=new','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            children.append(child)
            deadline=time.monotonic()+20
            while not (pathlib.Path(profile)/'DevToolsActivePort').exists() and time.monotonic()<deadline:
                assert child.poll() is None
                time.sleep(.1)
        listing=run('list','--sort','memory','--desc','--json')
        assert listing['schemaVersion']==1
        rows={r['pid']:r for r in listing['instances']}
        a,b=[rows[c.pid] for c in children]
        assert a['pages']['count']==1 and b['pages']['count']==1
        assert len(a['memberPIDs'])>1
        inspected=run('inspect',a['pid'],'--json')
        assert inspected['instances'][0]['startMicroseconds']==a['startMicroseconds']
        preview=run('close',a['pid'],'--force','--dry-run','--yes','--json')
        assert preview['dryRun'] and not preview['results']
        assert children[0].poll() is None
        run('close',a['pid'],'--json',expected=2)
        run('close',a['pid'],'--start-time',a['startMicroseconds']+1,'--yes','--json',expected=3)
        assert children[0].poll() is None
        run('protect',a['pid'],'--start-time',a['startMicroseconds'],'--json')
        assert run('inspect',a['pid'],'--no-pages','--json')['instances'][0]['protectedFromBulk']
        exclude=','.join(str(pid) for pid in rows if pid != a['pid'])
        plan=run('close','--automated','--exclude',exclude,'--dry-run','--json')
        assert a['pid'] not in [r['pid'] for r in plan['instances']]
        assert any(s['pid']==a['pid'] and 'Protected' in s['reason'] for s in plan['skipped'])
        run('unprotect',a['pid'],'--json')
        result=run('close',a['pid'],'--start-time',a['startMicroseconds'],'--yes','--json')
        assert result['results'][0]['status']=='Closed'
        children[0].wait(timeout=5)
        assert children[1].poll() is None
        children[1].send_signal(signal.SIGSTOP)
        pending=run('close',b['pid'],'--start-time',b['startMicroseconds'],'--yes','--json',expected=4)
        assert pending['results'][0]['status']=='Still running'
        assert children[1].poll() is None
        forced=run('close',b['pid'],'--start-time',b['startMicroseconds'],'--force','--yes','--json')
        assert forced['results'][0]['status']=='Closed'
        children[1].wait(timeout=5)
        print('PASS: list/inspect JSON, real page count, dry-run, confirmation gate, stale identity, shared protection, exclusion, normal close, sibling isolation, no automatic escalation, explicit force.')
    finally:
        for child in children:
            if child.poll() is None:
                subprocess.run([str(CLI),'unprotect',str(child.pid),'--json'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                child.send_signal(signal.SIGCONT)
                child.terminate()
                try: child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill();child.wait(timeout=5)
