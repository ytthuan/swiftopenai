# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] — 2026-02-26

### Added
- **Azure AI Foundry support** — `OpenAI.azureFoundry()` factory methods for Azure AI Foundry project endpoints with Entra ID (OAuth 2.0 client credentials) authentication
- `TokenProvider` protocol for dynamic authentication with automatic token refresh
- `EntraIDTokenProvider` actor — obtains and caches Azure Entra ID tokens via OAuth 2.0 client credentials flow (~1 hour lifetime, auto-refreshes 5 min before expiry)
- `StaticTokenProvider` — for pre-obtained tokens from external sources (CLI, backend)
- `OpenAI.azure(resourceName:apiKey:)` factory for Azure OpenAI v1 GA API with `api-key` header auth
- `OpenAI.azureFoundry(endpoint:tenantId:clientId:clientSecret:)` factory for full Entra ID auth
- `OpenAI.azureFoundry(endpoint:token:)` factory for pre-obtained token auth
- `Configuration.defaultQueryItems` — query items appended to every request (used for `api-version`)
- `Configuration.apiKeyHeaderName` — custom API key header name (e.g., `"api-key"` for Azure)
- Interactive streaming chat console in ExampleApp (`swift run ExampleApp chat`) — supports both API key and Foundry backends with auto-detection of Conversations API availability
- 19 new unit tests for Azure configuration, initializers, token provider, and query merge
- Azure Foundry live tests in ExampleApp (token auth, conversations CRUD, responses with conversation)

### Changed
- Comprehensive Azure documentation in README with feature comparison table, Entra ID setup guide, and Conversations API usage with Foundry project endpoints

### Fixed
- `EntraIDTokenProvider.percentEncode()` now uses RFC 3986 unreserved character set for form-urlencoded body encoding — prevents silent credential corruption when client secrets contain `&`, `=`, or `+`

## [0.6.1] — 2026-02-25

### Fixed
- Add 10 MB buffer limit on streaming error response body — prevents unbounded memory accumulation from malicious/misconfigured servers

## [0.6.0] — 2026-02-25

### Added
- Connection pre-warming via `OpenAI.warmConnection()` — eliminates TCP/TLS handshake latency on first request
- WebSocket keepalive pings in `WebSocketClient` — prevents idle connection drops in Realtime/ResponsesWebSocket sessions
- Explicit connect timeout cap (`timeoutIntervalForResource` capped at 1200s)

### Changed
- **SSE parsing**: Replaced byte-by-byte iteration with line-based processing (`AsyncLineSequence`) on Apple platforms — reduces async suspension overhead by 100-300x per SSE event
- **URL construction**: Cached `URLComponents` and pre-built common headers in `HTTPClient.init` — eliminates per-request URL re-parsing
- **MultipartFormData**: Uses `ContiguousArray<UInt8>` builder instead of intermediate `Data` allocations — 30-50% fewer allocations during form encoding
- **JSON decode**: Added explicit `CodingKeys` to SSE hot-path types (`ResponseStreamEvent`, `ChatCompletionChunk`, `ChatCompletion`, etc.) — eliminates runtime `convertFromSnakeCase` key transformation
- **Retry delay**: Backoff capped at 8s (matching Python SDK `MAX_RETRY_DELAY`); `Retry-After` header respected up to 120s

### Fixed
- SSE buffer overflow check now guards per-line size (not cumulative stream length) — prevents false truncation on large streaming responses (64K+ tokens)

## [0.5.0] — 2026-02-25

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
