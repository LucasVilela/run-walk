import RunKit
import SwiftUI

/// One past run: the summary layout, editable feeling, pain and notes, and delete.
struct RunDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let run: RunRecord

    @State private var feeling: Feeling?
    @State private var pain = false
    @State private var notes = ""
    /// What was last saved, so Save is enabled only when something changed.
    @State private var saved: (feeling: Feeling?, pain: Bool, notes: String)?
    @State private var confirmDelete = false
    @FocusState private var typing: Bool

    private var unit: DistanceUnit { model.settings?.units ?? .km }
    private var edited: Bool {
        guard let saved else { return false }
        return feeling != saved.feeling || pain != saved.pain || notes != saved.notes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                Text(run.startedAt.formatted(date: .complete, time: .shortened))
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
                RunStatsCard(run: run, distanceM: run.distanceM, unit: unit)
                if !run.counted {
                    Text("Not counted: \(Int(run.completionPct))% of the run.")
                        .font(Theme.body).foregroundStyle(Theme.secondaryText)
                }
                CheckInFields(feeling: $feeling, pain: $pain, notes: $notes, typing: $typing)
                Button("Delete this run", systemImage: "trash") { confirmDelete = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.padding)
        }
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(Theme.text)
        .background(Theme.background)
        .navigationTitle(run.workout?.title ?? "Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    typing = false
                    model.updateRun(run, feeling: feeling, pain: pain, notes: notes)
                    saved = (feeling, pain, notes)
                }
                .disabled(!edited)
            }
        }
        .confirmationDialog("Delete this run?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete run", role: .destructive) {
                model.deleteRun(run)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Its time, distance and notes are removed. Badges you've earned stay.")
        }
        .task {
            feeling = run.feeling
            pain = run.pain
            notes = run.notes
            saved = (run.feeling, run.pain, run.notes)
        }
    }
}
