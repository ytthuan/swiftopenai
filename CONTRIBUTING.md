# Contributing to SwiftOpenAI

Thank you for your interest in contributing! Here's how to get started.

## Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/swiftopenai.git
   cd swiftopenai
   ```
3. Create a **feature branch**:
   ```bash
   git checkout -b my-feature
   ```

## Development

### Build

```bash
swift build
```

### Test

All contributions must pass the test suite:

```bash
swift test
```

- Write tests for new functionality using **Swift Testing** (`@Test`, `#expect`).
- Use `MockURLProtocol` for HTTP mocking — never hit the real API in tests.

### Code Style

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- All public types must be `Sendable`.
- All network calls use `async throws`.
- Add `///` doc comments to every public type and method.

## Submitting Changes

1. Ensure `swift build` and `swift test` pass.
2. Commit your changes with a clear message.
3. Push to your fork and open a **Pull Request** against `main`.
4. Describe what your PR does and link any related issues.

## Code of Conduct

Be respectful and constructive. We are committed to providing a welcoming and inclusive experience for everyone.
