import RunKit
import SwiftUI

@main
struct RunWalkApp: App {
    @State private var model = AppModel.live()
    /// Mirrors `Theme.look`; when Settings changes it, the whole UI is rebuilt in the new look.
    @AppStorage(Theme.lookKey) private var look: Look = .calm

    init() {
        CueNotifications.shared.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .id(look)
                .preferredColorScheme(look.style.forcedScheme)
        }
    }
}

/// Onboarding on first launch, then the four tabs. Run and Summary are one full-screen flow.
struct RootView: View {
    @Environment(AppModel.self) private var model
    /// Kept outside the view so a look change (which rebuilds the view) stays on the same tab.
    @AppStorage("tab") private var tab = "today"
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.settings == nil {
                OnboardingView()
            } else {
                tabs
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reload() }
        }
        .fullScreenCover(isPresented: flowShown) {
            FlowView().environment(model)
        }
        .alert("Resume your run?", isPresented: resumeShown, presenting: model.resumeOffer) { active in
            Button("Resume") { model.resume(active) }
            Button("Discard it", role: .destructive) { model.discardResume() }
            Button("Not now", role: .cancel) {}
        } message: { active in
            Text("\(active.engine.plan.workout?.title ?? "Your run") was still going when the app closed.")
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.max", value: "today") { TodayView() }
            Tab("Plan", systemImage: "calendar", value: "plan") { PlanView() }
            Tab("Progress", systemImage: "chart.bar", value: "progress") { ProgressTabView() }
            Tab("Settings", systemImage: "gearshape", value: "settings") { SettingsView() }
        }
        .tint(Theme.accent)
    }

    private var flowShown: Binding<Bool> {
        Binding(get: { model.flow != nil }, set: { if !$0 { model.flow = nil } })
    }

    private var resumeShown: Binding<Bool> {
        // "Not now" hides the offer; the saved run stays, so it's offered again next launch.
        Binding(
            get: { model.resumeOffer != nil && model.flow == nil },
            set: { if !$0 { model.resumeOffer = nil } })
    }
}

/// Run → Summary without dismissing the cover in between.
private struct FlowView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.flow {
        case .run(let session): RunView(session: session)
        case .summary(let summary): RunSummaryView(summary: summary)
        case nil: Theme.background.ignoresSafeArea()
        }
    }
}
