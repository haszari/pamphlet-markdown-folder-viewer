# Tree load coordinator

## Goal

Consolidate workspace tree loading into one coordinator that owns queueing, priority changes, cancellation, retry, and node outcome state.

The current async tree work is functional, but load starts can come from root loading, background preload, foreground expansion, restored expansion replay, and refresh. That spreads scheduling policy across the view model and loader, making failure handling and tree regeneration harder to reason about.

## Approach

Make `WorkspaceTreeLoader` the single coordinator for tree load requests.

All callers submit load intent to the coordinator. The coordinator deduplicates paths, upgrades priority when the user asks for a folder, cancels stale generations on refresh, and emits one consistent outcome stream. The view model applies loader events to the visible tree but does not decide scheduling policy.

Directory load outcome is independent of load reason. Foreground and background reasons affect priority and UI emphasis while work is running; success and failure are durable node outcomes after work completes.

## Scope

- One coordinator owns:
  - root load
  - foreground directory expansion
  - restored expanded directory replay
  - background preload
  - refresh cancellation
  - path deduplication
  - priority promotion
  - failure outcome
- Tree regeneration rebuilds from the new root and replays useful work in this order:
  - restored expanded paths whose visible ancestors still exist
  - user-requested foreground expansions
  - background preload
- Expanded-path preservation checks full visible ancestry, not only root-level existence.
- Background and foreground load failures both settle nodes into `.failed`.
- The sidebar keeps its existing visual contract:
  - loading node rows show spinner and dimmed label
  - expanded unloaded/loading folders show an italic `Loading...` placeholder child
  - failed expanded folders show `Could not load folder`
  - background loading shows a subtle bottom-right tree-pane spinner
- Existing ignore behaviour remains unchanged:
  - ignored directories remain visible
  - ignored directories are not expanded, foreground-loaded, or background-preloaded
  - hidden dotfiles and hidden folders remain visible unless explicitly ignored

This plan does not change renderer file rendering, open-event routing, tabs, URL routing, file-size thresholds, markdown parsing, CSV parsing, image rendering, theme loading, or persisted scroll state.

## Implementation

1. Define load requests and queue ownership
  - Add a coordinator-owned request model for root, directory, restored expansion, background preload, and refresh-triggered work.
  - Keep request priority and final node outcome separate.
  - Make path deduplication and priority promotion coordinator responsibilities.

2. Move restored expansion replay into the coordinator
  - Pass preserved expanded paths into the new generation load.
  - After root and directory results arrive, enqueue restored descendants whose ancestors are visible and expandable.
  - Drop stale expanded paths when any ancestor is absent or non-expandable.

3. Unify failure handling
  - Emit failed directory outcomes for both background and foreground scans.
  - Preserve retry by allowing later foreground expansion to enqueue a failed path again.
  - Keep inline failure UI limited to expanded folders.

4. Enforce scheduling consistently
  - Route root, preload, foreground expansion, restored expansion, and refresh through the same queue.
  - Keep foreground work ahead of preload work.
  - Keep a single concurrency cap for active directory scans, with root load treated as generation setup.
  - Avoid duplicate scans for the same path within a generation.

5. Simplify the view model
  - Keep `WorkspaceViewModel` responsible for applying loader events to `tree`, `expandedDirectories`, and loading flags.
  - Remove scheduling decisions from `WorkspaceViewModel`.
  - Keep UI state on `FileNode` and transient task state inside the coordinator.

6. Expand tests
  - Cover background failure settling to `.failed`.
  - Cover foreground retry after a background failure.
  - Cover restored expanded path replay through nested folders.
  - Cover pruning expanded paths when an ancestor disappears.
  - Cover foreground priority over queued background preload.
  - Cover cancellation ignoring stale results after refresh.

## Verification

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

- Build and run the `Pamphlet` scheme in Xcode.

## Testing

Restart/rebuild:

```sh
cd renderer
npm run build
cd ..
```

Then build and run the `Pamphlet` scheme in Xcode.

Manual checks:

- Open a large workspace; expect root rows to appear before descendant preload completes.
- Expand a folder while background preload is active; expect that folder to load promptly and show row loading state.
- Close and reopen a workspace with expanded folders; expect restored expanded folders to show loading state until children appear.
- Use File > Refresh after expanding nested folders; expect still-existing expanded folders to restore and missing paths to stay collapsed.
- Make a folder unreadable, refresh or expand it, and expect loading state to settle into failure state instead of spinning indefinitely.
- Expand the failed folder again after making it readable; expect it to retry and load children.

## Completion checklist

- [ ] Tree load requests are coordinated through one scheduler.
- [ ] Foreground expansion, restored expansion, background preload, refresh, and cancellation share one dedupe and priority model.
- [ ] Failed background and foreground loads settle to `.failed`.
- [ ] Failed folders can retry on later foreground expansion.
- [ ] Restored expanded paths are replayed only when their visible ancestors still exist.
- [ ] Stale expanded paths are pruned during tree regeneration.
- [ ] Sidebar loading and failure states remain visually consistent.
- [ ] Loader and model tests cover priority, retry, restored expansion, stale results, and failure outcomes.
- [ ] All builds, linters, and tests pass.
