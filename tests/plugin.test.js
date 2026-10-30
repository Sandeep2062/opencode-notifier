import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { createNotifier } from '../plugin/notify.js';

function fixture(options = {}) {
  const calls = [], logs = [];
  const child = new EventEmitter(); child.unref = () => {};
  const notifier = createNotifier({ platform: 'win32', home: 'C:/test', env: {}, exists: () => true, claim: () => true, spawn: (...args) => { calls.push(args); return child; }, log: line => logs.push(line), ...options });
  return { calls, logs, child, notifier };
}

test('question dispatch is hidden, string-safe and custom audio is forwarded', () => {
  const { notifier, calls, child, logs } = fixture({ env: { XDG_CONFIG_HOME: 'C:/config', OPENCODE_NOTIFIER_SOUND: 'C:/my sound.wav' } });
  const event = { type: 'form.created', data: { id: 'q_dispatch', title: 'A & B' } };
  notifier.handleEvent(event); notifier.handleEvent(event);
  assert.equal(calls.length, 1);
  assert.ok(calls[0][1].includes('question'));
  assert.ok(calls[0][1].includes('C:/my sound.wav'));
  assert.equal(calls[0][2].windowsHide, true);
  assert.equal(calls[0][2].detached, false);
  assert.ok(calls[0][1].includes('-NonInteractive'));
  assert.ok(calls[0][1].every(arg => typeof arg === 'string'));
  child.emit('error', new Error('ENOENT'));
  child.emit('close', 2, null);
  assert.ok(logs.some(line => line.includes('ENOENT')));
  assert.ok(logs.some(line => line.includes('exit=2')));
});

test('Unix dispatch remains asynchronous and detached', () => {
  const { notifier, calls } = fixture({ platform: 'linux' });
  notifier.handleEvent({ type: 'form.created', data: { id: 'q_unix_dispatch' } });
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], 'bash');
  assert.equal(calls[0][2].detached, true);
});

test('missing helpers are logged and do not spawn', () => {
  const { notifier, calls, logs } = fixture({ exists: () => false });
  notifier.handleEvent({ type: 'question.asked', properties: { id: 'q_missing' } });
  assert.equal(calls.length, 0);
  assert.ok(logs.some(line => /missing/i.test(line)));
});

test('stream retries and cleanup cancels subscription', async () => {
  let subscriptions = 0, signal;
  const { notifier } = fixture({ retryDelay: 1 });
  const cleanup = notifier.start({ event: { subscribe(options) {
    signal = options.signal; subscriptions++;
    return (async function* () { if (subscriptions === 1) throw new Error('Disconnected'); await new Promise(resolve => signal.addEventListener('abort', resolve, { once: true })); })();
  } } });
  await new Promise(resolve => setTimeout(resolve, 20));
  assert.equal(subscriptions, 2);
  cleanup(); assert.equal(signal.aborted, true);
  await new Promise(resolve => setTimeout(resolve, 5));
  assert.equal(subscriptions, 2);
});
