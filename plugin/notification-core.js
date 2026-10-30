const TYPES = {
  'form.created': 'question', 'question.asked': 'question',
  'permission.asked': 'permission',
  'session.idle': 'idle', 'session.execution.succeeded': 'idle',
  'session.error': 'error', 'session.execution.failed': 'error', 'session.step.failed': 'error'
};

function text(value) {
  if (typeof value === 'string') return value;
  if (value && typeof value === 'object') return text(value.message || value.data?.message || value.description);
  return '';
}

export function notificationFor(event) {
  const type = TYPES[event?.type];
  if (!type) return null;
  const raw = event.data ?? event.properties ?? {};
  const data = raw.form ?? raw.request ?? raw.info ?? raw;
  let title, message;
  if (type === 'question') {
    title = 'OpenCode - Answer Required';
    const fields = data.questions ?? data.fields ?? [];
    const summaries = Array.isArray(fields) ? fields.filter(field => field && !field.hidden).slice(0, 3).map(field => {
      const options = Array.isArray(field.options) ? field.options.slice(0, 3).map(option => text(option.label)).filter(Boolean).join(', ') : '';
      return [text(field.question || field.title || field.description), options].filter(Boolean).join(': ');
    }) : [];
    message = [text(data.title), ...summaries].filter(Boolean).join(' — ') || 'OpenCode needs your response. Answer the question or choose an option.';
  } else if (type === 'permission') {
    title = 'OpenCode - Permission Required';
    message = text(data.title || data.description || data.action || data.permission || data.tool) || 'OpenCode is waiting for your permission.';
  } else if (type === 'idle') {
    title = 'OpenCode - Task Finished';
    message = 'OpenCode completed the task and is waiting for your input.';
  } else {
    title = 'OpenCode - Error';
    message = text(data.message || data.error || data.cause) || 'An error occurred in OpenCode.';
  }
  return {
    type, title, message: message.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, '').slice(0, 300),
    sessionID: text(data.sessionID || raw.sessionID),
    requestID: ['question', 'permission'].includes(type) ? text(data.id || data.requestID) : '',
    executionID: text(data.executionID || data.execution?.id),
    eventID: text(event.id), eventType: event.type, source: event
  };
}

export function createDeduplicator({ now = Date.now, ttl = 5000, maxEntries = 512 } = {}) {
  const recent = new Map();
  let anonymous = new WeakSet();
  return {
    accept(notification) {
      const time = now();
      for (const [key, expires] of recent) if (expires <= time) recent.delete(key);
      const { type, sessionID, requestID, executionID, eventID, source } = notification;
      const keys = [];
      if (eventID) keys.push(`event:${eventID}`);
      if (requestID) keys.push(`${type}:${sessionID}:${requestID}`);
      else if (executionID) keys.push(`${type}:${sessionID}:${executionID}`);
      else if (sessionID && ['idle', 'error'].includes(type)) keys.push(`${type}:${sessionID}`);
      if (!keys.length) {
        if (source && anonymous.has(source)) return false;
        if (source) anonymous.add(source);
        return true;
      }
      if (keys.some(key => recent.has(key))) return false;
      for (const key of keys) recent.set(key, time + ttl);
      while (recent.size > maxEntries) recent.delete(recent.keys().next().value);
      return true;
    },
    clear() { recent.clear(); anonymous = new WeakSet(); }
  };
}
