import {
  Component,
  createEffect,
  createMemo,
  createSignal,
  For,
  Show,
} from "solid-js";

import { createShortcut } from "@solid-primitives/keyboard";

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

  const { frames, heads } = useStore({ dataSignal: frameSignal });
  const cas = createCAS(fetchContent);

  const nav = createNav(heads, frames);

  createShortcut(["n"], nav.nextMessage);
  createShortcut(["p"], nav.prevMessage);
  createShortcut(["0"], nav.reset);


  return (
    <div style="display: flex; height: 100vh; overflow: hidden;">
      <div style="flex: 0 0 25ch; border-right: 1px solid var(--color-sub-bg); overflow-y: auto;">
        <For each={nav.heads()}>
          {(headId) => (
            <div
              style={{
                padding: "0.5em 1em",
                cursor: "pointer",
                "background-color": nav.selected_head() === headId
                  ? "var(--color-sub-bg)"
                  : "transparent",
              }}
              onClick={() => nav.setSelectedHead(headId)}
            >
              <Show
                when={cas.get(frames[headId].hash)()}
                fallback={<pre>Loading...</pre>}
              >
                {(text) => (
                  <pre>
                    {text().replace(/\n/g, ' ').slice(0, 25) + (text().length > 20 ? ".." : "")}
                  </pre>
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
              style={{
                padding: "0.5em 1em",
                cursor: "pointer",
                "background-color": nav.selected_id() === frame.id
                  ? "var(--color-sub-bg)"
                  : "transparent",
              }}
              onClick={() =>
                nav.setSelectedIndex(
                  nav.thread().findIndex((f) => f.id === frame.id),
                )}
            >
              <Show
                when={cas.get(frame.hash)()}
                fallback={<pre>Loading...</pre>}
              >
                {(text) => (
                  <pre>
                    {text().replace(/\n/g, ' ').slice(0, 25) + (text().length > 20 ? ".." : "")}
                  </pre>
                )}
              </Show>
            </div>
          )}
        </For>
      </div>

      <div style="flex: 1; padding: 1em; overflow-y: auto; overflow-x: hidden;">
        <Show when={nav.selected_head()}>
          <For each={nav.thread()}>
            {(frame) => {
              let ref: HTMLDivElement | undefined;
              createEffect(() => {
                if (nav.selected_id() === frame.id && ref) {
                  ref.scrollIntoView({ behavior: "smooth", block: "nearest" });
                }
              });

              return (
                <div
                  ref={ref}
                  onClick={() =>
                    nav.setSelectedIndex(
                      nav.thread().findIndex((f) => f.id === frame.id),
                    )}
                >
                  <div style="overflow-x: hidden; margin: 0 0.5em; border-radius: 0.25em; border: 1px solid var(--color-sub-bg); margin-bottom: 0.5em;">
                    <div style="display: flex; justify-content: space-between; font-size: 0.75rem; background-color: var(--color-accent); padding: 0.5em;">
                      <div>{frame.meta.role}</div>
                      <div>{frame.id}</div>
                    </div>

                    <div
                      style={{
                        padding: "0.5em",
                        cursor: "pointer",
                        "background-color": nav.selected_id() === frame.id
                          ? "var(--color-sub-bg)"
                          : "transparent",
                      }}
                    >
                      <pre>{cas.get(frame.hash)()}</pre>
                    </div>
                  </div>
                </div>
              );
            }}
          </For>
        </Show>
      </div>
    </div>
  );
};

export default App;
