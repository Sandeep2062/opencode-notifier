import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { join } from 'node:path';
import { createDeliveryClaim } from '../plugin/delivery-claim.js';

test('separate plugin runtimes claim each request once without merging new requests', () => {
  const root = process.platform === 'win32' ? join(process.env.LOCALAPPDATA, 'Temp', 'opencode') : process.env.TMPDIR || '/tmp';
  const directory = mkdtempSync(join(root, 'notifier-claims-'));
  const first = createDeliveryClaim(directory);
  const second = createDeliveryClaim(directory);
  const question = { type: 'question', sessionID: 's1', requestID: 'q1' };
  assert.equal(first(question), true);
  assert.equal(second(question), false);
  assert.equal(second({ ...question, requestID: 'q2' }), true);
  const expired = createDeliveryClaim(directory, { now: () => Date.now() + 6000 });
  assert.equal(expired(question), true);
});
