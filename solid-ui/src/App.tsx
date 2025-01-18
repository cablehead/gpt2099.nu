import {
  Component,
  createEffect,
  createMemo,
  createSignal,
  For,
  Show,
} from "solid-js";

import { createShortcut } from "@solid-primitives/keyboard";

import { Fingerprint } from "lucide-solid";
import { formatRelative } from "date-fns";
import { Scru128Id } from "scru128";
import CopyTrigger from "./components/CopyTrigger";

import { useFrameStream } from "./store/stream";
import { useStore } from "./store";
import { createCAS } from "./store/cas";

type Nav = {
  heads: () => string[];
  selected_head: () => string | null;
  setSelectedHead: (head: string | null) => void;

  thread: () => ReturnType<typeof getThread>;

  selected_index: () => number;
  setSelectedIndex: (index: number) => void;

  selected_id: () => string | null;

  nextMessage: () => void;
  prevMessage: () => void;
  reset: () => void;
};

const getThread = (headId: string, frames: Record<string, Frame>) => {
  const thread = [];
  let currentId = headId;
  while (currentId) {
    const frame = frames[currentId];
    if (!frame) break;
    thread.push(frame);
    currentId = frame.meta?.continues;
  }
  return thread;
};

const createNav = (heads: () => string[], frames: Record<string, Frame>) => {
  const [selectedHead, setSelectedHead] = createSignal<string | null>(null);
  const [selectedIndex, setSelectedIndex] = createSignal(0);

  const currentHead = createMemo(() =>
    selectedHead() ?? (heads().length > 0 ? heads()[0] : null)
  );

  const thread = createMemo(() =>
    currentHead() ? getThread(currentHead()!, frames) : []
  );

  const selected_id = createMemo(() => {
    const currentThread = thread();
    return currentThread[selectedIndex()]
      ? currentThread[selectedIndex()].id
      : null;
  });

  createEffect(() => {
    setSelectedIndex(0);
    currentHead(); // dependency tracking
  });

  return {
    heads,
    selected_head: currentHead,
    setSelectedHead,

    thread,

    selected_index: selectedIndex,
    setSelectedIndex,

    selected_id,

    nextMessage: () => {
      console.log("nextMessage", selectedIndex(), thread().length - 1);
      if (selectedIndex() < thread().length - 1) {
        setSelectedIndex(selectedIndex() + 1);
      }
    },

    prevMessage: () => {
      console.log("prevMessage", selectedIndex());
      if (selectedIndex() > 0) {
        setSelectedIndex(selectedIndex() - 1);
      }
    },

    reset: () => {
      if (heads().length > 0) {
        setSelectedHead(heads()[0]);
      }
      setSelectedIndex(0);
    },
  } as const;
};

const App: Component = () => {
  const frameSignal = useFrameStream();
  const fetchContent = async (hash: string) => {
    const response = await fetch(`/api/cas/${hash}`);
    if (!response.ok) {
      throw new Error(`Failed to fetch content for hash ${hash}`);
    }
    return await response.text();
  };

  const { frames, heads, isInitialized } = useStore({
    dataSignal: frameSignal,
  });
  const cas = createCAS(fetchContent);

  const nav = createNav(heads, frames);

  createShortcut(["n"], nav.nextMessage);
  createShortcut(["p"], nav.prevMessage);
  createShortcut(["0"], nav.reset);

  return (
    <Show when={isInitialized()} fallback={<pre>Loading...</pre>}>
      <div style="display: flex; height: 100vh; overflow: hidden;">
        <div style="flex: 0 0 25ch; border-right: 1px solid var(--color-sub-bg); overflow-y: auto;">
          <For each={nav.heads()}>
            {(headId) => (
              <div
                class={`nav-item ${
                  nav.selected_head() === headId ? "selected" : ""
                }`}
                style={{
                  padding: "0.5em 1em",
                  cursor: "pointer",
                }}
                onClick={() => nav.setSelectedHead(headId)}
              >
                <Show
                  when={cas.get(frames[headId].hash)()}
                  fallback={<p>Loading...</p>}
                >
                  {(text) => (
                    <div>
                      {text().replace(/\n/g, " ").slice(0, 25) +
                        (text().length > 20 ? ".." : "")}
                    </div>
                  )}
                </Show>
              </div>
            )}
          </For>
        </div>

        <div style="flex: 0 0 25ch; border-right: 1px solid var(--color-sub-bg); overflow-y: auto;">
          <For each={nav.thread()}>
            {(frame) => (
              <div
                class={`nav-item ${
                  nav.selected_id() === frame.id ? "selected" : ""
                }`}
                style={{
                  padding: "0.5em 1em",
                  cursor: "pointer",
                }}
                onClick={() =>
                  nav.setSelectedIndex(
                    nav.thread().findIndex((f) => f.id === frame.id),
                  )}
              >
                <Show
                  when={cas.get(frame.hash)()}
                  fallback={<p>Loading...</p>}
                >
                  {(text) => (
                    <div>
                      {text().replace(/\n/g, " ").slice(0, 25) +
                        (text().length > 20 ? ".." : "")}
                    </div>
                  )}
                </Show>
              </div>
            )}
          </For>
        </div>

        <div style="flex: 1; padding: 1em; overflow-x: auto;">
          <Show when={nav.selected_head()}>
            <div style="display: flex; flex-direction: row; gap: 0.5em;">
              <For each={nav.thread()}>
                {(frame) => {
                  let ref: HTMLDivElement | undefined;
                  createEffect(() => {
                    if (nav.selected_id() === frame.id && ref) {
                      ref.scrollIntoView({
                        behavior: "smooth",
                        block: "nearest",
                        inline: "nearest", // Added for horizontal scrolling
                      });
                    }
                  });

                  return (
                    <div
                      ref={ref}
                      onClick={() =>
                        nav.setSelectedIndex(
                          nav.thread().findIndex((f) => f.id === frame.id),
                        )}
                      style="
              flex-shrink: 0;
              width: 20em;
              height: 10em;
              overflow: hidden;
              margin: 0 0.25em;
              border-radius: 0.25em;
              box-shadow: 0 0 0.25em var(--color-shadow);
              background-color: var(--color-bg-alt);
            "
                    >
                      <div
                        class="panel"
                        style="display: flex; flex-direction: column; gap: 0.25em; padding: 0.5em 1em;"
                      >
                        <div style="display: flex; justify-content: space-between; align-items: center; gap: 1em;">
                          <span>{frame.meta.role}</span>
                          <div style="display:flex; gap: 0.2em;">
                            <Fingerprint
                              class="icon-button"
                              size={18}
                              onClick={(e) => {
                                e.preventDefault();
                                navigator.clipboard.writeText(frame.id);
                              }}
                            />
                            <Show when={cas.get(frame.hash)()} keyed>
                              {(content) => (
                                <span>
                                  <CopyTrigger content={content} />
                                </span>
                              )}
                            </Show>
                          </div>
                        </div>
                        <div style="display: flex; justify-content: flex-start; align-items: center; gap: 1em;">
                          <span>
                            {formatRelative(
                              new Date(
                                Scru128Id.fromString(frame.id).timestamp,
                              ),
                              new Date(),
                            )}
                          </span>
                        </div>
                      </div>
                      <div
                        style={{
                          padding: "0.5em 1em",
                          cursor: "pointer",
                          "background-color": nav.selected_id() === frame.id
                            ? "var(--color-pill)"
                            : "transparent",
                          "border-radius": "0.25em",
                        }}
                      >
                        <pre style="white-space: pre-wrap;">{cas.get(frame.hash)()}</pre>
                      </div>
                    </div>
                  );
                }}
              </For>
            </div>
          </Show>
        </div>
      </div>
    </Show>
  );
};

export default App;
