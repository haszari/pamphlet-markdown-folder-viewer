export type UrlPolicy = {
  workspaceToken: string;
  filePath: string;
  refreshVersion: number;
};

export type ResolvedUrl = {
  original: string;
  isExternal: boolean;
  isWorkspaceLocal: boolean;
  resolvedPath?: string;
  appUrl?: string;
};

const externalSchemes = new Set(["http:", "https:", "mailto:"]);

export function resolveUrl(href: string, policy: UrlPolicy): ResolvedUrl {
  const trimmed = href.trim();
  if (!trimmed || trimmed.startsWith("#")) {
    return { original: href, isExternal: false, isWorkspaceLocal: false };
  }

  try {
    const parsed = new URL(trimmed);
    if (externalSchemes.has(parsed.protocol)) {
      return { original: href, isExternal: true, isWorkspaceLocal: false };
    }
    return { original: href, isExternal: false, isWorkspaceLocal: false };
  } catch {
    // Relative URL; resolve below.
  }

  const withoutFragment = trimmed.split("#", 1)[0]?.split("?", 1)[0] ?? trimmed;
  const baseDirectory = directoryName(policy.filePath);
  const resolvedPath = normalizeWorkspacePath(
    withoutFragment.startsWith("/")
      ? withoutFragment.slice(1)
      : [baseDirectory, withoutFragment].filter(Boolean).join("/"),
  );

  if (!resolvedPath) {
    return { original: href, isExternal: false, isWorkspaceLocal: false };
  }

  return {
    original: href,
    isExternal: false,
    isWorkspaceLocal: true,
    resolvedPath,
    appUrl: `pamphlet-file://${encodeURIComponent(policy.workspaceToken)}/${encodePath(resolvedPath)}?v=${policy.refreshVersion}`,
  };
}

export function rewriteEmbeddedAssetUrl(
  url: string,
  policy: UrlPolicy,
): string {
  const resolved = resolveUrl(url, policy);
  return resolved.appUrl ?? url;
}

function directoryName(path: string): string {
  const index = path.lastIndexOf("/");
  return index === -1 ? "" : path.slice(0, index);
}

function normalizeWorkspacePath(path: string): string | undefined {
  const parts: string[] = [];
  for (const rawPart of path.split("/")) {
    const part = decodeURIComponent(rawPart);
    if (!part || part === ".") continue;
    if (part === "..") {
      if (parts.length === 0) return undefined;
      parts.pop();
      continue;
    }
    parts.push(part);
  }
  return parts.join("/");
}

function encodePath(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}
