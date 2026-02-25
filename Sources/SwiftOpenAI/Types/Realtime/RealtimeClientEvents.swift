import Foundation

/// All client events that can be sent to the Realtime API.
public enum RealtimeClientEvent: Encodable, Sendable {
    case sessionUpdate(RealtimeSessionUpdateEvent)
    case inputAudioBufferAppend(RealtimeInputAudioBufferAppendEvent)
    case inputAudioBufferCommit(RealtimeInputAudioBufferCommitEvent)
    case inputAudioBufferClear(RealtimeInputAudioBufferClearEvent)
    case conversationItemCreate(RealtimeConversationItemCreateEvent)
    case conversationItemDelete(RealtimeConversationItemDeleteEvent)
    case conversationItemTruncate(RealtimeConversationItemTruncateEvent)
    case responseCreate(RealtimeResponseCreateEvent)
    case responseCancel(RealtimeResponseCancelEvent)
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .sessionUpdate(let e): try e.encode(to: encoder)
        case .inputAudioBufferAppend(let e): try e.encode(to: encoder)
        case .inputAudioBufferCommit(let e): try e.encode(to: encoder)
        case .inputAudioBufferClear(let e): try e.encode(to: encoder)
        case .conversationItemCreate(let e): try e.encode(to: encoder)
        case .conversationItemDelete(let e): try e.encode(to: encoder)
        case .conversationItemTruncate(let e): try e.encode(to: encoder)
        case .responseCreate(let e): try e.encode(to: encoder)
        case .responseCancel(let e): try e.encode(to: encoder)
        }
    }
}

// MARK: - Session Events

public struct RealtimeSessionUpdateEvent: Codable, Sendable {
    public let type: String = "session.update"
    public let session: RealtimeSessionConfig
    public var eventId: String?
    
    public init(session: RealtimeSessionConfig, eventId: String? = nil) {
        self.session = session
        self.eventId = eventId
    }
}

// MARK: - Input Audio Buffer Events

public struct RealtimeInputAudioBufferAppendEvent: Codable, Sendable {
    public let type: String = "input_audio_buffer.append"
    public let audio: String // base64-encoded audio
    public var eventId: String?
    
    public init(audio: String, eventId: String? = nil) {
        self.audio = audio
        self.eventId = eventId
    }
}

public struct RealtimeInputAudioBufferCommitEvent: Codable, Sendable {
    public let type: String = "input_audio_buffer.commit"
    public var eventId: String?
    
    public init(eventId: String? = nil) {
        self.eventId = eventId
    }
}

public struct RealtimeInputAudioBufferClearEvent: Codable, Sendable {
    public let type: String = "input_audio_buffer.clear"
    public var eventId: String?
    
    public init(eventId: String? = nil) {
        self.eventId = eventId
    }
}

// MARK: - Conversation Item Events

public struct RealtimeConversationItemCreateEvent: Codable, Sendable {
    public let type: String = "conversation.item.create"
    public let item: RealtimeConversationItem
    public var previousItemId: String?
    public var eventId: String?
    
    public init(item: RealtimeConversationItem, previousItemId: String? = nil, eventId: String? = nil) {
        self.item = item
        self.previousItemId = previousItemId
        self.eventId = eventId
    }
}

public struct RealtimeConversationItemDeleteEvent: Codable, Sendable {
    public let type: String = "conversation.item.delete"
    public let itemId: String
    public var eventId: String?
    
    public init(itemId: String, eventId: String? = nil) {
        self.itemId = itemId
        self.eventId = eventId
    }
}

public struct RealtimeConversationItemTruncateEvent: Codable, Sendable {
    public let type: String = "conversation.item.truncate"
    public let itemId: String
    public let contentIndex: Int
    public let audioEndMs: Int
    public var eventId: String?
    
    public init(itemId: String, contentIndex: Int, audioEndMs: Int, eventId: String? = nil) {
        self.itemId = itemId
        self.contentIndex = contentIndex
        self.audioEndMs = audioEndMs
        self.eventId = eventId
    }
}

// MARK: - Response Events

public struct RealtimeResponseCreateEvent: Codable, Sendable {
    public let type: String = "response.create"
    public var response: RealtimeResponseConfig?
    public var eventId: String?
    
    public init(response: RealtimeResponseConfig? = nil, eventId: String? = nil) {
        self.response = response
        self.eventId = eventId
    }
}

public struct RealtimeResponseCancelEvent: Codable, Sendable {
    public let type: String = "response.cancel"
    public var eventId: String?
    
    public init(eventId: String? = nil) {
        self.eventId = eventId
    }
}
