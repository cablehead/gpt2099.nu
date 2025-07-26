import { Component, createResource, Show } from "solid-js";

import { A, Route, Router, useParams } from "@solidjs/router";

import { useFrameStream } from "./store/stream";
import { useStore } from "./store";
import { createCAS } from "./store/cas";
import { marked } from "./marked";
import { prefersDark, toggleTheme } from "./theme";

import ThemeTrigger from "./components/ThemeTrigger";

import Card from "./Card";
import NotFound from "./routes/NotFound";
import Home from "./routes/Home";

const App: Component = () => {
  const frameSignal = useFrameStream();

  const fetchContent = async (hash: string) => {
    const response = await fetch(`/api/cas/${hash}`);
    if (!response.ok) {
      throw new Error(`Failed to fetch content for hash ${hash}`);
    }
    return await response.text();
  };

  const CAS = createCAS(fetchContent);
  const { currentThread, title, loadingState, parseContent } = useStore({ dataSignal: frameSignal, CAS });

  const [titleContent] = createResource(
    () => {
      const frame = title();
      if (!frame) return "GPT Thread Viewer";
      return CAS.get(frame.hash)() || "GPT Thread Viewer";
    },
    async (content) => {
      return await marked.parse(content);
    }
  );

  return (
    <div>
      <header
        style="
                       display: flex;
                       justify-content: space-between;
                       align-items: center;
                       padding: 1em 0 2em;
                       "
      >
        <span
          style="font-size: 2em; font-weight: 500;"
          innerHTML={titleContent()}
        />

        <ThemeTrigger prefersDark={prefersDark} toggleTheme={toggleTheme} />
      </header>

      <Show when={currentThread() !== null} fallback={
        <div>
          <p>Loading GPT thread...</p>
          <p style="font-size: 0.9em; color: var(--color-dark-0);">{loadingState()}</p>
        </div>
      }>
        <Router>
          <Route
            path="/"
            component={() => <Home thread={currentThread()!} CAS={CAS} parseContent={parseContent} />}
          />
          <Route
            path="/:id"
            component={() => {
              const params = useParams();
              const turnId = params.id;
              const thread = currentThread();

              if (!thread) return <NotFound />;

              const foundTurn = thread.turns.find(turn => turn.id === turnId);

              return (
                <Show when={foundTurn} fallback={<NotFound />}>
                  <p>
                    <A href="/">home</A> / <A href={`/${turnId}`}>{turnId}</A>
                  </p>
                  <Card turn={foundTurn!} CAS={CAS} parseContent={parseContent} />
                </Show>
              );
            }}
          />
          <Route path="*paramName" component={NotFound} />
        </Router>
      </Show>
    </div>
  );
};

export default App;
