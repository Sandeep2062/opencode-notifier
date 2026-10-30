import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

test('Windows upgrade backs up legacy notifier and preserves unrelated files', { skip: process.platform !== 'win32' }, () => {
  const root = mkdtempSync(join(process.env.LOCALAPPDATA, 'Temp', 'opencode', 'notifier-install-'));
  mkdirSync(join(root, 'plugin'));
  const legacy = '// audio-visual-notifications legacy fixture';
  writeFileSync(join(root, 'plugin', 'notify.js'), legacy);
  writeFileSync(join(root, 'plugin', 'other.js'), 'unrelated plugin');
  writeFileSync(join(root, 'opencode.jsonc'), '// preserve configuration');
  const run = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'install.ps1', '-SkipTest', '-ConfigDir', root], { encoding: 'utf8' });
  assert.equal(run.status, 0, run.stdout + run.stderr);
  assert.equal(readFileSync(join(root, 'plugin', 'other.js'), 'utf8'), 'unrelated plugin');
  assert.equal(readFileSync(join(root, 'opencode.jsonc'), 'utf8'), '// preserve configuration');
  assert.equal(existsSync(join(root, 'plugin', 'notify.js')), false);
  assert.ok(existsSync(join(root, 'plugins', 'opencode-notifier', 'notification-core.js')));
  assert.ok(existsSync(join(root, 'notifier-sounds', 'attention.wav')));
  const backup = join(root, 'notifier-backups', readdirSync(join(root, 'notifier-backups'))[0]);
  assert.equal(readFileSync(join(backup, 'plugin', 'notify.js'), 'utf8'), legacy);
  const uninstall = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'uninstall.ps1', '-ConfigDir', root], { encoding: 'utf8' });
  assert.equal(uninstall.status, 0, uninstall.stdout + uninstall.stderr);
  assert.ok(existsSync(join(root, 'plugin', 'other.js')));
  assert.ok(existsSync(backup));
  assert.equal(existsSync(join(root, 'plugins', 'opencode-notifier', 'notify.js')), false);
});
