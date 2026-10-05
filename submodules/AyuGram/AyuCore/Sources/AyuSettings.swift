/*
 * AyuGram for iOS — port of AyuConfig.java from AyuGram4A (Copyright @Radolyn, 2023, GPL-2.0).
 * Same preference keys and defaults as Android, stored in UserDefaults(suiteName: "ayuconfig").
 *
 * Thread-safe: TelegramCore reads these values from its own queues.
 */

import Foundation

public final class AyuSettings {
    public static let shared = AyuSettings()

    public static let didChangeNotification = Notification.Name("AyuSettingsDidChange")

    public enum Key: String, CaseIterable {
        // ~ Ghost essentials
        case sendReadPackets
        case sendOnlinePackets
        case sendUploadProgress
        case sendOfflinePacketAfterOnline
        case markReadAfterSend
        case useScheduledMessages
        case sendStoryViews
        // ~ Spy essentials
        case saveDeletedMessages
        case saveMessagesHistory
        case saveForBots
        case saveReactions
        // ~ Useful features
        case disableAds
        case localPremium
        case regexFiltersEnabled
        case regexFiltersInChats
        case regexFiltersCaseInsensitive
        // ~ Customization
        case showGhostToggleInDrawer
        case showKillButtonInDrawer

        var defaultValue: Bool {
            switch self {
            case .sendReadPackets, .sendOnlinePackets, .sendUploadProgress, .sendStoryViews: return true
            case .sendOfflinePacketAfterOnline: return false
            case .markReadAfterSend: return true
            case .useScheduledMessages: return false
            case .saveDeletedMessages, .saveMessagesHistory, .saveForBots, .saveReactions: return true
            case .disableAds: return true
            case .localPremium: return false
            case .regexFiltersEnabled, .regexFiltersInChats: return false
            case .regexFiltersCaseInsensitive: return true
            case .showGhostToggleInDrawer: return true
            case .showKillButtonInDrawer: return false
            }
        }
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cache: [Key: Bool] = [:]
    private var stringCache: [String: String] = [:]

    public init(defaults: UserDefaults = UserDefaults(suiteName: "ayuconfig") ?? .standard) {
        self.defaults = defaults
        for key in Key.allCases {
            self.cache[key] = (defaults.object(forKey: key.rawValue) as? Bool) ?? key.defaultValue
        }
    }

    public subscript(key: Key) -> Bool {
        get {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.cache[key] ?? key.defaultValue
        }
        set {
            self.lock.lock()
            self.cache[key] = newValue
            self.lock.unlock()
            self.defaults.set(newValue, forKey: key.rawValue)
            self.notify()
        }
    }

    private func notify() {
        if Thread.isMainThread {
            NotificationCenter.default.post(name: AyuSettings.didChangeNotification, object: self)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: AyuSettings.didChangeNotification, object: self)
            }
        }
    }

    // MARK: - Strings (marks, filters)

    private func string(_ key: String, default value: String) -> String {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let cached = self.stringCache[key] {
            return cached
        }
        let stored = self.defaults.string(forKey: key) ?? value
        self.stringCache[key] = stored
        return stored
    }

    private func setString(_ key: String, _ value: String) {
        self.lock.lock()
        self.stringCache[key] = value
        self.lock.unlock()
        self.defaults.set(value, forKey: key)
        self.notify()
    }

    public static let defaultDeletedMark = "🧹"

    /// Text shown instead of the time prefix for deleted messages (Android: deletedMarkText).
    public var deletedMarkText: String {
        get { self.string("deletedMarkText", default: AyuSettings.defaultDeletedMark) }
        set { self.setString("deletedMarkText", newValue) }
    }

    /// Custom "edited" label; empty means Telegram's own localized label (Android: editedMarkText).
    public var editedMarkText: String {
        get { self.string("editedMarkText", default: "") }
        set { self.setString("editedMarkText", newValue) }
    }

    /// Regex filters, stored as a JSON array like on Android ("regexFilters").
    public var regexFilters: [String] {
        get {
            let json = self.string("regexFilters", default: "[]")
            guard let data = json.data(using: .utf8), let list = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return list
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
            self.setString("regexFilters", String(decoding: data, as: UTF8.self))
            AyuFilter.shared.rebuild()
        }
    }

    // MARK: - Ghost mode (AyuConfig.isGhostModeActive / setGhostMode)

    public var isGhostModeActive: Bool {
        return !self[.sendReadPackets] && !self[.sendOnlinePackets] && !self[.sendUploadProgress] && self[.sendOfflinePacketAfterOnline]
    }

    public func setGhostMode(_ enabled: Bool) {
        self.lock.lock()
        self.cache[.sendReadPackets] = !enabled
        self.cache[.sendOnlinePackets] = !enabled
        self.cache[.sendUploadProgress] = !enabled
        self.cache[.sendOfflinePacketAfterOnline] = enabled
        self.cache[.sendStoryViews] = !enabled
        self.lock.unlock()
        self.defaults.set(!enabled, forKey: Key.sendReadPackets.rawValue)
        self.defaults.set(!enabled, forKey: Key.sendOnlinePackets.rawValue)
        self.defaults.set(!enabled, forKey: Key.sendUploadProgress.rawValue)
        self.defaults.set(enabled, forKey: Key.sendOfflinePacketAfterOnline.rawValue)
        self.defaults.set(!enabled, forKey: Key.sendStoryViews.rawValue)
        self.notify()
    }

    public func toggleGhostMode() {
        self.setGhostMode(!self.isGhostModeActive)
    }

    // MARK: - Saving rules (AyuConfig.saveDeletedMessageFor / saveEditedMessageFor)

    public func shouldSaveDeletedMessage(isBotChat: Bool) -> Bool {
        guard self[.saveDeletedMessages] else {
            return false
        }
        return !isBotChat || self[.saveForBots]
    }

    public func shouldSaveEditHistory(isBotChat: Bool) -> Bool {
        guard self[.saveMessagesHistory] else {
            return false
        }
        return !isBotChat || self[.saveForBots]
    }
}

/// One-shot permissions for requests that ghost mode normally blocks
/// (AyuState.allowReadPacket on Android): "Read until here", "Read after reply".
public final class AyuGhostState {
    public static let shared = AyuGhostState()

    private let lock = NSLock()
    private var readAllowances: [Int64: Int] = [:]

    public init() {
    }

    /// Lets the next read-state push for this peer reach the server.
    public func allowNextRead(peerId: Int64) {
        self.lock.lock()
        self.readAllowances[peerId, default: 0] += 1
        self.lock.unlock()
    }

    /// Whether a read-state push for this peer may be sent now. Consumes a one-shot allowance.
    public func shouldSendRead(peerId: Int64) -> Bool {
        if AyuSettings.shared[.sendReadPackets] {
            return true
        }
        self.lock.lock()
        defer { self.lock.unlock() }
        if let count = self.readAllowances[peerId], count > 0 {
            if count == 1 {
                self.readAllowances[peerId] = nil
            } else {
                self.readAllowances[peerId] = count - 1
            }
            return true
        }
        return false
    }

    public var shouldSendOnline: Bool {
        return AyuSettings.shared[.sendOnlinePackets]
    }

    public var shouldSendTyping: Bool {
        return AyuSettings.shared[.sendUploadProgress]
    }

    public var shouldSendStoryViews: Bool {
        return AyuSettings.shared[.sendStoryViews]
    }

    /// Message contents (voice listened, video note watched, mentions) count as "read" too.
    public var shouldSendContentRead: Bool {
        return AyuSettings.shared[.sendReadPackets]
    }
}
