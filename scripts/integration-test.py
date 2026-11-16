#!/usr/bin/env python3
"""Exercise real, disposable Chrome instances. Never targets existing browsers."""
import json
import pathlib
import subprocess
import tempfile
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIAGNOSTICS = ROOT / '.build/debug/browser-scope-diagnostics'
CHROME = pathlib.Path('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
assert CHROME.exists(), 'Install Chrome to run this optional integration test.'
http = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def scan():
    return json.loads(subprocess.check_output([str(DIAGNOSTICS), 'scan'], timeout=20))

def request(port, path, method='GET'):
    with http.open(urllib.request.Request(f'http://127.0.0.1:{port}{path}', method=method), timeout=3) as response:
        return response.read()

with tempfile.TemporaryDirectory(prefix='browser-scope-test-', dir='/tmp') as first, tempfile.TemporaryDirectory(prefix='browser-scope-test-', dir='/tmp') as second:
    children = []
    try:
        for profile in [first, second]:
            child = subprocess.Popen([str(CHROME), '--headless=new', '--no-first-run', '--no-default-browser-check', '--remote-debugging-port=0', '--user-data-dir='+profile, 'about:blank'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            children.append(child)
        ports = []
        for profile, child in zip([first, second], children):
            endpoint = pathlib.Path(profile) / 'DevToolsActivePort'
            deadline = time.monotonic()+20
            while not endpoint.exists() and time.monotonic() < deadline:
                assert child.poll() is None, 'Disposable Chrome exited unexpectedly.'
                time.sleep(.1)
            ports.append(int(endpoint.read_text().splitlines()[0]))
        request(ports[0], '/json/new?about:blank', 'PUT')
        entries = {e['pid']: e for e in scan()}
        fixture = entries[children[0].pid]
        sibling = entries[children[1].pid]
        assert fixture['mode'] == 'Headless'
        assert fixture['profile'] == 'Temporary'
        assert fixture.get('bulkExclusion') is None
        assert len(fixture['members']) > 1, fixture
        assert fixture['memory']['bytes'] > 0
        assert fixture['pages']['count'] == 2, fixture['pages']
        assert sibling['pages']['count'] == 1
        stale = subprocess.run([str(DIAGNOSTICS), 'close-test', str(fixture['pid']), str(fixture['startMicroseconds']+1)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        assert stale.returncode != 0
        assert children[0].poll() is None
        result = json.loads(subprocess.check_output([str(DIAGNOSTICS), 'close-test', str(fixture['pid']), str(fixture['startMicroseconds'])], timeout=15))
        assert result['status'] == 'Closed', result
        children[0].wait(timeout=5)
        assert children[1].poll() is None, 'Sibling must remain running.'
        assert len(json.loads(request(ports[1], '/json/list'))) >= 1
        result2 = json.loads(subprocess.check_output([str(DIAGNOSTICS), 'close-test', str(sibling['pid']), str(sibling['startMicroseconds'])], timeout=15))
        assert result2['status'] == 'Closed', result2
        children[1].wait(timeout=5)
        print(json.dumps({'result':'PASS','checks':['real process aggregation','RSS available','two pages counted','independent sibling page count','stale identity refused','normal close verified','sibling unaffected','fixture cleanup verified'], 'aggregatedProcesses':len(fixture['members'])}, indent=2))
    finally:
        # Popen owns only the two test children. Never use a name-based process kill.
        for child in children:
            if child.poll() is None:
                child.terminate()
                try: child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
