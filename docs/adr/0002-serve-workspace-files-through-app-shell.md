# Serve workspace files through the app shell

The renderer does not get broad local `file://` access to the opened workspace. The native app shell reads primary file content, mediates local embedded asset requests through an app-controlled URL scheme, and supplies renderer URL policy so local links and assets are resolved consistently across markdown, safe inline HTML, text links, and table views. This keeps workspace file access, cache-busting refresh, and navigation decisions behind one native boundary instead of splitting them between Swift and WebKit.
