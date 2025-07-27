import { createEffect, createSignal } from "solid-js";

import { createPrefersDark } from "@solid-primitives/media";

import githubTheme from "highlight.js/styles/github.css?raw";
import nordTheme from "highlight.js/styles/nord.css?raw";

const systemPrefersDark = createPrefersDark();

const [prefersDark, setPrefersDark] = createSignal(systemPrefersDark());
const toggleTheme = () => setPrefersDark(!prefersDark());

createEffect(() => {
  setPrefersDark(systemPrefersDark());
});

export { prefersDark, toggleTheme };

const applyTheme = (css: string) => {
  let styleTag = document.getElementById("dynamic-theme-style");
  if (!styleTag) {
    styleTag = document.createElement("style");
    styleTag.id = "dynamic-theme-style";
    document.head.appendChild(styleTag);
  }
  styleTag.innerHTML = css;
};

createEffect(() => {
  document.body.dataset.theme = prefersDark() ? "dark" : "light";
  applyTheme(prefersDark() ? nordTheme : githubTheme);
});
