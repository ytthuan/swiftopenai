# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.2] — 2026-05-12

### Fixed

- **F-06 (multipart limits, Azure convenience inits)** — `OpenAI.azure(...)`, `OpenAI.azureFoundry(endpoint:tenantId:...)`, and `OpenAI.azureFoundry(endpoint:token:...)` now forward `maxMultipartPartSize` and `maxMultipartBodySize` to the primary `OpenAI.init`. Parameters are defaulted (512 MB / 1 GB) so the change is fully backward-compatible. Closes the gap from v0.10.1 where iOS/watchOS adopters using Azure convenience inits could not customize multipart size limits. 4 unit tests added.

### Added

- `.github/dependabot.yml` — automates `github-actions` and `swift` package update PRs (weekly cadence); `open-pull-requests-limit: 5` per ecosystem.
- `.github/workflows/digest-refresh.yml` — monthly cron + `workflow_dispatch` that opens a PR to refresh the `swift:6.0@sha256:...` Linux container image digest pin in `ci.yml`. Required because Dependabot's `docker` ecosystem does not support GitHub Actions `container:` image fields.
- `scripts/check-coverage.sh` — parses SwiftPM LLVM coverage JSON via `jq`; `--threshold`/`--tolerance` flags; exits non-zero on regression; posts markdown summary to `$GITHUB_STEP_SUMMARY`.
- `scripts/live-proxy-test.sh` — reads `$SWIFTOPENAI_LIVE_PROXY` (default `/tmp/pibochat-live-proxy.json`); skip-if-absent (exit 0) for CI; otherwise scaffolds a temp Swift Package executable and runs 11 Core + Responses scenarios.
- CI coverage gate — new `coverage` job in `.github/workflows/ci.yml` (macOS); no-regression threshold `67`, tolerance `0.5` (effective floor 66.5%). Linux job untouched.
- 53 new tests (347 → 400) across 4 files: `ChatCompletionTypeTests.swift`, `APIErrorTests.swift`, `TokenProviderTests.swift`, `CodableRoundTripTests.swift`.

### Quality

- Test coverage: 62.6% → **67.0%**. `ChatCompletion.swift`, `APIError.swift`, `CompletionTypes.swift`, `EmbeddingTypes.swift` now at 100%; `TokenProvider.swift` at 94.8%.

### Audit

- `JSONDecoder` `@unchecked Sendable` follow-up (flagged in v0.10.1) closed as **NOT-REPRODUCIBLE** — `JSONDecoder` is `@unchecked Sendable` on both Apple Foundation and Linux swift-corelibs-foundation; the static `let decoder` pattern in `HTTPClient` is the canonical safe approach. No code change needed.
- **S-02 (digest-refresh.yml)** — fixed deterministic branch-name collision on same-day `workflow_dispatch` re-run by switching `git checkout -b` → `git checkout -B` (force-create-or-reset).

## [0.10.1] — 2026-05-12

### Security

- **F-01 (CWE-770, P2/medium)** — Multipart uploads: added configurable size limits (`maxMultipartPartSize`, `maxMultipartBodySize`) to `Configuration` and `OpenAI.init`. Requests exceeding these limits now throw `OpenAIError.bufferOverflow` *before* allocation rather than risking unbounded memory growth at the trust boundary in server-side adopters. Defaults (512 MB part / 1 GB body) track OpenAI's server-side limits; opt out with `Int.max`. The internal encoder was also refactored to eliminate one redundant full-body copy (peak memory reduced from ~3× to ~2× payload). Note: uploads are still buffered eagerly in `Data`; true streaming via `URLRequest.httpBodyStream` is deferred to a future release. **iOS/watchOS adopters should set explicit lower limits** appropriate to their process heap.
- **F-02 (CWE-400, P3/low)** — Server-Sent Events parser: unified Darwin and Linux iterators into a single byte-by-byte loop. The 10 MB line-size cap now fires *before* string materialization on both platforms (previously, Darwin's `AsyncLineSequence`-based path materialized the full `String` line first). EOF-flush behavior preserved on the unified path so unterminated final SSE lines are still processed.
- **F-03 (CWE-494, P3/low)** — CI: Linux job container pinned to immutable Docker digest (`swift:6.0@sha256:efe796...6a49`) to prevent supply-chain attacks via Docker Hub tag mutation. Refresh procedure documented inline in `.github/workflows/ci.yml`. Recommended follow-up: add Dependabot Docker ecosystem for automated digest tracking.

### Changed

- `MultipartFormData.encode()` (internal) is now `encode(maxPartSize:maxBodySize:) throws -> Data`. No public API impact — `MultipartFormData` is `internal`.
- `ServerSentEvents` iterator: non-`DecodingError` exceptions thrown by `JSONDecoder.decode` are now wrapped uniformly as `OpenAIError.decodingError` (was: only `DecodingError` was wrapped, other errors propagated raw).

### Fixed

- `SDK.version` constant synced to `"0.10.1"` (was stale at `"0.8.0"`, never bumped past v0.8.0 despite v0.9.x and v0.10.0 tags). Affects only the `User-Agent` string sent on requests.

### Audit

- L6 deferred audit closure: line-by-line review of all custom `Codable` implementations under `Sources/SwiftOpenAI/Types/Chat/` and `Sources/SwiftOpenAI/Types/Responses/` (12 files, 7 with custom codecs). All polymorphic decoders use safe `default: .other(value)` fallback or explicit `throw`. No medium-or-higher findings. Three low-correctness observations noted but below the suppression bar established in the original Codex scan.

## [0.10.0] — 2026-05-12

### Added

- `ChatCompletionCreateParams.reasoningEffort` — `.disabled / .minimal / .low / .medium / .high / .xhigh / .other`
- `ChatCompletionCreateParams.streamOptions` — `includeUsage` and `includeObfuscation`; wired through `createStream`
- `ChatCompletionCreateParams.verbosity` — `.low / .medium / .high / .other`
- `ChatCompletionCreateParams.promptCacheKey`, `promptCacheRetention` (`.inMemory / .h24 / .other`), `safetyIdentifier`
- `ChatCompletionCreateParams.webSearchOptions` — `searchContextSize` + nested `user_location.approximate`
- `ChatCompletionCreateParams.prediction` — speculative decoding hint
- `ChatCompletionToolFunction.strict: Bool?` — enables Structured Outputs enforcement on function tools
- `ChatCompletionCustomTool` — new custom tool type with `.text / .grammar(.lark | .regex)` formats
- `ChatCompletionToolChoice.custom(name:)` and `.allowedTools(mode:tools:)` cases
- `ServiceTier` promoted from `String?` to a typed enum with `ExpressibleByStringLiteral`

### Changed

- `ChatCompletionTool` refactored from struct to enum (`.function | .custom`). Backward-compatible `init(function:)` and computed accessors (`type`, `function`, `custom`) preserved for source compatibility with v0.9.x call sites.

### Breaking

- `ChatCompletionMessage` enum cases gained `name: String?` on every role; the `.assistant` case also gained `refusal: String?`. Construction remains source-compatible (defaults). **Pattern-matching call sites (e.g. `if case .system(let x)`) now bind `x` as a tuple — callers must add `_` for the new fields.**

### Quality

- Live-tested against `gpt-5.4-nano`. 321 tests pass.

## [0.8.0] — 2026-04-16

### Added
- **Insecure local/LAN endpoint opt-in** — `Configuration.allowInsecureRequests` enables plain `http` / `ws` connections for local development and self-hosted servers
- `isLocalOrLAN(host:)` host classifier — permits loopback (`127.0.0.1`, `::1`), `.local` hostnames, and RFC 1918 private IPv4 ranges (`10.x`, `172.16–31.x`, `192.168.x`)
- `validateURL(_:allowInsecure:)` replaces the previous debug-only assertion with consistent enforcement across debug and release builds
- WebSocket URL derivation (`http → ws`, `https → wss`) now respects the insecure-requests flag
- `OpenAI(apiKey:baseURL:allowInsecureRequests:)` initializer propagates the opt-in through to configuration
- Extensive unit tests for host classification, URL validation, client init with insecure flag, and WebSocket scheme conversion

### Changed
- URL security validation is now enforced in all build configurations (previously debug-only `assertionFailure`)
- Examples and README updated with `allowInsecureRequests` usage and App Transport Security (ATS) guidance

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

[Unreleased]: https://github.com/ytthuan/swiftopenai/compare/v0.10.2...HEAD
[0.10.2]: https://github.com/ytthuan/swiftopenai/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/ytthuan/swiftopenai/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/ytthuan/swiftopenai/compare/v0.8.0...v0.10.0
[0.8.0]: https://github.com/ytthuan/swiftopenai/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/ytthuan/swiftopenai/compare/v0.6.1...v0.7.0
[0.6.1]: https://github.com/ytthuan/swiftopenai/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/ytthuan/swiftopenai/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/ytthuan/swiftopenai/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/ytthuan/swiftopenai/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/ytthuan/swiftopenai/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/ytthuan/swiftopenai/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ytthuan/swiftopenai/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ytthuan/swiftopenai/releases/tag/v0.1.0
