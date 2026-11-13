// Runs the server's Maven wrapper from the server folder: ./mvnw on macOS and Linux,
// mvnw.cmd on Windows. The server itself is a plain Spring Boot (Maven) project.
//
//   node scripts/server.mjs        start the server (mvnw spring-boot:run)
//   node scripts/server.mjs test   run the server tests (mvnw test)
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const serverDir = fileURLToPath(new URL('../server/', import.meta.url));
const windows = process.platform === 'win32';
const goals = process.argv[2] === 'test' ? ['test'] : ['spring-boot:run'];

const child = spawn(windows ? 'mvnw.cmd' : './mvnw', goals, { cwd: serverDir, stdio: 'inherit', shell: windows });

child.on('exit', (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => child.kill(signal));
