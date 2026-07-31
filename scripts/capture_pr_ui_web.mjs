import fs from 'node:fs';
import path from 'node:path';
import puppeteer from 'puppeteer-core';
import { spawn } from 'node:child_process';

const OUT = '/opt/cursor/artifacts/screenshots/pr-ui-gallery';
const BASE = process.env.WODO_WEB_URL ?? 'http://127.0.0.1:8090';
const CHROME = '/usr/local/bin/google-chrome';
const PROFILE = '/tmp/wodo-gallery-puppeteer';
const DEBUG_PORT = 9222;

fs.mkdirSync(OUT, { recursive: true });
fs.rmSync(PROFILE, { recursive: true, force: true });

const chrome = spawn(
  CHROME,
  [
    `--remote-debugging-port=${DEBUG_PORT}`,
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--disable-gpu',
    '--disable-service-workers',
    `--user-data-dir=${PROFILE}`,
    '--window-size=1280,900',
    '--window-position=0,0',
    `${BASE}/?gallery=${Date.now()}`,
  ],
  { env: { ...process.env, DISPLAY: process.env.DISPLAY ?? ':1' }, stdio: 'ignore' },
);

async function waitDebug() {
  for (let i = 0; i < 40; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${DEBUG_PORT}/json/version`);
      if (res.ok) return;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('Chrome debug port not ready');
}

await waitDebug();
const browser = await puppeteer.connect({
  browserURL: `http://127.0.0.1:${DEBUG_PORT}`,
  defaultViewport: null,
});
const page = (await browser.pages())[0] ?? (await browser.newPage());

const desktop = { width: 1280, height: 900 };
const mobile = { width: 390, height: 844, isMobile: true, hasTouch: true };

async function waitApp() {
  await new Promise((r) => setTimeout(r, 4500));
}

async function shot(name) {
  await page.screenshot({ path: path.join(OUT, name) });
  console.log('saved', name);
}

async function tap(x, y, wait = 1200) {
  await page.mouse.click(x, y);
  await new Promise((r) => setTimeout(r, wait));
}

await page.setViewport(desktop);
await waitApp();
await shot('01_home_desktop.png');
await tap(140, 200);
await shot('02_login_desktop.png');
await tap(640, 635, 5000);
await shot('03_qr_pairing_desktop.png');
await tap(35, 55);
await tap(640, 705);
await shot('04_register_desktop.png');
await tap(35, 55);
await tap(140, 520);
await shot('05_settings_desktop.png');
await page.mouse.wheel({ deltaY: 700 });
await new Promise((r) => setTimeout(r, 500));
await shot('06_settings_scrolled_desktop.png');

await page.setViewport(mobile);
await page.goto(`${BASE}/?mobile=${Date.now()}`, { waitUntil: 'networkidle2' });
await waitApp();
await shot('07_home_mobile.png');
await tap(350, 55);
await shot('08_settings_mobile.png');
await tap(195, 260);
await shot('09_login_mobile.png');
await tap(195, 600, 5000);
await shot('10_qr_pairing_mobile.png');
await tap(30, 55);
await tap(195, 690);
await shot('11_register_mobile.png');

await page.setViewport(desktop);
await page.goto(`${BASE}/?sec=${Date.now()}`, { waitUntil: 'networkidle2' });
await waitApp();
await tap(140, 200);
await tap(640, 705);
await tap(640, 380);
await page.keyboard.type('demo-screenshots@wodo.app', { delay: 10 });
await tap(640, 460);
await page.keyboard.type('DemoPass123!', { delay: 10 });
await tap(640, 545, 2500);
await shot('12_logged_in_home_desktop.png');
await tap(140, 520);
await shot('13_settings_logged_in_desktop.png');
await page.mouse.wheel({ deltaY: 900 });
await new Promise((r) => setTimeout(r, 500));
await shot('14_settings_security_desktop.png');
await tap(640, 430);
await shot('15_approve_pairing_desktop.png');
await tap(35, 55);
await tap(140, 520);
await tap(640, 500, 2000);
await shot('16_linked_devices_desktop.png');
await tap(35, 55);
await tap(140, 520);
await page.mouse.wheel({ deltaY: 900 });
await tap(640, 570, 800);
await shot('17_protect_dialog_desktop.png');

await browser.disconnect();
chrome.kill();
console.log('Done', OUT);
