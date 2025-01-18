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

type MessageSegment = {
  promptMessages: Frame[];
  responseMessage: Frame;
};

type Nav = {
  heads: () => string[];
  selected_head: () => string | null;
  setSelectedHead: (head: string | null) => void;
  thread: () => MessageSegment[];
  selected_index: () => number;
  setSelectedIndex: (index: number) => void;
  selected_id: () => string | null;
  nextMessage: () => void;
  prevMessage: () => void;
  reset: () => void;
};

const getThread = (
  headId: string,
  frames: Record<string, Frame>,
): MessageSegment[] => {
  const messages = [];
  let currentId = headId;

  while (currentId) {
    const frame = frames[currentId];
    if (!frame) break;
    messages.push(frame);
    currentId = frame.meta?.continues;
  }
  messages.reverse();

  const segments: MessageSegment[] = [];
  let currentPrompt: Frame[] = [];

  for (const message of messages) {
    if (message.meta.role === "assistant") {
      segments.push({
        promptMessages: [...currentPrompt],
        responseMessage: message,
      });
      currentPrompt = [];
    } else {
      currentPrompt.push(message);
    }
  }

  return segments;
};

const createNav = (
  heads: () => string[],
  frames: Record<string, Frame>,
): Nav => {
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
      ? currentThread[selectedIndex()].responseMessage.id
      : null;
  });

  createEffect(() => {
    setSelectedIndex(0);
    currentHead();
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
      if (selectedIndex() < thread().length - 1) {
        setSelectedIndex(selectedIndex() + 1);
      }
    },
    prevMessage: () => {
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
                        {(segment, colIndex) => {
                          const matchesAbove =
                            prevThread?.[colIndex()]?.responseMessage.id ===
                              segment.responseMessage.id;

                          const shouldShow = !matchesAbove;

                          return (
                            <div
                              style={`flex-shrink: 0; width: 20em; height: ${
                                shouldShow ? "10em" : "0"
                              }; margin: 0 0.25em;`}
                            >
                              {shouldShow && (
                                <MessageNav
                                  segment={segment}
                                  isSelected={nav.selected_id() ===
                                    segment.responseMessage.id}
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
