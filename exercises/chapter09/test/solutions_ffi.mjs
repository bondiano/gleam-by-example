// ============================================================
// FFI implementations for reference solutions
// ============================================================

// Упражнение 1: current_timestamp
export function getCurrentTimestamp() {
  return Date.now();
}

// Упражнение 2: local_storage
export function storageGet(key) {
  const value = localStorage.getItem(key);
  if (value === null) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: value };
}

export function storageSet(key, value) {
  try {
    localStorage.setItem(key, value);
    return { type: "Ok", 0: undefined };
  } catch (e) {
    return { type: "Error", 0: e.message };
  }
}

export function storageRemove(key) {
  localStorage.removeItem(key);
}

// Упражнение 3: console_log_levels
export function consoleLog(message) {
  console.log(message);
}

export function consoleWarn(message) {
  console.warn(message);
}

export function consoleError(message) {
  console.error(message);
}

// Упражнение 4: timeout
export function setTimeoutWrapper(callback, delay) {
  return globalThis.setTimeout(callback, delay);
}

export function clearTimeoutWrapper(id) {
  globalThis.clearTimeout(id);
}

// Упражнение 5: fetch_json
export function fetchJson(url) {
  return globalThis.fetch(url)
    .then(response => {
      if (!response.ok) {
        return { type: "Error", 0: `HTTP ${response.status}: ${response.statusText}` };
      }
      return response.text();
    })
    .then(text => {
      // If text is already a Result (from error branch), return as is
      if (typeof text === 'object' && text.type === 'Error') {
        return text;
      }
      // Otherwise wrap in Ok
      return { type: "Ok", 0: text };
    })
    .catch(error => ({ type: "Error", 0: error.message }));
}

// Упражнение 6: query_selector
export function querySelectorWrapper(selector) {
  const element = document.querySelector(selector);
  if (element === null) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: element };
}

export function querySelectorAllWrapper(selector) {
  const nodeList = document.querySelectorAll(selector);
  return Array.from(nodeList);
}

// Упражнение 7: json_parse_safe
export function jsonParseSafe(jsonStr) {
  try {
    const parsed = JSON.parse(jsonStr);
    return { type: "Ok", 0: parsed };
  } catch (e) {
    return { type: "Error", 0: e.message };
  }
}

// Упражнение 8: event_target_value
export function eventTargetValue(event) {
  const value = event?.target?.value;
  if (value === undefined || value === null) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: String(value) };
}
