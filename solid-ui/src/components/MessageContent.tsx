// MessageContent.tsx
import { Component, Show } from "solid-js";
import { Match, Switch } from "solid-js";

type MessagePanel = {
  type: string;
  text?: string;
  id?: string;
  name?: string;
  input?: {
    command: string;
    path?: string;
    old_str?: string;
    new_str?: string;
    // Add other potential input fields as needed
  };
};

const ToolUsePanel: Component<{ panel: MessagePanel }> = (props) => {
  return (
    <div class="tool-use-panel" style="border-left: 3px solid var(--color-accent); padding-left: 0.5em; margin: 0.5em 0;">
      <div style="color: var(--color-fg-dim); font-size: 0.9em;">
        {props.panel.name} - {props.panel.input?.command}
      </div>
      <Show when={props.panel.input?.path}>
        <div style="font-family: monospace; font-size: 0.9em; margin-top: 0.25em;">
          {props.panel.input?.path}
        </div>
      </Show>
      <Show when={props.panel.input?.old_str && props.panel.input?.new_str}>
        <div style="margin-top: 0.5em;">
          <details>
            <summary style="cursor: pointer; color: var(--color-fg-dim);">Show changes</summary>
            <div style="margin-top: 0.5em;">
              <div style="color: var(--color-error); white-space: pre-wrap;">- {props.panel.input?.old_str}</div>
              <div style="color: var(--color-success); white-space: pre-wrap;">+ {props.panel.input?.new_str}</div>
            </div>
          </details>
        </div>
      </Show>
    </div>
  );
};

const TextPanel: Component<{ text: string }> = (props) => {
  return (
    <div style="white-space: pre-wrap;">
      {props.text}
    </div>
  );
};

const MessageContent: Component<{ content: string }> = (props) => {
  const tryParseJson = () => {
    try {
      const parsed = JSON.parse(props.content);
      if (Array.isArray(parsed)) {
        return parsed as MessagePanel[];
      }
    } catch {
      return null;
    }
    return null;
  };

  const panels = tryParseJson();

  return (
    <Show 
      when={panels}
      fallback={<pre style="white-space: pre-wrap;">{props.content}</pre>}
    >
      <div style="display: flex; flex-direction: column; gap: 1em;">
        {panels?.map(panel => (
          <Switch>
            <Match when={panel.type === "text"}>
              <TextPanel text={panel.text!} />
            </Match>
            <Match when={panel.type === "tool_use"}>
              <ToolUsePanel panel={panel} />
            </Match>
          </Switch>
        ))}
      </div>
    </Show>
  );
};

export default MessageContent;