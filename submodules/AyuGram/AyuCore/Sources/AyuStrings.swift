import Foundation

/// AyuGram strings (Telegram's PresentationStrings are generated from its own localization
/// platform, so AyuGram keeps its own small table). Russian and English, keys follow AyuGram4A.
public enum AyuStrings {
    private static var isRussian: Bool {
        let code = Locale.preferredLanguages.first ?? "en"
        return code.hasPrefix("ru") || code.hasPrefix("uk") || code.hasPrefix("be") || code.hasPrefix("kk")
    }

    public static func get(_ key: String) -> String {
        guard let pair = table[key] else {
            return key
        }
        return isRussian ? pair.1 : pair.0
    }

    public static func format(_ key: String, _ args: CVarArg...) -> String {
        return String(format: get(key), arguments: args)
    }

    private static let table: [String: (String, String)] = [
        "AyuPreferences": ("AyuGram Preferences", "Настройки AyuGram"),
        "GhostEssentialsHeader": ("Ghost essentials", "Режим призрака"),
        "GhostModeToggle": ("Ghost Mode", "Режим призрака"),
        "GhostModeEnabled": ("Ghost mode is on", "Режим призрака включён"),
        "GhostModeDisabled": ("Ghost mode is off", "Режим призрака выключен"),
        "DontSendReadPackets": ("Don't read messages", "Не читать сообщения"),
        "DontSendOnlinePackets": ("Don't send online", "Не отправлять «онлайн»"),
        "DontSendUploadProgress": ("Don't send typing", "Не отправлять «печатает»"),
        "DontSendStoryViews": ("Don't mark stories as seen", "Не отмечать истории просмотренными"),
        "SendOfflinePacketAfterOnline": ("Immediate offline after online", "Автоматический «офлайн»"),
        "MarkReadAfterSend": ("Send read status after reply", "Читать после ответа"),
        "UseScheduledMessages": ("Schedule messages", "Использовать отложку"),
        "UseScheduledMessagesHint": ("Messages are sent as scheduled (+12 s), so sending doesn't show you online.", "Сообщения отправляются отложенными (+12 с), чтобы отправка не показывала вас в сети."),
        "SpyEssentialsHeader": ("Spy essentials", "Режим шпиона"),
        "SaveDeletedMessages": ("Save deleted messages", "Сохранять удалённые сообщения"),
        "SaveMessagesHistory": ("Save edits history", "Сохранять историю правок"),
        "MessageSavingSaveForBots": ("Save in bot dialogs", "Сохранять в диалогах с ботами"),
        "MessageSavingSaveReactions": ("Save reactions", "Сохранять реакции"),
        "QoLTogglesHeader": ("Useful features", "Полезные функции"),
        "DisableAds": ("Disable ads", "Отключить рекламу"),
        "LocalPremium": ("Local Telegram Premium", "Локальный Telegram Premium"),
        "LocalPremiumHint": ("Client-side only, like on Android.", "Только на устройстве, как на Android."),
        "RegexFilters": ("Message Filters", "Фильтры сообщений"),
        "RegexFiltersEnable": ("Enable filters", "Включить фильтры"),
        "RegexFiltersInChats": ("Apply in groups and private chats", "Применять в группах и личных чатах"),
        "RegexFiltersCaseInsensitive": ("Case insensitive", "Без учёта регистра"),
        "RegexFiltersAdd": ("Add filter", "Добавить фильтр"),
        "RegexFiltersHint": ("Messages matching a filter are hidden in channels (and in all chats if enabled).", "Сообщения, подходящие под фильтр, скрываются в каналах (и во всех чатах, если включено)."),
        "RegexFilterEmpty": ("Pattern is empty", "Пустой шаблон"),
        "RegexFilterPattern": ("Regular expression", "Регулярное выражение"),
        "RegexFilterInvalid": ("Invalid regular expression", "Неверное регулярное выражение"),
        "CustomizationHeader": ("Customization", "Персонализация"),
        "DeletedMarkText": ("Deleted mark", "Метка удалённого"),
        "EditedMarkText": ("Edited mark", "Метка изменённого"),
        "EditedMarkHint": ("Leave empty to use Telegram's label.", "Оставьте пустым, чтобы использовать надпись Telegram."),
        "ShowGhostToggleInDrawer": ("Ghost toggle in chat list", "Переключатель призрака в списке чатов"),
        "ShowKllButtonInDrawer": ("Show kill app button", "Кнопка закрытия приложения"),
        "KillApp": ("Close AyuGram", "Закрыть AyuGram"),
        "DebugHeader": ("Debug", "Отладка"),
        "ClearAyuDatabase": ("Clear edits history", "Очистить историю правок"),
        "ClearAyuDatabaseDone": ("Edits history cleared", "История правок очищена"),
        "SavedRevisionsCount": ("Saved revisions", "Сохранено версий"),
        "EditsHistoryMenu": ("Edits history", "История правок"),
        "EditsHistoryTitle": ("Edits history", "История редактирования"),
        "EditsHistoryEmpty": ("No saved versions yet.", "Сохранённых версий пока нет."),
        "RevisionBefore": ("Before %@", "До %@"),
        "RevisionCurrent": ("Current version", "Текущая версия"),
        "RevisionMediaReplaced": ("Media replaced: %@", "Заменено медиа: %@"),
        "ReadUntilMenuText": ("Read until here", "Прочитать до сюда"),
        "DeletedMessageLabel": ("Deleted", "Удалено"),
        "AboutAyuGram": ("AyuGram for iOS is based on Telegram for iOS and AyuGram4A. GPL-2.0.", "AyuGram для iOS основан на Telegram для iOS и AyuGram4A. GPL-2.0."),
    ]
}
