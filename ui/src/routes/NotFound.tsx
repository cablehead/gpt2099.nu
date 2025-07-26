import { Component } from "solid-js";
import { A } from "@solidjs/router";

const NotFound: Component = () => {
  return (
    <>
      <p>
        <A href="/">home</A>
      </p>
      <div>
        <h2>404 - Page Not Found</h2>
        <p>The page you're looking for doesn't exist.</p>
      </div>
    </>
  );
};

export default NotFound;
