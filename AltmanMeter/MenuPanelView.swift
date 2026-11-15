import SwiftUI
import WidgetKit

/// The panel that opens from the menu bar item. The top is the same card as
/// the medium desktop widget; below it are the settings and buttons.
struct MenuPanelView: View {
    let model: LiveStatsModel
    let loginItem: LoginItemController

    @AppStorage(BarDisplay.storageKey) private var display = BarDisplay.defaultValue
    @State private var widgetRefreshRequested = false

    var body: some View {
        let stats = model.stats
        let mood = Mood(stats: stats)

        VStack(alignment: .leading, spacing: 12) {
            WidgetCard(stats: stats, pokes: model.pokes, poke: .perform { model.poke() }, live: true)
                .padding(16)
                .frame(height: 170)
                .background(CardBackground(mood: mood))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )

            Text("Click his face to poke him.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, -4)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Menu bar shows")
                    Spacer()
                    Picker("Menu bar shows", selection: $display) {
                        ForEach(BarDisplay.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                Toggle("Open at login", isOn: Binding(
                    get: { loginItem.isOn },
                    set: { loginItem.setEnabled($0) }
                ))
                .toggleStyle(.switch)

                if loginItem.needsApproval {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Needs your approval in Login Items.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open Login Items…") { loginItem.openLoginItemsSettings() }
                    }
                    .font(.caption)
                }
                if let error = loginItem.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 4)

            Divider()

            HStack {
                Button {
                    WidgetCenter.shared.reloadTimelines(ofKind: AppConstants.widgetKind)
                    widgetRefreshRequested = true
                } label: {
                    Label(widgetRefreshRequested ? "Widget refresh requested" : "Refresh desktop widget",
                          systemImage: widgetRefreshRequested ? "checkmark" : "arrow.clockwise")
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .controlSize(.small)
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 380)
        .onAppear {
            model.panelDidOpen()
            loginItem.refresh()
            widgetRefreshRequested = false
        }
        .onDisappear {
            model.panelDidClose()
        }
    }
}

#Preview("Menu bar panel") {
    MenuPanelView(
        model: LiveStatsModel(stats: .previewFurious, live: false),
        loginItem: LoginItemController()
    )
}

#Preview("Menu bar panel – annoyed") {
    MenuPanelView(
        model: LiveStatsModel(stats: .previewAnnoyed, live: false),
        loginItem: LoginItemController()
    )
}
