/*
 * Port of AyuFilter.java (Copyright @Radolyn, 2023, GPL-2.0).
 * java.util.regex.Pattern (MULTILINE | CASE_INSENSITIVE) → NSRegularExpression.
 */

import Foundation

public final class AyuFilter {
    public static let shared = AyuFilter()

    private let lock = NSLock()
    private var patterns: [NSRegularExpression]?

    public init() {
    }

    public func rebuild() {
        self.lock.lock()
        self.patterns = nil
        self.lock.unlock()
    }

    public static func compile(_ filters: [String], caseInsensitive: Bool) -> [NSRegularExpression] {
        var options: NSRegularExpression.Options = [.anchorsMatchLines]
        if caseInsensitive {
            options.insert(.caseInsensitive)
        }
        return filters.compactMap { try? NSRegularExpression(pattern: $0, options: options) }
    }

    /// Returns an error description if the pattern is invalid.
    public static func validate(_ pattern: String) -> String? {
        if pattern.isEmpty {
            return AyuStrings.get("RegexFilterEmpty")
        }
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            return nil
        } catch let error {
            return error.localizedDescription
        }
    }

    public static func matches(_ text: String, patterns: [NSRegularExpression]) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return patterns.contains(where: { $0.firstMatch(in: text, options: [], range: range) != nil })
    }

    /// Filters apply in channels always and in other chats only with "regexFiltersInChats"
    /// (ChatActivity hook on Android).
    public func appliesIn(isChannel: Bool) -> Bool {
        let settings = AyuSettings.shared
        return settings[.regexFiltersEnabled] && (settings[.regexFiltersInChats] || isChannel)
    }

    public func isFiltered(text: String) -> Bool {
        let settings = AyuSettings.shared
        guard settings[.regexFiltersEnabled], !text.isEmpty else {
            return false
        }
        self.lock.lock()
        if self.patterns == nil {
            self.patterns = AyuFilter.compile(settings.regexFilters, caseInsensitive: settings[.regexFiltersCaseInsensitive])
        }
        let patterns = self.patterns ?? []
        self.lock.unlock()
        return AyuFilter.matches(text, patterns: patterns)
    }
}
