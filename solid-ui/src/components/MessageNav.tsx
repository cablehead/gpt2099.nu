import { Component, createEffect } from "solid-js";
import { Frame } from "../store/stream";
import { CASStore } from "../store/cas";

type MessageNavProps = {
  frame: Frame;
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
      <div
        class="panel"
        style="display: flex; flex-direction: column; gap: 0.25em; padding: 0.5em 1em;"
      >
        <div style="display: flex; justify-content: space-between; align-items: center; gap: 1em;">
          <span>{props.frame.meta?.role ?? "user"}</span>
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
        <pre style="white-space: pre-wrap;">{props.cas.get(props.frame.hash)()}</pre>
      </div>
    </div>
  );
};

export default MessageNav;
