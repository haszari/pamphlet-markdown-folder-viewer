import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { rendererThemeHooks } from "../src/themeHooks";

const testDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(testDir, "../..");
const swiftTokensPath = path.join(
  repoRoot,
  "Pamphlet/Models/ThemeTokens.swift",
);
const referencePath = path.join(repoRoot, "docs/theme-reference.pamphlet.css");
const generatorPath = path.join(
  repoRoot,
  "scripts/generate-theme-reference.mjs",
);

describe("theme reference CSS", () => {
  it("is generated from current theme contracts", () => {
    const before = readFileSync(referencePath, "utf8");
    execFileSync("node", [generatorPath], { cwd: repoRoot });
    const after = readFileSync(referencePath, "utf8");

    expect(after).toBe(before);
  });

  it("documents every Swift-recognised Pamphlet theme token", () => {
    const swiftTokens = [
      ...readFileSync(swiftTokensPath, "utf8").matchAll(
        /case\s+\w+\s*=\s*"(--pamphlet-[^"]+)"/g,
      ),
    ].map((match) => match[1]);
    const reference = readFileSync(referencePath, "utf8");

    expect(swiftTokens.length).toBeGreaterThan(0);
    for (const token of swiftTokens) {
      expect(reference).toContain(`${token}:`);
    }
  });

  it("documents renderer-owned hooks", () => {
    const reference = readFileSync(referencePath, "utf8");

    for (const hook of rendererThemeHooks) {
      expect(reference).toContain(hook.selector);
    }
  });
});
