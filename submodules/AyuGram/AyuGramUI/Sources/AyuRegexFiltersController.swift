/*
 * Message filters (RegexFiltersPreferencesActivity of AyuGram4A, GPL-2.0).
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
import PromptUI
import AyuCore

private final class AyuRegexFiltersArguments {
    let toggle: (AyuSettings.Key, Bool) -> Void
    let add: () -> Void
    let edit: (Int) -> Void
    let remove: (Int) -> Void

    init(toggle: @escaping (AyuSettings.Key, Bool) -> Void, add: @escaping () -> Void, edit: @escaping (Int) -> Void, remove: @escaping (Int) -> Void) {
        self.toggle = toggle
        self.add = add
        self.edit = edit
        self.remove = remove
    }
}

private enum AyuRegexFiltersSection: Int32 {
    case options
    case filters
}

private enum AyuRegexFiltersEntry: ItemListNodeEntry {
    case enabled(String, Bool)
    case inChats(String, Bool, Bool)
    case caseInsensitive(String, Bool)
    case optionsFooter(String)
    case filtersHeader(String)
    case add(String)
    case filter(Int, String)

    var section: ItemListSectionId {
        switch self {
        case .enabled, .inChats, .caseInsensitive, .optionsFooter:
            return AyuRegexFiltersSection.options.rawValue
        case .filtersHeader, .add, .filter:
            return AyuRegexFiltersSection.filters.rawValue
        }
    }

    var stableId: Int {
        switch self {
        case .enabled: return 0
        case .inChats: return 1
        case .caseInsensitive: return 2
        case .optionsFooter: return 3
        case .filtersHeader: return 4
        case .add: return 5
        case let .filter(index, _): return 100 + index
        }
    }

    static func <(lhs: AyuRegexFiltersEntry, rhs: AyuRegexFiltersEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyuRegexFiltersArguments
        switch self {
        case let .enabled(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.regexFiltersEnabled, value)
            })
        case let .inChats(title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.regexFiltersInChats, value)
            })
        case let .caseInsensitive(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(.regexFiltersCaseInsensitive, value)
            })
        case let .optionsFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .filtersHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .add(title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.add()
            })
        case let .filter(index, pattern):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: pattern, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.edit(index)
            })
        }
    }
}

private func ayuRegexFiltersEntries() -> [AyuRegexFiltersEntry] {
    let settings = AyuSettings.shared
    var entries: [AyuRegexFiltersEntry] = []
    entries.append(.enabled(AyuStrings.get("RegexFiltersEnable"), settings[.regexFiltersEnabled]))
    entries.append(.inChats(AyuStrings.get("RegexFiltersInChats"), settings[.regexFiltersInChats], settings[.regexFiltersEnabled]))
    entries.append(.caseInsensitive(AyuStrings.get("RegexFiltersCaseInsensitive"), settings[.regexFiltersCaseInsensitive]))
    entries.append(.optionsFooter(AyuStrings.get("RegexFiltersHint")))
    entries.append(.filtersHeader(AyuStrings.get("RegexFilters")))
    entries.append(.add(AyuStrings.get("RegexFiltersAdd")))
    for (index, pattern) in settings.regexFilters.enumerated() {
        entries.append(.filter(index, pattern))
    }
    return entries
}

private func ayuFiltersChanges() -> Signal<Void, NoError> {
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

public func ayuRegexFiltersController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?

    // Shows the pattern prompt; `index == nil` adds a new filter.
    var openEditorImpl: ((Int?, String) -> Void)?

    let showInvalid: (String, Int?, String) -> Void = { error, index, pattern in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: AyuStrings.get("RegexFilterInvalid"), text: error, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Edit, action: {
                openEditorImpl?(index, pattern)
            })
        ]))
    }

    openEditorImpl = { index, value in
        presentControllerImpl?(promptController(context: context, text: AyuStrings.get("RegexFilterPattern"), titleFont: .bold, value: value, placeholder: "^.*promo.*$", characterLimit: 1024, apply: { result in
            guard let result else {
                return
            }
            let pattern = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if let error = AyuFilter.validate(pattern) {
                showInvalid(error, index, pattern)
                return
            }
            var filters = AyuSettings.shared.regexFilters
            if let index, index < filters.count {
                filters[index] = pattern
            } else if !filters.contains(pattern) {
                filters.append(pattern)
            }
            AyuSettings.shared.regexFilters = filters
        }))
    }

    let arguments = AyuRegexFiltersArguments(
        toggle: { key, value in
            AyuSettings.shared[key] = value
            if key == .regexFiltersCaseInsensitive {
                AyuFilter.shared.rebuild()
            }
        },
        add: {
            openEditorImpl?(nil, "")
        },
        edit: { index in
            let filters = AyuSettings.shared.regexFilters
            guard index < filters.count else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: filters[index], actions: [
                TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                    var filters = AyuSettings.shared.regexFilters
                    if index < filters.count {
                        filters.remove(at: index)
                        AyuSettings.shared.regexFilters = filters
                    }
                }),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Edit, action: {
                    openEditorImpl?(index, filters[index])
                })
            ]))
        },
        remove: { index in
            var filters = AyuSettings.shared.regexFilters
            if index < filters.count {
                filters.remove(at: index)
                AyuSettings.shared.regexFilters = filters
            }
        }
    )

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, ayuFiltersChanges())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(AyuStrings.get("RegexFilters")),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuRegexFiltersEntries(), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
