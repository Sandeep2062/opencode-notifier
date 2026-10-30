import { spawn } from "child_process";
import { homedir } from "os";
import { join } from "path";
import { existsSync, appendFileSync } from "fs";

const LOG_FILE = join(homedir(), ".config", "opencode", "notify.log");
const PS_SCRIPT = join(homedir(), ".config", "opencode", "opencode-notify.ps1");
const SH_SCRIPT = join(homedir(), "opencode-notify.sh");

const recentEvents = new Set();

function logDebug(msg) {
  try {
    appendFileSync(LOG_FILE, `[${new Date().toISOString()}] ${msg}\n`);
  } catch {}
}

function triggerNotification(type, data = {}) {
  let title = "OpenCode";
  let message = "";

  switch (type) {
    case "permission.asked":
      title = "OpenCode - Permission Required";
      message = data?.title || data?.description || data?.tool || "OpenCode is waiting for your permission.";
      break;
    case "session.idle":
      title = "OpenCode - Finished";
      message = "OpenCode completed the task and is waiting for your input.";
      break;
    case "session.error":
      title = "OpenCode - Error";
      message = data?.message || data?.error || "An error occurred in OpenCode.";
      break;
    default:
      title = "OpenCode Notification";
      message = `Event: ${type}`;
      break;
  }

  logDebug(`Triggering notification: ${type} - ${title}: ${message}`);

  try {
    if (process.platform === "win32") {
      const child = spawn(
        "powershell.exe",
        [
          "-NoProfile",
          "-ExecutionPolicy",
          "Bypass",
          "-File",
          PS_SCRIPT,
          "-Type",
          type,
          "-Title",
          title,
          "-Message",
          message
        ],
        {
          detached: true,
          stdio: "ignore",
          windowsHide: true
        }
      );
      child.unref();
    } else if (existsSync(SH_SCRIPT)) {
      const child = spawn(SH_SCRIPT, [type, message, title], {
        detached: true,
        stdio: "ignore"
      });
      child.unref();
    }
  } catch (err) {
    logDebug(`Error spawning notification: ${err}`);
  }
}

function handleEvent(event) {
  if (!event || !event.type) return;

  // Deduplicate events that might fire multiple times across different hooks
  const eventKey = event.id || `${event.type}_${Date.now()}`;
  if (recentEvents.has(eventKey)) return;
  recentEvents.add(eventKey);
  setTimeout(() => recentEvents.delete(eventKey), 5000);

  logDebug(`Received event: ${event.type}`);

  if (
    event.type === "permission.asked" ||
    event.type === "session.idle" ||
    event.type === "session.error"
  ) {
    triggerNotification(event.type, event.data);
  }
}

// Unified OpenCode v2 + v1 Plugin Export
export default {
  id: "audio-visual-notifications",

  // OpenCode v2 lifecycle setup
  async setup(ctx) {
    logDebug("Plugin v2 setup initialized");

    if (ctx?.event?.subscribe) {
      (async () => {
        try {
          for await (const event of ctx.event.subscribe()) {
            handleEvent(event);
          }
        } catch (err) {
          logDebug(`Event stream error: ${err}`);
        }
      })();
    }

    return {
      event: async ({ event }) => {
        handleEvent(event);
      }
    };
  },

  // OpenCode v1 server export
  async server() {
    logDebug("Plugin v1 server initialized");
    return {
      event: async ({ event }) => {
        handleEvent(event);
      }
    };
  }
};

// Backwards compatibility export for legacy OpenCode v1 loaders
export const NotificationPlugin = async () => {
  return {
    event: async ({ event }) => {
      handleEvent(event);
    }
  };
};
