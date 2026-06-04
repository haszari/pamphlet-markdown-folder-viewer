export type RenderThemePayload = {
  variables?: Record<string, string>;
  rawAppCSS?: string;
  rawWorkspaceCSS?: string;
};

const APP_THEME_STYLE_ID = "pamphlet-app-theme-css";
const WORKSPACE_THEME_STYLE_ID = "pamphlet-workspace-theme-css";
const managedVariables = new Set<string>();

export function applyRenderTheme(theme: RenderThemePayload | undefined): void {
  applyVariables(theme?.variables ?? {});
  applyThemeStyle(APP_THEME_STYLE_ID, theme?.rawAppCSS ?? "");
  applyThemeStyle(WORKSPACE_THEME_STYLE_ID, theme?.rawWorkspaceCSS ?? "");
}

function applyVariables(variables: Record<string, string>): void {
  const rootStyle = document.documentElement.style;

  for (const name of managedVariables) {
    if (!(name in variables)) {
      rootStyle.removeProperty(name);
    }
  }

  managedVariables.clear();

  for (const [name, value] of Object.entries(variables)) {
    if (!name.startsWith("--pamphlet-")) continue;
    rootStyle.setProperty(name, value);
    managedVariables.add(name);
  }

  const colorScheme = colorSchemeForAppearance(
    variables["--pamphlet-appearance"],
  );
  if (colorScheme) {
    rootStyle.colorScheme = colorScheme;
  } else {
    rootStyle.removeProperty("color-scheme");
  }
}

function applyThemeStyle(id: string, css: string): void {
  const style = findOrCreateThemeStyle(id);
  style.textContent = removeImports(css);
}

function findOrCreateThemeStyle(id: string): HTMLStyleElement {
  const existing = document.getElementById(id);
  if (existing instanceof HTMLStyleElement) return existing;

  const style = document.createElement("style");
  style.id = id;
  style.dataset.pamphletTheme = "true";
  document.head.appendChild(style);
  return style;
}

function colorSchemeForAppearance(value: string | undefined): string | null {
  switch (value?.trim()) {
    case "light":
      return "light";
    case "dark":
      return "dark";
    case "adaptive":
      return "light dark";
    default:
      return null;
  }
}

export function removeImports(css: string): string {
  return css.replace(/@import\s+(?:url\()?["'][^"']+["']\)?[^;]*;/gi, "");
}
