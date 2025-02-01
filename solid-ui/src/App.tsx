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
import MessageCard from "./components/MessageCard";
import MessageNav from "./components/MessageNav";

type Nav = {
  heads: () => string[];
  selected_head: () => string | null;
  setSelectedHead: (head: string | null) => void;
  thread: () => Frame[];
  reversedThread: () => Frame[];
  selected_index: () => number;
  setSelectedIndex: (index: number) => void;
  selected_id: () => string | null;
  nextMessage: () => void;
  prevMessage: () => void;
  nextRow: () => void;
  prevRow: () => void;
  reset: () => void;
};

const getThread = (
  headId: string,
  frames: Record<string, Frame>,
): Frame[] => {
  const messages = [];
  let currentId = headId;

  while (currentId) {
    const frame = frames[currentId];
    if (!frame) break;
    messages.push(frame);
    currentId = frame.meta?.continues;
  }

  return messages.reverse();
};

const createNav = (
  heads: () => string[],
  frames: Record<string, Frame>,
): Nav => {
  const [selectedHead, setSelectedHead] = createSignal<string | null>(null);
  const [selectedIndex, setSelectedIndex] = createSignal<number | null>(null);

  const currentHead = createMemo(() =>
    selectedHead() ?? (heads().length > 0 ? heads()[0] : null)
  );

  const thread = createMemo(() =>
    currentHead() ? getThread(currentHead()!, frames) : []
  );

  const reversedThread = createMemo(() => [...thread()].reverse());

  const currentIndex = createMemo(() => {
    const currentThread = thread();
    return selectedIndex() ??
      (currentThread.length > 0 ? currentThread.length - 1 : 0);
  });

  const selected_id = createMemo(() => {
    const currentThread = thread();
    return currentThread[currentIndex()]
      ? currentThread[currentIndex()].id
      : null;
  });

  createEffect(() => {
    setSelectedIndex(null); // Reset to default behavior
    currentHead();
  });

  return {
    heads,
    selected_head: currentHead,
    setSelectedHead,
    thread,
    reversedThread,
    selected_index: currentIndex,
    setSelectedIndex,
    selected_id,
    nextMessage: () => {
      if (currentIndex() < thread().length - 1) {
        setSelectedIndex(currentIndex() + 1);
      }
    },
    prevMessage: () => {
      if (currentIndex() > 0) {
        setSelectedIndex(currentIndex() - 1);
      }
    },
    nextRow: () => {
      if (
        currentHead() && heads().indexOf(currentHead()!) < heads().length - 1
      ) {
        setSelectedHead(heads()[heads().indexOf(currentHead()!) + 1]);
      }
    },
    prevRow: () => {
      if (currentHead() && heads().indexOf(currentHead()!) > 0) {
        setSelectedHead(heads()[heads().indexOf(currentHead()!) - 1]);
      }
    },
    reset: () => {
      if (heads().length > 0) {
        setSelectedHead(heads()[0]);
      }
      setSelectedIndex(null); // Reset to default (last message)
    },
  };
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

  createShortcut(["l"], nav.nextMessage);
  createShortcut(["h"], nav.prevMessage);
  createShortcut(["j"], nav.nextRow);
  createShortcut(["k"], nav.prevRow);
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
                        {(message, colIndex) => {
                          const matchesAbove =
                            prevThread?.[colIndex()]?.id === message.id;

                          const shouldShow = !matchesAbove;

                          return (
                            <div
                              style={`flex-shrink: 0; width: 20em; height: ${
                                shouldShow ? "10em" : "0"
                              }; margin: 0 0.25em;`}
                            >
                              {shouldShow && (
                                <MessageNav
                                  frame={message}
                                  isSelected={nav.selected_id() === message.id}
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

        <div style="flex: 1; max-width: min(750px, 50%); overflow: hidden">
          <div style="height: 100%; padding: 1em; overflow-y: auto">
            <div style="display: flex; flex-direction: column; gap: 1em;">
              <Show when={nav.selected_id()}>
                <For each={nav.reversedThread()}>
                  {(message) => (
                    <Show when={message}>
                      <MessageCard
                        frame={message}
                        isSelected={nav.selected_id() === message.id}
                        cas={cas}
                        onSelect={() => {
                          nav.setSelectedIndex(
                            nav.thread().findIndex((m) => m.id === message.id),
                          );
                        }}
                      />
                    </Show>
                  )}
                </For>
              </Show>
            </div>
          </div>
        </div>
      </div>
    </Show>
  );
};

export default App;
