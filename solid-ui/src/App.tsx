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

import MessageNav from "./components/MessageNav";

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
  return thread.reverse();
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
        <div style="flex: 1; padding: 1em; overflow-x: auto;">
          <Show when={nav.selected_head()}>
            <div style="display: flex; flex-direction: column; gap: 1em;">
              <For each={heads()}>
                {(headId, rowIndex) => {
                  const prevThread = rowIndex() > 0
                    ? getThread(heads()[rowIndex() - 1], frames)
                    : undefined;
                  const currentThread = getThread(headId, frames);

                  return (
                    <div style="display: flex; flex-direction: row; gap: 0.5em;">
                      <For each={currentThread}>
                        {(frame, colIndex) => {
                          const matchesAbove =
                            prevThread?.[colIndex()]?.id === frame.id;

                          if (frame.id == "03d7j4vt5c7in9ki52fbefby6") {
                            console.log({
                              rowIndex: rowIndex(),
                              colIndex: colIndex(),
                              frameId: frame.id,
                              prevFrameId: prevThread?.[colIndex()]?.id,
                              matchesAbove,
                            });
                          }

                          const shouldShow = !matchesAbove;

                          return (
                            <div
                              style={`flex-shrink: 0; width: 20em; height: ${
                                shouldShow ? "10em" : "0"
                              }; margin: 0 0.25em;`}
                            >
                              {shouldShow && (
                                <MessageNav
                                  frame={frame}
                                  isSelected={nav.selected_id() === frame.id}
                                  cas={cas}
                                  onSelect={() => {
                                    nav.setSelectedHead(headId);
                                    nav.setSelectedIndex(colIndex());
                                  }}
                                />
                              )}
                            </div>
                          );
                        }}
                      </For>
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
