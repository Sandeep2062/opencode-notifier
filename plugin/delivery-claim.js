import { createHash } from 'node:crypto';
import { mkdirSync, openSync, closeSync, statSync, unlinkSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

// OpenCode can load plugins in separate location runtimes. A short-lived atomic
// file claim deduplicates those runtimes, not just imports in one JS module.
export function createDeliveryClaim(directory, { now = Date.now, ttl = 5000 } = {}) {
  return notification => {
    const identity = notification.requestID
      ? `${notification.type}:${notification.sessionID}:${notification.requestID}`
      : notification.executionID
        ? `${notification.type}:${notification.sessionID}:${notification.executionID}`
        : notification.eventID ? `event:${notification.eventID}`
          : notification.sessionID ? `${notification.type}:${notification.sessionID}` : '';
    if (!identity) return true;
    try {
      mkdirSync(directory, { recursive: true });
      const time = now();
      for (const name of readdirSync(directory)) {
        if (!/^[a-f0-9]{64}\.lock$/.test(name)) continue;
        const file = join(directory, name);
        try { if (time - statSync(file).mtimeMs >= ttl) unlinkSync(file); } catch { }
      }
      const file = join(directory, `${createHash('sha256').update(identity).digest('hex')}.lock`);
      try { const fd = openSync(file, 'wx'); closeSync(fd); return true; }
      catch (error) { if (error.code === 'EEXIST') return false; throw error; }
    } catch { return true; /* Unwritable cache must not lose notifications. */ }
  };
}
