# Rename app to Pamphlet

## Goal

Rename the app from `Markdown Folder Viewer` to `Pamphlet` before folder theming work starts.

## Scope

Included:

- User-visible app name, app menu labels, help menu labels, and recent-document display context.
- Xcode scheme, target, product, bundle display name, and project-visible groups where practical.
- Swift module references and test target references required by the rename.
- Renderer package name and documentation references.
- Application Support folder naming for future app themes.
- Existing terminology in `CONTEXT.md` where it describes the app name.
- Bundle identifier and product identity.
- Baseline `.gitignore` coverage for the macOS/Xcode and Node/Vite repo.

Not included:

- Theme implementation.
- Workspace theme files.
- App theme files.
- Signing, notarisation, installer packaging, auto-update, or App Store distribution.
- Migration of existing user defaults or recent documents.
- Removing already-tracked generated files or dependencies from git.

## Implementation order

1. Add baseline `.gitignore` coverage for Xcode, macOS, Node/Vite, logs, env files, and generated renderer output.
2. Rename Xcode-visible app identity: scheme, target/product display name, bundle identifier, app menu labels, help labels, and Info.plist display name.
3. Rename source folders, project groups, Swift module references, and test imports only where needed by the build.
4. Rename renderer package metadata and documentation references.
5. Update Application Support naming constants used by future app-theme loading if they already exist during implementation.
6. Run the documented formatter where applicable.

## Verification

Run during implementation:

```sh
cd renderer
npm run build
npm run format
cd ..
```

Run macOS app tests from Xcode using the `Pamphlet` scheme after the rename.

Manual implementation checks:

- Open the project in Xcode and confirm the runnable scheme is named `Pamphlet`.
- Build and run the app.
- Confirm the app menu says `Pamphlet`.
- Confirm `File > Open…` still opens a workspace.
- Confirm recent documents still display and open.
- Confirm the titlebar file proxy still represents the selected file.

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
- Confirm the app launches as `Pamphlet`.
- Confirm menus use `Pamphlet`.
- Confirm the bundle identifier is renamed for the app target.
- Select `README.md`; expect the file to render.
- Drag the titlebar file proxy to Finder; expect it to represent the selected file.

## Completion checklist

- [ ] User-visible app identity is Pamphlet.
- [ ] Xcode scheme and build settings use Pamphlet where required.
- [ ] Bundle identifier and product identity use Pamphlet.
- [ ] Baseline `.gitignore` covers generated files, local state, dependencies, logs, and env files.
- [ ] Swift app and test targets build after the rename.
- [ ] Renderer metadata and documentation use Pamphlet.
- [ ] Existing open-workspace behaviour is unchanged.
- [ ] All builds, linters, and tests pass.
