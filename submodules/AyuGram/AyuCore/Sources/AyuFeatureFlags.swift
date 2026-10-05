import Foundation

/// AyuGram build-time feature switches.
public enum AyuFeatureFlags {
    /// Siri / Intents integration (INPreferences, INInteraction donations).
    /// Sideloaded builds (LiveContainer, SideStore, AltStore, ...) are re-signed without the
    /// com.apple.developer.siri entitlement, and touching INPreferences then crashes the app on launch.
    /// Keep this off unless you sign the app with a profile that includes the Siri entitlement
    /// (and set "enable_siri" in the build configuration).
    public static let siriEnabled = false
}
