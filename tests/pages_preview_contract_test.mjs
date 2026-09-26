import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, mkdir, readFile, rm, writeFile, chmod, access } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const script = resolve('tools/attach_pages_preview.sh');
assert.equal(spawnSync('bash', ['-n', script], { encoding: 'utf8' }).status, 0, 'Preview attachment script must parse');
const temp = await mkdtemp(join(tmpdir(), 'cf-pages-preview-'));
try {
  const bin = join(temp, 'bin');
  await mkdir(bin, { recursive: true });
  const fakeGh = join(bin, 'gh');
  await writeFile(fakeGh, String.raw`#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == api ]]; then
  if [[ "$MOCK_MODE" == wrong-sha ]]; then
    printf 'incorrect\tcompleted\tsuccess\n'
  else
    printf '%s\tcompleted\tsuccess\n' "$PREVIEW_HEAD_SHA"
  fi
elif [[ "$1" == run && "$2" == download ]]; then
  if [[ "$MOCK_MODE" == download-failure ]]; then exit 1; fi
  while [[ "$1" != --dir ]]; do shift; done
  shift
  mkdir -p "$1"
  printf '<!doctype html><title>Preview fixture</title>' > "$1/index.html"
  printf 'console.log("fixture")' > "$1/index.js"
else
  exit 2
fi
`);
  await chmod(fakeGh, 0o755);
  for (const mode of ['success', 'wrong-sha', 'download-failure']) {
    const cwd = join(temp, mode);
    await mkdir(join(cwd, 'build/web'), { recursive: true });
    await writeFile(join(cwd, 'build/web/index.html'), 'MAIN-ROOT-SENTINEL');
    const output = join(cwd, 'outputs.txt');
    await writeFile(output, '');
    const run = spawnSync('bash', [script], {
      cwd,
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: bin + ':' + process.env.PATH,
        MOCK_MODE: mode,
        GH_TOKEN: 'mock-only',
        GITHUB_REPOSITORY: 'ws951125/custom-fighter',
        GITHUB_OUTPUT: output,
        PREVIEW_RUN_ID: '36250217352',
        PREVIEW_HEAD_SHA: '9b8de45959f9e382f3ba90333cd7855709c8e5cd'
      }
    });
    assert.equal(run.status, 0, mode + ' must never break the main site: ' + run.stderr);
    assert.equal(await readFile(join(cwd, 'build/web/index.html'), 'utf8'), 'MAIN-ROOT-SENTINEL');
    assert.equal((await readFile(output, 'utf8')).trim(), 'enabled=' + (mode === 'success' ? 'true' : 'false'));
    const previewDir = join(cwd, 'build/web/preview/pr-212');
    if (mode === 'success') {
      await access(join(previewDir, 'index.html'));
      assert.equal((await readFile(join(previewDir, 'preview-source.txt'), 'utf8')).trim(), '9b8de45959f9e382f3ba90333cd7855709c8e5cd');
    } else {
      await assert.rejects(access(previewDir), 'Invalid/expired preview artifacts must leave no partial publish directory');
    }
  }
  console.log('SAME_ORIGIN_PAGES_PREVIEW_CONTRACT_PASSED cases=3 mainPreserved=true pinnedSha=true failClosed=true');
} finally {
  await rm(temp, { recursive: true, force: true });
}
