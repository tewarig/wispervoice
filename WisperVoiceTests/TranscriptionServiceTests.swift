import XCTest
// @testable import WisperVoice (logic test - sources compiled in)

final class TranscriptionServiceTests: XCTestCase {

    // MARK: - polish()
    func testPolishEmptyReturnsEmpty() async {
        let svc = TranscriptionService()
        let out = await svc.polish("", useLLMPolishing: false, openAIKey: nil)
        XCTAssertEqual(out, "")
        let out2 = await svc.polish("   ", useLLMPolishing: false, openAIKey: nil)
        XCTAssertEqual(out2, "")
    }

    func testPolishRemovesFillersCaseInsensitive() async {
        let svc = TranscriptionService()
        let raw = " um hello uh world like you know so actually basically literally test "
        let out = await svc.polish(raw, useLLMPolishing: false, openAIKey: nil)
        // fillers removed, double spaces collapsed, capitalized first letter
        XCTAssertFalse(out.lowercased().contains(" um "))
        XCTAssertFalse(out.lowercased().contains(" uh "))
        XCTAssertEqual(String(out.prefix(1)), String(out.prefix(1)).uppercased())
        XCTAssertFalse(out.contains("  "))
    }

    func testPolishLeadingFillerRemoved() async {
        let svc = TranscriptionService()
        let out = await svc.polish("um hello world", useLLMPolishing: false, openAIKey: nil)
        XCTAssertEqual(out, "Hello world")
        let out2 = await svc.polish("Uh hello", useLLMPolishing: false, openAIKey: nil)
        XCTAssertEqual(out2, "Hello")
        let out3 = await svc.polish("like hello there", useLLMPolishing: false, openAIKey: nil)
        XCTAssertEqual(out3, "Hello there")
    }

    func testPolishCollapsesDoubleSpacesAndCapitalizes() async {
        let svc = TranscriptionService()
        let out = await svc.polish("  hello   world  ", useLLMPolishing: false, openAIKey: nil)
        XCTAssertEqual(out, "Hello world")
        XCTAssertEqual(String(out.prefix(1)), String(out.prefix(1)).uppercased())
    }

    func testPolishLLMDisabledEvenWithKey() async {
        let svc = TranscriptionService()
        let out = await svc.polish("hello um world", useLLMPolishing: false, openAIKey: "sk-test")
        XCTAssertEqual(out, "Hello world")
    }

    func testPolishLLMEnabledButNilKeyDoesLocalOnly() async {
        let svc = TranscriptionService()
        let out = await svc.polish("hello uh world", useLLMPolishing: true, openAIKey: nil)
        XCTAssertEqual(out, "Hello world")
    }

    func testPolishLLMEnabledEmptyKeyDoesLocalOnly() async {
        let svc = TranscriptionService()
        let out = await svc.polish("hello uh world", useLLMPolishing: true, openAIKey: "")
        XCTAssertEqual(out, "Hello world")
    }

    func testPolishLLMSuccessPath() async {
        // Mock URLProtocol to return polished text
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)

        let mockJSON = """
        {"choices":[{"message":{"content":" Hello, polished world. "}}]}
        """.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertTrue(req.url?.absoluteString.contains("chat/completions") == true)
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, mockJSON)
        }
        let out = await svc.polish("hello world", useLLMPolishing: true, openAIKey: "sk-test")
        XCTAssertEqual(out, "Hello, polished world.")
    }

    func testPolishLLMFailureFallsBackToLocal() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)
        MockURLProtocol.handler = { req in
            return (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let out = await svc.polish("hello uh world", useLLMPolishing: true, openAIKey: "sk-test")
        // local polish still applied, not throwing
        XCTAssertEqual(out, "Hello world")
    }

    // MARK: - llmPolish direct
    func testLLMPolishDecodesCorrectly() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)
        let json = #"{"choices":[{"message":{"content":" Polished! "}}]}"#.data(using: .utf8)!
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-123")
            // body contains model gpt-4o-mini
            let body = String(data: req.httpBody!, encoding: .utf8)!
            XCTAssertTrue(body.contains("gpt-4o-mini"))
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }
        let out = try await svc.llmPolish("raw", apiKey: "sk-123")
        XCTAssertEqual(out, "Polished!")
    }

    func testLLMPolishThrowsOnHTTPError() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)
        MockURLProtocol.handler = { req in
            return (HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data())
        }
        do {
            _ = try await svc.llmPolish("raw", apiKey: "sk")
            XCTFail("should throw")
        } catch { XCTAssertNotNil(error) }
    }

    func testLLMPolishThrowsOnInvalidJSON() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)
        MockURLProtocol.handler = { req in
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("not json".utf8))
        }
        do { _ = try await svc.llmPolish("raw", apiKey: "sk"); XCTFail() } catch { XCTAssertNotNil(error) }
    }

    // MARK: - transcribeWithWhisper
    func testWhisperEmptyAPIKeyThrows() async {
        let svc = TranscriptionService()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dummy.wav")
        try? Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        do { _ = try await svc.transcribeWithWhisper(fileURL: url, apiKey: "", language: "en"); XCTFail() }
        catch { XCTAssertTrue((error as NSError).code == -4) }
    }

    func testWhisperFileNotFoundThrows() async {
        let svc = TranscriptionService()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID()).wav")
        do { _ = try await svc.transcribeWithWhisper(fileURL: url, apiKey: "sk", language: nil); XCTFail() }
        catch { XCTAssertNotNil(error) }
    }

    func testWhisperHTTPErrorThrows() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).wav")
        try? Data("fake audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        MockURLProtocol.handler = { req in
            XCTAssertTrue(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
            XCTAssertTrue(req.value(forHTTPHeaderField: "Content-Type")!.contains("multipart"))
            let errData = #"{"error":"bad"}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, errData)
        }
        do { _ = try await svc.transcribeWithWhisper(fileURL: url, apiKey: "sk-test", language: "en"); XCTFail() }
        catch { XCTAssertTrue((error as NSError).localizedDescription.contains("Whisper API error")) }
    }

    func testWhisperSuccessWithoutLanguage() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).wav")
        try Data("audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        MockURLProtocol.handler = { req in
            let body = String(data: req.httpBody!, encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("whisper-1"))
            XCTAssertFalse(body.contains("name=\"language\""))
            let resp = #"{"text":"hello world"}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, resp)
        }
        let out = try await svc.transcribeWithWhisper(fileURL: url, apiKey: "sk", language: nil)
        XCTAssertEqual(out, "hello world")
    }

    func testWhisperSuccessWithLanguage() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).wav")
        try Data("audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        MockURLProtocol.handler = { req in
            let body = String(data: req.httpBody!, encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("language"))
            XCTAssertTrue(body.contains("en"))
            let resp = #"{"text":"bonjour"}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, resp)
        }
        let out = try await svc.transcribeWithWhisper(fileURL: url, apiKey: "sk", language: "en")
        XCTAssertEqual(out, "bonjour")
    }

    func testWhisperSuccessEmptyLanguageStringNotSent() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let svc = TranscriptionService(urlSession: session)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID()).wav")
        try Data("audio".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        MockURLProtocol.handler = { req in
            let body = String(data: req.httpBody!, encoding: .utf8) ?? ""
            XCTAssertFalse(body.contains("name=\"language\""))
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, #"{"text":"hi"}"#.data(using: .utf8)!)
        }
        let out = try await svc.transcribeWithWhisper(fileURL: url, apiKey: "sk", language: "")
        XCTAssertEqual(out, "hi")
    }

    // MARK: - TranscriptionProvider
    func testProviderRawValues() {
        XCTAssertEqual(TranscriptionProvider.appleSpeech.rawValue, "Apple Speech (On-device)")
        XCTAssertEqual(TranscriptionProvider.openAIWhisper.rawValue, "OpenAI Whisper")
        XCTAssertEqual(TranscriptionProvider.allCases.count, 2)
        XCTAssertEqual(TranscriptionProvider.appleSpeech.id, TranscriptionProvider.appleSpeech.rawValue)
    }
}

// Simple URLProtocol mock
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let h = Self.handler else { client?.urlProtocolDidFinishLoading(self); return }
        do {
            let (resp, data) = try h(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
