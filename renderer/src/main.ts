import { render, type RenderPayload } from "./render";

declare global {
  interface Window {
    Pamphlet: {
      render(payload: RenderPayload): void;
    };
    webkit?: {
      messageHandlers?: {
        linkClick?: {
          postMessage(message: unknown): void;
        };
      };
    };
  }
}

window.Pamphlet = { render };

export { render };
