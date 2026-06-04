# Folder theming

## Goal

Add app-wide theming so each workspace can make the whole window visually recognisable with a small, user-editable theme file. The theme applies to native chrome surfaces, the view surface, renderer content, watermark badge, and the window title. Typography customisation applies to rendered content only.

## Approach

Use CSS as the theme source of truth. Theme files define sanctioned `--pamphlet-*` CSS custom properties for app and default content theme configuration. Swift reads only those variables for native chrome colours, surfaces, watermark placement, and title formatting. The renderer receives the same resolved variables plus the raw theme CSS, so advanced users can also customise rendered markdown and safe inline HTML with ordinary CSS selectors.

Theme files will be regular CSS files with comments allowed. The workspace file name will be `.pamphlet.css`. App theme files will use the same format and live in:

- built-in: `Pamphlet/Resources/Themes/*.css`
- user-added: `~/Library/Application Support/Pamphlet/Themes/*.css`

CSS is chosen because theme authors can start with a handful of variables, add comments freely, and customise rendered markdown/content using normal selectors without switching formats.

## Theme model

Add a small Swift domain model under `Pamphlet/Models/` for the subset of theme values the native app shell must understand:

- `ThemeSource`
- `ResolvedTheme`
- `ThemeBadge`
- `ThemePlacement`
- `ThemeTitleTemplate`
- `ThemeVariableParser`

App theme identity comes from the app theme file name. Workspace themes do not have ids. The `--pamphlet-*` namespace is the stable contract; selectors outside that namespace affect rendered content only and are ignored by native chrome.

Swift theme extraction is intentionally limited:

- read `--pamphlet-*` declarations from `:root`
- read `--pamphlet-*` declarations from `@media (prefers-color-scheme: dark) { :root { ... } }`
- strip CSS comments before extraction
- preserve raw CSS for renderer injection
- ignore non-`--pamphlet-*` selectors and declarations for native chrome
- do not evaluate general CSS cascade, imports, nested selectors, `var()`, or colour functions

Sanctioned theme variables must be flat tokens. A `--pamphlet-*` value that references another CSS variable or expression is unsupported for the theme surface; the app ignores that value and uses the derived/default value instead. Advanced CSS outside the sanctioned theme variable surface may still use normal CSS features for custom rendered content.

Supported CSS variables:

- `--pamphlet-background`
- `--pamphlet-foreground`
- `--pamphlet-accent`
- `--pamphlet-sidebar-background`
- `--pamphlet-content-background`
- `--pamphlet-selection-background`
- `--pamphlet-border`
- `--pamphlet-font-family`
- `--pamphlet-heading-font-family`
- `--pamphlet-monospace-font-family`
- `--pamphlet-code-background`
- `--pamphlet-quote-background`
- `--pamphlet-title-template`
- `--pamphlet-badge-kind`
- `--pamphlet-badge-value`
- `--pamphlet-badge-placement`
- `--pamphlet-badge-anchor`
- `--pamphlet-badge-margin-top`
- `--pamphlet-badge-margin-right`
- `--pamphlet-badge-margin-bottom`
- `--pamphlet-badge-margin-left`
- `--pamphlet-badge-opacity`
- `--pamphlet-badge-size`

Only `--pamphlet-background`, `--pamphlet-foreground`, and `--pamphlet-accent` are required for a useful custom theme. Missing fields are derived from those base colours in Swift and exported back to the renderer as resolved CSS variables. `--pamphlet-font-family` sets body and heading text by default; `--pamphlet-heading-font-family` customises headings only.

Code and quoted box backgrounds default from `--pamphlet-background` and `--pamphlet-foreground`, but can be customised independently:

- `--pamphlet-code-background` controls fenced code blocks and inline code backgrounds.
- `--pamphlet-quote-background` controls blockquotes and quoted/callout-style boxes.

Default badge values:

- `placement`: `bottomRight`
- `anchor`: `content`
- `margin`: `24` on all edges
- `opacity`: `0.12`
- `size`: `96`

## Theme loading and precedence

Add `ThemeStore` under `Pamphlet/Services/`.

Load order:

1. Built-in app themes from `Pamphlet/Resources/Themes/`.
2. User app themes from `~/Library/Application Support/Pamphlet/Themes/`.
3. Workspace override from `.pamphlet.css`.

Precedence:

- Built-in fallback variables are always loaded first.
- The configured default app theme CSS is layered on top.
- Workspace theme CSS is layered last.
- There is no `extends` field in workspace themes.
- If the workspace file has invalid CSS or unreadable app-facing variables, ignore only the invalid values, keep valid values, and log parse details with `Logger`.

Default app theme selection will be stored in `UserDefaults` as `defaultThemeID`, with the initial value `system`. The first implementation does not need a preferences window; this setting can be changed later from UI or tests.

## Built-in themes

Bundle these app themes:

- `system`: adaptive theme that follows macOS appearance.
- `light`: fixed light theme.
- `dark`: fixed dark theme.
- `pro`: restrained dark theme with cool accent.
- `fun`: warm high-colour theme.

`system` will be the default because it preserves OS dark/light behaviour before the user customises anything. It will be an adaptive CSS theme using `@media (prefers-color-scheme: dark)`. Fixed light and dark themes are normal CSS files without a dark-mode media block.

## App-wide application

Add `@Published var theme: ResolvedTheme` to `WorkspaceViewModel`.

Resolve effective variables from:

- built-in fallback variables
- selected app theme CSS
- workspace override
- `NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])`, used to evaluate `prefers-color-scheme`

Update theme resolution when:

- a workspace window is created
- the user triggers Refresh
- macOS effective appearance changes

Apply native theme tokens in:

- `WorkspaceView`
- `SidebarView`
- `TabStripView`
- `ViewPane`

Native UI will use semantic colour and surface tokens rather than direct `NSColor` defaults. The split view divider remains native AppKit behaviour, native typography remains system typography, and surrounding surfaces and row selection colours come from the theme.

## Renderer application

Extend `RendererPayload` with:

- resolved theme variables
- raw app theme CSS
- raw workspace theme CSS

Update `renderer/src/render.ts` to set CSS custom properties on `document.documentElement` before rendering content and inject raw theme CSS after the base renderer stylesheet.

Update `renderer/src/styles.css` to replace direct `Canvas`, `CanvasText`, `LinkText`, and hard-coded neutral mixes with CSS variables:

- `--pamphlet-background`
- `--pamphlet-content-background`
- `--pamphlet-foreground`
- `--pamphlet-muted-foreground`
- `--pamphlet-accent`
- `--pamphlet-border`
- `--pamphlet-selection-background`
- `--pamphlet-code-background`
- `--pamphlet-quote-background`
- `--pamphlet-table-header-background`
- `--pamphlet-font-family`
- `--pamphlet-heading-font-family`
- `--pamphlet-monospace-font-family`

Keep highlight.js using the existing imported theme for this implementation, but wrap code blocks with derived code background and foreground tokens so code remains legible against the selected content background.

## Badge watermark

Implement the badge in SwiftUI so it can overlay either the whole window or just the content pane:

- `anchor: window` renders from `WorkspaceView`.
- `anchor: content` renders from `ViewPane`.

Emoji badges render as text using the resolved UI font with a fixed box size. Image badges load from the workspace when defined by the workspace theme, or from the app theme resource folder when defined by an app theme. Failed image loads render no badge.

The badge is decorative only:

- no hit testing
- no accessibility label
- no layout effect on sidebar, tabs, or content

## Window title

Change `WorkspaceViewModel.updateWindowSubject()` so the title is formatted from workspace context while preserving `representedURL`.

Default title format:

```text
{workspaceName}/ - {fileName}
```

When there is no active tab:

```text
{workspaceName}/
```

Supported title template placeholders:

- `{workspaceName}`
- `{fileName}`
- `{relativePath}`

Example workspace override:

```css
/* .pamphlet.css */
:root {
  --pamphlet-background: #fff6d7;
  --pamphlet-foreground: #201806;
  --pamphlet-accent: #d58a00;
  --pamphlet-heading-font-family: "Avenir Next";
  --pamphlet-title-template: "🍌 Banana Corp - {fileName}";
  --pamphlet-badge-kind: emoji;
  --pamphlet-badge-value: "🍌";
  --pamphlet-badge-placement: bottomRight;
  --pamphlet-badge-anchor: window;
}

@media (prefers-color-scheme: dark) {
  :root {
    --pamphlet-background: #201806;
    --pamphlet-foreground: #fff6d7;
    --pamphlet-accent: #ffc247;
  }
}
```

`window.representedURL` remains the active file URL when a file is selected, otherwise the workspace URL. This preserves the titlebar file proxy behaviour.

## Documentation

Update:

- `CONTEXT.md`: add terms for app theme, workspace theme, adaptive theme, theme variable, badge watermark, and themed window title.
- `README.md`: document the workspace theme file, user app theme folder, built-in theme ids, supported fields, and exact build/test commands.

## App rename

Complete [Rename app to Pamphlet](./20260604-rename-app-to-pamphlet.md) before theme implementation. The rename must update:

- app display name, menu labels, bundle-facing names, and help labels
- Xcode target, scheme, and project-visible groups where practical
- Swift module references and test target references if the target/module name changes
- renderer package and documentation references
- Application Support folder used for user app themes
- theme variable prefix from `--mfv-*` to `--pamphlet-*`

## Implementation order

1. Complete the separate Pamphlet rename plan.
2. Add theme model types, CSS variable parsing, validation defaults, and unit tests.
3. Add bundled theme CSS files and resource-copy project configuration.
4. Add `ThemeStore` loading for built-in themes, user app themes, and workspace overrides.
5. Add resolved theme state to `WorkspaceViewModel` and refresh/appearance reload hooks.
6. Apply resolved theme variables to native SwiftUI/AppKit surfaces.
7. Extend `RendererPayload`, renderer TypeScript types, raw theme CSS injection, and CSS variable application.
8. Add badge watermark overlay for window/content anchors.
9. Update window title formatting while preserving `representedURL`.
10. Update documentation.
11. Run the documented formatter.

## Scope

Included:

- Workspace-level theme override file `.pamphlet.css`.
- Built-in app themes `system`, `light`, `dark`, `pro`, and `fun`.
- User-added app theme files in Application Support.
- OS dark/light support through CSS media-query variants.
- Native chrome theming for sidebar, tab strip, view pane background, selected rows, and borders.
- Renderer theming for markdown, source, table, image, code block surfaces, quoted boxes, links, and body/heading/monospace typography.
- Badge watermark as emoji or image.
- Window title customisation through template placeholders.

Not included:

- Theme editor dialog.
- Generative theme creation.
- Live editing without pressing Refresh.
- Per-file theme overrides.
- Per-tab theme overrides.
- Syntax-specific highlight.js token palettes.
- Remote theme files.
- Executable theme code.
- Sandboxed security-scoped persistence for user theme folders.

## Verification

Run during implementation:

```sh
cd renderer
npm test
npm run build
npm run format
cd ..
```

Run macOS app tests from Xcode using the `Pamphlet` scheme after the rename.

Manual implementation checks:

- Open `fixtures/sample-workspace/` with no workspace theme file and confirm the `system` theme follows macOS light/dark appearance.
- Add `.pamphlet.css` to `fixtures/sample-workspace/` with only `--pamphlet-background`, `--pamphlet-foreground`, and `--pamphlet-accent`; press Refresh and confirm sidebar, content, links, tables, and code blocks are readable.
- Add an emoji badge anchored to `window`; confirm it can overlay the sidebar and does not block clicks.
- Change the badge anchor to `content`; confirm it stays inside the content pane.
- Add a title template; confirm the window title changes and the titlebar file proxy still represents the selected file.
- Add an invalid workspace theme file; confirm the app falls back to the default theme without a blank window.

## Testing

Restart/rebuild:

```sh
cd renderer
npm run build
cd ..
```

Then build and run the `Pamphlet` scheme in Xcode after the rename.

Click/check:

- Open `fixtures/sample-workspace/`.
- Confirm the sidebar and content area use the selected default theme.
- Toggle macOS light/dark mode; expect the `system` theme to change without losing the open file.
- Create `.pamphlet.css` in the workspace with three colour variables; choose `File > Refresh`; expect the whole window to change.
- Add `--pamphlet-title-template: "🍌 Banana Corp - {fileName}";`; choose `File > Refresh`; expect the window title to include the custom workspace name and current file name.
- Select another file; expect the file name in the title to update.
- Drag the titlebar file proxy to Finder; expect it to still represent the selected file.
- Add an emoji badge; expect the watermark to appear at the configured edge and stay behind interactions.

## Completion checklist

- [ ] The app is renamed to Pamphlet across user-visible app surfaces and project references needed by the build.
- [ ] Workspace theme files load and override the default app theme.
- [ ] Built-in and user app themes share one schema.
- [ ] OS light/dark mode resolves through CSS media-query variants.
- [ ] Native chrome and renderer content use the same resolved theme tokens.
- [ ] Badge watermark supports emoji, images, placement, margins, opacity, size, and window/content anchors.
- [ ] Window titles include workspace context and preserve titlebar file proxy behaviour.
- [ ] Theme usage is documented in `README.md` and domain language is documented in `CONTEXT.md`.
- [ ] All builds, linters, and tests pass.
