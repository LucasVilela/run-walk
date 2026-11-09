import SwiftUI

extension View {
    /// The "+" in the navigation bar: time a run outside the plan now, or log one done earlier.
    /// It stays small so Today's Start button is still the one obvious next step.
    func otherRunMenu() -> some View { modifier(OtherRunMenu()) }
}

private struct OtherRunMenu: ViewModifier {
    @Environment(AppModel.self) private var model
    @State private var logging = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("A run outside the plan") {
                            Button("Time a run now", systemImage: "stopwatch") { model.startFreeRun() }
                            Button("Log a run you did", systemImage: "square.and.pencil") { logging = true }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Other run")
                    .accessibilityHint("Time or log a run outside the plan")
                }
            }
            .sheet(isPresented: $logging) {
                LogRunSheet().environment(model)
            }
    }
}
