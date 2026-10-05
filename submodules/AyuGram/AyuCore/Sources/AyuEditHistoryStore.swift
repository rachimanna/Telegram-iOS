/*
 * Edits history (EditedMessage entity / EditedMessageDao of AyuGram4A, GPL-2.0).
 *
 * Stored outside Postbox on purpose: Telegram replaces a message's attributes whenever it
 * re-fetches it from the server, which would silently drop history kept as an attribute.
 * Layout: <Application Support>/AyuGram/edits/<accountPeerId>/<peerId>.json
 */

import Foundation

public struct AyuMessageRevision: Codable, Equatable {
    public struct Entity: Codable, Equatable {
        public var type: String
        public var offset: Int
        public var length: Int
        public var url: String?

        public init(type: String, offset: Int, length: Int, url: String? = nil) {
            self.type = type
            self.offset = offset
            self.length = length
            self.url = url
        }
    }

    /// Text of the message *before* the edit.
    public var text: String
    public var entities: [Entity]
    /// Original send date of the message (unix time).
    public var messageDate: Int32
    /// When the edit was observed (entityCreateDate on Android).
    public var savedAt: Int32
    /// Edit date of that version, 0 if it was the original.
    public var editDate: Int32
    /// Short description of media that was replaced by the edit ("Photo", "File: report.pdf"), if any.
    public var replacedMedia: String?

    public init(text: String, entities: [Entity], messageDate: Int32, savedAt: Int32, editDate: Int32, replacedMedia: String?) {
        self.text = text
        self.entities = entities
        self.messageDate = messageDate
        self.savedAt = savedAt
        self.editDate = editDate
        self.replacedMedia = replacedMedia
    }
}

public struct AyuMessageKey: Hashable, Codable {
    public var namespace: Int32
    public var id: Int32

    public init(namespace: Int32, id: Int32) {
        self.namespace = namespace
        self.id = id
    }

    var stringValue: String {
        return "\(self.namespace):\(self.id)"
    }
}

public final class AyuEditHistoryStore {
    public static let shared = AyuEditHistoryStore()

    private let queue = DispatchQueue(label: "org.ayugram.edit-history")
    private let rootURL: URL
    /// accountPeerId → peerId → "namespace:id" → revisions (oldest first)
    private var loaded: [Int64: [Int64: [String: [AyuMessageRevision]]]] = [:]

    public init(rootURL: URL? = nil) {
        if let rootURL = rootURL {
            self.rootURL = rootURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.rootURL = support.appendingPathComponent("AyuGram/edits", isDirectory: true)
        }
    }

    private func fileURL(accountPeerId: Int64, peerId: Int64) -> URL {
        return self.rootURL
            .appendingPathComponent("\(accountPeerId)", isDirectory: true)
            .appendingPathComponent("\(peerId).json", isDirectory: false)
    }

    private func load(accountPeerId: Int64, peerId: Int64) -> [String: [AyuMessageRevision]] {
        if let cached = self.loaded[accountPeerId]?[peerId] {
            return cached
        }
        var result: [String: [AyuMessageRevision]] = [:]
        if let data = try? Data(contentsOf: self.fileURL(accountPeerId: accountPeerId, peerId: peerId)),
           let decoded = try? JSONDecoder().decode([String: [AyuMessageRevision]].self, from: data) {
            result = decoded
        }
        self.loaded[accountPeerId, default: [:]][peerId] = result
        return result
    }

    private func save(accountPeerId: Int64, peerId: Int64, _ value: [String: [AyuMessageRevision]]) {
        self.loaded[accountPeerId, default: [:]][peerId] = value
        let url = self.fileURL(accountPeerId: accountPeerId, peerId: peerId)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    /// Appends the previous version of an edited message.
    public func append(accountPeerId: Int64, peerId: Int64, message: AyuMessageKey, revision: AyuMessageRevision) {
        self.queue.async {
            var all = self.load(accountPeerId: accountPeerId, peerId: peerId)
            var list = all[message.stringValue] ?? []
            if let last = list.last, last.text == revision.text, last.entities == revision.entities, last.replacedMedia == revision.replacedMedia {
                return
            }
            list.append(revision)
            all[message.stringValue] = list
            self.save(accountPeerId: accountPeerId, peerId: peerId, all)
        }
    }

    public func revisions(accountPeerId: Int64, peerId: Int64, message: AyuMessageKey) -> [AyuMessageRevision] {
        return self.queue.sync {
            return self.load(accountPeerId: accountPeerId, peerId: peerId)[message.stringValue] ?? []
        }
    }

    public func hasRevisions(accountPeerId: Int64, peerId: Int64, message: AyuMessageKey) -> Bool {
        return !self.revisions(accountPeerId: accountPeerId, peerId: peerId, message: message).isEmpty
    }

    /// Waits for pending writes (tests).
    public func flush() {
        self.queue.sync {}
    }

    /// "Clear Ayu Database"
    public func removeAll() {
        self.queue.sync {
            self.loaded = [:]
            try? FileManager.default.removeItem(at: self.rootURL)
        }
    }

    public func totalCount() -> Int {
        return self.queue.sync {
            guard let accounts = try? FileManager.default.contentsOfDirectory(at: self.rootURL, includingPropertiesForKeys: nil) else {
                return 0
            }
            var count = 0
            for account in accounts {
                guard let files = try? FileManager.default.contentsOfDirectory(at: account, includingPropertiesForKeys: nil) else {
                    continue
                }
                for file in files {
                    if let data = try? Data(contentsOf: file), let decoded = try? JSONDecoder().decode([String: [AyuMessageRevision]].self, from: data) {
                        count += decoded.values.reduce(0, { $0 + $1.count })
                    }
                }
            }
            return count
        }
    }
}
