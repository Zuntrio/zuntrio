import SwiftUI
import ZuntrioCore

struct SettingsView: View {
    let model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                general
                Divider()
                disable
                Divider()
                shortcuts
            }
            .padding(24)
        }
        .frame(width: 560, height: 680)
    }

    // MARK: - General

    private var general: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General").font(.title2.weight(.semibold))

            Toggle("Launch Zuntrio at login", isOn: Binding(
                get: { model.launchAtLogin != .disabled },
                set: { model.setLaunchAtLogin($0) }
            ))
            if model.launchAtLogin == .requiresApproval {
                HStack {
                    Text("Allow Zuntrio in System Settings → General → Login Items.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Open Login Items") { model.openLoginItemsSettings() }
                }
            }
            if let error = model.launchAtLoginError {
                Text(error).font(.callout).foregroundStyle(.red)
            }

            HStack(spacing: 6) {
                Image(systemName: model.isTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(model.isTrusted ? .green : .orange)
                Text(model.isTrusted ? "Accessibility access granted" : "Accessibility access needed")
                if !model.isTrusted {
                    Button("Open Accessibility Settings") { model.openAccessibilitySettings() }
                }
            }

            Text("Zuntrio \(model.version)").font(.callout).foregroundStyle(.secondary)
        }
    }

    // MARK: - Disable

    private var disable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Disable Shortcuts").font(.title2.weight(.semibold))
            Text("While off, Zuntrio's shortcuts go to the app you're using instead.")
                .font(.callout).foregroundStyle(.secondary)

            if let until = model.pausedUntilText {
                HStack {
                    Label("Off until \(until)", systemImage: "pause.circle")
                    Spacer()
                    Button("Turn Back On") { model.resume() }
                }
            } else {
                HStack {
                    Picker("Turn off for", selection: Binding(get: { model.pauseHours }, set: { model.pauseHours = $0 })) {
                        ForEach(Array(PauseSettings.hourRange), id: \.self) { hours in
                            Text(hours == 1 ? "1 hour" : "\(hours) hours").tag(hours)
                        }
                    }
                    .fixedSize()
                    Button("Turn Off") { model.pauseNow() }
                }
            }

            Text("Always off in these apps").font(.headline).padding(.top, 4)
            if model.disabledApps.isEmpty {
                Text("None. Add an app here, or use Disable Shortcuts in the menu while it's in front.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(model.disabledApps, id: \.bundleID) { app in
                    HStack {
                        Text(app.name)
                        Spacer()
                        Button("Remove") { model.removeDisabledApp(app.bundleID) }
                            .accessibilityLabel("Remove \(app.name)")
                    }
                }
            }
            Button("Add App…") { model.addDisabledApp() }
        }
    }

    // MARK: - Shortcuts

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts").font(.title2.weight(.semibold))

            HStack {
                Picker("Preset", selection: Binding(get: { model.preset }, set: { model.select($0) })) {
                    ForEach(ShortcutPreset.allCases, id: \.self) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .fixedSize()
                Spacer()
                Button("Restore Defaults") { model.restoreDefaults() }
            }
            Text("Click a shortcut to change it, then press the new keys. Esc cancels, ⌫ clears.")
                .font(.callout).foregroundStyle(.secondary)
            if model.isReadOnly {
                Text("These settings were saved by a newer version of Zuntrio. Changes won't be saved.")
                    .font(.callout).foregroundStyle(.orange)
            }

            ForEach(SettingsModel.sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title).font(.headline).padding(.top, 6)
                    ForEach(section.actions, id: \.self) { action in
                        if let row = model.rows[action] {
                            ShortcutRowView(row: row, model: model)
                        }
                    }
                }
            }
        }
    }
}

struct ShortcutRowView: View {
    let row: SettingsModel.Row
    let model: SettingsModel

    private var isRecording: Bool { model.recording == row.action }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Toggle(row.action.displayName, isOn: Binding(
                    get: { row.isEnabled },
                    set: { model.setEnabled($0, for: row.action) }
                ))
                .toggleStyle(.checkbox)
                Spacer()
                if isRecording {
                    Button { model.toggleRecording(row.action) } label: {
                        Text("Type shortcut…").frame(minWidth: 130)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button { model.toggleRecording(row.action) } label: {
                        Text(row.shortcut ?? "Record Shortcut")
                            .font(row.shortcut == nil ? .body : .body.monospaced())
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(.bordered)
                }
            }
            if let message = model.rowMessage, message.action == row.action {
                Text(message.text).font(.caption).foregroundStyle(.red)
            } else if let warning = row.warning {
                Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
        }
    }
}
