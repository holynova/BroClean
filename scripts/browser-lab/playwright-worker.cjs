const { chromium } = require('playwright-core');
const { execFileSync } = require('node:child_process');
const contexts = [];
const known = new Set();
let stopping = false;
async function stop() {
  if (stopping) return; stopping = true;
  await Promise.allSettled(contexts.map(c => c.close()));
  process.exit(0);
}
process.on('message', async message => {
  if (message.type === 'stop') return stop();
  if (message.type !== 'start') return;
  for (const scenario of message.scenarios) {
    try {
      const context = await chromium.launchPersistentContext(scenario.profile, {
        executablePath: message.chrome, headless: scenario.headless, chromiumSandbox: true,
        args: scenario.cdp ? ['--remote-debugging-port=0', '--remote-debugging-address=127.0.0.1'] : [],
        viewport: { width: 900, height: 620 }, timeout: 30000,
      });
      contexts.push(context);
      const pages = context.pages();
      for (let i = 0; i < scenario.pages; i++) {
        const page = pages[i] || await context.newPage();
        await page.goto(`${message.base}/page/${scenario.id}/${i+1}`);
      }
      const pid = execFileSync('/bin/ps', ['-axo','pid=,ppid=,comm='], {encoding:'utf8'}).split('\n')
        .map(line => line.trim().match(/^(\d+)\s+(\d+)\s+(.+)$/))
        .filter(Boolean).find(row => Number(row[2]) === process.pid && row[3] === message.chrome && !known.has(Number(row[1])));
      if (!pid) throw new Error('Could not identify launched browser PID');
      known.add(Number(pid[1]));
      context.on('close', () => process.send?.({id:scenario.id, status:'closed'}));
      process.send({id:scenario.id, status:'running', pid:Number(pid[1])});
    } catch (error) { process.send({id:scenario.id, status:'failed', error:error.message}); }
  }
});
process.on('SIGTERM', stop);
process.on('disconnect', stop);
