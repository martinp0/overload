// Copy the static web app into www/ for Capacitor. The site at the repo root
// stays the GitHub Pages app; www/ is a generated bundle and is not committed.

import { cp, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const www = path.join(root, 'www');

const files = [
  'index.html',
  'privacy.html',
  'manifest.webmanifest',
  'sw.js',
  'css/app.css',
  'css/fold.css',
  'js/app.js',
  'js/art.js',
  'js/chart.js',
  'js/components.js',
  'js/data.js',
  'js/engine.js',
  'js/fold.js',
  'js/fold-metrics.js',
  'js/picker.js',
  'js/share.js',
  'js/store.js',
  'js/timer.js',
  'js/ui.js',
  'js/views/exercises.js',
  'js/views/history.js',
  'js/views/settings.js',
  'js/views/shared.js',
  'js/views/today.js',
  'js/views/workout.js',
  'icons/icon.svg',
  'icons/icon-192.png',
  'icons/icon-512.png',
  'icons/icon-maskable-512.png',
  'icons/icon-maskable.svg',
  'icons/apple-touch-icon.png',
];

await rm(www, { recursive: true, force: true });
await mkdir(www, { recursive: true });
for (const file of files) {
  const dest = path.join(www, file);
  await mkdir(path.dirname(dest), { recursive: true });
  await cp(path.join(root, file), dest);
}
console.log(`Synced ${files.length} files to www/`);
