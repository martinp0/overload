import { spawn } from 'node:child_process';
import path from 'node:path';

const android = path.resolve(import.meta.dirname, '..', 'android');
const args = process.argv.slice(2);
const child = spawn('./gradlew', args, { cwd: android, stdio: 'inherit' });
child.on('exit', (code) => process.exit(code == null ? 1 : code));
