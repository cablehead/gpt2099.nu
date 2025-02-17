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

  const getThread = (headId: string) => {
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

  const [selectedHead, setSelectedHead] = createSignal<string | null>(null);
  const currentHead = createMemo(() =>
    selectedHead() ?? (heads().length > 0 ? heads()[0] : null)
  );

  const [selectedThreadItem, setSelectedThreadItem] = createSignal<
    string | null
  >(null);
  const currentThreadItem = createMemo(() => {
    const thread = currentHead() ? getThread(currentHead()!) : [];
    return selectedThreadItem() ?? (thread.length > 0 ? thread[0].id : null);
  });

  createEffect(() => {
    // Reset selectedThreadItem whenever selectedHead changes
    setSelectedThreadItem(null);
    selectedHead(); // dependency tracking
  });

  createShortcut(["Control", "n"], () => {
    const thread = currentHead() ? getThread(currentHead()!) : [];
    const currentIndex = thread.findIndex((f) => f.id === currentThreadItem());
    if (currentIndex < thread.length - 1) {
      setSelectedThreadItem(thread[currentIndex + 1].id);
    }
  });

  createShortcut(["Control", "p"], () => {
    const thread = currentHead() ? getThread(currentHead()!) : [];
    const currentIndex = thread.findIndex((f) => f.id === currentThreadItem());
    if (currentIndex > 0) {
      setSelectedThreadItem(thread[currentIndex - 1].id);
    }
  });

  return (
    <div style="display: flex; height: 100vh; overflow: hidden;">
      <div style="flex: 0 0 25ch; border-right: 1px solid var(--color-sub-bg); overflow-y: auto;">
        <For each={heads()}>
          {(headId) => (
            <div
              style={{
                padding: "0.5em 1em",
                cursor: "pointer",
                "background-color": currentHead() === headId
                  ? "var(--color-sub-bg)"
                  : "transparent",
              }}
              onClick={() => setSelectedHead(headId)}
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
        <Show when={currentHead()}>
          <For each={getThread(currentHead()!)}>
            {(frame) => (
              <div
                style={{
                  padding: "0.5em 1em",
                  cursor: "pointer",
                  "background-color": currentThreadItem() === frame.id
                    ? "var(--color-sub-bg)"
                    : "transparent",
                }}
                onClick={() => setSelectedThreadItem(frame.id)}
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
        </Show>
      </div>

      <div style="flex: 1; padding: 1em; overflow-y: auto; overflow-x: hidden;">
        <Show when={currentHead()}>
          <For each={getThread(currentHead()!)}>
            {(frame) => {
              let ref: HTMLDivElement | undefined;
              createEffect(() => {
                if (currentThreadItem() === frame.id && ref) {
                  ref.scrollIntoView({ behavior: "smooth", block: "nearest" });
                }
              });

              return (
                <div
                  ref={ref}
                  onClick={() => setSelectedThreadItem(frame.id)}
                >
                  <div style="overflow-x: hidden; margin: 0 0.5em; border-radius: 0.25em; border: 1px solid var(--color-sub-bg); margin-bottom: 0.5em;">
                    <div style="display: flex; justify-content: space-between; font-size: 0.75rem; background-color: var(--color-accent); padding: 0.5em;">
                      <div>
                        {frame.meta.role}
                      </div>
                      <div>
                        {frame.id}
                      </div>
                    </div>

                    <div
                      style={{
                        padding: "0.5em",
                        cursor: "pointer",
                        "background-color": currentThreadItem() === frame.id
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
