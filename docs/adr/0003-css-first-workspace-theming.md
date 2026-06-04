# CSS-first workspace theming

## Status

Proposed

## Context

Pamphlet needs workspace-window theming that is easy to author from a few brand colours, can scale to detailed rendered-content customisation, and can theme native workspace window UI without turning the app shell into a browser CSS engine.

The same mechanism needs to support built-in app themes, user app themes, and workspace overlays. Theme authors also need a clear reference for the public renderer hooks exposed by Pamphlet, markdown rendering, safe inline HTML, and highlight.js.

## Decision

Use self-contained CSS files as the theme format.

Theme files define flat sanctioned `--pamphlet-*` variables for values Pamphlet understands, and may also include ordinary CSS selectors for rendered-content customisation.

Pamphlet extracts only sanctioned flat theme variables needed for workspace window UI and window behaviour. The renderer receives resolved variables plus raw theme CSS.

Workspace `.pamphlet.css` files are overlays layered after the selected app theme. They do not declare a parent theme, `extends`, or a base app theme.

Persist the selected app theme as a discovered theme reference such as `built-in::default/theme.css` or `user::Banana Corp/theme.css`, keeping built-in and user app themes in isolated namespaces.

Generate `docs/theme-reference.pamphlet.css` from checked-in theme token and renderer hook metadata so the public theming surface is repeatable and copyable.

## Consequences

Theme authors can start with a small number of variables and add normal CSS when they need detailed content styling.

Native workspace UI uses a limited, predictable theme contract instead of trying to evaluate arbitrary CSS.

Advanced content styling relies on documented renderer hooks and inherited markdown/HTML/highlight.js selectors.

Some CSS features are intentionally unsupported in sanctioned theme variables, including variable aliases, expressions, imports, and non-hex colours.

Theme CSS cannot use `@import` or load remote fonts. Theme authors can reference fonts already installed on the user's Mac.

Detailed syntax highlighting customisation uses ordinary highlight.js CSS selectors rather than sanctioned `--pamphlet-*` variables.
