import { Component, For } from "solid-js";
import { Frame } from "../store/stream";
import { Fingerprint } from "lucide-solid";
import { formatRelative } from "date-fns";
import { Scru128Id } from "scru128";
import CopyTrigger from "./CopyTrigger";
import { CASStore } from "../store/cas";
import { Show } from "solid-js";

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
          <span>{props.segment.responseMessage.meta.role}</span>
          <Show when={props.isSelected}>
            <div style="display:flex; gap: 0.2em;">
              <Fingerprint
                class="icon-button"
                size={18}
                onClick={(e) => {
                  e.preventDefault();
                  navigator.clipboard.writeText(
                    props.segment.responseMessage.id,
                  );
                }}
              />
              <Show
                when={props.cas.get(props.segment.responseMessage.hash)()}
                keyed
              >
                {(content) => (
                  <span>
                    <CopyTrigger content={content} />
                  </span>
                )}
              </Show>
            </div>
          </Show>
        </div>
        <div style="max-height: 7em; overflow-y: auto;">
          <For each={props.segment.promptMessages}>
            {(message) => (
              <div style="font-size: 0.8em; opacity: 0.8;">
                {props.cas.get(message.hash)()}
              </div>
            )}
          </For>
          <div style="font-weight: bold;">
            {props.cas.get(props.segment.responseMessage.hash)()}
          </div>
        </div>
      </div>
    </div>
  );
};

export default MessageNav;
