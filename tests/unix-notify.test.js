import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const bash = process.platform === 'win32' ? 'C:/Program Files/Git/bin/bash.exe' : 'bash';
const available = spawnSync(bash, ['--version'], { encoding: 'utf8' }).status === 0;
const tempRoot = process.platform === 'win32' ? join(process.env.LOCALAPPDATA, 'Temp', 'opencode') : process.env.TMPDIR || '/tmp';

test('Unix helper parses', { skip: !available }, () => {
  const result = spawnSync(bash, ['-n', 'scripts/opencode-notify.sh'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
});

test('Linux banner does not require an audio player and text remains literal', { skip: !available }, () => {
  const dir = mkdtempSync(join(tempRoot, 'notifier-unix-'));
  mkdirSync(join(dir, 'opencode'));
  const bin = join(dir, 'bin'); mkdirSync(bin);
  const capture = join(dir, 'capture');
  const shellPath = value => value.replaceAll('\\', '/').replace(/^([A-Za-z]):/, (_, drive) => `/${drive.toLowerCase()}`);
  writeFileSync(join(bin, 'notify-send'), '#!/bin/bash\nprintf "%s\\n" "$@" > "$CAPTURE"\n', { mode: 0o755 });
  const result = spawnSync(bash, ['scripts/opencode-notify.sh', 'question', 'Choose "one" & <two>', 'OpenCode - Answer Required'], {
    encoding: 'utf8', env: { ...process.env, PATH: shellPath(bin), XDG_CONFIG_HOME: shellPath(dir), CAPTURE: shellPath(capture) }
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.ok(existsSync(capture));
  assert.match(readFileSync(capture, 'utf8'), /Choose "one" & <two>/);
});
