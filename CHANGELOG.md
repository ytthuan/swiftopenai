# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — v0.5.0

### Added
- Retry with exponential backoff for 429/5xx responses (configurable `maxRetries`, `retryDelay`)
- Auto-pagination via `AutoPaginatingSequence` AsyncSequence on `CursorPage`
- `SDK.version` and `SDK.userAgent` centralized constants
- `ResponseStreamEvent` fields: `itemId`, `text`, `arguments`, `name`, `callId`, `sequenceNumber`
- `OpenAI.shutdown()` for proper URLSession cleanup
- `ChatCompletionMessage` Decodable conformance (now fully Codable)
- Public memberwise initializers on `ChatCompletion` and `Response` types
- `TruncationStrategy` and `ServiceTier` enums with `other(String)` fallback
- SSE buffer size limit (10 MB) and WebSocket `maximumMessageSize`
- Audio MIME type inference from filename extension
- SECURITY.md, CONTRIBUTING.md
- Build caching in CI; Linux validation in release workflow

### Fixed
- `ConversationItem.callId` always decoded as nil due to CodingKeys conflict
- `ResponsesWebSocket` `isInFlight` permanently stuck on send failure
- URLSession resource leaks in `HTTPClient` and `RealtimeConnection`
- CRLF header injection via `organization`, `project`, and `mimeType` values
- Realtime URL not using `URLComponents` (model name left unencoded)
- Missing `OpenAI-Beta: realtime=v1` header on Realtime connections
- `Content-Type` header incorrectly set on GET/DELETE requests
- `ChatCompletions.createStream` missing 11 parameters vs `create`

### Security
- Sanitized `organization`, `project`, and `mimeType` headers against CRLF injection
- HTTPS enforcement promoted from DEBUG-only to always-on
- Linux security defaults (cookies and cache disabled)
- GitHub Actions workflow steps pinned to commit SHAs
- Added `.env`/`.key` patterns to `.gitignore`

---

## [0.4.0] — 2026-02-25

### Added
- **Realtime API** — full `RealtimeConnection` over WebSocket (`wss://api.openai.com/v1/realtime`)
- Darwin-only URLSession configuration wrapped in `#if canImport(Darwin)` for Linux compatibility

### Changed
- `CursorPage` now fully `Codable`
- `ServiceTier` uses flexible enum with `other(String)` fallback
- Stream variable naming improvements

### Fixed
- 5-cycle performance and security optimization pass (connection pooling, request encoding, response decoding)
- 7 bugs surfaced by automated audit (type safety, error propagation, API surface gaps)
- `Model.ownedBy` made optional for Azure/third-party provider compatibility

---

## [0.3.1] — 2026-02-25

### Fixed
- Error handling improvements across all resources
- Type-safety hardening (stricter Codable conformances)
- Security surface reduction (header sanitization, safe defaults)
- API surface corrections identified in architecture assessment

---

## [0.3.0] — 2026-02-24

### Added
- **WebSocket mode** for the Responses API — stream events over a persistent WebSocket connection
- Comprehensive README documenting the Responses API, streaming, function calling, structured outputs, and WebSocket mode

---

## [0.2.0] — 2026-02-24

### Added
- **Conversations API** resource (`client.conversations`)
- Enhanced tool types and convenience APIs for function calling

### Fixed
- `Model.ownedBy` made optional for Azure compatibility
- Type resilience improvements for Azure and third-party provider responses

---

## [0.1.0] — 2026-02-24

### Added
- Initial release of SwiftOpenAI — async/await Swift 6 client for the OpenAI API
- Swift package scaffolding targeting iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+
- **Core infrastructure**: `OpenAI` client, `HTTPClient`, `APIError`, `Configuration`, `MultipartFormData`, SSE streaming parser
- **Models** resource (`client.models`)
- **Embeddings** resource (`client.embeddings`)
- **Moderations** resource (`client.moderations`)
- **Chat Completions** resource (`client.chat.completions`) — streaming and non-streaming
- **Files** resource (`client.files`)
- **Audio** resource (`client.audio`) — transcriptions, translations, speech
- **Images** resource (`client.images`) — generate, edit, variations
- **Responses API** resource (`client.responses`) — function calling, structured outputs, streaming, compaction
- **Fine-Tuning** resource (`client.fineTuning`)
- **Batches** resource (`client.batches`)
- **Vector Stores** resource (`client.vectorStores`)
- **Uploads** resource (`client.uploads`)
- **Completions** resource (`client.completions`) — legacy completions
- Linux support via `FoundationNetworking` with conditional compilation throughout
- CI/CD workflows (GitHub Actions) with Swift build and test pipelines
- Comprehensive usage examples in `Examples/`

[Unreleased]: https://github.com/ytthuan/swiftopenai/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/ytthuan/swiftopenai/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/ytthuan/swiftopenai/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/ytthuan/swiftopenai/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ytthuan/swiftopenai/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ytthuan/swiftopenai/releases/tag/v0.1.0
