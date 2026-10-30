import { spawn as spawnProcess } from 'node:child_process';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync, appendFileSync, mkdirSync, statSync, renameSync } from 'node:fs';
import { notificationFor, createDeduplicator } from './notification-core.js';
import { createDeliveryClaim } from './delivery-claim.js';

const sharedDuplicates = createDeduplicator();
const moduleDir = dirname(fileURLToPath(import.meta.url));

function logger(configDir) {
  return message => {
    try {
      mkdirSync(configDir, { recursive: true });
      const file = join(configDir, 'notify.log');
      if (existsSync(file) && statSync(file).size > 1024 * 1024) renameSync(file, `${file}.previous`);
      appendFileSync(file, `[${new Date().toISOString()}] ${String(message).replace(/[\r\n]/g, ' ').slice(0, 1000)}\n`);
    } catch { /* Diagnostics must never interrupt OpenCode. */ }
  };
}

export function createNotifier({ platform = process.platform, home = homedir(), env = process.env, exists = existsSync, spawn = spawnProcess, log, now, claim, retryDelay = 1000 } = {}) {
  const configDir = join(env.XDG_CONFIG_HOME || join(home, '.config'), 'opencode');
  log ??= logger(configDir);
  const duplicates = now ? createDeduplicator({ now }) : sharedDuplicates;
  claim ??= createDeliveryClaim(join(configDir, 'notifier-cache'));
  let stopped = false;

  function handleEvent(event) {
    if (stopped) return;
    const notification = notificationFor(event);
    if (!notification || !duplicates.accept(notification)) return;
    const filename = platform === 'win32' ? 'opencode-notify.ps1' : 'opencode-notify.sh';
    const candidates = [join(configDir, filename), join(home, filename), join(moduleDir, '..', 'scripts', filename)];
    const helper = candidates.find(path => exists(path));
    if (!helper) { log(`Notification helper missing: ${candidates.join(', ')}`); return; }
    if (!claim(notification)) return;
    log(`Dispatch ${notification.eventType} -> ${notification.type} session=${notification.sessionID || 'unknown'}`);
    const sound = env.OPENCODE_NOTIFIER_SOUND || '';
    let command, args;
    if (platform === 'win32') {
      command = 'powershell.exe';
      args = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', helper, '-Type', notification.type, '-Title', notification.title, '-Message', notification.message, '-LogPath', join(configDir, 'notify.log')];
      if (sound) args.push('-SoundPath', sound);
    } else {
      command = 'bash';
      args = [helper, notification.type, notification.message, notification.title, sound];
    }
    try {
      // Detached PowerShell can exit 0 before running its script on Windows.
      // spawn/unref is already asynchronous; only Unix needs detachment.
      const child = spawn(command, args, { detached: platform !== 'win32', stdio: ['ignore', 'ignore', 'pipe'], windowsHide: true });
      let stderr = '';
      child.stderr?.on('data', data => { stderr = (stderr + String(data)).slice(0, 2000); });
      child.stderr?.unref?.();
      child.on('spawn', () => log(`Notification process started pid=${child.pid || 'unknown'}`));
      child.on('error', error => log(`Notification process error: ${error.message}`));
      child.on('close', (code, signal) => log(`Notification process exit=${code} signal=${signal || 'none'}${stderr ? ` stderr=${stderr}` : ''}`));
      child.unref();
    } catch (error) { log(`Notification spawn failed: ${error.message}`); }
  }

  function start(ctx) {
    const controller = new AbortController();
    let timer;
    let resume;
    let attempts = 0;
    log('Notifier v2 setup: form/question alerts enabled');
    if (!ctx?.event?.subscribe) { log('Missing V2 event subscription API'); return () => { stopped = true; }; }
    void (async () => {
      while (!controller.signal.aborted) {
        try {
          for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
            if (controller.signal.aborted) break;
            attempts = 0;
            handleEvent(event);
          }
          if (!controller.signal.aborted) log('Event stream ended; reconnecting');
        } catch (error) { if (!controller.signal.aborted) log(`Event stream failed: ${error.message}; reconnecting`); }
        if (controller.signal.aborted) break;
        const delay = Math.min(30000, retryDelay * 2 ** Math.min(attempts++, 5));
        await new Promise(resolve => { resume = resolve; timer = setTimeout(resolve, delay); timer.unref?.(); });
      }
    })().catch(error => log(`Event subscriber failed: ${error.message}`));
    return () => { stopped = true; controller.abort(); clearTimeout(timer); resume?.(); log('Notifier unloaded'); };
  }
  return { handleEvent, start };
}

export default {
  id: 'audio-visual-notifications',
  setup(ctx) { return createNotifier().start(ctx); },
  async server() { return NotificationPlugin(); }
};

// Compatibility adapter; current V2 uses setup() and the public event stream.
export const NotificationPlugin = async () => {
  const notifier = createNotifier();
  return { event: async ({ event }) => notifier.handleEvent(event) };
};
