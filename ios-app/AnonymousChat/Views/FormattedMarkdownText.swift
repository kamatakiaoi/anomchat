import SwiftUI

public struct FormattedMarkdownText: View {
    public let text: String
    public var fontSize: CGFloat = 14
    public var fontColor: Color = .white

    public init(text: String, fontSize: CGFloat = 14, fontColor: Color = .white) {
        self.text = text
        self.fontSize = fontSize
        self.fontColor = fontColor
    }

    public var body: some View {
        Text(parseMarkdown(text))
            .font(.system(size: fontSize))
            .foregroundColor(fontColor)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func parseMarkdown(_ input: String) -> AttributedString {
        let str = input
        if let attr = try? AttributedString(markdown: str, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attr
        }
        return AttributedString(input)
    }
}
