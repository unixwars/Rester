import XCTest

import Yams
@testable import ResterCore





final class ResterTests: XCTestCase {

    func test_decode_variables() throws {
        let s = try readFixture("env.yml")
        let env = try YAMLDecoder().decode(Rester.self, from: s)
        XCTAssertEqual(env.variables!["INT_VALUE"], .int(42))
        XCTAssertEqual(env.variables!["STRING_VALUE"], .string("some string value"))
    }

    func test_subtitute() throws {
        let vars: Variables = ["API_URL": .string("https://foo.bar"), "foo": .int(5)]
        let sub = try _substitute(string: "${API_URL}/baz/${foo}/${foo}", with: vars)
        XCTAssertEqual(sub, "https://foo.bar/baz/5/5")
    }

    func test_version_request() throws {
        let s = try readFixture("version.yml")
        let rest = try YAMLDecoder().decode(Rester.self, from: s)
        let variables = rest.variables!
        let requests = rest.requests!
        let versionReq = try requests["version"]!.substitute(variables: variables)
        XCTAssertEqual(variables["API_URL"]!, .string("https://dev.vbox.space"))
        XCTAssertEqual(versionReq.url, "https://dev.vbox.space/api/metrics/build")
    }

    func test_parse_validation() throws {
        struct Test: Decodable {
            let validation: Validation
        }
        let s = """
        validation:
          status: 200
          json:
            int: 42
            string: foo
            regex: .regex(\\d+\\.\\d+\\.\\d+|\\S{40})
        """
        let t = try YAMLDecoder().decode(Test.self, from: s)
        XCTAssertEqual(t.validation.status, 200)
        XCTAssertEqual(t.validation.json!["int"], Matcher.int(42))
        XCTAssertEqual(t.validation.json!["string"], Matcher.string("foo"))
        XCTAssertEqual(t.validation.json!["regex"], Matcher.regex("\\d+\\.\\d+\\.\\d+|\\S{40}".r!))
    }

    func test_request_execute() throws {
        struct Result: Codable { let version: String }

        let s = try readFixture("version.yml")
        let rester = try YAMLDecoder().decode(Rester.self, from: s)
        let variables = rester.variables!
        let requests = rester.requests!
        let versionReq = try requests["version"]!.substitute(variables: variables)

        let expectation = self.expectation(description: #function)

        _ = try versionReq.execute()
            .map {
                XCTAssertEqual($0.response.statusCode, 200)
                let res = try JSONDecoder().decode(Result.self, from: $0.data)
                XCTAssertNotNil(res.version)
                expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
    }

    func test_rester_execute() throws {
        struct Result: Codable { let version: String }

        let expectation = self.expectation(description: #function)

        let s = try readFixture("version.yml")
        let rester = try YAMLDecoder().decode(Rester.self, from: s)
        _ = try rester.expandedRequest("version").execute()
            .map {
                XCTAssertEqual($0.response.statusCode, 200)
                let res = try JSONDecoder().decode(Result.self, from: $0.data)
                XCTAssertNotNil(res.version)
                expectation.fulfill()
        }
        waitForExpectations(timeout: 5)
    }

    func test_validate_status() throws {
        let s = try readFixture("httpbin.yml")
        let rester = try YAMLDecoder().decode(Rester.self, from: s)

        do {
            let expectation = self.expectation(description: #function)
            _ = try rester.expandedRequest("anything").test()
                .map { result in
                    XCTAssertEqual(result, ValidationResult.valid)
                    expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }

        do {
            let expectation = self.expectation(description: #function)
            _ = try rester.expandedRequest("failure").test()
                .map { result in
                    XCTAssertEqual(result, ValidationResult.invalid("status invalid, expected '500' was '200'"))
                    expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }
    }

    func test_validate_json() throws {
        let s = try readFixture("httpbin.yml")
        let rester = try YAMLDecoder().decode(Rester.self, from: s)

        do {
            let expectation = self.expectation(description: #function)
            _ = try rester.expandedRequest("json-success").test()
                .map {
                    XCTAssertEqual($0, ValidationResult.valid)
                    expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }

        do {
            let expectation = self.expectation(description: #function)
            _ = try rester.expandedRequest("json-failure").test()
                .map {
                    XCTAssertEqual($0, ValidationResult.invalid("json.method invalid, expected 'nope' was 'GET'"))
                    expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }

        do {
            let expectation = self.expectation(description: #function)
            _ = try rester.expandedRequest("json-failure-type").test()
                .map {
                    XCTAssertEqual($0, ValidationResult.invalid("json.method expected to be of type Int, was 'GET'"))
                    expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }
    }

    func test_validate_json_regex() throws {
        let s = try readFixture("httpbin.yml")
        let rester = try YAMLDecoder().decode(Rester.self, from: s)

        do {
            let expectation = self.expectation(description: #function)
            _ = try rester.expandedRequest("json-regex").test()
                .map {
                    XCTAssertEqual($0, ValidationResult.valid)
                    expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }

        do {
            let expectation = self.expectation(description: #function)
            _ = try rester.expandedRequest("json-regex-failure").test()
                .map {
                    switch $0 {
                    case .valid:
                        XCTFail("expected failure but received success")
                    case .invalid(let message):
                        XCTAssert(message.starts(with: "json.uuid failed to match \'^\\w{8}$\'"))
                    }
                    expectation.fulfill()
            }
            waitForExpectations(timeout: 5)
        }
    }

    func test_request_order() throws {
        let s = """
            requests:
              first:
                url: http://foo.com
              second:
                url: http://foo.com
              3rd:
                url: http://foo.com
            """
        let rester = try YAMLDecoder().decode(Rester.self, from: s)
        let names = rester.requests?.names
        XCTAssertEqual(names, ["first", "second", "3rd"])
    }

}


func url(for fixture: String, path: String = #file) -> URL {
  let testDir = URL(fileURLWithPath: path).deletingLastPathComponent()
  return testDir.appendingPathComponent("TestData/\(fixture)")
}


func readFixture(_ fixture: String, path: String = #file) throws -> String {
  let file = url(for: fixture)
  return try String(contentsOf: file)
}
