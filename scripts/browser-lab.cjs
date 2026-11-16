#!/usr/bin/env node
// Disposable local browser fixtures. No name-based kills, user profiles or external pages.
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const http = require('node:http');
const crypto = require('node:crypto');
const {spawn, fork} = require('node:child_process');
const ROOT = path.resolve(__dirname,'..');
const STATE_DIR = path.join(ROOT,'.browser-lab');
const STATE_FILE = path.join(STATE_DIR,'session.json');
const CHROME = process.env.BROWSER_LAB_CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const delay = ms => new Promise(resolve => setTimeout(resolve,ms));
function readState() { try {return JSON.parse(fs.readFileSync(STATE_FILE,'utf8'));} catch{return null;} }
async function control(state, method='GET') {
  if (!state) return null;
  try {
    const response = await fetch(`http://127.0.0.1:${state.port}/control`, {method, headers:{'x-lab-token':state.token}, signal:AbortSignal.timeout(3000)});
    if (!response.ok) return null;
    const result = await response.json();
    return result.runId === state.runId ? result : null;
  } catch {return null;}
}
function show(state) {
  console.table(state.scenarios.map(s => ({scenario:s.id,mode:s.headless?'Headless':'Headed',pages:s.pages,
    expectedDisplay:s.cdp?String(s.pages):'—',pid:s.pid??'—',status:s.status,bulk:s.bulk?'Eligible':'Excluded'})));
  for (const scenario of state.scenarios) if (scenario.error) console.error(`${scenario.id}: ${scenario.error}`);
  console.log(`Run: ${state.runId}\nStop: node scripts/browser-lab.cjs stop`);
}
async function serve() {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(),'browser-scope-test-lab-'));
  const session = {runId:crypto.randomUUID(),token:crypto.randomBytes(24).toString('hex'),tempRoot,port:0,scenarios:[
    {id:'playwright-pipe',headless:true,pages:2,cdp:false,bulk:true,profile:path.join(tempRoot,'playwright_pipe')},
    {id:'playwright-cdp',headless:true,pages:3,cdp:true,bulk:true,profile:path.join(tempRoot,'playwright_cdp')},
    {id:'playwright-headed',headless:false,pages:2,cdp:true,bulk:false,profile:path.join(tempRoot,'playwright_headed')},
    {id:'puppeteer-cdp',headless:true,pages:4,cdp:true,bulk:true,profile:path.join(tempRoot,'puppeteer-browser-lab')},
    {id:'custom-headless',headless:true,pages:1,cdp:true,bulk:false,profile:path.join(tempRoot,'custom-profile')},
    {id:'personal-headed',headless:false,pages:2,cdp:false,bulk:false,profile:path.join(tempRoot,'Library/Application Support/Google/Chrome')},
  ]};
  const children = [];
  for(const s of session.scenarios) {s.status='starting';fs.mkdirSync(s.profile,{recursive:true});}
  function persist() {fs.writeFileSync(STATE_FILE,JSON.stringify(session,null,2),{mode:0o600});}
  function update(message) {
    const s=session.scenarios.find(s=>s.id===message.id);
    if(s) {Object.assign(s,message);persist();}
  }
  let stopping=false;
  async function stop() {
    if(stopping) return;stopping=true;
    for(const child of children) {
      if(child.exitCode !== null || child.signalCode !== null) continue;
      if(child.connected) child.send({type:'stop'});
      else child.kill('SIGTERM');
    }
    for(let i=0;i<100 && children.some(c=>c.exitCode===null && c.signalCode===null);i++) await delay(100);
    const remaining=children.filter(c=>c.exitCode===null && c.signalCode===null);
    if(remaining.length) {console.error('Some owned launchers remain. Keeping session control available; no forced kill sent.');stopping=false;return;}
    // Keep disposable profiles for inspection; stop never deletes browser data.
    if(readState()?.runId===session.runId) fs.unlinkSync(STATE_FILE);
    server.close();process.exit(0);
  }
  const server=http.createServer((req,res)=>{
    if(req.url==='/control') {
      if(req.headers['x-lab-token']!==session.token) {res.writeHead(403);return res.end();}
      res.setHeader('Content-Type','application/json');res.end(JSON.stringify(session));
      if(req.method==='POST') void stop();
      return;
    }
    const match=req.url.match(/^\/page\/([a-z-]+)\/(\d+)$/);
    const s=match&&session.scenarios.find(s=>s.id===match[1]);
    if(!s){res.writeHead(404);return res.end('Not found');}
    res.setHeader('Content-Type','text/html; charset=utf-8');
    res.end(`<!doctype html><html lang="en"><meta charset="utf-8"><title>BroClean · ${s.id} · ${match[2]}</title><style>body{font:18px system-ui;background:#eff3f8;color:#24324a;margin:8vw;max-width:760px}small{color:#58708d}h1{font-size:42px}section{padding:32px;background:white;border-radius:20px}strong{color:#5c4bc4}</style><small>BROCLEAN · DISPOSABLE LOCAL TEST</small><h1>${s.id}</h1><section><h2>Page ${match[2]} of ${s.pages}</h2><p>Mode: <strong>${s.headless?'Headless':'Headed'}</strong></p><p>Expected pages in BroClean: ${s.cdp?s.pages:'— (no accessible TCP endpoint)'}</p><p>Bulk cleanup: ${s.bulk?'Eligible temporary profile':'Excluded; review individually'}</p><p>You can safely close this test browser. It uses a separate profile and only local pages.</p></section></html>`);
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  session.port=server.address().port;persist();
  const base=`http://127.0.0.1:${session.port}`;
  for(const family of ['playwright','puppeteer']) {
    const scenarios=session.scenarios.filter(s=>s.id.startsWith(family));
    const child=fork(path.join(__dirname,'browser-lab',`${family}-worker.cjs`),[],{stdio:['ignore','inherit','inherit','ipc']});
    children.push(child);child.on('message',update);
    child.on('exit',()=>{for(const s of scenarios) if(s.status==='starting'||s.status==='running')update({id:s.id,status:'launcher exited'});});
    child.send({type:'start',scenarios,base,chrome:CHROME});
  }
  for(const s of session.scenarios.filter(s=>!s.id.startsWith('playwright')&&!s.id.startsWith('puppeteer'))) {
    const args=[`--user-data-dir=${s.profile}`,'--no-first-run','--no-default-browser-check'];
    if(s.headless)args.push('--headless=new');
    if(s.cdp)args.push('--remote-debugging-port=0','--remote-debugging-address=127.0.0.1');
    for(let i=1;i<=s.pages;i++)args.push(`${base}/page/${s.id}/${i}`);
    const child=spawn(CHROME,args,{stdio:'ignore'});children.push(child);
    child.on('spawn',()=>update({id:s.id,pid:child.pid,status:'running'}));
    child.on('error',error=>update({id:s.id,status:'failed',error:error.message}));
    child.on('exit',()=>update({id:s.id,status:'closed'}));
  }
  process.on('SIGTERM',stop);process.on('SIGINT',stop);
}
async function main() {
  fs.mkdirSync(STATE_DIR,{recursive:true,mode:0o700});
  const command=process.argv[2]||'start';
  if(command==='serve')return serve();
  const existing=await control(readState());
  if(command==='status') {if(existing)show(existing);else console.log('No active browser lab.');return;}
  if(command==='stop') {
    if(!existing){console.log('No active browser lab. No processes signalled.');return;}
    await control(existing,'POST');
    for(let i=0;i<120;i++){if(!await control(existing)){console.log('Stopped the owned browser lab. Existing browsers were not selected.');return;}await delay(100);}
    throw Error('Stop is still pending. Check .browser-lab/session.log; no forced kill was sent.');
  }
  if(command!=='start')throw Error('Usage: node scripts/browser-lab.cjs start|status|stop');
  if(existing){console.log('Reusing active lab (no duplicate launch).');show(existing);return;}
  if(!fs.existsSync(CHROME))throw Error('Chrome not found. Set BROWSER_LAB_CHROME to its executable path.');
  for(const name of ['playwright-core','puppeteer-core'])require.resolve(name,{paths:[path.join(__dirname,'browser-lab')]});
  const log=fs.openSync(path.join(STATE_DIR,'session.log'),'a',0o600);
  const child=spawn(process.execPath,[__filename,'serve'],{detached:true,stdio:['ignore',log,log]});child.unref();fs.closeSync(log);
  for(let i=0;i<150;i++) {
    const current=await control(readState());
    if(current && current.scenarios.every(s=>s.status!=='starting')) {
      show(current);
      if(current.scenarios.some(s=>s.status!=='running')) process.exitCode=1;
      return;
    }
    await delay(500);
  }
  throw Error('Startup timed out. Run status; details in .browser-lab/session.log.');
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
