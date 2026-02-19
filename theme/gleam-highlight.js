/**
 * Gleam language definition for highlight.js
 * Registers the "gleam" language and re-highlights code blocks on page load.
 */
(function () {
  function gleamLanguage(hljs) {
    const KEYWORDS = {
      keyword:
        "pub fn let case import type if else use as opaque const todo panic echo assert",
      literal: "True False Nil",
    };

    const COMMENT = hljs.COMMENT("//", "$");

    const STRING = {
      className: "string",
      begin: '"',
      end: '"',
      contains: [
        { begin: "\\\\[\\s\\S]", relevance: 0 }, // escape sequences
      ],
    };

    const NUMBER = {
      className: "number",
      relevance: 0,
      variants: [
        { begin: "\\b0x[0-9a-fA-F][0-9a-fA-F_]*" },
        { begin: "\\b0o[0-7][0-7_]*" },
        { begin: "\\b0b[01][01_]*" },
        { begin: "\\b[0-9][0-9_]*(\\.[0-9][0-9_]*)?" },
      ],
    };

    // Capitalized names are types or constructors
    const TYPE = {
      className: "type",
      begin: "\\b[A-Z][a-zA-Z0-9_]*",
      relevance: 0,
    };

    // Lowercase identifiers followed by ( are function calls/definitions
    const FUNCTION_CALL = {
      className: "title function",
      begin: "\\b[a-z_][a-z0-9_]*(?=\\s*\\()",
      relevance: 0,
    };

    // Operators: ->, |>, .., <>, ==, !=, <=, >=, &&, ||, <-, =
    const OPERATOR = {
      className: "operator",
      begin: "->|\\|>|\\.\\.|\\.\\.|<>|==|!=|<=|>=|&&|\\|\\||<-|=",
      relevance: 0,
    };

    return {
      name: "Gleam",
      keywords: KEYWORDS,
      contains: [
        COMMENT,
        STRING,
        NUMBER,
        TYPE,
        OPERATOR,
        FUNCTION_CALL,
      ],
    };
  }

  // Register the language IMMEDIATELY (synchronously)
  if (typeof hljs !== "undefined") {
    hljs.registerLanguage("gleam", gleamLanguage);
  }

  // Re-highlight function
  function rehighlightGleam() {
    if (typeof hljs === "undefined") return;

    // Ensure language is registered
    if (!hljs.getLanguage("gleam")) {
      hljs.registerLanguage("gleam", gleamLanguage);
    }

    // Re-highlight all gleam code blocks
    document
      .querySelectorAll("pre code.language-gleam")
      .forEach(function (block) {
        // Clear previous classes
        block.className = "language-gleam hljs";

        // Use the correct API based on version
        if (typeof hljs.highlightElement === "function") {
          // v11+
          delete block.dataset.highlighted;
          block.removeAttribute("data-highlighted");
          hljs.highlightElement(block);
        } else if (typeof hljs.highlightBlock === "function") {
          // v9-10
          hljs.highlightBlock(block);
        } else if (typeof hljs.highlightAuto === "function") {
          // Fallback: auto-detect and highlight
          const result = hljs.highlight("gleam", block.textContent);
          block.innerHTML = result.value;
          block.className = "language-gleam hljs";
        }
      });
  }

  // Use multiple strategies to ensure highlighting works:

  // Strategy 1: DOMContentLoaded
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function() {
      setTimeout(rehighlightGleam, 0);
    });
  }

  // Strategy 2: window.load (in case DOMContentLoaded already fired)
  window.addEventListener("load", function() {
    setTimeout(rehighlightGleam, 50);
  });

  // Strategy 3: Immediate execution with delay (if DOM already loaded)
  if (document.readyState === "interactive" || document.readyState === "complete") {
    setTimeout(rehighlightGleam, 100);
  }
})();
