import SwiftUI

public struct TopicRowView: View {
    public let topic: Topic
    public let onSelect: () -> Void

    public var body: some View {
        HStack(spacing: 12) {
            // Topic Icon or Hashtag
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(topic.isGeneralTopic ? Color.blue.opacity(0.15) : Color(hex: "#27272A"))
                    .frame(width: 42, height: 42)

                if topic.isGeneralTopic {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#38BDF8"))
                } else if topic.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#EF4444"))
                } else if topic.name.lowercased() == "patch notes" {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#F59E0B"))
                } else {
                    Text("#")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(Color(hex: "#A1A1AA"))
                }
            }

            // Topic Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(topic.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if topic.isSystemTopic {
                        Text("SYSTEM")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Color(hex: "#38BDF8"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }

                    if topic.isOwnerTopic {
                        Text("YOU")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Color(hex: "#34D399"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                if let last = topic.lastMsg, let name = last.name, let text = last.text, !text.isEmpty {
                    Text("\(name): \(text)")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color(hex: "#71717A"))
                        .lineLimit(1)
                } else {
                    Text("No messages yet")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color(hex: "#52525B"))
                }
            }

            Spacer()

            // Online count badge
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Circle().fill(Color(hex: "#22C55E")).frame(width: 5, height: 5)
                    Text("\(topic.onlineCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#A1A1AA"))
                }

                Text("\(topic.totalMessages) msgs")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#52525B"))
            }
        }
        .contentShape(Rectangle())
        .padding(12)
        .background(Color(hex: "#141416"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
    }
}
