import { createEffect, createMemo } from "solid-js";
import { createStore } from "solid-js/store";
import { Frame } from "./stream";

type Store = {
  frames: { [id: string]: Frame };
  heads: string[];
};

type StreamProps = {
  dataSignal: () => Frame | null;
};

export function useStore({ dataSignal }: StreamProps) {
  const [store, setStore] = createStore<Store>({
    frames: {},
    heads: [],
  });

  createEffect(() => {
    const frame = dataSignal();
    if (!frame) return;

    if (frame.topic !== "message") return;

    setStore("frames", (frames) => ({ ...frames, [frame.id]: frame }));

    const continues = frame.meta?.continues;
    if (continues) {
      setStore("heads", (heads) => {
        const newHeads = heads.filter((id) => id !== continues);
        return [...newHeads, frame.id];
      });
    } else {
      setStore("heads", (heads) => [...heads, frame.id]);
    }
  });

  const heads = createMemo(() => [...store.heads].sort().reverse());
  const { frames } = store;

  return { frames, heads };
}
