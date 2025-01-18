import { Component, createEffect } from "solid-js";

import { Frame } from "../store/stream";
import { CASStore } from "../store/cas";

type MessageNavProps = {
  segment: {
    promptMessages: Frame[];
    responseMessage: Frame;
  };
  isSelected: boolean;
  cas: CASStore;
  onSelect?: () => void;
};

const MessageNav: Component<MessageNavProps> = (props) => {
  let ref: HTMLDivElement | undefined;

  createEffect(() => {
    if (props.isSelected && ref) {
      ref.scrollIntoView({
        behavior: "smooth",
        block: "nearest",
        inline: "nearest",
      });
    }
  });

  return (
    <div
      ref={ref}
      style={{
        "flex-shrink": "0",
        width: "20em",
        height: "10em",
        overflow: "hidden",
        margin: "0 0.25em",
        "border-radius": "0.25em",
        "box-shadow": "0 0 0.25em var(--color-shadow)",
        "background-color": "var(--color-bg-alt)",
        opacity: props.isSelected ? "1" : "0.7",
      }}
      onClick={props.onSelect}
    >
      <div>
        <div
          class="panel"
          style="padding: 0.5em 1em; height: 2em; overflow: hidden;"
        >
          <div>
            {props.cas.get(props.segment.promptMessages.at(-1).hash)()}
          </div>
        </div>
        <div
          style={{
            padding: "0.5em 1em",
            cursor: "pointer",
            backgroundColor: props.isSelected
              ? "var(--color-pill)"
              : "transparent",
            borderRadius: "0.25em",
          }}
        >
          <div>
            {props.cas.get(props.segment.responseMessage.hash)()}
          </div>
        </div>
      </div>
    </div>
  );
};

export default MessageNav;
