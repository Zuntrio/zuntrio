import Observation
import SwiftUI
import ZuntrioCore

@MainActor
@Observable
final class OnboardingModel {
    var isTrusted: Bool
    /// `spoken` is the shortcut in words, for VoiceOver.
    var examples: [(name: String, shortcut: String, spoken: String)]
    var openSettings: () -> Void = {}
    var finish: () -> Void = {}

    init(isTrusted: Bool, examples: [(name: String, shortcut: String, spoken: String)]) {
        self.isTrusted = isTrusted
        self.examples = examples
    }
}

/// First-run window: what Zuntrio does, why it needs Accessibility access,
/// what it never does, and the live permission state.
struct OnboardingView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to Zuntrio")
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Move and resize windows with your keyboard. Zuntrio lives in the menu bar.")
                        .foregroundStyle(.secondary)
                }
            }

            permissionCard

            VStack(alignment: .leading, spacing: 8) {
                Text("Try it").font(.headline).accessibilityAddTraits(.isHeader)
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    ForEach(model.examples, id: \.name) { example in
                        GridRow {
                            Text(example.name)
                            Text(example.shortcut).font(.body.monospaced()).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(example.name): \(example.spoken)")
                    }
                }
                Text("All actions and shortcut options are in the Zuntrio menu-bar menu.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Privacy").font(.headline).accessibilityAddTraits(.isHeader)
                Text("""
                    Zuntrio only reads and changes the position and size of the window you're working in. \
                    It never reads window contents, titles or keystrokes, and it makes no network connections \
                    unless you check for updates.
                    """)
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(model.isTrusted ? "Start Using Zuntrio" : "Later") { model.finish() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: model.isTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(model.isTrusted ? .green : .orange)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(model.isTrusted ? "Accessibility access granted" : "Accessibility access needed")
                    .font(.headline)
            }
            if model.isTrusted {
                Text("You're all set. Zuntrio can now arrange your windows.")
                    .foregroundStyle(.secondary)
            } else {
                Text("""
                    macOS requires Accessibility access before one app can move another app's windows. \
                    Turn on Zuntrio in the list; this window updates as soon as you do.
                    """)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Accessibility Settings") { model.openSettings() }
                Text("Or open \(AccessibilityPermission.manualPath) yourself.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
