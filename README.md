# ConvexBetterAuth

Lightweight Swift package to use Better Auth (Sign in with Apple) as an auth provider for Convex.

This package wraps the `BetterAuthSwift` client and exposes a Convex-style provider with `login`, `loginFromCache`, `extractIdToken`, and `logout` methods.

## Install

Add both packages to your app:

```swift
// In your app's Package.swift
dependencies: [
    .package(url: "https://github.com/iskng/BetterAuthSwift.git", from: "1.0.0"),
    .package(url: "https://github.com/iskng/ConvexBetterAuth.git", from: "0.1.0")
]
```

This repository depends on `BetterAuthSwift`.

## Usage

```swift
import ConvexBetterAuth

// Create provider
let provider = try BetterAuthProvider(baseURL: "https://your-better-auth-server.com")

// Interactive login with Apple
let creds = try await provider.login()

// Cached login (if previously authenticated)
let cached = try await provider.loginFromCache()

// Provide token to Convex
let idToken = provider.extractIdToken(from: cached)
```

When integrating with Convex, conform this provider to the actual `AuthProvider` protocol expected by `ConvexClientWithAuth` (replace the placeholder `ConvexAuthProvider` if needed).

## License

MIT
