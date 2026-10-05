/*
 * AyuGram preferences screen (AyuGramPreferencesActivity of AyuGram4A, GPL-2.0),
 * built with Telegram's ItemListUI so it looks and behaves like the rest of Settings.
 */

import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import AyuCore

private final class AyuGramSettingsArguments {
    let toggle: (AyuSettings.Key, Bool) -> Void
    let toggleGhostMode: (Bool) -> Void
    let openFilters: () -> Void
    let updateDeletedMark: (String) -> Void
    let updateEditedMark: (String) -> Void
    let clearHistory: () -> Void
    let killApp: () -> Void

    init(toggle: @escaping (AyuSettings.Key, Bool) -> Void, toggleGhostMode: @escaping (Bool) -> Void, openFilters: @escaping () -> Void, updateDeletedMark: @escaping (String) -> Void, updateEditedMark: @escaping (String) -> Void, clearHistory: @escaping () -> Void, killApp: @escaping () -> Void) {
        self.toggle = toggle
        self.toggleGhostMode = toggleGhostMode
        self.openFilters = openFilters
        self.updateDeletedMark = updateDeletedMark
        self.updateEditedMark = updateEditedMark
        self.clearHistory = clearHistory
        self.killApp = killApp
    }
}

private enum AyuGramSettingsSection: Int32 {
    case ghost
    case spy
    case useful
    case customization
    case debug
}

/// A switch bound directly to an AyuSettings key. `inverted` is used for the
/// "Don't …" toggles whose underlying setting is "send …" (same as Android).
private struct AyuSwitch: Equatable {
    let key: AyuSettings.Key
    let title: String
    let inverted: Bool
    let enabled: Bool
}

private enum AyuGramSettingsEntry: ItemListNodeEntry {
    case ghostHeader(String)
    case ghostMaster(String, Bool)
    case ghostSwitch(Int, AyuSwitch, Bool)
    case ghostFooter(String)

    case spyHeader(String)
    case spySwitch(Int, AyuSwitch, Bool)

    case usefulHeader(String)
    case usefulSwitch(Int, AyuSwitch, Bool)
    case filters(String, String)

    case customizationHeader(String)
    case deletedMark(String, String)
    case editedMark(String, String)
    case customizationFooter(String)

    case debugHeader(String)
    case revisionsCount(String, String)
    case clearHistory(String)
    case killApp(String)
    case about(String)

    var section: ItemListSectionId {
        switch self {
        case .ghostHeader, .ghostMaster, .ghostSwitch, .ghostFooter:
            return AyuGramSettingsSection.ghost.rawValue
        case .spyHeader, .spySwitch:
            return AyuGramSettingsSection.spy.rawValue
        case .usefulHeader, .usefulSwitch, .filters:
            return AyuGramSettingsSection.useful.rawValue
        case .customizationHeader, .deletedMark, .editedMark, .customizationFooter:
            return AyuGramSettingsSection.customization.rawValue
        case .debugHeader, .revisionsCount, .clearHistory, .killApp, .about:
            return AyuGramSettingsSection.debug.rawValue
        }
    }

    var stableId: Int {
        switch self {
        case .ghostHeader: return 0
        case .ghostMaster: return 1
        case let .ghostSwitch(index, _, _): return 10 + index
        case .ghostFooter: return 99
        case .spyHeader: return 100
        case let .spySwitch(index, _, _): return 110 + index
        case .usefulHeader: return 200
        case let .usefulSwitch(index, _, _): return 210 + index
        case .filters: return 290
        case .customizationHeader: return 300
        case .deletedMark: return 301
        case .editedMark: return 302
        case .customizationFooter: return 303
        case .debugHeader: return 400
        case .revisionsCount: return 401
        case .clearHistory: return 402
        case .killApp: return 403
        case .about: return 404
        }
    }

    static func <(lhs: AyuGramSettingsEntry, rhs: AyuGramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuGramSettingsArguments
        switch self {
        case let .ghostHeader(text), let .spyHeader(text), let .usefulHeader(text), let .customizationHeader(text), let .debugHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .ghostMaster(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleGhostMode(value)
            })
        case let .ghostSwitch(_, item, value), let .spySwitch(_, item, value), let .usefulSwitch(_, item, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: item.title, value: value, enabled: item.enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(item.key, item.inverted ? !value : value)
            })
        case let .ghostFooter(text), let .customizationFooter(text), let .about(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .filters(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openFilters()
            })
        case let .deletedMark(title, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: title), text: value, placeholder: AyuSettings.defaultDeletedMark, type: .regular(capitalization: false, autocorrection: false), maxLength: 32, sectionId: self.section, textUpdated: { value in
                arguments.updateDeletedMark(value)
            }, action: {})
        case let .editedMark(title, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: title), text: value, placeholder: presentationData.strings.Conversation_MessageEditedLabel, type: .regular(capitalization: false, autocorrection: false), maxLength: 32, sectionId: self.section, textUpdated: { value in
                arguments.updateEditedMark(value)
            }, action: {})
        case let .revisionsCount(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .clearHistory(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearHistory()
            })
        case let .killApp(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.killApp()
            })
        }
    }
}

private func ayuGramSettingsEntries(revisionsCount: Int) -> [AyuGramSettingsEntry] {
    let settings = AyuSettings.shared
    let s = AyuStrings.get
    var entries: [AyuGramSettingsEntry] = []

    func makeSwitch(_ key: AyuSettings.Key, _ title: String, inverted: Bool = false, enabled: Bool = true) -> (AyuSwitch, Bool) {
        let raw = settings[key]
        return (AyuSwitch(key: key, title: title, inverted: inverted, enabled: enabled), inverted ? !raw : raw)
    }

    entries.append(.ghostHeader(s("GhostEssentialsHeader")))
    entries.append(.ghostMaster(s("GhostModeToggle"), settings.isGhostModeActive))
    let ghostSwitches: [(AyuSwitch, Bool)] = [
        makeSwitch(.sendReadPackets, s("DontSendReadPackets"), inverted: true),
        makeSwitch(.sendOnlinePackets, s("DontSendOnlinePackets"), inverted: true),
        makeSwitch(.sendUploadProgress, s("DontSendUploadProgress"), inverted: true),
        makeSwitch(.sendStoryViews, s("DontSendStoryViews"), inverted: true),
        makeSwitch(.sendOfflinePacketAfterOnline, s("SendOfflinePacketAfterOnline")),
        makeSwitch(.markReadAfterSend, s("MarkReadAfterSend")),
        makeSwitch(.useScheduledMessages, s("UseScheduledMessages")),
    ]
    for (index, item) in ghostSwitches.enumerated() {
        entries.append(.ghostSwitch(index, item.0, item.1))
    }
    entries.append(.ghostFooter(s("UseScheduledMessagesHint")))

    entries.append(.spyHeader(s("SpyEssentialsHeader")))
    let saving = settings[.saveDeletedMessages] || settings[.saveMessagesHistory]
    let spySwitches: [(AyuSwitch, Bool)] = [
        makeSwitch(.saveDeletedMessages, s("SaveDeletedMessages")),
        makeSwitch(.saveMessagesHistory, s("SaveMessagesHistory")),
        makeSwitch(.saveForBots, s("MessageSavingSaveForBots"), enabled: saving),
        makeSwitch(.saveReactions, s("MessageSavingSaveReactions"), enabled: settings[.saveDeletedMessages]),
    ]
    for (index, item) in spySwitches.enumerated() {
        entries.append(.spySwitch(index, item.0, item.1))
    }

    entries.append(.usefulHeader(s("QoLTogglesHeader")))
    let usefulSwitches: [(AyuSwitch, Bool)] = [
        makeSwitch(.disableAds, s("DisableAds")),
        makeSwitch(.regexFiltersEnabled, s("RegexFiltersEnable")),
        makeSwitch(.regexFiltersInChats, s("RegexFiltersInChats"), enabled: settings[.regexFiltersEnabled]),
    ]
    for (index, item) in usefulSwitches.enumerated() {
        entries.append(.usefulSwitch(index, item.0, item.1))
    }
    entries.append(.filters(s("RegexFilters"), "\(settings.regexFilters.count)"))

    entries.append(.customizationHeader(s("CustomizationHeader")))
    entries.append(.deletedMark(s("DeletedMarkText"), settings.deletedMarkText))
    entries.append(.editedMark(s("EditedMarkText"), settings.editedMarkText))
    entries.append(.customizationFooter(s("EditedMarkHint")))

    entries.append(.debugHeader(s("DebugHeader")))
    entries.append(.revisionsCount(s("SavedRevisionsCount"), "\(revisionsCount)"))
    entries.append(.clearHistory(s("ClearAyuDatabase")))
    entries.append(.killApp(s("KillApp")))
    entries.append(.about(s("AboutAyuGram")))

    return entries
}

/// Emits every time AyuSettings changes (from this screen, the chat list toggle, etc).
private func ayuSettingsChanges() -> Signal<Void, NoError> {
    return Signal { subscriber in
        subscriber.putNext(Void())
        let observer = NotificationCenter.default.addObserver(forName: AyuSettings.didChangeNotification, object: nil, queue: .main, using: { _ in
            subscriber.putNext(Void())
        })
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

public func ayuGramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var displayUndoImpl: ((String) -> Void)?

    let revisionsCount = ValuePromise<Int>(0, ignoreRepeated: true)
    let reloadRevisionsCount: () -> Void = {
        DispatchQueue.global(qos: .utility).async {
            let count = AyuEditHistoryStore.shared.totalCount()
            revisionsCount.set(count)
        }
    }
    reloadRevisionsCount()

    let arguments = AyuGramSettingsArguments(
        toggle: { key, value in
            AyuSettings.shared[key] = value
        },
        toggleGhostMode: { value in
            AyuSettings.shared.setGhostMode(value)
            displayUndoImpl?(AyuStrings.get(value ? "GhostModeEnabled" : "GhostModeDisabled"))
        },
        openFilters: {
            pushControllerImpl?(ayuRegexFiltersController(context: context))
        },
        updateDeletedMark: { value in
            AyuSettings.shared.deletedMarkText = value
        },
        updateEditedMark: { value in
            AyuSettings.shared.editedMarkText = value
        },
        clearHistory: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: AyuStrings.get("ClearAyuDatabase"), text: AyuStrings.get("SavedRevisionsCount") + ": \(AyuEditHistoryStore.shared.totalCount())", actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    DispatchQueue.global(qos: .utility).async {
                        AyuEditHistoryStore.shared.removeAll()
                        DispatchQueue.main.async {
                            reloadRevisionsCount()
                            displayUndoImpl?(AyuStrings.get("ClearAyuDatabaseDone"))
                        }
                    }
                })
            ]))
        },
        killApp: {
            AyuEditHistoryStore.shared.flush()
            exit(0)
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        ayuSettingsChanges(),
        revisionsCount.get()
    )
    |> map { presentationData, _, revisionsCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(AyuStrings.get("AyuPreferences")),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuGramSettingsEntries(revisionsCount: revisionsCount), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    displayUndoImpl = { [weak controller] text in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: 3.0, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
    }
    return controller
}
