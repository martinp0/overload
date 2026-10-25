// Regenerates apple/Shared/Resources/exercises.json from the web app's exercise library
// (js/data.js), so the iPhone and Watch apps use exactly the same exercise ids and names.
//
//   node apple/scripts/export-exercises.mjs
//
// Run it whenever js/data.js changes.
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { EXERCISES, MUSCLES } from '../../js/data.js';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'Shared', 'Resources', 'exercises.json');
const muscles = Object.fromEntries(Object.entries(MUSCLES).map(([id, m]) => [id, m.name]));
writeFileSync(out, JSON.stringify({ muscles, exercises: EXERCISES }, null, 1) + '\n');
console.log(`Wrote ${EXERCISES.length} exercises to ${out}`);
