// ============================================================
// JavaScript FFI implementations for chapter09
// ============================================================

/**
 * Returns current time in milliseconds
 */
export function getCurrentTime() {
  return Date.now();
}

/**
 * System time in milliseconds (for dual FFI)
 */
export function systemTimeMillis() {
  return Date.now();
}

/**
 * Console logging
 */
export function consoleLog(message) {
  console.log(message);
}

/**
 * localStorage.getItem wrapper
 * Returns Result(String, Nil)
 */
export function localStorageGet(key) {
  const value = localStorage.getItem(key);
  if (value === null) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: value };
}

/**
 * localStorage.setItem wrapper
 * Returns Result(Nil, String)
 */
export function localStorageSet(key, value) {
  try {
    localStorage.setItem(key, value);
    return { type: "Ok", 0: undefined };
  } catch (e) {
    return { type: "Error", 0: e.message };
  }
}

/**
 * setTimeout wrapper
 */
export function setTimeout(callback, delay) {
  return globalThis.setTimeout(callback, delay);
}

/**
 * clearTimeout wrapper
 */
export function clearTimeout(id) {
  globalThis.clearTimeout(id);
}

/**
 * fetch API wrapper returning Promise(Result(String, String))
 */
export function fetchText(url) {
  return globalThis.fetch(url)
    .then(response => {
      if (!response.ok) {
        return { type: "Error", 0: `HTTP ${response.status}: ${response.statusText}` };
      }
      return response.text();
    })
    .then(text => {
      if (typeof text === 'string') {
        return { type: "Ok", 0: text };
      }
      return text; // Already a Result from error case
    })
    .catch(error => ({ type: "Error", 0: error.message }));
}

/**
 * document.querySelector wrapper
 * Returns Result(Element, Nil)
 */
export function querySelector(selector) {
  const element = document.querySelector(selector);
  if (element === null) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: element };
}

/**
 * document.querySelectorAll wrapper
 * Returns List(Element)
 */
export function querySelectorAll(selector) {
  const nodeList = document.querySelectorAll(selector);
  return Array.from(nodeList);
}

/**
 * Set innerText of an element
 */
export function setInnerText(element, text) {
  element.innerText = text;
}

/**
 * Get innerText of an element
 */
export function getInnerText(element) {
  return element.innerText;
}

/**
 * addEventListener wrapper
 */
export function addEventListener(element, event, handler) {
  element.addEventListener(event, handler);
}

/**
 * Extract value from event.target
 * Returns Result(String, Nil)
 */
export function eventTargetValue(event) {
  const value = event?.target?.value;
  if (value === undefined || value === null) {
    return { type: "Error", 0: undefined };
  }
  return { type: "Ok", 0: String(value) };
}

/**
 * Safe JSON.parse with error handling
 * Returns Result(Dynamic, String)
 */
export function jsonParseSafe(jsonStr) {
  try {
    const parsed = JSON.parse(jsonStr);
    return { type: "Ok", 0: parsed };
  } catch (e) {
    return { type: "Error", 0: e.message };
  }
}
