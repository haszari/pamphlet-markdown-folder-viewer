# Pamphlet

This context defines the language for a macOS app that lets users read markdown from folders and individual files.

## Language

**Markdown-first folder viewer**:
The app concept: a folder viewer optimised for reading markdown while also showing other viewable files.
_Avoid_: Markdown-only viewer, general file manager

**Pamphlet**:
The app name for the markdown-first folder viewer.
_Avoid_: Markdown Folder Viewer, product codename

**Workspace**:
A folder that acts as the root of markdown navigation. A workspace can be selected directly by the user or inferred from the parent folder of an opened markdown file.
_Avoid_: Project, root folder, repository

**Hidden-sidebar mode**:
A per-window workspace presentation where the sidebar is hidden and the opened markdown file is shown directly.
_Avoid_: Orphan viewer, external tab, loose file, standalone preview

**Outside-workspace markdown link**:
A markdown link whose resolved target is outside the current workspace. It opens in a new window whose workspace is inferred from the target file's parent folder and starts in hidden-sidebar mode.
_Avoid_: External markdown link, escaped link

**Markdown dialect**:
The markdown feature set the app renders as first-class content: GitHub-flavoured markdown plus footnotes, with static inline HTML allowed and executable HTML neutralised.
_Avoid_: CommonMark-only, raw HTML rendering

**Renderer libraries**:
The first-build web renderer libraries: `markdown-it` for markdown, markdown-it plugins for footnotes and task lists, `DOMPurify` for sanitisation, `highlight.js` for code highlighting, and Papa Parse for CSV/TSV parsing.
_Avoid_: Renderer-agnostic plan, custom markdown parser

**Code highlighting**:
Syntax highlighting driven by explicit fenced-code languages and obvious file extensions. The first build does not use broad auto-detection for arbitrary content.
_Avoid_: Guess-heavy highlighting, mandatory highlighting

**Viewable file**:
A file type the app can read directly inside the app, even when it is not markdown.
_Avoid_: Attachment, asset, unsupported document

**Viewable type detection**:
The app's decision about whether a file can be read directly. It should use system and library type detection first, with small targeted overrides for important misses.
_Avoid_: Giant extension allowlist, renderer-owned file typing

**Text decoding**:
The first-build text decoding rule: UTF-8 text is viewable, including UTF-8 with BOM. Other text encodings can fail politely.
_Avoid_: Encoding picker, legacy text decoding

**HTML file view**:
HTML files are viewed as source text in the first build, not rendered as web pages.
_Avoid_: Local web page view, arbitrary HTML execution

**SVG handling**:
SVG files are viewed as source text when selected directly. SVGs may display as images when referenced by markdown image syntax or safe image markup, without inlining SVG markup into the rendered document.
_Avoid_: Inline SVG execution, SVG page view

**Workspace tree**:
The complete file and folder tree for a workspace, including hidden dotfiles and hidden folders.
_Avoid_: Markdown tree, document tree, filtered tree

**Tree order**:
The Finder-like ordering of a workspace tree: folders before files, then localized case-insensitive name sorting, with hidden dotfiles included in normal order.
_Avoid_: Markdown-first order, repo order

**View selection**:
The viewable file currently shown in the view pane. Selecting a non-viewable file in the workspace tree does not change the view selection.
_Avoid_: Active file, current file

**System reveal**:
An action that shows a file, folder, or tab target in Finder.
_Avoid_: Open in explorer, reveal externally

**Titlebar file proxy**:
The native macOS titlebar representation of the current view selection or workspace, used for standard file actions such as reveal in Finder.
_Avoid_: Custom title widget, breadcrumb

**Window subject**:
The file or folder represented by the window title and titlebar file proxy. It is the current view selection when present, otherwise the workspace folder.
_Avoid_: Window context, active document

**View tab**:
A tab that contains a view selection. Folders and non-viewable files are not view tabs.
_Avoid_: File tab, document tab

**Tab history**:
Future per-tab navigation history for view selections visited inside that tab.
_Avoid_: Window history, global history

**Tab scroll position**:
The in-memory scroll position for a view tab while its window is open.
_Avoid_: Persisted scroll state, global scroll position

**Tab strip**:
The subtle tab UI shown only when a window has at least two view tabs.
_Avoid_: Always-on tabs, tab bar

**First view tab**:
The first view tab in a window. It establishes a view selection but does not show a visible tab strip by itself.
_Avoid_: Visible single tab, tabless special case

**Closing the last view tab**:
Closing the final view tab returns the window to empty view and keeps the workspace window open.
_Avoid_: Close window, hidden undeletable tab

**Table view**:
A static view for delimiter-separated text files. It can treat the first row as a header, but that header interpretation is user-toggleable.
_Avoid_: Spreadsheet, grid editor

**View surface**:
The unified read-only rendering area for viewable files. It presents markdown, text, code, images, and table views under one visual content style.
_Avoid_: Editor, web page, preview surface

**Content style**:
Styling applied only to rendered content inside the view surface. It does not style the sidebar, tabs, toolbar, menus, or other app chrome.
_Avoid_: App theme, window theme, chrome theme

**App theme**:
A workspace window's visual identity across workspace window UI and rendered content. Workspace window UI theming is limited to window surfaces, sidebar, tabs, selection, borders, watermark badge, and title context, while content style owns richer document presentation such as typography. Utility windows such as Preferences are not themed.
_Avoid_: Content style, CSS skin

**Theme variable**:
A sanctioned `--pamphlet-*` CSS custom property that the app understands as theme configuration. Theme variables are the stable contract for workspace window UI and default content styling, while ordinary CSS selectors remain an advanced content customisation mechanism.
_Avoid_: Arbitrary CSS option, hidden setting

**Flat theme token**:
A theme variable whose value is directly parseable by the app shell without resolving another CSS variable or expression. Theme variables are flat tokens; advanced CSS may use richer CSS features outside the sanctioned theme variable surface.
_Avoid_: Derived token, variable alias

**Opinionated theme surface**:
The principle that sanctioned theme variables use one clear spelling for each concept unless additional flexibility is necessary. Advanced variation belongs in ordinary content CSS, not in multiple equivalent app-facing token formats.
_Avoid_: Permissive theme API, many spellings

**Theme extraction**:
The app shell's limited reading of sanctioned theme variables from theme CSS. It extracts app-facing values for workspace window UI and window behaviour, while the renderer remains responsible for interpreting full CSS.
_Avoid_: CSS engine, stylesheet evaluation

**Adaptive theme**:
A single app theme file that uses standard CSS colour-scheme features, especially `@media (prefers-color-scheme: dark)`, to respond to macOS light and dark appearance.
_Avoid_: Light/dark theme pair, generated theme variant

**Workspace theme overlay**:
A workspace's `.pamphlet.css` file layered after the selected app theme. It is not a child theme and does not name a parent; later CSS wins.
_Avoid_: Theme inheritance, theme extension, parent theme

**Workspace title**:
The workspace label shown inside the app-owned window title format. It can be customised by workspace theme CSS, but the window title shape remains owned by Pamphlet.
_Avoid_: Window title template, title format

**Theme CSS**:
The shared self-contained file format for built-in app themes, user app themes, and workspace theme overlays. All theme CSS follows the same rules: sanctioned flat theme variables configure app-recognised values, and ordinary CSS selectors customise rendered content.
_Avoid_: App theme format, workspace theme format

**Theme reference CSS**:
The generated, copyable CSS reference that documents Pamphlet's sanctioned theme variables and renderer styling hooks. It is documentation, not the source of a built-in app theme.
_Avoid_: Built-in theme, generated app theme

**Transparent rendering**:
Rendering that preserves the source content's apparent meaning and avoids clever transformations. Usability adjustments, such as fitting oversized images to the pane, should be simple and preferably user-configurable.
_Avoid_: Smart rewriting, enhanced rendering

**Default content style**:
The built-in content style used by every view surface in the first build. It should be structured so custom content styles can be added later.
_Avoid_: Theme picker, custom CSS override

**Preferences window**:
A dedicated settings UI for changing app behaviour such as the default app theme.
_Avoid_: Settings surface, options panel

**In-workspace viewable link**:
A link whose resolved target is a viewable file inside the current workspace. A normal click replaces the current view selection, while Cmd-click opens a new view tab in the same window.
_Avoid_: Internal markdown link, app link

**Tree activation**:
Selecting a viewable file from the workspace tree. A normal click replaces the active view tab, while Cmd-click opens a new view tab.
_Avoid_: Sidebar navigation, file selection

**Duplicate view tab**:
A second tab for the same file in the same window. Duplicate view tabs are not allowed within one window.
_Avoid_: Split tab, repeated tab

**Workspace window**:
A window showing one workspace. Multiple workspace windows can point at the same folder and remain independent.
_Avoid_: Project instance, folder instance

**Platform target**:
The macOS version range the app is built for. The first build favours recent macOS APIs, with macOS 14 as the baseline unless a materially better macOS 15 API simplifies the product.
_Avoid_: Legacy macOS support, broad compatibility mode

**Local development distribution**:
The first-build distribution target: local run from Xcode or command-line build, without notarisation, installer packaging, auto-update, or App Store distribution.
_Avoid_: Release packaging, App Store build

**Sandboxing**:
The macOS App Sandbox and related security-scoped access work. It is deferred until distribution is being prepared.
_Avoid_: First-build sandboxing, premature bookmark persistence

**App shell**:
The native macOS app target that owns app metadata, resources, entitlements, file opening, window chrome, signing, and packaging.
_Avoid_: Pure package app, command-line app

**Renderer asset pipeline**:
The web build pipeline that bundles the renderer, markdown libraries, syntax highlighting, and content style assets for use inside the app shell.
_Avoid_: Ad hoc script tags, remote renderer

**Renderer package**:
The self-contained web package that builds renderer assets consumed by the app shell.
_Avoid_: Root npm app, embedded script collection

**Full-stack build**:
The local build flow that builds renderer assets and then builds the native app shell. It may be documented as explicit steps before it is wrapped in one script.
_Avoid_: Committed generated renderer assets, manual asset copying

**Missing renderer assets**:
A developer setup failure where the app shell cannot find built renderer output. It must fail clearly rather than showing a blank view.
_Avoid_: Blank renderer, silent fallback

**Renderer behaviour**:
Rendering and classification behaviour owned by the renderer package, such as markdown sanitisation, table display, link classification payloads, and content style application.
_Avoid_: App shell behaviour, native window behaviour

**Remote render asset**:
A network resource referenced by viewable content and displayed inside the view. Remote images can render, but executable remote code is not part of the markdown dialect.
_Avoid_: Remote theme, remote script

**Local render asset**:
A local file referenced by viewable content and displayed inside the view. The app shell mediates these reads rather than giving the renderer broad local file access.
_Avoid_: Arbitrary file URL access

**Renderer URL policy**:
The app-supplied context that tells the renderer how to turn local links and embedded assets into app-mediated URLs or click metadata. The renderer applies the policy consistently across markdown, safe inline HTML, text links, and table views.
_Avoid_: Ad hoc link rewriting, renderer-owned file access

**Conservative linkification**:
Automatic link creation for obvious absolute URLs in text-like views. Relative path guessing is not part of first-build linkification outside markdown.
_Avoid_: Path guessing, code-specific link rules

**App shell behaviour**:
Native macOS behaviour owned by the app shell, such as workspace inference, tree ordering, tab state, menu commands, and system file actions.
_Avoid_: Renderer behaviour, web view styling

**Start document**:
The viewable file opened automatically when a workspace window is created from a folder.
_Avoid_: Default file, landing page, home document

**Empty view**:
A window state with no view selection and no view tab. It shows the workspace tree without explanatory placeholder content in the view pane.
_Avoid_: Empty-state copy, welcome panel

**Refresh**:
A user-triggered reload that rescans the workspace tree and reloads the current view selection from disk, bypassing stale rendered content and stale asset caches.
_Avoid_: Live reload, auto-watch, background sync

**Refresh position**:
The best-effort scroll location restored after refresh. It must not prevent a reliable reload from disk.
_Avoid_: Persistent scroll state, exact scroll restore

**View find**:
Search within the current view surface only.
_Avoid_: Workspace search, tree filter, search index

**App command**:
A menu and keyboard action for common viewer operations. First-build commands cover opening, refresh, view find, tab navigation, tab/window closing, and sidebar visibility.
_Avoid_: Toolbar-only action, hidden shortcut

**Tab-first close**:
The close command closes the active view tab when a view tab exists, even if the tab strip is hidden. In empty view, the close command closes the window.
_Avoid_: Always-close-window, protected single tab

**Open event**:
A macOS file or folder open request from Finder, the dock icon, File > Open, or equivalent system routing.
_Avoid_: Import, in-window drop target

**Openable item**:
A folder or viewable file that can create a workspace window from an open event. Non-viewable files in open events are ignored.
_Avoid_: Any file, system-opened item

**Single open picker**:
The File > Open picker accepts exactly one file or folder. Multi-item open events from Finder or the dock can still open one workspace window per item.
_Avoid_: Multi-select picker, batch import

**View zoom**:
Native-feeling per-window zoom in and zoom out for the view surface.
_Avoid_: Per-format zoom controls, custom zoom mode

**Large file guard**:
A safeguard that prevents expensive views from freezing the app. It can use sensible thresholds, progress, or cancellation while leaving the current view selection unchanged until a new view is ready.
_Avoid_: Unlimited rendering, eager full render

**Deferred progress**:
Progress UI that appears only after view loading is noticeably slow. It should not add permanent chrome unless another app-level need exists.
_Avoid_: Always-visible status bar, eager loading screen

## Example dialogue

Developer: "If a user opens a single markdown file from Finder, is that outside the workspace model?"
Domain expert: "No. Treat the file's parent folder as the workspace, open the file directly, and hide the sidebar."

Developer: "Can the user reveal the sidebar in a file-opened window?"
Domain expert: "Yes. Sidebar visibility is a per-window presentation setting and does not change the workspace."

Developer: "What happens when a workspace file links to a markdown file in a sibling folder?"
Domain expert: "Open it in a new window, infer that file's parent folder as the workspace, and keep the sidebar hidden."

Developer: "What markdown should the renderer target first?"
Domain expert: "Render GitHub-flavoured markdown plus footnotes, allow safe static HTML, and neutralise executable HTML."

Developer: "Should the sidebar only show markdown files?"
Domain expert: "No. Show the full workspace tree, including hidden dotfiles and hidden folders. The view decides whether a file is viewable in-app."

Developer: "Should dotfiles be grouped separately?"
Domain expert: "No. Use Finder-like tree order and include dotfiles in normal order."

Developer: "What happens when a user single-clicks a non-viewable file in the tree?"
Domain expert: "Keep the view selection unchanged. Use double-click or the context menu for system actions."

Developer: "Should reveal in Finder only be available from context menus?"
Domain expert: "No. Use the native macOS titlebar file proxy where available."

Developer: "Should the window title show the workspace name or current file?"
Domain expert: "Show the current view selection when one exists; otherwise show the workspace folder."

Developer: "Can a folder or non-viewable file become a tab?"
Domain expert: "No. Tabs represent view selections only."

Developer: "Should the tab strip be visible when there is one tab?"
Domain expert: "No. Show the tab strip only when there are at least two view tabs."

Developer: "Does the first build need back and forward navigation?"
Domain expert: "No. If navigation history is added later, it belongs to each tab rather than the whole window."

Developer: "Is a CSV view a spreadsheet?"
Domain expert: "No. It is a static table view, and the user can toggle whether the first row is treated as a header."

Developer: "Should code files use a separate native editor view?"
Domain expert: "No. Use one view surface for viewable files so theming remains consistent."

Developer: "Does a content style affect the whole app?"
Domain expert: "No. A content style only styles rendered content inside the view surface."

Developer: "Should the renderer make clever changes to content?"
Domain expert: "No. Prefer transparent rendering, with simple usability adjustments that can become preferences."

Developer: "Does the first build need custom content themes?"
Domain expert: "No. Use one default content style, structured so custom content styles can be added later."

Developer: "Does the first build need a Preferences window?"
Domain expert: "No. Do not add a settings surface until there are mature settings to expose."

Developer: "Does Cmd-click only apply to markdown files?"
Domain expert: "No. Cmd-click opens any in-workspace viewable link in a new view tab."

Developer: "Does clicking a viewable file in the tree create a tab?"
Domain expert: "A normal click reuses the active view tab. Cmd-click opens a new view tab."

Developer: "Can the same file be open twice in the same window?"
Domain expert: "No. Open another window for the same workspace if separate scroll positions are needed."

Developer: "What happens if the user opens a folder that is already open?"
Domain expert: "Create another independent workspace window for the same folder."

Developer: "Does the app restore previous workspace windows on launch?"
Domain expert: "No. The first build starts clean and keeps only global settings."

Developer: "Should the first build support older macOS versions?"
Domain expert: "No. Favour recent macOS APIs, using macOS 14 as the baseline unless macOS 15 materially simplifies the app."

Developer: "Does the first build need App Sandbox support?"
Domain expert: "No. Defer sandboxing until distribution is being prepared."

Developer: "Is this a pure Swift package app?"
Domain expert: "No. Use a native app shell, with a renderer asset pipeline for the WebKit-rendered content."

Developer: "Does the repo root own the renderer's npm package?"
Domain expert: "No. Keep the renderer as a separate package that the native app shell consumes as built assets."

Developer: "Should built renderer assets be committed?"
Domain expert: "No. The full-stack build should regenerate renderer assets whenever they are needed."

Developer: "What happens if the app is built before renderer assets exist?"
Domain expert: "Fail clearly instead of showing a blank view."

Developer: "Where should rendering rules be tested?"
Domain expert: "Test renderer behaviour in the renderer package, and app shell behaviour in Swift tests."

Developer: "Can markdown load remote images?"
Domain expert: "Yes. Use browser-like safe defaults: display remote images, but do not execute remote scripts."

Developer: "Can the renderer freely read local file URLs?"
Domain expert: "No. The app shell mediates local render assets."

Developer: "Who decides how local URLs inside rendered content are resolved?"
Domain expert: "The app shell configures the renderer URL policy; the renderer applies it uniformly when creating links and embedded assets."

Developer: "Should text and code views guess relative file links?"
Domain expert: "No. Outside markdown, linkify only obvious absolute URLs in the first build."

Developer: "Which file opens automatically when a folder workspace opens?"
Domain expert: "Use a root-level markdown readme or index file, matching `.md` or `.markdown` case-insensitively. If neither exists, start with no view selection."

Developer: "Should the app update automatically when files change on disk?"
Domain expert: "No. The first build uses an explicit refresh, and that refresh must reliably reload from disk."

Developer: "Can refresh reuse cached preview assets?"
Domain expert: "No. Refresh must reload changed source files and assets from disk."

Developer: "Should refresh preserve scroll position?"
Domain expert: "Preserve it best-effort, but reliable reload is more important than exact scroll restoration."

Developer: "Does the first build need workspace-wide search?"
Domain expert: "No. It only needs find within the current view."

Developer: "Do core viewer actions need menu entries and hotkeys?"
Domain expert: "Yes. Common actions should be app commands, not only visible controls."

Developer: "Should the view support zoom?"
Domain expert: "Yes. Support native-feeling per-window zoom in and zoom out across the view surface."

Developer: "Should the app try to render any file regardless of size?"
Domain expert: "No. Use sensible large file guards so large files cannot freeze the app."

Developer: "Should loading a large file replace useful content with a progress screen?"
Domain expert: "No. Keep the current view visible and show progress only if loading is noticeably slow."
