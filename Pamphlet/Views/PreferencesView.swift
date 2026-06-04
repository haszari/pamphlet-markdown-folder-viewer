import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var themeStore = ThemeStore.shared
    @State private var selectedReference = ThemeStore.shared.effectiveSelectedTheme.reference.rawValue

    private var builtInThemes: [AppTheme] {
        themeStore.appThemes.filter { $0.reference.namespace == .builtIn }
    }

    private var userThemes: [AppTheme] {
        themeStore.appThemes.filter { $0.reference.namespace == .user }
    }

    var body: some View {
        Form {
            Picker("Theme", selection: $selectedReference) {
                Section("Built in") {
                    ForEach(builtInThemes) { theme in
                        Text(theme.displayName).tag(theme.reference.rawValue)
                    }
                }
                if !userThemes.isEmpty {
                    Section("User") {
                        ForEach(userThemes) { theme in
                            Text(theme.displayName).tag(theme.reference.rawValue)
                        }
                    }
                }
            }
            .pickerStyle(.menu)

            HStack {
                Spacer()
                Button("Reveal Themes Folder") {
                    themeStore.revealUserThemesFolder()
                }
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            themeStore.reloadAppThemes()
            selectedReference = themeStore.effectiveSelectedTheme.reference.rawValue
        }
        .onChange(of: selectedReference) { _, newValue in
            guard let reference = ThemeReference(rawValue: newValue) else { return }
            themeStore.selectedThemeReference = reference
            AppCoordinator.shared.refreshThemesForOpenWorkspaces()
        }
    }
}

