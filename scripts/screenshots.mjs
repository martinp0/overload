// Layout proofs for the Galaxy phone, Flip Flex Mode, Fold, cover glance, and TV.
// Serves the repo and drives the installed Chrome. Fails if a layout assertion misses.

import { spawn } from 'node:child_process';
import { mkdir, cp } from 'node:fs/promises';
import path from 'node:path';
import { chromium } from 'playwright';

const root = path.resolve(import.meta.dirname, '..');
const out = path.join(root, 'samsung', 'screenshots');
const artifacts = '/opt/cursor/artifacts/screenshots';
const port = 8765;
const base = `http://127.0.0.1:${port}`;

function workout(now) {
  return {
    id: 'demo',
    name: 'Push day',
    split: 'push',
    startedAt: now - 18 * 60 * 1000,
    rest: { endsAt: now + 75 * 1000, total: 90, alerted: false },
    exercises: [
      {
        uid: 'e1', exId: 'bb_bench', name: 'Barbell Bench Press', min: 6, max: 10, rest: 90,
        sets: [
          { w: 80, r: 8, s: null, done: true, wu: false },
          { w: 80, r: 8, s: null, done: false, wu: false },
          { w: null, r: null, s: null, done: false, wu: false },
          { w: null, r: null, s: null, done: false, wu: false },
        ],
      },
      {
        uid: 'e2', exId: 'bb_ohp', name: 'Overhead Press', min: 6, max: 10, rest: 90,
        sets: [
          { w: null, r: null, s: null, done: false, wu: false },
          { w: null, r: null, s: null, done: false, wu: false },
          { w: null, r: null, s: null, done: false, wu: false },
        ],
      },
      {
        uid: 'e3', exId: 'tricep_pushdown', name: 'Tricep Pushdown', min: 8, max: 12, rest: 75,
        sets: [
          { w: null, r: null, s: null, done: false, wu: false },
          { w: null, r: null, s: null, done: false, wu: false },
          { w: null, r: null, s: null, done: false, wu: false },
        ],
      },
    ],
  };
}

function seed(active) {
  const settings = {
    unit: 'kg', theme: 'auto', goal: 'hypertrophy', duration: 60, split: 'push',
    customMuscles: ['chest', 'shoulders', 'triceps'],
    equipment: ['barbell', 'dumbbell', 'bench', 'cable', 'machine'],
    inc: { kg: { barbell: 2.5, dumbbell: 2, machine: 5 }, lb: { barbell: 5, dumbbell: 5, machine: 10 } },
    autoRest: true, sound: false, vibrate: false, wakeLock: false,
  };
  const entries = [
    ['overload.settings', JSON.stringify(settings)],
    ['overload.history', '[]'],
    ['overload.templates', '[]'],
    ['overload.custom', '[]'],
    ['overload.prefs', JSON.stringify({ fav: {}, excl: {} })],
    ['overload.draft', 'null'],
    ['overload.active', active ? JSON.stringify(active) : 'null'],
  ];
  return entries;
}

async function boot(page, { path: urlPath, active, width, height }) {
  await page.addInitScript((entries) => {
    for (const [k, v] of entries) localStorage.setItem(k, v);
  }, seed(active));
  await page.setViewportSize({ width, height });
  await page.emulateMedia({ colorScheme: 'dark' });
  await page.goto(base + urlPath, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(400);
}

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

const server = spawn('python3', ['-m', 'http.server', String(port)], { cwd: root, stdio: 'ignore' });
let browser;
try {
  await new Promise((resolve, reject) => {
    const start = Date.now();
    const ping = async () => {
      try {
        const res = await fetch(base + '/');
        if (res.ok) return resolve();
      } catch { /* not up yet */ }
      if (Date.now() - start > 8000) reject(new Error('static server did not start'));
      else setTimeout(ping, 150);
    };
    ping();
  });

  await mkdir(out, { recursive: true });
  browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });

  const now = Date.now();
  const active = workout(now);

  {
    const page = await browser.newPage();
    await boot(page, { path: '/#/', active: null, width: 390, height: 844 });
    await page.waitForSelector('.display');
    const info = await page.evaluate(() => ({
      windowClass: document.documentElement.dataset.window,
      posture: document.documentElement.dataset.posture,
      cover: document.documentElement.dataset.cover || '',
      tabs: getComputedStyle(document.getElementById('tabs')).flexDirection,
      max: getComputedStyle(document.getElementById('view')).maxWidth,
    }));
    assert(info.windowClass === 'compact', `compact window class, got ${info.windowClass}`);
    assert(info.posture === 'flat', `phone posture flat, got ${info.posture}`);
    assert(info.cover === '', 'phone is not the cover glance');
    assert(info.tabs === 'row', `phone tabs stay in a row, got ${info.tabs}`);
    assert(info.max === '600px', `phone column max-width stays 600px, got ${info.max}`);
    await page.screenshot({ path: path.join(out, 'phone-compact.png') });
    await page.close();
  }

  {
    const page = await browser.newPage();
    await boot(page, { path: '/?fold=flex#/workout/e1', active, width: 412, height: 900 });
    await page.waitForSelector('#fold-stage .sets');
    const before = await page.locator('#fold-stage .set-row:not(.head)').count();
    const info = await page.evaluate(() => {
      const dock = document.getElementById('dock').getBoundingClientRect();
      const top = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--fold-top'));
      return {
        posture: document.documentElement.dataset.posture,
        look: !!document.querySelector('#view .fold-look'),
        setsInStage: !!document.querySelector('#fold-stage .sets'),
        dockBottom: dock.bottom,
        foldTop: top,
        rest: document.querySelector('#dock [data-rest-time]')?.textContent || '',
      };
    });
    assert(info.posture === 'flex', `flex posture, got ${info.posture}`);
    assert(info.look, 'exercise stays in the top half');
    assert(info.setsInStage, 'set controls sit in the bottom half');
    assert(info.dockBottom <= info.foldTop + 2, `rest timer should sit in the top half (${info.dockBottom} > ${info.foldTop})`);
    assert(info.rest && info.rest !== '0:00', `rest timer painted, got ${info.rest}`);
    await page.screenshot({ path: path.join(out, 'flip-flex.png') });

    await page.evaluate(() => {
      history.replaceState(null, '', location.pathname + location.hash);
      window.dispatchEvent(new Event('resize'));
    });
    await page.waitForFunction(() => document.documentElement.dataset.posture === 'flat');
    const value = await page.locator('#view .set-in').nth(2).inputValue();
    await page.locator('#view .set-row:not(.done) .set-in').first().fill('42.5');
    await page.evaluate(() => {
      history.replaceState(null, '', '?fold=flex' + location.hash);
      window.dispatchEvent(new Event('resize'));
    });
    await page.waitForFunction(() => document.querySelector('#fold-stage .set-in'));
    const kept = await page.locator('#fold-stage .set-in').evaluateAll((nodes) => nodes.map((n) => n.value));
    assert(kept.includes('42.5'), `typed weight survived the fold, values ${kept.join(',')}`);
    await page.locator('#fold-stage [data-act="addset"]').click();
    await page.waitForFunction((n) => document.querySelectorAll('#fold-stage .set-row:not(.head)').length > n, before);
    assert(value === '80' || value === '80.0' || value === '', `flat log still has its inputs (${value})`);
    await page.close();
  }

  {
    const page = await browser.newPage();
    await boot(page, { path: '/#/workout/e1', active, width: 1280, height: 800 });
    await page.waitForSelector('.fold-split .sets');
    const info = await page.evaluate(() => ({
      windowClass: document.documentElement.dataset.window,
      posture: document.documentElement.dataset.posture,
      tabs: getComputedStyle(document.getElementById('tabs')).flexDirection,
      cols: getComputedStyle(document.querySelector('.fold-split')).gridTemplateColumns,
      setsInView: !!document.querySelector('#view .sets'),
    }));
    assert(info.windowClass === 'large', `expanded/large window, got ${info.windowClass}`);
    assert(info.posture === 'flat', 'open fold is flat');
    assert(info.tabs === 'column', `nav rail, got ${info.tabs}`);
    assert(info.cols.split(' ').length >= 2, `two-pane log, got ${info.cols}`);
    assert(info.setsInView, 'expanded log keeps sets in the page');
    await page.screenshot({ path: path.join(out, 'fold-expanded.png') });
    await page.close();
  }

  {
    const page = await browser.newPage();
    await boot(page, { path: '/?fold=book#/workout/e1', active, width: 1100, height: 840 });
    await page.waitForSelector('#fold-stage .sets');
    const info = await page.evaluate(() => ({
      posture: document.documentElement.dataset.posture,
      look: !!document.querySelector('#view .fold-look'),
      sets: !!document.querySelector('#fold-stage .sets'),
    }));
    assert(info.posture === 'book', `book posture, got ${info.posture}`);
    assert(info.look && info.sets, 'book splits the exercise and the sets across the hinge');
    await page.screenshot({ path: path.join(out, 'fold-book.png') });
    await page.close();
  }

  {
    const page = await browser.newPage();
    await boot(page, { path: '/?fold=cover#/workout/e1', active, width: 360, height: 380 });
    await page.waitForSelector('#cover-glance .cover-time');
    const info = await page.evaluate(() => ({
      cover: document.documentElement.dataset.cover,
      glance: getComputedStyle(document.getElementById('cover-glance')).display,
      view: getComputedStyle(document.getElementById('view')).display,
      title: document.querySelector('.cover-title').textContent,
      time: document.querySelector('[data-rest-time]').textContent,
    }));
    assert(info.cover === '1', 'cover flag');
    assert(info.glance !== 'none', 'glance is visible');
    assert(info.view === 'none', 'full UI is hidden on the cover');
    assert(info.title.includes('Bench'), `cover names the exercise, got ${info.title}`);
    assert(info.time && info.time !== '0:00', `cover rest time, got ${info.time}`);
    await page.screenshot({ path: path.join(out, 'flip-cover.png') });
    await page.close();
  }

  {
    const page = await browser.newPage();
    await boot(page, { path: '/tizen/dist/index.html', active: null, width: 1920, height: 1080 });
    await page.waitForSelector('.tv-row');
    const label = await page.locator('.tv-row-label').first().innerText();
    assert(/workout|trénink/i.test(label), `TV home offers a workout, got ${label}`);
    await page.screenshot({ path: path.join(out, 'tv-home.png') });
    await page.close();
  }

  {
    const page = await browser.newPage();
    await boot(page, { path: '/tizen/dist/index.html', active, width: 1920, height: 1080 });
    await page.waitForSelector('[data-tv-rest]');
    await page.waitForFunction(() => {
      const el = document.querySelector('[data-tv-rest]');
      return el && el.textContent && el.textContent !== '0:00';
    });
    const lift = await page.locator('.lift').innerText();
    assert(lift.includes('Bench'), `TV shows the lift, got ${lift}`);
    await page.screenshot({ path: path.join(out, 'tv-workout.png') });
    await page.close();
  }

  await mkdir(artifacts, { recursive: true });
  for (const name of ['phone-compact.png', 'flip-flex.png', 'fold-expanded.png', 'fold-book.png', 'flip-cover.png', 'tv-home.png', 'tv-workout.png']) {
    await cp(path.join(out, name), path.join(artifacts, name));
  }
  console.log('Screenshots written to samsung/screenshots');
} finally {
  if (browser) await browser.close();
  server.kill();
}
