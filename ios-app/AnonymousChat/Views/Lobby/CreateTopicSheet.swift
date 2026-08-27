import SwiftUI

public struct CreateTopicSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var socketManager = SocketManager.shared
    @State private var topicName: String = ""

    public var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0A0A0A").ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Topic Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#A1A1AA"))

                        TextField("e.g. gaming, technology, anime...", text: $topicName)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(hex: "#18181B"))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#27272A"), lineWidth: 1)
                            )
                    }

                    Button(action: {
                        let clean = topicName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        socketManager.createTopic(name: clean)
                        dismiss()
                    }) {
                        Text("Create Topic")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.top, 10)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("New Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
