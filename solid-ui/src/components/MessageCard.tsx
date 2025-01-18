import { Component, createEffect } from "solid-js";
import { Frame } from "../store/stream";
import { Fingerprint } from "lucide-solid";
import { formatRelative } from "date-fns";
import { Scru128Id } from "scru128";
import CopyTrigger from "./CopyTrigger";
import { CASStore } from "../store/cas";
import { Show } from "solid-js";

type MessageCardProps = {
  frame: Frame;
  isSelected: boolean;
  cas: CASStore;
  onSelect?: () => void;
};

const MessageCard: Component<MessageCardProps> = (props) => {
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
          <span>{props.frame.meta.role}</span>
          <Show when={props.isSelected}>
            <div style="display:flex; gap: 0.2em;">
              <Fingerprint
                class="icon-button"
                size={18}
                onClick={(e) => {
                  e.preventDefault();
                  navigator.clipboard.writeText(props.frame.id);
                }}
              />
              <Show when={props.cas.get(props.frame.hash)()} keyed>
                {(content) => (
                  <span>
                    <CopyTrigger content={content} />
                  </span>
                )}
              </Show>
            </div>
          </Show>
        </div>
        <div style="display: flex; justify-content: flex-start; align-items: center; gap: 1em;">
          <span>
            {formatRelative(
              new Date(Scru128Id.fromString(props.frame.id).timestamp),
              new Date(),
            )}
          </span>
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

export default MessageCard;
