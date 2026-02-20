// Mock setup function that can be called from Gleam
export function setupMocks() {
  // Mocks are set up immediately when this module loads
}

// Mock localStorage for Node.js tests
if (typeof globalThis.localStorage === 'undefined') {
  class LocalStorageMock {
    constructor() {
      this.store = {};
    }

    getItem(key) {
      return this.store[key] || null;
    }

    setItem(key, value) {
      this.store[key] = String(value);
    }

    removeItem(key) {
      delete this.store[key];
    }

    clear() {
      this.store = {};
    }
  }

  globalThis.localStorage = new LocalStorageMock();
}

// Mock document for Node.js tests
if (typeof globalThis.document === 'undefined') {
  globalThis.document = {
    querySelector: function(selector) {
      // Return null for test purposes
      return null;
    },
    querySelectorAll: function(selector) {
      // Return empty NodeList-like array
      return [];
    }
  };
}

// Mock fetch if not available
if (typeof globalThis.fetch === 'undefined') {
  globalThis.fetch = function(url) {
    return Promise.reject(new Error('fetch is not available in test environment'));
  };
}
