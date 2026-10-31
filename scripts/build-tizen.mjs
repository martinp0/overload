// Build an installable Tizen web app at tizen/dist and an unsigned tizen/Overload.wgt.
// `aerotizen install tizen/dist` (or the .wgt) signs it with the TV certificate.

import { spawnSync } from 'node:child_process';
import { cp, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const dist = path.join(root, 'tizen', 'dist');

const files = [
  ['tizen/config.xml', 'config.xml'],
  ['tizen/index.html', 'index.html'],
  ['icons/icon-512.png', 'icon.png'],
  ['css/tv.css', 'css/tv.css'],
  ['js/tv-app.js', 'js/tv-app.js'],
  ['js/data.js', 'js/data.js'],
  ['js/store.js', 'js/store.js'],
  ['js/engine.js', 'js/engine.js'],
];

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
for (const [from, to] of files) {
  const dest = path.join(dist, to);
  await mkdir(path.dirname(dest), { recursive: true });
  await cp(path.join(root, from), dest);
}

const wgt = path.join(root, 'tizen', 'Overload.wgt');
await rm(wgt, { force: true });
const zip = spawnSync('zip', ['-r', '-X', wgt, '.'], { cwd: dist, stdio: 'inherit' });
if (zip.status !== 0) {
  console.error('zip failed. Install zip or use the tizen/dist folder directly.');
  process.exit(zip.status || 1);
}
console.log('Tizen package: tizen/dist');
console.log('Unsigned widget: tizen/Overload.wgt');
console.log('Install: aerotizen install tizen/dist');
