import { mkdirSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';

const outputDir = 'test-results';
const outputPath = `${outputDir}/creator-preview-diagnostic.json`;
mkdirSync(outputDir, { recursive: true });

const result = spawnSync(process.execPath, ['tests/creator_preview_web_smoke.mjs'], {
  cwd: process.cwd(),
  env: process.env,
  encoding: 'utf8',
  maxBuffer: 4 * 1024 * 1024,
});

const exitCode = Number.isInteger(result.status) ? result.status : 1;
const diagnostic = {
  exitCode,
  signal: result.signal ?? null,
  error: result.error ? String(result.error) : null,
  stdout: result.stdout ?? '',
  stderr: result.stderr ?? '',
};

writeFileSync(outputPath, `${JSON.stringify(diagnostic, null, 2)}\n`, 'utf8');

if (diagnostic.stdout) process.stdout.write(diagnostic.stdout);
if (diagnostic.stderr) process.stderr.write(diagnostic.stderr);
if (diagnostic.error) console.error(diagnostic.error);

process.exitCode = exitCode;
