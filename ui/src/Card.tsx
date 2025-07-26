import { Component, Show, For, createResource } from "solid-js";
import { styled } from "solid-styled-components";
import { A } from "@solidjs/router";

import { formatRelative } from "date-fns";
import Fingerprint from "lucide-solid/icons/fingerprint";

import { Turn, ContentBlock } from "./store/stream";
import { CASStore } from "./store/cas";
import { marked } from "./marked";
import CopyTrigger from "./components/CopyTrigger";

const CardWrapper = styled("div")`
  display: flex;
  flex-direction: column;
  overflow: hidden;
  position: relative;
  border-radius: 0.25em;
  box-shadow: 0 0 0.25em var(--color-shadow);
  border-left: none;
  border-right: none;
  margin-bottom: 1em;
  background-color: var(--color-bg-alt);
`;

const Content = styled("div")`
  flex: 1;
  max-height: 33vh;
  overflow: auto;
  padding: 0.25em 0.5em;
  overflow-wrap: break-word;
`;

const Meta = styled("div")`
  font-size: 0.9em;
  padding: 0.5em 1em;
  display: flex;
  flex-direction: column;
  gap: 0.25em;
`;

const RoleBadge: Component<{ role: string }> = (props) => {
  const getBgColor = () => {
    switch (props.role) {
      case 'user': return 'var(--color-green)';
      case 'assistant': return 'var(--color-frost-2)';
      default: return 'var(--color-orange)';
    }
  };

  return (
    <span
      style={`
        padding: 0.2em 0.5em;
        border-radius: 0.2em;
        font-size: 0.8em;
        font-weight: 500;
        background-color: ${getBgColor()};
        color: var(--color-black);
      `}
    >
      {props.role}
    </span>
  );
};

type CardProps = {
  turn: Turn;
  CAS: CASStore;
  parseContent: (turn: Turn) => ContentBlock[];
};

const ContentBlockRenderer: Component<{ block: ContentBlock }> = (props) => {
  const { block } = props;

  switch (block.type) {
    case "text":
      const [textHtml] = createResource(
        () => block.text,
        async (text) => await marked.parse(text)
      );
      return (
        <Show when={textHtml()} keyed>
          {(html) => <div class="markdown" innerHTML={html} />}
        </Show>
      );
    
    case "tool_use":
      return (
        <div style="background: var(--color-pill); padding: 0.5em; border-radius: 0.25em; margin: 0.5em 0;">
          <strong>🔧 Tool Use: {block.name}</strong>
          <pre style="margin-top: 0.5em; font-size: 0.9em;">
            {JSON.stringify(block.input, null, 2)}
          </pre>
        </div>
      );
    
    case "tool_result":
      return (
        <div style="background: var(--color-frost-0); padding: 0.5em; border-radius: 0.25em; margin: 0.5em 0;">
          <strong>⚙️ Tool Result</strong>
          <pre style="margin-top: 0.5em; font-size: 0.9em;">
            {JSON.stringify(block.content, null, 2)}
          </pre>
        </div>
      );
    
    case "document":
      return (
        <div style="background: var(--color-yellow); color: var(--color-black); padding: 0.5em; border-radius: 0.25em; margin: 0.5em 0;">
          <strong>📄 Document: {block.source.media_type}</strong>
          <div style="margin-top: 0.5em; font-size: 0.9em;">
            {block.source.media_type.startsWith('text/') ? (
              (() => {
                const [docHtml] = createResource(
                  () => atob(block.source.data),
                  async (text) => await marked.parse(text)
                );
                return (
                  <Show when={docHtml()} keyed>
                    {(html) => <div class="markdown" innerHTML={html} />}
                  </Show>
                );
              })()
            ) : (
              <em>Binary document ({block.source.media_type})</em>
            )}
          </div>
        </div>
      );
    
    default:
      return (
        <div style="background: var(--color-red); color: var(--color-white); padding: 0.5em; border-radius: 0.25em; margin: 0.5em 0;">
          Unknown content type: {JSON.stringify(block)}
        </div>
      );
  }
};

const Card: Component<CardProps> = (props) => {
  const { turn, parseContent } = props;

  // Create reactive content signal
  const content = () => parseContent(turn);

  const textContent = () => {
    return content()
      .filter(block => block.type === "text")
      .map(block => (block as any).text)
      .join("\n");
  };

  return (
    <CardWrapper>
      <Meta class="panel">
        <div
          style="
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 1em;
          "
        >
          <div style="display: flex; align-items: center; gap: 0.5em;">
            <RoleBadge role={turn.role} />
            <Show when={turn.cache}>
              <span style="font-size: 0.8em; color: var(--color-purple);">cached</span>
            </Show>
          </div>

          <div style="display:flex; gap: 0.2em;">
            <Fingerprint
              class="icon-button"
              size={18}
              onClick={(e) => {
                e.preventDefault();
                navigator.clipboard.writeText(turn.id);
              }}
            />

            <Show when={textContent()}>
              <CopyTrigger content={textContent()} />
            </Show>
          </div>
        </div>
        <div
          style="
          display: flex;
          justify-content: space-between;
          align-items: center;
          gap: 1em;
          "
        >
          <span style="font-size: 0.8em; color: var(--color-dark-0);">
            {Object.keys(turn.options).length > 0 && 
              `Options: ${JSON.stringify(turn.options)}`
            }
          </span>
          
          <span>
            <A href={`/${turn.id}`}>{formatRelative(turn.timestamp, new Date())}</A>
          </span>
        </div>
      </Meta>
      <Content>
        <For each={content()}>
          {(block) => <ContentBlockRenderer block={block} />}
        </For>
      </Content>
    </CardWrapper>
  );
};

export default Card;