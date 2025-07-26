import { Component, For } from "solid-js";
import { A } from "@solidjs/router";

import { CASStore } from "../store/cas";
import { Thread, Turn, ContentBlock } from "../store/stream";
import Card from "../Card";

const Home: Component<{ 
  thread: Thread; 
  CAS: CASStore;
  parseContent: (turn: Turn) => ContentBlock[];
}> = (props) => {
  return (
    <>
      <p>
        <A href="/">home</A> - Thread: {props.thread.head_id}
      </p>
      <div style="margin-bottom: 1em; padding: 0.5em; background: var(--color-bg-alt); border-radius: 0.25em;">
        <strong>Options:</strong> {JSON.stringify(props.thread.options)}
      </div>
      <For each={props.thread.turns}>
        {(turn) => <Card turn={turn} CAS={props.CAS} parseContent={props.parseContent} />}
      </For>
    </>
  );
};

export default Home;
