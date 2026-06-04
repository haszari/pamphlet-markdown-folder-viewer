# Pamphlet

Pamphlet is a native macOS, markdown-first folder viewer. The macOS app shell is SwiftUI/AppKit, and the read-only view surface is rendered by a separate WebKit renderer package.

## Setup

Install development dependencies:

- macOS
- Xcode, including the macOS SDK
- Node.js
- npm

Install renderer dependencies:

```sh
cd renderer
npm install
```

## Build

Build the renderer first:

```sh
cd renderer
npm run build
```

Then open `Pamphlet.xcodeproj` in Xcode, select the `Pamphlet` scheme, and build.

## Launch

Launch the app from Xcode using the `Pamphlet` scheme.

## Use it
- `File > Open…` a markdown file or folder of markdown + code. 
- Drag folders or files onto the app icon to open.

## Automated tests

Run renderer tests:

```sh
cd renderer
npm test
cd ..
```

Run macOS app tests from Xcode using the `Pamphlet` scheme.

Generated renderer output in `renderer/dist/` is not committed. If the app build cannot find renderer assets, build the renderer package first.
