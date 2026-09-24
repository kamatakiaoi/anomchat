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
            .layoutPriority(1)
    }

    private static var cache = NSCache<NSString, NSAttributedString>()

    private func parseMarkdown(_ input: String) -> AttributedString {
        let key = input as NSString
        if let cached = Self.cache.object(forKey: key) {
            return AttributedString(cached)
        }
        
        let str = input
        if let attr = try? AttributedString(markdown: str, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Self.cache.setObject(NSAttributedString(attr), forKey: key)
            return attr
        }
        return AttributedString(input)
    }
}
