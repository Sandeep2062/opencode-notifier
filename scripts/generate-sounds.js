import { mkdirSync, writeFileSync } from 'node:fs';

const rate = 44100;
const duration = 0.72;
const samples = Math.floor(rate * duration);
const directory = new URL('../sounds/', import.meta.url);
mkdirSync(directory, { recursive: true });
for (const [name, notes] of Object.entries({ attention: [660, 880], complete: [523, 784], error: [440, 330] })) {
  const wav = Buffer.alloc(44 + samples * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write('data', 36); wav.writeUInt32LE(samples * 2, 40);
  for (let index = 0; index < samples; index++) {
    const t = index / rate;
    let amplitude = 0;
    notes.forEach((frequency, note) => {
      const local = t - note * 0.22;
      if (local >= 0 && local < 0.48) {
        const envelope = Math.min(1, local / 0.018) * Math.exp(-local * 8) * Math.min(1, (0.48 - local) / 0.04);
        amplitude += 0.23 * envelope * (Math.sin(2 * Math.PI * frequency * local) + 0.12 * Math.sin(4 * Math.PI * frequency * local));
      }
    });
    wav.writeInt16LE(Math.round(Math.max(-0.39, Math.min(0.39, amplitude)) * 32767), 44 + index * 2);
  }
  writeFileSync(new URL(`${name}.wav`, directory), wav);
}
console.log('Generated original attention, completion, and error PCM chimes.');
