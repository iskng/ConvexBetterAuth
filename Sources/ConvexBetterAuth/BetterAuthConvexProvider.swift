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
        // Uses OpenAPI social endpoints by default in BetterAuthSwift
        self.client = try BetterAuthClient(baseURL: baseURL, notificationCenter: notificationCenter)
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
        return BetterAuthCredentials(sessionToken: auth.session.token, user: auth.user, expiresAt: auth.session.expiresAt)
        #else
        throw BetterAuthError.invalidURL("AuthenticationServices not available on this platform")
        #endif
    }

    /// Attempts to restore a session from stored tokens and validate with the backend.
    public func loginFromCache() async throws -> BetterAuthCredentials {
        guard enableCachedLogins else { fatalError("Can't call loginFromCache when not enabled") }
        guard let token = client.currentToken else { throw BetterAuthError.missingToken }
        let resp = try await client.getSession()
        if let auth = resp.data {
            return BetterAuthCredentials(sessionToken: auth.session.token, user: auth.user, expiresAt: auth.session.expiresAt)
        }
        return BetterAuthCredentials(sessionToken: token, user: nil, expiresAt: nil)
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
