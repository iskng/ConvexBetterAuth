import XCTest
@testable import ConvexBetterAuth
import BetterAuthSwift

final class BetterAuthConvexProviderTests: XCTestCase {
    func testLoginFromCacheValidatesSession() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/session")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer cached-token")
            let body = """
            {"success": true, "data": {"session": {"token": "new-token"}, "user": {"id": "u"}}}
            """.data(using: .utf8)!
            return (200, body)
        }
        let session = URLSession(configuration: config)
        let store = InMemoryTokenStore()
        try store.storeToken("cached-token")
        let client = try BetterAuthClient(baseURL: "https://example.com", session: session, tokenStore: store)
        let provider = BetterAuthProvider(client: client)
        let creds = try await provider.loginFromCache()
        XCTAssertEqual(creds.sessionToken, "new-token")
        XCTAssertEqual(store.retrieveToken(), "new-token")
    }

    func testExtractIdTokenReturnsToken() {
        let creds = BetterAuthCredentials(sessionToken: "abc", user: nil, expiresAt: nil)
        // Create a dummy provider (won't use network)
        let client = try! BetterAuthClient(baseURL: "https://example.com")
        let provider = BetterAuthProvider(client: client)
        XCTAssertEqual(provider.extractIdToken(from: creds), "abc")
    }

    func testLogoutClearsToken() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/signout")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = """
            {"success": true}
            """.data(using: .utf8)!
            return (200, body)
        }
        let session = URLSession(configuration: config)
        let store = InMemoryTokenStore()
        try store.storeToken("tok")
        let client = try BetterAuthClient(baseURL: "https://example.com", session: session, tokenStore: store)
        let provider = BetterAuthProvider(client: client)
        try await provider.logout()
        XCTAssertNil(store.retrieveToken())
    }
}

// MARK: - Test helpers

final class InMemoryTokenStore: TokenStoring {
    private var token: String?
    func storeToken(_ token: String) throws { self.token = token }
    func retrieveToken() -> String? { token }
    func deleteToken() throws { token = nil }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "NoHandler", code: 0))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

