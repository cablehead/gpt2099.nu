import { Component, Show } from "solid-js";
import MoonStar from "lucide-solid/icons/moon-star";
import Sun from "lucide-solid/icons/sun";

const ThemeTrigger: Component<{
  prefersDark: () => boolean;
  toggleTheme: () => void;
}> = (props) => {
  return (
    <div class="icon-button" onclick={props.toggleTheme}>
      <Show when={props.prefersDark()} fallback={<MoonStar />}>
        <Sun />
      </Show>
    </div>
  );
};

export default ThemeTrigger;
