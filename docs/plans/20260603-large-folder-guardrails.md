# Large folder guardrails

## Goal

Make large workspace opening responsive by replacing eager recursive tree scanning with lazy directory loading, cancellable refresh work, and a global ignore list for known high-volume folders.

The current implementation calls `refreshTree()` during workspace creation, and `refreshTree()` recursively scans every child directory through `scanChildren(of:relativePath:)`. Large repositories can block the main actor before the user can interact with the window.

## Scope

- Workspace tree loading becomes shallow by default:
  - opening a workspace scans only the root directory
  - expanding a directory scans that directory's immediate children
  - collapsing a directory keeps already-loaded children in memory
  - Refresh clears and reloads visible/expanded directories only
- Directory scans run through cancellable async work and publish results back to the main actor.
- The sidebar shows lightweight loading state for a directory while its children are being read.
- The scanner applies a global ignore list before reading ignored directories.
- The default ignore list is:
  - `.git`
  - `node_modules`
  - `.next`
  - `.turbo`
  - `.cache`
  - `.parcel-cache`
  - `dist`
  - `build`
  - `DerivedData`
  - `.venv`
  - `vendor`
- Hidden dotfiles and hidden folders remain visible unless they are explicitly ignored by the global ignore list.
- Ignored directories remain visible as folder nodes so the tree is transparent, but they are not auto-expanded or scanned.

This plan does not change renderer file rendering, open-event routing, tabs, URL routing, file-size thresholds, markdown parsing, CSV parsing, or image rendering.

## Implementation

1. Add tree loading state to `FileNode`
  - Represent unloaded directories, loading directories, loaded directories, ignored directories, and failed directory reads.
  - Keep existing fields for path, URL, display name, directory flag, and viewable flag.
  - Avoid storing recursively-complete trees as the default state.

2. Add a workspace tree scanner service
  - Move filesystem enumeration out of `WorkspaceViewModel`.
  - Add a method that scans one directory level at a time.
  - Preserve the existing sort order: directories first, then localized case-insensitive names.
  - Preserve viewable-file detection for immediate child files.
  - Detect symlink directories and do not recurse through them.

3. Add global ignore matching
  - Add a small ignore policy object used by the scanner.
  - Match ignored names by exact path component.
  - Apply ignore checks before reading a directory's children.
  - Mark ignored directory nodes as ignored instead of omitting them from the tree.

4. Make expansion load children
  - Update `toggleDirectory(_:)` so expanding an unloaded directory starts a scan task.
  - Keep collapse synchronous.
  - If a scan is already running for a directory, expansion reuses that task state.
  - When a scan finishes, update only that directory subtree.

5. Make refresh cancellable and bounded
  - Track active scan tasks in `WorkspaceViewModel`.
  - Cancel outstanding scan tasks before starting refresh.
  - Reload root immediately.
  - Reload only directories that are still expanded after root reload.
  - Leave the active rendered file unchanged while tree refresh is in progress.

6. Add minimal loading UI in the sidebar
  - Show a subtle spinner or progress row only for directories whose load is still pending after a short delay.
  - Do not add a permanent status bar.
  - Keep ignored directories visually normal except for disabled expansion.

7. Add tests around scanner behavior
  - Test root-only initial scan.
  - Test expanding a directory loads only that directory's immediate children.
  - Test ignored directories appear but are not scanned.
  - Test hidden files remain visible.
  - Test sorting remains folders first, localized case-insensitive.
  - Test refresh cancels prior scans and preserves active view selection.

## Verification

- Run renderer tests with:

```sh
cd renderer
npm test
cd ..
```

- Run the macOS app tests with:

```sh
xcodebuild -project Pamphlet.xcodeproj -scheme Pamphlet -configuration Debug test
```

- Build the renderer before launching the app:

```sh
cd renderer
npm run build
cd ..
```

- Build the macOS app from Xcode using the `Pamphlet` scheme.
- Open a large repository containing `node_modules`, `.git`, and build output folders.
- Confirm the window appears before deep child folders are scanned.
- Confirm expanding a normal folder loads its direct children.
- Confirm ignored folders are visible but do not load children.
- Confirm Refresh is responsive and does not replace the active rendered file while the tree reloads.

## Testing

Restart/rebuild:

```sh
cd renderer
npm run build
cd ..
```

Then build and run the `Pamphlet` scheme in Xcode.

Manual checks:

- Open `fixtures/sample-workspace`; expect the root tree to appear and normal folders to expand.
- Open a large repo; expect the window to appear without waiting for the entire repo to be indexed.
- Expand a small source folder; expect child files to appear after expansion.
- Expand `node_modules`; expect it not to recursively populate.
- Confirm dotfiles at root still appear unless their name is in the ignore list.
- Select a markdown file, then use File > Refresh; expect the rendered file to stay visible while the sidebar updates.

## Completion checklist

- [ ] Workspace opening no longer eagerly scans every descendant directory.
- [ ] Directory expansion loads children on demand.
- [ ] Long-running scans can be cancelled by Refresh or window close.
- [ ] Default global ignore list prevents known high-volume folders from being scanned.
- [ ] Ignored directories remain visible in the sidebar.
- [ ] Hidden dotfiles and hidden folders remain visible unless explicitly ignored.
- [ ] Sidebar loading state appears only when a directory load is noticeably slow.
- [ ] Scanner behavior is covered by focused tests.
- [ ] All builds, linters, and tests pass.
