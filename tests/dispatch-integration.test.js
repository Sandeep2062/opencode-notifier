import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { copyFileSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { createNotifier } from '../plugin/notify.js';

test('real Windows process launch reaches helper dry-run with spaced paths', { skip: process.platform !== 'win32', timeout: 15000 }, async t => {
  const root = mkdtempSync(join(process.env.LOCALAPPDATA, 'Temp', 'opencode', 'notifier-dispatch spaced-'));
  const configDir = join(root, 'opencode');
  mkdirSync(configDir);
  copyFileSync(new URL('../scripts/opencode-notify.ps1', import.meta.url), join(configDir, 'opencode-notify.ps1'));
  const logs = [];
  let stdout = '', stderr = '';
  let finished, failed, child;
  t.after(() => {
    if (child?.exitCode === null) child.kill();
    rmSync(root, { recursive: true, force: true });
  });
  const completion = new Promise((resolve, reject) => { finished = resolve; failed = reject; });
  const notifier = createNotifier({ home: root, env: { XDG_CONFIG_HOME: root }, claim: () => true, log: line => logs.push(line), spawn(command, args, options) {
    child = spawn(command, [...args, '-DryRun'], { ...options, stdio: ['ignore', 'pipe', 'pipe'] });
    child.stdout.on('data', data => { stdout += data; });
    child.stderr.on('data', data => { stderr += data; });
    child.once('error', failed);
    child.once('close', code => finished(code));
    return child;
  } });
  notifier.handleEvent({ type: 'form.created', data: { id: `frm_integration_${Date.now()}`, title: 'Choose "one" & <two> Ω $HOME' } });
  assert.equal(await completion, 0, stderr || logs.join('\n'));
  assert.ok(stdout.trim(), `Helper returned no dry-run output: ${logs.join('\n')}`);
  const result = JSON.parse(stdout);
  assert.equal(result.type, 'question');
  assert.match(result.xml, /Choose &quot;one&quot; &amp; &lt;two&gt; Ω \$HOME/);
  assert.equal(result.log, join(configDir, 'notify.log'));
});
