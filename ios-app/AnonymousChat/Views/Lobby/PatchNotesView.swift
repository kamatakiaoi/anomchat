import SwiftUI

public struct PatchNotesView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var prefs = PreferenceManager.shared

    @State private var patchNotes: [PatchNote] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Loading changelog...")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#71717A"))
                    }
                } else if let err = errorMessage, patchNotes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "#EF4444"))
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#A1A1AA"))
                        Button("Retry") { loadNotes() }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(patchNotes) { note in
                                patchNoteCard(note)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Patch Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
            .onAppear {
                loadNotes()
            }
        }
    }

    private func patchNoteCard(_ note: PatchNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#38BDF8"))
                    Text("v\(note.version)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#38BDF8"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(6)

                Spacer()

                Text(note.date)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#71717A"))
            }

            Text(note.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(note.items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#38BDF8"))
                        Text(item)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#D4D4D8"))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#141416"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
    }

    private func loadNotes() {
        isLoading = true
        errorMessage = nil

        // 1. Try to load from server endpoint
        let serverUrl = prefs.serverBaseUrl + "/patch_notes.json"
        if let url = URL(string: serverUrl) {
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, let list = try? JSONDecoder().decode([PatchNote].self, from: data) {
                    DispatchQueue.main.async {
                        self.patchNotes = list
                        self.isLoading = false
                    }
                    return
                }

                // 2. Fallback to local bundled patch_notes.json
                loadBundledNotes()
            }.resume()
        } else {
            loadBundledNotes()
        }
    }

    private func loadBundledNotes() {
        DispatchQueue.main.async {
            if let bundleUrl = Bundle.main.url(forResource: "patch_notes", withExtension: "json"),
               let data = try? Data(contentsOf: bundleUrl),
               let list = try? JSONDecoder().decode([PatchNote].self, from: data) {
                self.patchNotes = list
                self.isLoading = false
            } else {
                self.isLoading = false
                self.errorMessage = "Could not load patch notes"
            }
        }
    }
}
