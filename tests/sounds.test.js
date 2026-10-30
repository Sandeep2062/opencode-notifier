import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

for (const name of ['attention', 'complete', 'error']) test(`${name} is a short PCM WAV`, () => {
  const wav = readFileSync(new URL(`../sounds/${name}.wav`, import.meta.url));
  assert.equal(wav.toString('ascii', 0, 4), 'RIFF');
  assert.equal(wav.toString('ascii', 8, 12), 'WAVE');
  assert.equal(wav.readUInt16LE(20), 1);
  assert.equal(wav.readUInt16LE(22), 1);
  assert.equal(wav.readUInt16LE(34), 16);
  const duration = wav.readUInt32LE(40) / wav.readUInt32LE(28);
  assert.ok(duration > 0.3 && duration < 1);
  let peak = 0;
  for (let offset = 44; offset < wav.length; offset += 2) peak = Math.max(peak, Math.abs(wav.readInt16LE(offset)));
  assert.ok(peak > 1000 && peak < 13108);
});
