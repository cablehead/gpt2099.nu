// CSS raw imports
declare module "*.css?raw" {
  const content: string;
  export default content;
}

// Other Vite specific imports you might need
declare module "*.css" {
  const content: Record<string, string>;
  export default content;
}

declare module "*.scss?raw" {
  const content: string;
  export default content;
}
