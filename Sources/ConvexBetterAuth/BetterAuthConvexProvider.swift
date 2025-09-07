import Foundation
import BetterAuthSwift

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

/// Minimal protocol mirroring Convex's expected auth provider shape.
/// Replace with Convex's `AuthProvider` when integrating into your app.
public protocol ConvexAuthProvider {
    associatedtype T
    func login() async throws -> T
    func loginFromCache() async throws -> T
    func extractIdToken(from authResult: T) -> String
    func logout() async throws
}

/// Lightweight credentials object returned by the BetterAuth provider.
public struct BetterAuthCredentials: Codable {
    public let sessionToken: String
    public let user: User?
    public let expiresAt: Date?
}

/// A Convex-style AuthProvider backed by Better Auth (Sign in with Apple).
///
/// Usage: Supply this to Convex's `ConvexClientWithAuth` as the provider
/// (conforming it to the real `AuthProvider` type expected by Convex).
public final class BetterAuthProvider: ConvexAuthProvider {
    public typealias T = BetterAuthCredentials

    private let client: BetterAuthClient
    private let enableCachedLogins: Bool

    /// Create a provider backed by a Better Auth server.
    /// - Parameters:
    ///   - baseURL: Base server URL (e.g., "https://your-server.com").
    ///   - enableCachedLogins: If true, `loginFromCache()` will try to restore previous session.
    ///   - notificationCenter: Custom NotificationCenter for token change notifications.
    public init(baseURL: String, enableCachedLogins: Bool = true, notificationCenter: NotificationCenter = .default) throws {
        self.enableCachedLogins = enableCachedLogins
        let authBase = try BetterAuthProvider.normalizeAuthBaseURL(baseURL)
        self.client = try BetterAuthClient(baseURL: authBase.absoluteString, notificationCenter: notificationCenter)
    }

    /// Convenience: Initialize from a Convex deployment root; appends `/api/auth` automatically.
    public convenience init(deploymentURL: String, enableCachedLogins: Bool = true, notificationCenter: NotificationCenter = .default) throws {
        let authBase = try BetterAuthProvider.normalizeAuthBaseURL(deploymentURL)
        try self.init(baseURL: authBase.absoluteString, enableCachedLogins: enableCachedLogins, notificationCenter: notificationCenter)
    }

    private static func normalizeAuthBaseURL(_ input: String) throws -> URL {
        guard var url = URL(string: input) else { throw BetterAuthError.invalidURL(input) }
        let path = url.path.lowercased()
        if path.hasSuffix("/api/auth") || path.hasSuffix("/api/auth/") {
            return url
        }
        url.appendPathComponent("api")
        url.appendPathComponent("auth")
        return url
    }

    /// Create a provider using an existing BetterAuthClient.
    public init(client: BetterAuthClient, enableCachedLogins: Bool = true) {
        self.client = client
        self.enableCachedLogins = enableCachedLogins
    }

    /// Interactive sign-in via Apple and Better Auth.
    public func login() async throws -> BetterAuthCredentials {
        #if canImport(AuthenticationServices)
        let resp = try await client.signInWithApple()
        guard let auth = resp.data else { throw BetterAuthError.missingToken }
        // Exchange for Convex JWT and publish that as the credential for Convex
        let convexJwt = try await client.getConvexToken()
        return BetterAuthCredentials(sessionToken: convexJwt, user: auth.user, expiresAt: auth.session.expiresAt)
        #else
        throw BetterAuthError.invalidURL("AuthenticationServices not available on this platform")
        #endif
    }

    /// Attempts to restore a session from stored tokens and validate with the backend.
    public func loginFromCache() async throws -> BetterAuthCredentials {
        guard enableCachedLogins else { fatalError("Can't call loginFromCache when not enabled") }
        guard client.currentToken != nil else { throw BetterAuthError.missingToken }
        // Validate session and hydrate user if available
        let resp = try await client.getSession()
        let convexJwt = try await client.getConvexToken()
        if let auth = resp.data {
            return BetterAuthCredentials(sessionToken: convexJwt, user: auth.user, expiresAt: auth.session.expiresAt)
        }
        return BetterAuthCredentials(sessionToken: convexJwt, user: nil, expiresAt: nil)
    }

    /// Returns the token string expected by Convex's auth integration.
    public func extractIdToken(from authResult: BetterAuthCredentials) -> String {
        return authResult.sessionToken
    }

    /// Clears server-side session and local token.
    public func logout() async throws {
        try await client.signOut()
    }
}

#if canImport(ConvexMobile)
import ConvexMobile
// Conform to the real Convex AuthProvider when available.
extension BetterAuthProvider: AuthProvider {}
#endif
