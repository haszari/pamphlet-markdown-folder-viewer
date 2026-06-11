# Large folder guardrails

## Goal

Make workspace opening responsive by moving all workspace tree loading off the main actor, showing immediate loading state, and progressively filling the tree from the root down.

The current implementation calls `refreshTree()` during workspace creation, and `refreshTree()` recursively scans every child directory through `scanChildren(of:relativePath:)`. Large repositories can block the main actor before the user can interact with the window. The root folder itself can also be large, so the root scan must not be treated as a cheap synchronous step.

## Approach

Use async top-down tree loading with priority for user-visible work.

Workspace opening starts an async root load immediately. While the root is loading, the window opens with the sidebar in a loading state and the start document can still render if one is already known. When root entries are available, the sidebar renders them and background preload continues through the rest of the tree.

Directory expansion is foreground work. If the user expands a folder before background preload has loaded it, that directory load is prioritised and its row shows loading state. Background preload continues only when it does not compete with foreground expansion and refresh work.

Refresh cancels active tree work and starts a fresh async top-down reload. The existing tree remains visible while the replacement root load is running. When the replacement root arrives, the tree is replaced atomically and expanded paths that still exist are preserved. Stale async results from older load generations are ignored.

## Scope

- All workspace tree loading becomes async:
  - opening a workspace starts async root loading
  - root loading shows visible sidebar progress immediately
  - expanding an unloaded directory starts or prioritises that directory load
  - background preload fills the whole non-ignored tree top-down after root entries are available
  - Refresh cancels active work and restarts from the root while keeping the previous tree visible until the new root is available
- Directory scans publish results back to the main actor after filesystem work completes.
- The sidebar shows visible loading state for:
  - root loading
  - foreground directory expansion
  - background preload still in progress
- Initial loading copy can be adjusted during implementation, with these defaults:
  - root loading: `Loading workspace...`
  - foreground subtree loading: `Loading...`
  - background preload: tiny spinner, with `Loading tree...` only if text is needed
  - foreground load failure: `Could not load folder`
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
- Ignored directories remain visible as folder nodes so the tree is transparent, but they are not expanded, foreground-loaded, or background-preloaded.
- Collapsing a directory while it is loading does not need to cancel the load. The result may be retained for later expansion or background preload.
- Failed foreground directory loads retry on later expansion.
- Hidden-sidebar windows still start tree loading, but tree work must not compete with opening and rendering the initial file.
- Loaded tree nodes can be retained in memory after background preload completes. Cache eviction is not part of this plan.

This plan does not change renderer file rendering, open-event routing, tabs, URL routing, file-size thresholds, markdown parsing, CSV parsing, image rendering, workspace restoration policy, or persisted scroll state.

## Implementation

1. Add tree loading state to `FileNode`
  - Represent unloaded directories, loading directories, loaded directories, ignored directories, and failed directory reads.
  - Keep existing fields for path, URL, display name, directory flag, and viewable flag.
  - Track whether a directory load is foreground expansion or background preload.
  - Keep durable per-directory UI state on the node.
  - Keep transient task bookkeeping out of `FileNode`.
  - Avoid requiring recursively-complete trees before showing parent nodes.

2. Add a workspace tree loader service
  - Move filesystem enumeration out of `WorkspaceViewModel`.
  - Add async methods that scan one directory level at a time.
  - Use a narrow scanner abstraction inside the loader. The scanner reads one directory level and returns filesystem descriptors; the loader owns async scheduling and maps descriptors into tree state events.
  - Preserve the existing sort order: directories first, then localized case-insensitive names.
  - Preserve viewable-file detection for immediate child files.
  - Detect symlink directories and do not recurse through them.
  - Emit typed incremental events such as root loading, root loaded, directory loading, directory loaded, directory failed, preload started, preload finished, and cancelled.
  - Directory-loaded events replace one directory's immediate children atomically.

3. Add load generation and cancellation
  - Store a generation ID for each full tree load.
  - Cancel all active scan and preload tasks on Refresh and window close.
  - Ignore results whose generation ID no longer matches the active tree generation.
  - Check generation both before events are emitted and before the view model applies events.
  - Keep foreground expansion cancellable without corrupting already-loaded sibling directories.
  - Expose explicit cancellation for window close, with model deinitialisation as a safety net.

4. Add global ignore matching
  - Add a small ignore policy object used by the loader.
  - Match ignored names by exact path component.
  - Apply ignore checks before reading a directory's children.
  - Mark ignored directory nodes as ignored instead of omitting them from the tree.

5. Make workspace opening async
  - Replace synchronous `refreshTree()` during `WorkspaceViewModel` creation with `startTreeLoad()`.
  - Show root loading state immediately.
  - Load the root directory in the background and publish root nodes when available.
  - Keep the window responsive while root entries are loading.
  - Keep start-document discovery independent from tree loading, using a targeted lookup for known root-level start document filenames.
  - In hidden-sidebar mode, open the initial file first and keep tree loading low priority.

6. Make expansion load or prioritise children
  - Update `toggleDirectory(_:)` so expanding an unloaded directory starts a foreground scan.
  - If background preload is already scanning that directory, promote the result to foreground state rather than starting duplicate work.
  - Keep collapse synchronous.
  - Preserve a directory load result even if the directory is collapsed before the result arrives.
  - Retry failed foreground loads on later expansion.
  - When a scan finishes, update only that directory subtree.

7. Add background preload
  - After root nodes are published, start top-down preload for non-ignored directories.
  - Preload by directory level so nearby branches become ready before deep descendants.
  - Avoid preloading ignored directories.
  - Avoid blocking foreground expansion results behind preload work.
  - Cap total concurrent directory scans with an initial implementation default of 4.
  - Prioritise foreground user-triggered loads over background preload within the cap.
  - Mark background preload as complete when all reachable, non-ignored directories are loaded or failed.

8. Make refresh restart loading
  - Increment the load generation.
  - Cancel outstanding root, foreground, and preload tasks.
  - Keep the old tree visible and show refreshing/loading state while replacement root loading runs.
  - Replace the tree atomically when the new root result arrives.
  - Preserve expanded paths where those paths still exist in the replacement tree, and quietly drop missing paths.
  - Start a fresh async root load and top-down preload.
  - Leave the active rendered file unchanged while tree reload is in progress.

9. Add minimal loading UI
  - Show root loading state in the sidebar before root nodes are available.
  - Show a subtle loading indicator on directory rows being foreground-loaded.
  - Show a subtle sidebar status while background preload is still running.
  - Do not add a permanent status bar.
  - Do not show fake percentage progress; directory totals are not known without walking the tree.

10. Add tests around loader behavior
  - Test root load is async and does not require recursive descendants before publishing root nodes.
  - Test expanding a directory loads only that directory's immediate children as foreground work.
  - Test background preload eventually fills non-ignored descendants.
  - Test foreground expansion is not blocked behind background preload.
  - Test ignored directories appear but are not loaded or preloaded.
  - Test foreground load failure is visible inline and retries on later expansion.
  - Test refresh cancels prior work, ignores stale results, restarts from root, and preserves active view selection.
  - Test refresh keeps the old tree visible until replacement root is available and preserves expanded paths that still exist.
  - Test hidden-sidebar windows start low-priority tree loading after opening the initial file.
  - Use fake scanner tests for loader orchestration: cancellation, generation filtering, foreground priority, scan coalescing, full-tree preload, and failure behaviour.
  - Use real temporary directory tests for filesystem integration: root entries, hidden files and folders, sorting, symlink directories, and ignored folders.

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
- Open a large repository containing a very large root directory, `node_modules`, `.git`, and build output folders.
- Confirm the window appears immediately with root loading state.
- Confirm root entries appear before deep child folders are fully preloaded.
- Confirm background preload fills the rest of the tree while the user can read and interact.
- Confirm expanding a normal unloaded folder prioritises that folder and shows row loading state.
- Confirm ignored folders are visible but do not load children.
- Confirm Refresh cancels in-flight work, keeps the old tree visible while the replacement root loads, preserves still-valid expanded folders, and does not replace the active rendered file while the tree reloads.

## Testing

Restart/rebuild:

```sh
cd renderer
npm run build
cd ..
```

Then build and run the `Pamphlet` scheme in Xcode.

Manual checks:

- Open `fixtures/sample-workspace`; expect the sidebar to load and normal folders to expand.
- Open a workspace with thousands of files at the root; expect the window to appear immediately with loading state, then root rows to appear.
- Open a large repo; expect the first readable document to remain usable while the tree continues loading.
- Expand a source folder before preload completes; expect that folder's children to appear without waiting for unrelated folders.
- Expand `node_modules`; expect it to stay visible but not populate children.
- Confirm dotfiles at root still appear unless their name is in the ignore list.
- Select a markdown file, expand a few folders, then use File > Refresh; expect the rendered file and old tree to stay visible until replacement root rows appear, with still-existing expanded folders preserved.

## Completion checklist

- [ ] Workspace opening no longer synchronously scans root or descendant directories.
- [ ] Root loading is async and shows immediate visible loading state.
- [ ] Directory expansion loads or prioritises children on demand.
- [ ] Background preload fills reachable non-ignored directories after root entries are available.
- [ ] Foreground expansion is not blocked behind background preload.
- [ ] Long-running scans can be cancelled by Refresh or window close.
- [ ] Refresh restarts async top-down loading while keeping the old tree visible until replacement root rows are available.
- [ ] Refresh preserves expanded paths that still exist after reload.
- [ ] Stale async results are ignored after cancellation or refresh.
- [ ] Default global ignore list prevents known high-volume folders from being loaded.
- [ ] Ignored directories remain visible in the sidebar.
- [ ] Hidden dotfiles and hidden folders remain visible unless explicitly ignored.
- [ ] Sidebar loading state covers root loading, foreground expansion, and background preload.
- [ ] Failed foreground directory loads retry on later expansion.
- [ ] Hidden-sidebar windows start tree loading without competing with initial file rendering.
- [ ] Loader orchestration is covered by fake scanner tests.
- [ ] Filesystem scanning behavior is covered by real temporary directory tests.
- [ ] All builds, linters, and tests pass.
