# ConvexBetterAuth

Lightweight Swift package to use Better Auth (Sign in with Apple) as an auth provider for Convex.

This package wraps the `BetterAuthSwift` client and exposes a Convex-style provider with `login`, `loginFromCache`, `extractIdToken`, and `logout` methods. When `ConvexMobile` is available (via the `convex-swift` package dependency), the provider automatically conforms to Convex's `AuthProvider` protocol so it can be passed directly into `ConvexClientWithAuth`.

## Install

Add the packages to your app:

```swift
// In your app's Package.swift
dependencies: [
    .package(url: "https://github.com/iskng/BetterAuthSwift.git", from: "0.1.0"),
    .package(url: "https://github.com/iskng/ConvexBetterAuth.git", from: "0.1.0")
]
```

This repository depends on `BetterAuthSwift` and `convex-swift` (ConvexMobile).

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

When integrating with Convex, pass the provider directly into `ConvexClientWithAuth`—the package supplies the `AuthProvider` conformance whenever `ConvexMobile` is linked.

## License

MIT
