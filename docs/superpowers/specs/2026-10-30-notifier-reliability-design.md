# Reliable input-request notifications and soft audio

Date: 2026-10-30
Status: Approved; implemented and verified on Windows with a real option prompt.

## Goal and confirmed cause

OpenCode must alert the user acoustically and visually when it needs an answer or an option selected, as well as for permissions, completion, and errors. The user approved a focused reliability upgrade with a soft two-tone chime and custom WAV support.

The installed OpenCode v2.2.2 emits `form.created` for question/selection prompts. The original plugin only dispatches permissions, completion, and failures, so it never attempts an alert for these prompts. Subsequent real-process testing also confirmed that its detached Windows PowerShell launch exits 0 without executing the helper. Both causes are fixed; Windows XML and fallback bugs were additional delivery risks.

## Event handling

- Treat native `form.created` and compatibility `question.asked` as `question` alerts: title `OpenCode - Answer Required`, with a bounded question/form summary and a fallback explaining that OpenCode needs a response.
- Preserve `permission.asked`, `session.execution.succeeded`, `session.execution.failed`, `session.step.failed`, and compatibility `session.idle`/`session.error` alerts.
- Accept current `event.data` and compatibility `event.properties` payloads. Format structured errors safely rather than passing objects as process arguments.
- Do not notify for answers, cancellations, ordinary streaming/tool activity, or a question merely mentioned in assistant text without an actual interactive request.
- Deduplicate event IDs and stable request/session/execution identities for a bounded window; never collapse different requests solely because their text matches. Store only notification-relevant events, bound memory, and avoid per-event timers.
- Claim dispatch atomically in a short-lived hashed cache file so independent OpenCode location runtimes do not send the same request repeatedly. Cache failure must not prevent delivery; expired claims are pruned.
- Use one abortable V2 event subscription per instance, return lifecycle cleanup, and retry unexpected stream termination with capped backoff. Keep the existing legacy entrypoints as isolated compatibility adapters.

## Components and data flow

Keep the dependency-free JavaScript plugin and native platform helpers. Add a small independently testable notification core for payload formatting, event classification, and duplicate filtering. Keep process dispatch and subscription lifecycle in the plugin entrypoint.

Flow: public event -> normalize/classify -> duplicate filter -> platform helper with explicit argument array -> desktop delivery and audio attempted independently -> bounded diagnostic log.

Resolve installed helper paths from `XDG_CONFIG_HOME` when set, otherwise `~/.config/opencode`, with documented compatibility paths. Missing files and asynchronous spawn/exit failures must be visible in diagnostics without crashing OpenCode or blocking agent work.

## Windows delivery and audio

- Build toast XML with safely escaped text; strip invalid XML control characters and cap displayed message length.
- Launch PowerShell asynchronously with `windowsHide: true` and `detached: false`; unreference the child rather than detaching it. Real-process testing on this Windows installation shows detached launches exit successfully without running any script. Include `-NonInteractive` and require valid silent dry-run output in regression tests.
- Try the registered notifier AppID and a Windows PowerShell fallback. If all attempts fail, actually attempt a system-tray balloon and keep its resources alive long enough to display, then dispose them.
- Use standard non-modal toasts. Query notification availability where supported, and record disabled/blocked status. An accepted OS API call is not proof that a banner appeared or was heard.
- Attempt sound even when visual delivery fails, and visual delivery even when audio fails. Silence toast-native audio when using the separate player to avoid double chimes.
- Bundle original short PCM WAV cues: question/permission use a soft attention chime; completion and error use recognizable variations. Do not copy or claim to bundle Google Antigravity's exact sound. Generate assets deterministically with a development script, with no runtime download.
- Support an optional custom WAV path through `OPENCODE_NOTIFIER_SOUND` and helper `-SoundPath` (Unix fourth positional argument), falling back to bundled audio then platform system audio when invalid or unavailable.
- No synthesized speech, modal dialogs, forced repeated reminders, or changes to OS volume/Do Not Disturb settings.

## Other supported platforms

- macOS: pass notification text as AppleScript arguments, not interpolated source; use `afplay` for the bundled/custom WAV, with system sounds as fallback.
- Linux: attempt `notify-send` independently of sound-player availability. Select an available WAV-capable player rather than sending Ogg files to `aplay`.
- WSL/Git Bash: locate the installed PowerShell helper and convert helper/custom-audio paths for Windows execution. Report missing prerequisites; never silently select an incompatible home-directory path.
- Preserve asynchronous hidden-window dispatch and keep notification helper processes short-lived.

## Installation and documentation

Update both installers/uninstallers for the V2 global `plugins/` discovery layout and install the core/helper/audio files together. Preserve legacy compatibility entrypoints without loading duplicate copies of this notifier. Only replace known notifier files; back up an existing installation during an authorized upgrade and do not alter unrelated config, plugins, or user shortcuts.

Remove unconditional background-service restarts. Use automatic config reload or `/reload`; do not interrupt active sessions to apply the update. Installer tests must distinguish an attempted notification from user-confirmed visibility/audibility.

Document question alerts, custom WAV usage, installation, self-tests, diagnostics, Do Not Disturb/muted-audio limitations, and platform prerequisites. Keep accurate V2 guidance and do not claim unverified full V1 compatibility.

The user approved repository implementation, the installed upgrade, verification, commit, and push. Automated tests remain silent; announce live smoke tests before running them.

## Tests and acceptance criteria

Use Node's built-in test runner with mocked dispatch, clocks, event streams, and child processes. Tests must not emit real notifications or audio.

Cover native `form.created`, compatibility `question.asked`, data/properties shapes, empty/multiple questions, option prompts, structured failures, request-aware deduplication, irrelevant/resolved events, missing scripts, spawn errors and failed exits, stream retry/cleanup, and path/custom-audio argument handling.

Use PowerShell parsing plus a testable XML construction/dry-run path for quotes, ampersands, angle brackets, Unicode, and invalid control characters. Validate WAV headers and duration. Check Unix script syntax when Bash is available. Test platform fallback logic without presenting actual banners wherever feasible.
The Windows launch regression must execute the repository helper from an isolated config path containing spaces (not depend on a preinstalled helper), use the production launch flags, and require nonempty JSON from `-DryRun` with a finite test timeout.

Acceptance: a new interactive question/form dispatches exactly one attention notification; permission/completion/error alerts remain supported; duplicate deliveries are suppressed without losing distinct prompts; notification and audio failures leave actionable diagnostics and do not crash OpenCode. An explicitly authorized Windows smoke test verifies the new installed helper, followed by user confirmation of sound/banner. macOS/Linux delivery remains unverified unless tested on those systems.

## Verification result

- Silent automated suite: 17 tests passed, including real PowerShell startup from a spaced path, XML/Unicode round-trip, and isolated installer upgrade/removal.
- Installed live `form.created`: one dispatch followed by helper startup, dedicated toast acceptance, `attention.wav` playback, and clean exit. User confirmed both banner and sound for that exact prompt.
- No service restart or OS notification/volume changes. Real macOS/Linux desktop delivery remains unverified; Unix syntax and command-stub checks passed.

## References

- https://opencode.ai/v2/docs/build/plugins
- https://opencode.ai/v2/docs/build/plugins/server
- https://opencode.ai/v2/docs/plugins
- https://opencode.ai/v2/openapi.json (`form.created`, `Form.Info`)
