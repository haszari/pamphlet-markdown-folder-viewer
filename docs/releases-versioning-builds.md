# Releases, Versioning & Builds

Version numbers are maintained in multiple places. When bumping the version, update **all** locations consistently.

## Current Version

```
0.1.1
```

## Version Locations

### macOS App (Xcode)

| Key | File | Description |
|-----|------|-------------|
| `CFBundleShortVersionString` | `Pamphlet/App/Info.plist` | Marketing version shown to users |
| `CFBundleVersion` | `Pamphlet/App/Info.plist` | Build number (increment each build) |

### Renderer (npm)

| Key | File | Description |
|-----|------|-------------|
| `version` | `renderer/package.json` | Package version |
| `version` | `renderer/package-lock.json` | Lock file version (2 entries) |

## Versioning Scheme

- **Semantic Versioning**: `MAJOR.MINOR.PATCH`
  - `MAJOR`: Breaking changes
  - `MINOR`: New features, backwards compatible
  - `PATCH`: Bug fixes, backwards compatible
- **Pre-1.0**: Use `0.MINOR.PATCH` for initial development

## Build Number

- `CFBundleVersion` in `Info.plist` is the build number
- Increment with each build, even for same marketing version
- Reset to `1` when marketing version changes

## Update Procedure

1. Decide new version (e.g., `0.1.2`)
2. Update `Pamphlet/App/Info.plist`:
   - Set `CFBundleShortVersionString` to new version
   - Increment `CFBundleVersion` (or reset to `1` if new marketing version)
3. Update `renderer/package.json` version
4. Run `npm install` in `renderer/` to update `package-lock.json`
5. Commit all changes together

## Local Development Distribution

First build is for local development only:
- No notarisation
- No installer packaging
- No auto-update
- No App Store distribution
- Build directly from Xcode or command line