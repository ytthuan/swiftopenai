import Testing
import Foundation
@testable import SwiftOpenAI

/// Tests for OpenAIError Equatable conformance and LocalizedError descriptions.
@Suite struct OpenAIErrorEquatableTests {

    @Test func equalityForApiError() {
        let a = OpenAIError.apiError(statusCode: 418, message: "teapot", type: "t", code: "c")
        let b = OpenAIError.apiError(statusCode: 418, message: "teapot", type: "t", code: "c")
        let c = OpenAIError.apiError(statusCode: 418, message: "different", type: "t", code: "c")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func equalityForAuthenticationError() {
        let a = OpenAIError.authenticationError(message: "bad key")
        let b = OpenAIError.authenticationError(message: "bad key")
        let c = OpenAIError.authenticationError(message: "other")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func equalityForPermissionDeniedError() {
        let a = OpenAIError.permissionDeniedError(message: "denied")
        let b = OpenAIError.permissionDeniedError(message: "denied")
        #expect(a == b)
    }

    @Test func equalityForConflictError() {
        let a = OpenAIError.conflictError(message: "conflict")
        let b = OpenAIError.conflictError(message: "conflict")
        #expect(a == b)
    }

    @Test func equalityForNotFoundError() {
        let a = OpenAIError.notFoundError(message: "not found")
        let b = OpenAIError.notFoundError(message: "not found")
        #expect(a == b)
    }

    @Test func equalityForRateLimitError() {
        let a = OpenAIError.rateLimitError(message: "slow down")
        let b = OpenAIError.rateLimitError(message: "slow down")
        #expect(a == b)
    }

    @Test func equalityForUnprocessableEntityError() {
        let a = OpenAIError.unprocessableEntityError(message: "bad input")
        let b = OpenAIError.unprocessableEntityError(message: "bad input")
        #expect(a == b)
    }

    @Test func equalityForInternalServerError() {
        let a = OpenAIError.internalServerError(message: "oops")
        let b = OpenAIError.internalServerError(message: "oops")
        #expect(a == b)
    }

    @Test func equalityForConnectionError() {
        let a = OpenAIError.connectionError(message: "no network")
        let b = OpenAIError.connectionError(message: "no network")
        #expect(a == b)
    }

    @Test func equalityForDecodingError() {
        let a = OpenAIError.decodingError(message: "parse fail")
        let b = OpenAIError.decodingError(message: "parse fail")
        #expect(a == b)
    }

    @Test func equalityForTimeout() {
        #expect(OpenAIError.timeout == OpenAIError.timeout)
    }

    @Test func equalityForBufferOverflow() {
        let a = OpenAIError.bufferOverflow(message: "too big")
        let b = OpenAIError.bufferOverflow(message: "too big")
        #expect(a == b)
    }

    @Test func inequalityAcrossDifferentCases() {
        let a = OpenAIError.timeout
        let b = OpenAIError.authenticationError(message: "x")
        #expect(a != b)
    }
}

/// Tests for OpenAIError LocalizedError conformance.
@Suite struct OpenAIErrorLocalizedTests {

    @Test func apiErrorDescription() {
        let err = OpenAIError.apiError(statusCode: 400, message: "Bad request", type: nil, code: nil)
        #expect(err.errorDescription == "Bad request")
    }

    @Test func authenticationErrorDescription() {
        let err = OpenAIError.authenticationError(message: "Invalid key")
        #expect(err.errorDescription == "Invalid key")
    }

    @Test func permissionDeniedErrorDescription() {
        let err = OpenAIError.permissionDeniedError(message: "Denied")
        #expect(err.errorDescription == "Denied")
    }

    @Test func conflictErrorDescription() {
        let err = OpenAIError.conflictError(message: "Conflict")
        #expect(err.errorDescription == "Conflict")
    }

    @Test func notFoundErrorDescription() {
        let err = OpenAIError.notFoundError(message: "Not found")
        #expect(err.errorDescription == "Not found")
    }

    @Test func rateLimitErrorDescription() {
        let err = OpenAIError.rateLimitError(message: "Rate limited")
        #expect(err.errorDescription == "Rate limited")
    }

    @Test func unprocessableEntityErrorDescription() {
        let err = OpenAIError.unprocessableEntityError(message: "Bad entity")
        #expect(err.errorDescription == "Bad entity")
    }

    @Test func internalServerErrorDescription() {
        let err = OpenAIError.internalServerError(message: "Server error")
        #expect(err.errorDescription == "Server error")
    }

    @Test func connectionErrorDescription() {
        let err = OpenAIError.connectionError(message: "No connection")
        #expect(err.errorDescription == "No connection")
    }

    @Test func decodingErrorDescription() {
        let err = OpenAIError.decodingError(message: "Decode failed")
        #expect(err.errorDescription == "Decode failed")
    }

    @Test func timeoutDescription() {
        let err = OpenAIError.timeout
        #expect(err.errorDescription == "Request timed out.")
    }

    @Test func bufferOverflowDescription() {
        let err = OpenAIError.bufferOverflow(message: "Buffer full")
        #expect(err.errorDescription == "Buffer full")
    }
}

/// Tests for APIErrorBody / APIErrorDetail Codable.
@Suite struct APIErrorBodyTests {

    @Test func decodesFullErrorBody() throws {
        let json = """
        {"error": {"message": "Model not found", "type": "invalid_request_error", "param": "model", "code": "model_not_found"}}
        """
        let body = try JSONDecoder().decode(APIErrorBody.self, from: json.data(using: .utf8)!)
        #expect(body.error.message == "Model not found")
        #expect(body.error.type == "invalid_request_error")
        #expect(body.error.param == "model")
        #expect(body.error.code == "model_not_found")
    }

    @Test func decodesMinimalErrorBody() throws {
        let json = """
        {"error": {"message": "Something went wrong", "type": null, "param": null, "code": null}}
        """
        let body = try JSONDecoder().decode(APIErrorBody.self, from: json.data(using: .utf8)!)
        #expect(body.error.message == "Something went wrong")
        #expect(body.error.type == nil)
        #expect(body.error.param == nil)
        #expect(body.error.code == nil)
    }
}
