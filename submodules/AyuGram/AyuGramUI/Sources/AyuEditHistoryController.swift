/*
 * "Edits history" screen (MessageHistoryActivity / EditedMessage of AyuGram4A, GPL-2.0).
 */

import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import ItemListUI
import PresentationDataUtils
import AccountContext
import AyuCore

private enum AyuEditHistoryEntry: ItemListNodeEntry {
    case header(Int, String)
    case text(Int, String)
    case media(Int, String)
    case empty(String)

    var section: ItemListSectionId {
        switch self {
        case let .header(index, _), let .text(index, _), let .media(index, _):
            return Int32(index)
        case .empty:
            return 0
        }
    }

    var stableId: Int {
        switch self {
        case let .header(index, _): return index * 3
        case let .text(index, _): return index * 3 + 1
        case let .media(index, _): return index * 3 + 2
        case .empty: return -1
        }
    }

    static func <(lhs: AyuEditHistoryEntry, rhs: AyuEditHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .text(_, text):
            return ItemListMultilineTextItem(presentationData: presentationData, text: text, enabledEntityTypes: [.allUrl, .mention, .hashtag], sectionId: self.section, style: .blocks)
        case let .media(_, text), let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ayuEditHistoryEntries(presentationData: PresentationData, revisions: [AyuMessageRevision], currentText: String, currentDate: Int32) -> [AyuEditHistoryEntry] {
    var entries: [AyuEditHistoryEntry] = []
    if revisions.isEmpty {
        entries.append(.empty(AyuStrings.get("EditsHistoryEmpty")))
    }
    for (index, revision) in revisions.enumerated() {
        let versionDate = revision.editDate != 0 ? revision.editDate : revision.messageDate
        let dateString = stringForFullDate(timestamp: versionDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
        entries.append(.header(index, dateString.uppercased()))
        entries.append(.text(index, revision.text.isEmpty ? "—" : revision.text))
        if let media = revision.replacedMedia {
            entries.append(.media(index, AyuStrings.format("RevisionMediaReplaced", media)))
        }
    }
    if !revisions.isEmpty {
        let index = revisions.count
        let dateString = stringForFullDate(timestamp: currentDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
        entries.append(.header(index, "\(AyuStrings.get("RevisionCurrent")) · \(dateString)".uppercased()))
        entries.append(.text(index, currentText.isEmpty ? "—" : currentText))
    }
    return entries
}

public func ayuEditHistoryController(context: AccountContext, message: Message) -> ViewController {
    let revisions = ayuEditRevisions(accountPeerId: context.account.peerId, message: message)
    var currentDate = message.timestamp
    if let edited = message.attributes.first(where: { $0 is EditedMessageAttribute }) as? EditedMessageAttribute {
        currentDate = edited.date
    }
    let currentText = message.text

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(AyuStrings.get("EditsHistoryTitle")),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayuEditHistoryEntries(presentationData: presentationData, revisions: revisions, currentText: currentText, currentDate: currentDate), style: .blocks, animateChanges: false)
        return (controllerState, (listState, Void()))
    }

    return ItemListController(context: context, state: signal)
}
