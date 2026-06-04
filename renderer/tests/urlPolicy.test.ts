import { describe, expect, it } from "vitest";
import { resolveUrl } from "../src/urlPolicy";

const policy = {
  workspaceToken: "abc",
  filePath: "docs/readme.md",
  refreshVersion: 3,
};

describe("resolveUrl", () => {
  it("keeps external urls external", () => {
    expect(resolveUrl("https://example.com", policy)).toMatchObject({
      isExternal: true,
      isWorkspaceLocal: false,
    });
  });

  it("resolves relative workspace paths", () => {
    expect(resolveUrl("./image.png", policy)).toMatchObject({
      isWorkspaceLocal: true,
      resolvedPath: "docs/image.png",
      appUrl: "pamphlet-file://abc/docs/image.png?v=3",
    });
  });

  it("rejects paths outside the workspace", () => {
    expect(
      resolveUrl("../outside.md", { ...policy, filePath: "readme.md" }),
    ).toMatchObject({
      isWorkspaceLocal: false,
    });
  });
});
