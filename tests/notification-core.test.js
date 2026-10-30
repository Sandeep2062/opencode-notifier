import test from 'node:test';
import assert from 'node:assert/strict';
import { notificationFor, createDeduplicator } from '../plugin/notification-core.js';

test('native forms and legacy questions request attention', () => {
  const form = notificationFor({ type: 'form.created', data: { id: 'frm_1', sessionID: 's1', title: 'Choose a deployment', fields: [{ title: 'Environment', options: [{ label: 'Staging' }] }] } });
  assert.equal(form.type, 'question');
  assert.match(form.message, /Choose a deployment/);
  assert.match(form.message, /Staging/);
  assert.equal(form.requestID, 'frm_1');
  const question = notificationFor({ type: 'question.asked', properties: { id: 'q1', questions: [{ question: 'Proceed?' }, { question: 'Which option?' }] } });
  assert.match(question.message, /Proceed\?.*Which option/);
  assert.match(notificationFor({ type: 'form.created' }).message, /response/);
});

test('all supported events produce strings and irrelevant events do nothing', () => {
  for (const type of ['permission.asked', 'session.idle', 'session.execution.succeeded', 'session.error', 'session.execution.failed', 'session.step.failed']) {
    const result = notificationFor({ type, data: { error: { message: 'Provider unavailable' } } });
    assert.equal(typeof result.message, 'string');
  }
  assert.match(notificationFor({ type: 'session.error', properties: { error: { data: { message: 'Bad request' } } } }).message, /Bad request/);
  for (const type of ['form.replied', 'form.cancelled', 'question.replied', 'session.tool.called']) assert.equal(notificationFor({ type }), null);
  assert.equal(notificationFor(null), null);
  assert.ok(notificationFor({ type: 'form.created', data: { title: 'x'.repeat(1000) } }).message.length <= 300);
});

test('deduplication preserves distinct requests and expires with bounded state', () => {
  let now = 0;
  const dedup = createDeduplicator({ now: () => now, ttl: 5000, maxEntries: 2 });
  const event = id => notificationFor({ type: 'form.created', data: { id, sessionID: 's1', title: 'Choose' } });
  assert.equal(dedup.accept(event('q1')), true);
  assert.equal(dedup.accept(event('q1')), false);
  assert.equal(dedup.accept(event('q2')), true);
  now = 5001;
  assert.equal(dedup.accept(event('q1')), true);
  dedup.accept(event('q3')); dedup.accept(event('q4'));
  assert.equal(dedup.accept(event('q2')), true);
  dedup.clear();
  assert.equal(dedup.accept(event('q2')), true);
});

test('terminal aliases are deduplicated without hiding new executions', () => {
  const dedup = createDeduplicator();
  const event = (type, id) => notificationFor({ type, data: { sessionID: 's1', executionID: id } });
  assert.equal(dedup.accept(event('session.execution.succeeded', 'run1')), true);
  assert.equal(dedup.accept(event('session.idle', 'run1')), false);
  assert.equal(dedup.accept(event('session.execution.succeeded', 'run2')), true);
});
