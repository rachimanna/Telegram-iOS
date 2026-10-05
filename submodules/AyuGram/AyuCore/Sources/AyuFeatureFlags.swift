import Foundation

/// AyuGram build-time feature switches.
///
/// Sideloaded builds (LiveContainer, SideStore, AltStore, free Apple ID signing, ...) are re-signed
/// without the Siri and iCloud entitlements. Touching INPreferences or CloudKit without them makes
/// the system terminate the app, so both integrations are off unless you sign with a profile that
/// includes those entitlements (and set "enable_siri" / "enable_icloud" in the build configuration).
public enum AyuFeatureFlags {
    /// Siri / Intents integration (INPreferences, INInteraction donations).
    public static let siriEnabled = false
    /// CloudKit / iCloud integration (CKContainer, NSUbiquitousKeyValueStore).
    public static let iCloudEnabled = false
}

/// Helpers that keep the app running when it is re-signed without the original entitlements.
public enum AyuSideloadSupport {
    /// BGTaskScheduler.register(forTaskWithIdentifier:) raises an exception for identifiers that are
    /// not listed in BGTaskSchedulerPermittedIdentifiers. Sideloading tools change the bundle id but
    /// not that list, so check before registering.
    public static func isBackgroundTaskIdentifierPermitted(_ identifier: String) -> Bool {
        guard let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] else {
            return false
        }
        for pattern in permitted {
            if pattern == identifier {
                return true
            }
            if pattern.hasSuffix("*") && identifier.hasPrefix(String(pattern.dropLast())) {
                return true
            }
        }
        return false
    }

    /// The app group container, or a private directory inside the app sandbox when the app group is
    /// unavailable (no com.apple.security.application-groups entitlement, e.g. LiveContainer).
    /// Without the fallback the app stops at launch with "Error 2".
    public static func sharedContainerURL(appGroupName: String) -> URL? {
        let fileManager = FileManager.default
        if let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupName), isUsableDirectory(url) {
            return url
        }
        guard let baseUrl = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        let url = baseUrl.appendingPathComponent("telegram-container", isDirectory: true)
        guard isUsableDirectory(url) else {
            return nil
        }
        return url
    }

    private static func isUsableDirectory(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if (try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)) == nil {
                return false
            }
            isDirectory = true
        }
        return isDirectory.boolValue && fileManager.isWritableFile(atPath: url.path)
    }
}
