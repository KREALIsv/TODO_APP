const { chromium, devices } = require('playwright');

async function run(url, label) {
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--disable-dev-shm-usage',
      '--enable-unsafe-swiftshader',
      '--use-gl=angle',
      '--use-angle=swiftshader-webgl',
    ],
  });
  const context = await browser.newContext({ ...devices['iPhone 13'], locale: 'es-ES' });
  const page = await context.newPage();
  const logs = [];
  page.on('console', (m) => logs.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', (e) => logs.push(`[PAGEERROR] ${e.message}\n${e.stack || ''}`));
  page.on('requestfailed', (r) => logs.push(`[REQFAIL] ${r.url()} ${r.failure()?.errorText}`));

  console.log('===', label, url);
  await page.goto(url, { waitUntil: 'networkidle', timeout: 120000 }).catch((e) => {
    logs.push(`[GOTO] ${e.message}`);
  });
  await page.waitForTimeout(25000);
  const info = await page.evaluate(() => ({
    title: document.title,
    text: (document.body?.innerText || '').slice(0, 300),
    hasFlutterView: !!document.querySelector('flutter-view'),
    hasCanvas: !!document.querySelector('canvas'),
    hasGlass: !!document.querySelector('flt-glass-pane'),
  }));
  console.log(JSON.stringify(info, null, 2));
  console.log('---LOGS---');
  for (const line of logs.slice(-80)) console.log(line);
  await page.screenshot({ path: `/opt/cursor/artifacts/blank-debug-${label}.png` });
  await browser.close();
}

(async () => {
  await run('http://127.0.0.1:8080/', 'local');
  await run('https://app.wodo.app/', 'prod');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
