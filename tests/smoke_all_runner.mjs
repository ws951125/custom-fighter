import { spawnSync } from 'node:child_process';

const smokeScripts = [
  'smoke:web',
  'smoke:match-restart',
  'smoke:opponent-ai',
  'smoke:area',
  'smoke:formation',
  'smoke:buff',
  'smoke:melee',
  'smoke:coordination',
  'smoke:character',
  'smoke:character-selection',
  'smoke:competitive-local',
  'smoke:character-animation',
  'smoke:creator',
  'smoke:creator-skill',
  'smoke:creator-timeline',
  'smoke:creator-preview',
  'smoke:creator-preview-family',
  'smoke:creator-vfx',
  'smoke:creator-vfx-runtime',
  'smoke:creator-ai-vfx',
  'smoke:creator-remote-ai-vfx',
  'smoke:creator-remote-reference-ai-vfx',
  'smoke:creator-ai-skill-proposal',
  'smoke:creator-package',
  'smoke:creator-package-vfx',
  'smoke:mobile',
];

function runNpmScript(scriptName) {
  if (process.platform === 'win32') {
    const commandProcessor = process.env.ComSpec || process.env.COMSPEC || 'cmd.exe';
    return spawnSync(commandProcessor, ['/d', '/s', '/c', `npm run ${scriptName}`], {
      stdio: 'inherit',
      env: process.env,
    });
  }

  return spawnSync('npm', ['run', scriptName], {
    stdio: 'inherit',
    env: process.env,
  });
}

for (const scriptName of smokeScripts) {
  console.log(`SMOKE_SUITE_STAGE_START script=${scriptName}`);
  const result = runNpmScript(scriptName);
  if (result.error || result.status !== 0) {
    const detail = result.error ? String(result.error) : `exit=${result.status ?? 'unknown'} signal=${result.signal ?? ''}`;
    const annotation = `script=${scriptName} ${detail}`
      .replaceAll('%', '%25')
      .replaceAll('\r', '%0D')
      .replaceAll('\n', '%0A');
    console.error(`::error title=Smoke suite failure::${annotation}`);
    process.exit(result.status || 1);
  }
  console.log(`SMOKE_SUITE_STAGE_PASS script=${scriptName}`);
}

console.log(`SMOKE_SUITE_PASSED count=${smokeScripts.length}`);
