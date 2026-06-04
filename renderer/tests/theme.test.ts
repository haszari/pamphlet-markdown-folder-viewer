import { beforeEach, describe, expect, it } from "vitest";
import { render, type RenderPayload } from "../src/render";

const basePayload: RenderPayload = {
  mode: "markdown",
  content: "# Hello\n\nWorld",
  fileName: "index.md",
  filePath: "index.md",
  workspaceToken: "abc",
  refreshVersion: 1,
};

describe("theme rendering", () => {
  beforeEach(() => {
    document.head.innerHTML = "";
    document.body.innerHTML = '<div id="root"></div>';
    document.documentElement.removeAttribute("style");
  });

  it("sets resolved variables and browser color scheme", () => {
    render({
      ...basePayload,
      theme: {
        variables: {
          "--pamphlet-appearance": "dark",
          "--pamphlet-background": "#101010",
          "--pamphlet-accent": "#ffcc00",
        },
      },
    });

    const style = document.documentElement.style;
    expect(style.getPropertyValue("--pamphlet-background")).toBe("#101010");
    expect(style.getPropertyValue("--pamphlet-accent")).toBe("#ffcc00");
    expect(style.colorScheme).toBe("dark");
  });

  it("injects app CSS before workspace CSS", () => {
    render({
      ...basePayload,
      theme: {
        rawAppCSS: ".markdown { color: #111111; }",
        rawWorkspaceCSS: ".markdown { color: #222222; }",
      },
    });

    const themeStyles = Array.from(
      document.head.querySelectorAll("style[data-pamphlet-theme='true']"),
    );
    expect(themeStyles.map((style) => style.id)).toEqual([
      "pamphlet-app-theme-css",
      "pamphlet-workspace-theme-css",
    ]);
    expect(themeStyles[0].textContent).toContain("#111111");
    expect(themeStyles[1].textContent).toContain("#222222");
  });

  it("removes CSS imports before injection", () => {
    render({
      ...basePayload,
      theme: {
        rawAppCSS:
          '@import url("https://example.com/theme.css"); .markdown { color: #111111; }',
      },
    });

    const style = document.getElementById("pamphlet-app-theme-css");
    expect(style?.textContent).not.toContain("@import");
    expect(style?.textContent).toContain(".markdown");
  });

  it("clears variables and CSS from previous renders", () => {
    render({
      ...basePayload,
      theme: {
        variables: {
          "--pamphlet-background": "#101010",
        },
        rawWorkspaceCSS: ".markdown { color: #222222; }",
      },
    });
    render(basePayload);

    expect(
      document.documentElement.style.getPropertyValue(
        "--pamphlet-background",
      ),
    ).toBe("");
    expect(
      document.getElementById("pamphlet-workspace-theme-css")?.textContent,
    ).toBe("");
  });
});
