import { Component, createSignal, Show } from "solid-js";
import Copy from "lucide-solid/icons/copy";
import CopyCheck from "lucide-solid/icons/copy-check";

const CopyTrigger: Component<{ content: string }> = (props) => {
  const [copied, setCopied] = createSignal(false);

  const handleCopyClick = () => {
    navigator.clipboard.writeText(props.content).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 300);
    });
  };

  return (
    <div class="icon-button" onClick={handleCopyClick}>
      <Show when={copied()} fallback={<Copy size={18} />}>
        <CopyCheck size={18} />
      </Show>
    </div>
  );
};

export default CopyTrigger;
