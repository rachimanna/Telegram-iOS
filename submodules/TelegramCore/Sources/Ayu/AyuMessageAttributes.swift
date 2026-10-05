import Foundation
import Postbox

/// AyuGram: the message was deleted on the server but is kept locally ("Save deleted messages").
/// Port of the DeletedMessage entity of AyuGram4A (GPL-2.0); instead of a separate table the
/// message simply stays in Postbox with this marker.
public final class AyuDeletedMessageAttribute: MessageAttribute, Equatable {
    /// When AyuGram noticed the deletion (unix time).
    public let deletedAt: Int32

    public init(deletedAt: Int32) {
        self.deletedAt = deletedAt
    }

    required public init(decoder: PostboxDecoder) {
        self.deletedAt = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.deletedAt, forKey: "d")
    }

    public static func ==(lhs: AyuDeletedMessageAttribute, rhs: AyuDeletedMessageAttribute) -> Bool {
        return lhs.deletedAt == rhs.deletedAt
    }
}

public extension Message {
    /// AyuGram: true if the message was deleted on the server and is shown from the local copy.
    var ayuIsDeleted: Bool {
        return self.attributes.contains(where: { $0 is AyuDeletedMessageAttribute })
    }
}

public extension EngineMessage {
    /// AyuGram: true if the message was deleted on the server and is shown from the local copy.
    var ayuIsDeleted: Bool {
        return self._asMessage().ayuIsDeleted
    }
}
