# Native markdown-first folder viewer

## Goal

Build Pamphlet, a view-only native macOS app for reading a folder of markdown-first content. The app opens folders and viewable files, shows the complete workspace tree on the left, and shows a focused read-only view surface on the right.

The first build prioritises native macOS behaviour, reliable refresh from disk, transparent rendering, and a clean renderer boundary. It does not include editing, workspace-wide search, preferences, custom themes, release packaging, sandboxing, or live file watching.

## Architecture

Use a native SwiftUI/AppKit app shell with a separate WebKit renderer package.

- The app shell owns windows, menus, keyboard commands, titlebar file proxy, Finder integration, workspace state, tree state, tabs, file reads, local asset serving, and system actions.
- The renderer package owns markdown rendering, sanitisation, code highlighting, table views, image display, content style, URL rewriting, and click metadata.
- The app shell serves workspace-local files to the renderer through an app-controlled URL scheme. The renderer does not get broad `file://` access.
- Renderer assets are generated from a separate Vite/TypeScript package and are not committed.

Architectural decisions are recorded in:

- [ADR 0001: Use a native macOS app shell with a WebKit renderer](../adr/0001-native-app-shell-with-webkit-renderer.md)
- [ADR 0002: Serve workspace files through the app shell](../adr/0002-serve-workspace-files-through-app-shell.md)

Reference docs:

- Apple SwiftUI: https://developer.apple.com/documentation/swiftui
- Apple AppKit `NSApplicationDelegate`: https://developer.apple.com/documentation/appkit/nsapplicationdelegate
- Apple WebKit `WKWebView`: https://developer.apple.com/documentation/webkit/wkwebview
- Apple WebKit `WKURLSchemeHandler`: https://developer.apple.com/documentation/webkit/wkurlschemehandler
- Apple Uniform Type Identifiers: https://developer.apple.com/documentation/uniformtypeidentifiers
- Vite: https://vite.dev/
- `markdown-it`: https://github.com/markdown-it/markdown-it
- `DOMPurify`: https://github.com/cure53/DOMPurify
- `highlight.js`: https://highlightjs.org/
- Papa Parse: https://www.papaparse.com/

## First-build scope

- Native macOS app named Pamphlet.
- macOS 14 minimum unless a macOS 15 API materially simplifies implementation.
- Local development distribution only: Xcode or command-line build, no notarisation, installer, auto-update, App Store, or sandboxing.
- Open events from Finder, dock icon drag/drop, File > Open, and equivalent macOS routing.
- File > Open accepts exactly one file or folder.
- Finder/dock multi-item open events open one workspace window per openable item.
- Openable items are folders and viewable files. Non-viewable files in open events are ignored.
- Opening a folder creates a workspace window with sidebar visible.
- Opening a viewable file creates a workspace from the file’s parent folder and starts in hidden-sidebar mode.
- Opening the same folder or file again creates another independent workspace window.
- In-window drag/drop is not required first build.
- Complete workspace tree shows all files and folders, including hidden dotfiles and hidden folders.
- Tree order is Finder-like: folders first, then files, localized case-insensitive sorting, with dotfiles included in normal order.
- Viewable files include markdown, UTF-8 text/code, raster images, SVG-as-source, CSV, and TSV.
- Viewable type detection uses system/library defaults first, with small targeted overrides for common misses such as `Makefile`, `.gitignore`, `.env`, and `Dockerfile`.
- HTML files render as source text, not as web pages.
- PDF, ZIP, video, audio, and other non-viewable files do not replace the current view.
- Double-click or context menu on a non-viewable tree file can open it with the system handler.
- Context menu actions are limited to reveal in Finder, open with system app where applicable, and close tab where applicable.
- Native macOS titlebar file proxy represents the current view selection when present, otherwise the workspace folder.
- Start document for folder-opened workspaces is root-level `readme.md`, `readme.markdown`, `index.md`, or `index.markdown`, case-insensitive. If none exists, start in empty view.
- Empty view has no explanatory placeholder content.

## View behaviour

- One unified WebKit-backed view surface renders all viewable files.
- Markdown dialect is GitHub-flavoured markdown plus footnotes.
- Safe static inline HTML in markdown can render; executable HTML is neutralised.
- Renderer libraries are `markdown-it`, markdown-it plugins for footnotes and task lists, `DOMPurify`, `highlight.js`, and Papa Parse.
- Code highlighting uses explicit fenced-code languages and obvious file extensions. Broad auto-detection is not part of the first build.
- Text decoding is UTF-8 only, including UTF-8 with BOM. Other encodings fail politely.
- CSV/TSV render as a static table view with a user-toggleable first-row header. No formulas, sorting, filtering, editing, type inference, or spreadsheet behaviours.
- Images render transparently. Oversized images fit the pane to avoid annoying overflow; no gallery, metadata panel, rotate control, or custom image tool.
- SVG files selected directly render as source text. SVGs referenced by markdown image syntax or safe image markup may display as images through the app-mediated asset route, without inlining SVG markup.
- Animated images animate if WebKit supports them.
- View zoom is per-window with native-feeling zoom in, zoom out, and reset.
- The first build ships one default content style only.
- The default content style is structured so custom styles can be added later.
- No theme picker, user CSS loading, preferences window, or per-workspace config in the first build.
- Conservative linkification outside markdown creates links only for obvious absolute URLs.
- Relative path guessing outside markdown is not part of the first build.

## Navigation and tabs

- Normal click on an in-workspace viewable markdown link replaces the current view selection.
- Cmd-click on an in-workspace viewable markdown link opens a new view tab in the same window.
- Normal click on an outside-workspace markdown link opens a new workspace window inferred from the target file’s parent folder and starts in hidden-sidebar mode.
- Absolute web URLs open in the system browser.
- Non-viewable links do not replace the current view. System open is available through explicit user actions.
- The renderer applies app-supplied URL policy consistently across markdown, safe inline HTML, text links, and table views.
- The renderer sends click metadata to the app shell; the app shell decides replacement, new tab, new window, or system action.
- Normal tree activation on a viewable file reuses the active view tab.
- Cmd-click tree activation on a viewable file opens a new view tab.
- If a viewable file is already open in another tab in the same window, activate that existing tab instead of creating a duplicate.
- Duplicate view tabs are not allowed within one window.
- The same file can be open in separate windows for separate scroll positions.
- Tabs represent view selections only. Folders and non-viewable files are not tabs.
- A window with one view tab does not show a visible tab strip.
- The tab strip appears only when there are at least two view tabs.
- Closing the last view tab returns the window to empty view and keeps the workspace window open.
- Cmd-W closes the active view tab when any tab exists, even if the tab strip is hidden. Cmd-W in empty view closes the window.
- Each tab remembers its scroll position in memory while the window is open.
- Back/forward navigation history is out of first-build scope, but tab state should be shaped so per-tab history can be added later.

## Refresh and loading

- No live file watching in the first build.
- Refresh is explicit and reliable.
- Refresh rescans the workspace tree and reloads the current view selection from disk.
- Refresh bypasses stale rendered content and stale local asset caches.
- Refresh preserves scroll position best-effort, but reliable reload wins over exact restoration.
- Large file guards prevent expensive views from freezing the app.
- Large file thresholds can be sensible implementation choices; current view selection remains unchanged until a new view is ready.
- Deferred progress UI appears only when loading is noticeably slow. No permanent status bar is required for first build.
- Missing renderer assets fail clearly during development rather than producing a blank view.

## App commands

- Cmd-O: open one file or folder.
- Cmd-R: refresh.
- Cmd-F: find within current view.
- Cmd-W: tab-first close, then window close in empty view.
- Cmd-Plus, Cmd-Minus, Cmd-0: per-window view zoom.
- Cmd-Shift-[ and Cmd-Shift-]: previous and next tab.
- Sidebar toggle is available through the menu with an idiomatic macOS shortcut if practical.
- Common actions are menu commands, not only toolbar or context-menu actions.

## Implementation order

1. Scaffold the native app shell
  - Create `Pamphlet.xcodeproj` with a macOS SwiftUI app target.
  - Set app name to Pamphlet.
  - Target macOS 14 unless implementation proves macOS 15 materially simplifies the app.
  - Add SwiftUI/AppKit app entry, main window management, commands, and basic app metadata.
  - Configure open event handling for folders and viewable files.
  - Keep App Sandbox, notarisation, installer packaging, and auto-update out of scope.

2. Scaffold the renderer package
  - Create `renderer/` as a self-contained Vite/TypeScript package.
  - Add `markdown-it`, footnote and task-list plugins, `DOMPurify`, `highlight.js`, and Papa Parse.
  - Add renderer build, test, and format scripts inside `renderer/package.json`.
  - Add generated renderer output to `.gitignore`.
  - Document the two-step full-stack build: build renderer assets, then build the app shell.

3. Connect app shell to renderer assets
  - Add a `WKWebView` wrapper for SwiftUI.
  - Load generated renderer assets from the app bundle.
  - Fail clearly if renderer assets are missing.
  - Define the Swift-to-renderer payload for file content, file kind, workspace token, workspace-relative path, render mode, refresh version, and URL policy.

4. Implement app-mediated workspace file serving
  - Add an app-controlled URL scheme with `WKURLSchemeHandler`.
  - Serve local render assets only after resolving them against the workspace and validating the path.
  - Use cache-busting refresh version tokens for local assets.
  - Keep primary file content reads in the app shell.
  - Keep renderer navigation decisions as click metadata sent back to Swift.

5. Build workspace and open-event state
  - Model workspace windows independently, even for the same folder.
  - Infer workspace from parent folder when opening a viewable file.
  - Support hidden-sidebar mode as per-window presentation state.
  - Implement openable item detection for folders and viewable files.
  - Ignore non-viewable files delivered through app open events.
  - Detect start document at workspace root using case-insensitive `readme` and `index` markdown names.

6. Build workspace tree and viewable type detection
  - Recursively scan the full workspace tree, including dotfiles and hidden folders.
  - Sort directories before files, then localized case-insensitive name order.
  - Use Uniform Type Identifiers and library defaults for viewable type detection.
  - Add targeted overrides for common text/code files missed by system detection.
  - Apply UTF-8 text decoding and binary/size guards.

7. Build the view surface render modes
  - Render markdown through `markdown-it` and sanitise with `DOMPurify`.
  - Render text and code as escaped source with extension/language-driven highlighting.
  - Render HTML files as source text.
  - Render CSV/TSV as static table views with first-row header toggle.
  - Render raster images with transparent fit behaviour.
  - Render SVG files as source text when selected directly.
  - Render markdown-referenced SVGs as image assets through the app-mediated route.
  - Apply one default content style across all view modes.

8. Add URL policy and navigation routing
  - Add a shared renderer URL resolver for markdown links/images, safe inline HTML links/images, text links, and table links.
  - Rewrite embedded workspace-local assets to app-mediated URLs.
  - Linkify only obvious absolute URLs outside markdown.
  - Send click metadata to the app shell.
  - Implement normal-click replacement, Cmd-click new tab, outside-workspace new window, and web URL system browser routing.

9. Add tabs, scroll state, and commands
  - Implement view tabs with no duplicates per window.
  - Hide the tab strip until at least two view tabs exist.
  - Close the last tab back to empty view.
  - Store tab scroll positions in memory.
  - Add Cmd-O, Cmd-R, Cmd-F, Cmd-W, tab navigation, zoom commands, and sidebar toggle.
  - Add context menus for tree nodes and tabs.
  - Set window title and titlebar file proxy from the current view selection or workspace folder.

10. Add refresh and large file handling
  - Refresh tree and active view from disk.
  - Bypass local rendered content and asset caches.
  - Preserve active tab and scroll position best-effort.
  - Add large file guards and deferred progress UI.
  - Ensure failed/cancelled loads leave the current view unchanged.

11. Add focused tests and documentation
  - Add Swift tests for workspace inference, start document detection, tree ordering, tab de-duplication, openable item handling, and routing decisions.
  - Add renderer tests for markdown sanitisation, markdown features, URL policy, linkification, CSV header toggle, content style application, and render mode selection.
  - Add a fixture workspace for manual and automated checks.
  - Add README build instructions for renderer build, app build, and common development flow.

## Verification

- Run renderer install/build using the documented `renderer/package.json` scripts.
- Run renderer tests using the documented renderer test script.
- Build the macOS app using the documented Xcode or `xcodebuild` command.
- Run Swift tests using the documented Xcode or `xcodebuild` command.
- Verify a clean checkout fails clearly if the native app is built before renderer assets exist.
- Verify fixture workspace behaviours:
  - folder open creates sidebar-visible workspace window
  - markdown file open creates hidden-sidebar workspace window from parent folder
  - image, text/code, CSV, and TSV file opens create hidden-sidebar workspace windows
  - PDF and ZIP open events are ignored
  - root readme/index markdown opens as start document
  - no start document shows empty view
  - full tree includes hidden dotfiles and hidden folders
  - tree order is folders first, localized case-insensitive
  - single-click non-viewable file keeps current view unchanged
  - double-click/context menu can open non-viewable file with system handler
  - titlebar proxy follows current view selection or workspace folder
  - markdown tables, footnotes, task lists, safe inline HTML, images, SVG images, fenced code, and links render correctly
  - HTML and SVG files selected directly render as source
  - CSV/TSV first-row header toggle works
  - Cmd-click in markdown and tree opens a new tab
  - repeated Cmd-click of an already-open file activates the existing tab
  - closing the final tab returns to empty view
  - Refresh reloads changed markdown and changed local images from disk
  - per-window zoom works across markdown, code, image, and table views

## Testing

Start fresh after implementation:

- Quit Pamphlet.
- From the repo root, build renderer assets using the documented renderer build command.
- Build the macOS app using the documented app build command.
- Open the app from Finder or Xcode.

Manual checks:

- Drag a folder onto the app icon. Expect one workspace window with the sidebar visible.
- Drag multiple folders/files onto the app icon. Expect one workspace window for each folder or viewable file, and no window for non-viewable files.
- Use File > Open on a folder. Expect the full tree, including dotfiles, to appear.
- Use File > Open on a markdown file. Expect its parent folder as the workspace and the sidebar hidden.
- Open a folder with root `README.md` or `index.md`. Expect that file to show automatically.
- Open a folder without root readme/index. Expect an empty view pane and no placeholder copy.
- Click markdown, code, image, and CSV files in the tree. Expect each to render in the current view.
- Single-click a PDF or ZIP in the tree. Expect the current view to remain unchanged.
- Double-click or right-click a PDF or ZIP in the tree. Expect it to open with the system handler or reveal in Finder.
- Click an in-workspace markdown link. Expect the current view to change.
- Cmd-click an in-workspace markdown link. Expect a new subtle tab.
- Click an outside-workspace markdown link. Expect a new hidden-sidebar window rooted at that target file’s parent folder.
- Click a web URL. Expect the default browser to open it.
- Cmd-click a viewable file in the tree. Expect a new tab, unless that file is already open in the window.
- Close tabs until one remains. Expect the tab strip to disappear.
- Close the final tab. Expect the window to stay open in empty view.
- Edit a markdown file or local image on disk, then use Refresh. Expect the changed content to appear.
- Use Cmd-Plus, Cmd-Minus, and Cmd-0. Expect the active window’s view surface to zoom.

## Completion checklist

- [ ] native macOS app shell opens folders and viewable files through idiomatic macOS open events
- [ ] renderer package builds WebKit assets from TypeScript and CSS without committing generated output
- [ ] app shell serves workspace-local render assets through an app-controlled URL scheme
- [ ] full workspace tree displays all files and folders, including hidden dotfiles and hidden folders
- [ ] viewable file detection handles markdown, UTF-8 text/code, images, CSV, and TSV
- [ ] unified view surface renders markdown, source text/code, images, and static table views
- [ ] markdown renderer supports GitHub-flavoured markdown, footnotes, task lists, safe inline HTML, images, fenced code, and tables
- [ ] navigation routes in-workspace links, outside-workspace links, web URLs, tree activation, and non-viewable files correctly
- [ ] view tabs support hidden single-tab mode, Cmd-click creation, no duplicates per window, close-to-empty, and per-tab scroll position
- [ ] explicit Refresh reliably reloads changed source files and local assets from disk
- [ ] app commands, context menus, titlebar file proxy, sidebar toggle, and per-window zoom feel native on macOS
- [ ] default content style is polished and structured for future custom styles
- [ ] all documented renderer builds, app builds, linters, and tests pass
