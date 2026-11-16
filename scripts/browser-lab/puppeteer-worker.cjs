let browser;
async function stop() { if (browser) await browser.close().catch(() => {}); process.exit(0); }
process.on('message', async message => {
  if (message.type === 'stop') return stop();
  if (message.type !== 'start') return;
  const scenario = message.scenarios[0];
  try {
    const { default: puppeteer } = await import('puppeteer-core');
    browser = await puppeteer.launch({executablePath:message.chrome, headless:true, userDataDir:scenario.profile,
      args:['--remote-debugging-port=0','--remote-debugging-address=127.0.0.1'], timeout:30000});
    const pages = await browser.pages();
    for(let i=0;i<scenario.pages;i++) await (pages[i] || await browser.newPage()).goto(`${message.base}/page/${scenario.id}/${i+1}`);
    browser.on('disconnected', () => process.send?.({id:scenario.id,status:'closed'}));
    process.send({id:scenario.id,status:'running',pid:browser.process().pid});
  } catch(error) { process.send({id:scenario.id,status:'failed',error:error.message}); }
});
process.on('SIGTERM', stop);
process.on('disconnect', stop);
