import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

test('Windows helper silent XML/fallback checks', { skip: process.platform !== 'win32' }, () => {
  const result = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'tests/windows-notify.test.ps1'], { encoding: 'utf8', windowsHide: true });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
