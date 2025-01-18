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
      <div>
        <div
          class="panel"
          style=" padding: 0.5em 1em;"
        >
          <div>
            {props.cas.get(props.segment.promptMessages.at(-1).hash)()}
          </div>
        </div>
        <div>
          {props.cas.get(props.segment.responseMessage.hash)()}
        </div>
      </div>
    </div>
  );
};

export default MessageNav;
