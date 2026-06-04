# Folder theming

## Goal

Add workspace-window theming so each workspace can make its window visually recognisable with a small, user-editable CSS file. The theme applies to every visible surface inside the workspace window: sidebar, tab strip, empty view, rendered content, watermark badge, and window title context.

Typography customisation applies to rendered content only. Utility windows such as Preferences are not themed.

## Approach

Use CSS as the theme source of truth.

Theme files define flat sanctioned `--pamphlet-*` CSS custom properties for values Pamphlet understands. Theme files may also include ordinary CSS selectors for rendered-content customisation.

Swift extracts only sanctioned variables needed for workspace window UI and window behaviour. The renderer receives resolved variables plus raw theme CSS. WebKit handles ordinary CSS parsing.

Theme files are regular self-contained CSS files with comments allowed. `@import` is unsupported and must be removed or rejected before renderer injection.

Theme locations:

- built-in app themes: `Pamphlet/Resources/Themes/<theme-name>/theme.css`
- user app theme folders: `~/Library/Application Support/Pamphlet/Themes/<theme-name>/theme.css`
- user app theme shorthand files: `~/Library/Application Support/Pamphlet/Themes/<theme-name>.css`
- workspace overlay: `.pamphlet.css`

## Theme CSS rules

Built-in app themes, user app themes, and workspace overlays follow the same CSS rules.

The `--pamphlet-*` namespace is the app-recognised theme surface. Values must be flat tokens: no `var()`, aliases, CSS expressions, imports, nested selectors, or colour functions. Invalid `--pamphlet-*` values fail soft: ignore the invalid value, apply valid values, and log parse details with `Logger`.

Raw CSS outside the sanctioned variable surface is injected into the renderer after unsupported constructs are removed. It can style markdown output, safe inline HTML, source views, table views, image views, and highlight.js output.

Themes cannot load external fonts. Theme authors may reference fonts already installed on the user's Mac through `font-family`; documentation must explain how to find installed family names with macOS Font Book.

## Sanctioned variables

Required for a useful custom theme:

- `--pamphlet-background`
- `--pamphlet-foreground`
- `--pamphlet-accent`

Optional theme variables:

- `--pamphlet-muted-foreground`
- `--pamphlet-appearance`
- `--pamphlet-window-background`
- `--pamphlet-selection-background`
- `--pamphlet-border`
- `--pamphlet-font-family`
- `--pamphlet-heading-font-family`
- `--pamphlet-monospace-font-family`
- `--pamphlet-code-background`
- `--pamphlet-quote-background`
- `--pamphlet-workspace-title`
- `--pamphlet-badge`
- `--pamphlet-badge-emoji`
- `--pamphlet-badge-image`
- `--pamphlet-badge-placement`
- `--pamphlet-badge-anchor`
- `--pamphlet-badge-margin-x`
- `--pamphlet-badge-margin-y`
- `--pamphlet-badge-opacity`
- `--pamphlet-badge-size`

Variable meanings:

- `--pamphlet-background`: primary background for rendered content, empty view, and the window's base theme.
- `--pamphlet-foreground`: primary text colour.
- `--pamphlet-accent`: action/link/accent colour.
- `--pamphlet-muted-foreground`: subdued text colour across workspace UI and content.
- `--pamphlet-window-background`: optional single background override for sidebar and tab UI.
- `--pamphlet-font-family`: body and heading font for rendered content unless heading font is set.
- `--pamphlet-heading-font-family`: heading font for rendered content.
- `--pamphlet-monospace-font-family`: code/source/table monospace font for rendered content.
- `--pamphlet-code-background`: fenced code and inline code background.
- `--pamphlet-quote-background`: blockquote and quoted/callout-style box background.
- `--pamphlet-workspace-title`: workspace-only title label used inside Pamphlet's window title format.

Authoring principles:

- a good custom theme should be possible with `background`, `foreground`, and `accent`
- detailed themes can override specific values such as muted foreground, code background, quote background, borders, selection, and highlight.js classes
- ordinary CSS selectors are the detailed content styling mechanism

Sanctioned colour variables accept hex colours only: `#rgb`, `#rrggbb`, and `#rrggbbaa`. Raw content CSS can use normal CSS colour syntax.

Sanctioned font variables accept normal CSS font-family stacks as flat values. They are content-only. Native workspace UI keeps system typography.

`--pamphlet-appearance` accepts:

- `light`
- `dark`
- `adaptive`

`adaptive` means the theme supports both macOS appearances, usually with `@media (prefers-color-scheme: dark)`. The renderer maps `--pamphlet-appearance` to the browser `color-scheme` property.

Built-in and user app themes should set `--pamphlet-appearance`. Workspace overlays usually omit it and inherit the selected app theme's appearance. Do not infer appearance from background colour at runtime.

## Badge watermark

Badge defaults:

- `--pamphlet-badge-placement`: `bottom-left`
- `--pamphlet-badge-anchor`: `window`
- `--pamphlet-badge-margin-x`: `1.5rem`
- `--pamphlet-badge-margin-y`: `1.5rem`
- `--pamphlet-badge-opacity`: `0.12`
- `--pamphlet-badge-size`: `6rem`

Supported placements:

- `top-left`
- `top-right`
- `bottom-left`
- `bottom-right`

Supported anchors:

- `window`
- `content`

Badge content variables:

- `--pamphlet-badge: none`: disables an inherited badge.
- `--pamphlet-badge-emoji`: emoji or short text string.
- `--pamphlet-badge-image`: local image path using `url("...")`.

If both emoji and image are present, image wins. Built-in app themes are badge-free by default.

Badge image paths are local only:

- workspace `.pamphlet.css`: workspace-relative
- built-in app theme: relative to that built-in theme folder
- user app theme: relative to that user theme file's folder

Absolute paths and remote URLs are unsupported.

The badge is decorative only:

- no hit testing
- no accessibility label
- no layout effect on sidebar, tabs, or content

When a window-anchored badge uses a bottom placement, add bottom scroll headroom to the sidebar tree so final rows can scroll above the watermark.

## Theme loading and precedence

Add `ThemeStore` under `Pamphlet/Services/`.

Load order:

1. Built-in fallback variables.
2. Selected app theme CSS.
3. Workspace `.pamphlet.css`.

Workspace themes are overlays, not child themes:

- no `extends`
- no parent id
- no base app theme pinning
- later CSS wins

If a workspace wants a fixed look regardless of the selected app theme, it must set all relevant `--pamphlet-*` variables itself, including any dark-mode media block.

Workspace `.pamphlet.css` reloads only when the user chooses Refresh.

## App themes and Preferences

Built-in app themes:

- `default/theme.css`: `Default`, adaptive
- `default-dark/theme.css`: `Default (dark)`, fixed dark
- `default-light/theme.css`: `Default (light)`, fixed light
- `pro/theme.css`: `Pro`, adaptive if straightforward, otherwise intentionally fixed
- `fun/theme.css`: `Fun`, adaptive if straightforward, otherwise intentionally fixed

Built-in and user app themes are isolated namespaces. User themes do not override built-in themes, even when display names match. Preferences lists built-in and user themes in separate groups.

Persist the selected default app theme in `UserDefaults` as a discovered theme reference:

- `built-in::default/theme.css`
- `user::Banana Corp/theme.css`
- `user::Banana Corp.css`

Reject discovered or stored references with absolute paths, `..`, or path traversal outside the namespace root. Theme folders must use `theme.css` as the entrypoint.

If the stored theme reference no longer exists, use `built-in::default/theme.css` as the effective theme. Do not rewrite the stored reference until the user chooses a new default theme.

Preferences requirements:

- add a standard macOS Preferences window
- include a Theme control
- scan `~/Library/Application Support/Pamphlet/Themes/` when opened
- include a Reveal Themes Folder button
- show readable names derived from discovered files or folders
- persist the selected default app theme
- refresh all open workspace windows immediately when the default app theme changes
- do not edit, open, or show file paths for theme files
- do not watch the user themes folder for changes

User theme docs prefer folder themes because they scale to assets and uninstall cleanly. Direct `.css` files are supported as shorthand.

## Workspace title

Pamphlet owns the window title shape. Workspaces can customise only the workspace title value.

Default title with an active file:

```text
{workspaceTitle} - {fileName}
```

Default title without an active file:

```text
{workspaceTitle}
```

Default workspace title:

```text
{workspaceFolderName}
```

Workspace title customisation:

```css
--pamphlet-workspace-title: "Banana Corp";
```

`--pamphlet-workspace-title` is workspace-only. Ignore it in built-in and user app themes.

The selected view contributes only its file name to the window title. Relative paths are not shown. `window.representedURL` remains the active file URL when a file is selected, otherwise the workspace URL, preserving titlebar file proxy behaviour.

## Renderer application

Extend `RendererPayload` with:

- resolved theme variables
- raw app theme CSS
- raw workspace theme CSS

Renderer CSS cascade order:

1. renderer library CSS, including highlight.js
2. Pamphlet base renderer CSS
3. selected app theme CSS
4. workspace `.pamphlet.css`

Theme CSS applies consistently across markdown, source, table, and image views. It does not change based on which file is open. It still applies when `.pamphlet.css` itself is selected.

Keep highlight.js using the existing imported theme for this implementation. Themes can override highlight.js output through ordinary `.hljs-*` selectors. Do not add sanctioned syntax-token variables in this plan.

## Reference theme documentation

Add `docs/theme-reference.pamphlet.css` as the user-facing reference for:

- sanctioned `--pamphlet-*` variables
- renderer-owned public CSS hooks
- curated inherited markdown, HTML, CSS, and highlight.js hooks

The reference CSS is documentation-first. It should be copyable into a user theme folder or workspace as a starting point, but it is not the source of a built-in app theme.

The reference must guide casual themers by naming the markdown concept first and showing the CSS hook second.

Reference CSS inputs:

- `Pamphlet/Models/ThemeTokens.swift`: app-recognised `--pamphlet-*` variables.
- `renderer/src/themeHooks.ts`: renderer-owned public CSS hooks such as `.view`, `.markdown`, `.source`, `.table`, `.image`, and `.table-scroll`.
- `scripts/theme-reference-data.ts`: curated inherited markdown, HTML, highlight.js, and CSS documentation metadata.

Add a repeatable generation script that regenerates `docs/theme-reference.pamphlet.css` from those inputs.

Add a lightweight test that parses `docs/theme-reference.pamphlet.css` and confirms every documented sanctioned `--pamphlet-*` token is recognised by theme extraction.

The reference must include these renderer hooks:

- renderer view roots: `.view`, `.markdown`, `.source`, `.table`, `.image`
- markdown headings: `h1`, `h2`, `h3`, `h4`, `h5`, `h6`
- markdown flow content: `p`, `ul`, `ol`, `li`, `blockquote`, `hr`
- markdown inline content: `a`, `code`, `strong`, `em`
- markdown media and tables: `img`, `table`, `thead`, `tbody`, `tr`, `th`, `td`
- source/code surfaces: `pre`, `code`, `.hljs`, common `.hljs-*` token classes
- table view surfaces: `.table-scroll`

The reference must link to authoritative docs:

- CSS custom properties: <https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascading_variables/Using_custom_properties>
- `@media (prefers-color-scheme: dark)`: <https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-color-scheme>
- browser `color-scheme`, used internally from `--pamphlet-appearance`: <https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color-scheme>
- CSS `font-family`: <https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/font-family>
- CSS `url()`: <https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/url>
- CSS length values: <https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/length>
- CSS hex colours: <https://developer.mozilla.org/en-US/docs/Web/CSS/hex-color>
- CSS selectors/classes: <https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_selectors>
- highlight.js theme classes: <https://highlightjs.readthedocs.io/en/latest/theme-guide.html>

## Documentation

Update:

- `CONTEXT.md`: theme vocabulary.
- `docs/adr/0003-css-first-workspace-theming.md`: CSS-first theming decision.
- `README.md`: workspace theme file, user app theme folder, built-in theme names, Preferences theme selection, reference CSS, installed font guidance, and exact build/test commands.

## Implementation order

1. Add theme token/source models, theme reference validation, CSS variable extraction, defaults, and unit tests.
2. Add built-in theme folders and resource-copy project configuration.
3. Add `ThemeStore` loading for built-in app themes, user app themes, and workspace overlays.
4. Add the Preferences window default theme selector.
5. Add resolved theme state to `WorkspaceViewModel` and refresh/appearance reload hooks.
6. Apply resolved theme variables to workspace window SwiftUI/AppKit surfaces.
7. Extend `RendererPayload`, renderer TypeScript types, raw theme CSS injection, and CSS variable application.
8. Add badge watermark overlay for window/content anchors and sidebar tree bottom headroom.
9. Update window title workspace context while preserving `representedURL`.
10. Add theme reference inputs, generator, generated CSS reference, and validation test.
11. Update documentation and ADR.
12. Run the documented formatter.

## Scope

Included:

- Workspace-level theme overlay file `.pamphlet.css`.
- `.pamphlet.css` remains visible in the workspace tree and renders as CSS-highlighted source text when selected.
- Workspace theming still applies when `.pamphlet.css` itself is selected.
- Built-in app themes `default`, `default-dark`, `default-light`, `pro`, and `fun`.
- User app themes from Application Support.
- Preferences window default app theme selection.
- Workspace-window theming only; Preferences and other utility windows are not themed.
- OS dark/light support through CSS media-query variants.
- Native workspace window UI theming for sidebar, tab strip, empty view, selected rows, and borders.
- Renderer theming for markdown, safe inline HTML, source, table, image, code block surfaces, quoted boxes, links, and typography.
- Badge watermark as an emoji/string or local image.
- Workspace title customisation within the app-owned title format.
- Generated `docs/theme-reference.pamphlet.css`.

Invalid `--pamphlet-*` values fail soft in version one. A future non-modal, dismissable error surface can make critical theme errors visible without interrupting reading.

Not included:

- Theme editor dialog.
- Generative theme creation.
- CSS `@import` in theme files.
- Loading remote fonts or theme-provided bundled fonts.
- Live editing without pressing Refresh.
- Automatic reload of workspace `.pamphlet.css` without Refresh.
- Live watching of the user app themes folder.
- Non-modal theme error UI.
- Per-file theme overrides.
- Per-tab theme overrides.
- Sanctioned syntax-specific highlight.js token variables.
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

Run macOS app tests from Xcode using the `Pamphlet` scheme.

Manual implementation checks:

- Open `fixtures/sample-workspace/` with no workspace theme file and confirm `Default` follows macOS light/dark appearance.
- Open Preferences, change the default app theme, and confirm open workspace windows update immediately.
- Add `.pamphlet.css` to `fixtures/sample-workspace/` with only `--pamphlet-background`, `--pamphlet-foreground`, and `--pamphlet-accent`; press Refresh and confirm sidebar, content, links, tables, and code blocks are readable.
- Add an emoji badge anchored to `window`; confirm it overlays the sidebar and does not block clicks.
- Confirm final sidebar tree rows can scroll above a bottom-left window badge.
- Change the badge anchor to `content`; confirm it stays inside the content pane.
- Add a workspace title; confirm the window title changes and the titlebar file proxy still represents the selected file.
- Add an invalid workspace theme value; confirm valid values still apply and the app does not show a blank window.
- Regenerate `docs/theme-reference.pamphlet.css`; confirm the validation test passes.

## Testing

Restart/rebuild:

```sh
cd renderer
npm run build
cd ..
```

Then build and run the `Pamphlet` scheme in Xcode.

Click/check:

- Open `fixtures/sample-workspace/`.
- Open Preferences and select a different app theme; expect the default theme selection to persist after relaunch.
- Confirm the sidebar and content area use the selected default theme.
- Toggle macOS light/dark mode; expect `Default` to change without losing the open file.
- Create `.pamphlet.css` in the workspace with three colour variables; choose `File > Refresh`; expect the whole workspace window to change.
- Add `--pamphlet-workspace-title: "Banana Corp";`; choose `File > Refresh`; expect the window title to include the custom workspace title and current file name.
- Select another file; expect the file name in the title to update.
- Drag the titlebar file proxy to Finder; expect it to represent the selected file.
- Add `--pamphlet-badge-emoji`; expect the watermark to appear at the configured edge and stay behind interactions.

## Completion checklist

- [ ] Workspace theme files load and overlay the selected app theme.
- [ ] Built-in and user app themes share one CSS schema.
- [ ] Preferences selects and persists the default app theme.
- [ ] OS light/dark mode resolves through CSS media-query variants.
- [ ] Native workspace window UI and renderer content use the same resolved theme tokens.
- [ ] Badge watermark supports emoji, images, placement, margins, opacity, size, and window/content anchors.
- [ ] Window titles include workspace context without a trailing slash and preserve titlebar file proxy behaviour.
- [ ] Theme reference CSS is generated repeatably and validated against recognised theme tokens.
- [ ] Theme usage is documented in `README.md` and domain language is documented in `CONTEXT.md`.
- [ ] All builds, linters, and tests pass.
