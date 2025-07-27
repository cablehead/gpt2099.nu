import { Marked } from "marked";
import { markedHighlight } from "marked-highlight";
import hljs from "highlight.js";

// Set up `marked` with `marked-highlight`
export const marked = new Marked(
  markedHighlight({
    emptyLangClass: "hljs language-plaintext",
    langPrefix: "hljs language-",
    highlight(code, lang) {
      const language = hljs.getLanguage(lang) ? lang : "plaintext";
      const res = hljs.highlight(code, { language }).value;
      return res;
    },
  })
);
