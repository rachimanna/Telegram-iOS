/*
 * AyuGram hooks for TelegramCore — port of AyuMessagesController.java (AyuGram4A, GPL-2.0).
 *
 * Android intercepts updateDeleteMessages / updateEditMessage in MessagesController.
 * Here the same happens while TelegramCore replays server updates into Postbox
 * (AccountStateManagementUtils.replayFinalState) and when history validation finds that
 * a message no longer exists on the server.
 */

import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import AyuCore

private func ayu_isBotChat(transaction: Transaction, peerId: PeerId) -> Bool {
    if let user = transaction.getPeer(peerId) as? TelegramUser, user.botInfo != nil {
        return true
    }
    return false
}

/// "Save deleted messages": instead of removing messages that were deleted by someone else,
/// keep them and mark them with `AyuDeletedMessageAttribute`.
/// Returns the ids that must still be deleted normally.
func ayu_preserveDeletedMessages(transaction: Transaction, ids: [MessageId]) -> [MessageId] {
    let settings = AyuSettings.shared
    guard settings[.saveDeletedMessages], !ids.isEmpty else {
        return ids
    }
    let now = Int32(Date().timeIntervalSince1970)
    var remaining: [MessageId] = []
    for id in ids {
        guard id.namespace == Namespaces.Message.Cloud, let message = transaction.getMessage(id) else {
            remaining.append(id)
            continue
        }
        if message.ayuIsDeleted {
            continue
        }
        guard settings.shouldSaveDeletedMessage(isBotChat: ayu_isBotChat(transaction: transaction, peerId: id.peerId)) else {
            remaining.append(id)
            continue
        }
        let keepReactions = settings[.saveReactions]
        transaction.updateMessage(id, update: { current in
            var attributes = current.attributes
            if !keepReactions {
                attributes.removeAll(where: { $0 is ReactionsMessageAttribute })
            }
            attributes.append(AyuDeletedMessageAttribute(deletedAt: now))
            return .update(StoreMessage(
                id: current.id,
                customStableId: nil,
                globallyUniqueId: current.globallyUniqueId,
                groupingKey: current.groupingKey,
                threadId: current.threadId,
                timestamp: current.timestamp,
                flags: StoreMessageFlags(current.flags),
                tags: current.tags,
                globalTags: current.globalTags,
                localTags: current.localTags,
                forwardInfo: current.forwardInfo.map { StoreMessageForwardInfo($0) },
                authorId: current.author?.id,
                text: current.text,
                attributes: attributes,
                media: current.media
            ))
        })
    }
    return remaining
}

/// Same for updates that carry "global" message ids (private chats and basic groups).
/// Returns the global ids that must still be deleted normally.
func ayu_preserveDeletedMessages(transaction: Transaction, globalIds: [Int32]) -> [Int32] {
    guard AyuSettings.shared[.saveDeletedMessages], !globalIds.isEmpty else {
        return globalIds
    }
    return globalIds.filter { globalId in
        let messageIds = transaction.messageIdsForGlobalIds([globalId])
        if messageIds.isEmpty {
            return true
        }
        return !ayu_preserveDeletedMessages(transaction: transaction, ids: messageIds).isEmpty
    }
}

private func ayu_describeMedia(_ media: [Media]) -> String? {
    for item in media {
        if item is TelegramMediaImage {
            return "Photo"
        } else if let file = item as? TelegramMediaFile {
            if let fileName = file.fileName, !fileName.isEmpty {
                return "File: \(fileName)"
            }
            return "File"
        }
    }
    return nil
}

private func ayu_entities(_ attributes: [MessageAttribute]) -> [AyuMessageRevision.Entity] {
    guard let entities = (attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute)?.entities else {
        return []
    }
    return entities.compactMap { entity -> AyuMessageRevision.Entity? in
        let type: String
        var url: String?
        switch entity.type {
        case .Bold: type = "bold"
        case .Italic: type = "italic"
        case .Underline: type = "underline"
        case .Strikethrough: type = "strike"
        case .Spoiler: type = "spoiler"
        case .Code: type = "code"
        case .Pre: type = "pre"
        case let .TextUrl(value):
            type = "url"
            url = value
        default:
            return nil
        }
        return AyuMessageRevision.Entity(type: type, offset: entity.range.lowerBound, length: entity.range.count, url: url)
    }
}

/// "Save edits history": stores the previous version of an edited message.
func ayu_recordEdit(accountPeerId: PeerId, transaction: Transaction, previous: Message, updated: StoreMessage) {
    let settings = AyuSettings.shared
    guard settings.shouldSaveEditHistory(isBotChat: ayu_isBotChat(transaction: transaction, peerId: previous.id.peerId)) else {
        return
    }
    let previousMediaIds = previous.media.compactMap { $0.id }
    let updatedMediaIds = updated.media.compactMap { $0.id }
    let mediaChanged = previousMediaIds != updatedMediaIds
    let previousEntities = ayu_entities(previous.attributes)
    let textChanged = previous.text != updated.text || previousEntities != ayu_entities(updated.attributes)
    if !textChanged && !mediaChanged {
        return
    }
    var previousEditDate: Int32 = 0
    if let edited = previous.attributes.first(where: { $0 is EditedMessageAttribute }) as? EditedMessageAttribute {
        previousEditDate = edited.date
    }
    let revision = AyuMessageRevision(
        text: previous.text,
        entities: previousEntities,
        messageDate: previous.timestamp,
        savedAt: Int32(Date().timeIntervalSince1970),
        editDate: previousEditDate,
        replacedMedia: mediaChanged ? ayu_describeMedia(previous.media) : nil
    )
    AyuEditHistoryStore.shared.append(
        accountPeerId: accountPeerId.toInt64(),
        peerId: previous.id.peerId.toInt64(),
        message: AyuMessageKey(namespace: previous.id.namespace, id: previous.id.id),
        revision: revision
    )
}

/// Sends a read packet for `peer` up to `maxId` even in ghost mode
/// (AyuGhostUtils.markReadOnServer: "Read until here", "Read after reply").
func ayu_pushReadOnServer(network: Network, stateManager: AccountStateManager?, peer: Peer, maxId: Int32) -> Signal<Never, NoError> {
    if peer is TelegramChannel {
        guard let inputChannel = apiInputChannel(peer) else {
            return .complete()
        }
        return network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: maxId))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .complete()
        }
        |> ignoreValues
    }
    guard let inputPeer = apiInputPeer(peer) else {
        return .complete()
    }
    return network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxId))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        if let result = result {
            switch result {
            case let .affectedMessages(affectedMessagesData):
                stateManager?.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
            }
        }
        return .complete()
    }
}

/// Marks the chat read locally up to `index` and tells the server, ignoring ghost mode once.
func _internal_ayuReadOnServer(account: Account, index: MessageIndex) -> Signal<Never, NoError> {
    let peerId = index.id.peerId
    if peerId.namespace == Namespaces.Peer.SecretChat {
        return .complete()
    }
    return account.postbox.transaction { transaction -> Peer? in
        // The local read state is updated as usual; its own push is skipped in ghost mode,
        // the explicit request below is what reaches the server.
        let _ = transaction.applyInteractiveReadMaxIndex(index)
        return transaction.getPeer(peerId)
    }
    |> mapToSignal { peer -> Signal<Never, NoError> in
        guard let peer = peer else {
            return .complete()
        }
        return ayu_pushReadOnServer(network: account.network, stateManager: account.stateManager, peer: peer, maxId: index.id.id)
    }
}

/// Saved previous versions of `message` (oldest first), for the "Edits history" screen.
public func ayuEditRevisions(accountPeerId: PeerId, message: Message) -> [AyuMessageRevision] {
    return AyuEditHistoryStore.shared.revisions(
        accountPeerId: accountPeerId.toInt64(),
        peerId: message.id.peerId.toInt64(),
        message: AyuMessageKey(namespace: message.id.namespace, id: message.id.id)
    )
}

public func ayuHasEditRevisions(accountPeerId: PeerId, message: Message) -> Bool {
    return !ayuEditRevisions(accountPeerId: accountPeerId, message: message).isEmpty
}
