//
//  TestUtilsTests.swift
//  ResterTests
//
//  Created by Sven A. Schmidt on 17/03/2019.
//

import Path
import XCTest


class TestUtilsTests: XCTestCase {

    func test_path() throws {
        XCTAssertEqual(path(fixture: "basic.yml")?.basename(), "basic.yml")
        XCTAssertEqual(path(example: "array")?.basename(), "array")
    }

    func test_maskTime() throws {
        XCTAssertEqual("basic PASSED (0.01s)".maskTime, "basic PASSED (X.XXXs)")
        XCTAssertEqual("basic PASSED (0s)".maskTime, "basic PASSED (X.XXXs)")
    }

    func test_maskPath() throws {
        do {  // file
            let filePath = path(fixture: "basic.yml")!
            let input = "Resting \(filePath) ...\n\nreferencing the file again: \(filePath). Done."
            let output = "Resting basic.yml ...\n\nreferencing the file again: basic.yml. Done."
            XCTAssertEqual(input.maskPath(filePath), output)
        }
        do {  // directory
            let filePath = testDataDirectory()!
            let input = "Resting \(filePath) ...\n\nreferencing the file again: \(filePath). Done."
            let output = "Resting XXX ...\n\nreferencing the file again: XXX. Done."
            XCTAssertEqual(input.maskPath(filePath), output)
        }
    }

    func test_maskJSONField() throws {
        do {
            let input = ", \"Date\": \"Sun, 17 Mar 2019 10:14:45 GMT\"]"
            let output = ", \"Date\": \"XXX\"]"
            XCTAssertEqual(input.maskJSONField("Date"), output)
        }
        do {
            let input = "\"User-Agent\": \"rester (unknown version) CFNetwork/976 Darwin/18.2.0 (x86_64)\", \"Accept\": \"*/*\""
            let output = "\"User-Agent\": \"XXX\", \"Accept\": \"*/*\""
            XCTAssertEqual(input.maskJSONField("User-Agent"), output)
        }
    }

    func test_maskLine() throws {
        do {
            let input = "first line\nJSON: [\" ...\nnext line"
            let output = "first line\nJSON: <non-deterministic output masked>\nnext line"
            XCTAssertEqual(input.maskLine(prefix: "JSON: "), output)
        }
        do {  // test to preserve blank lines
            let input = "first line\n\nJSON: [\" ...\n\nnext line"
            let output = "first line\n\nJSON: <non-deterministic output masked>\n\nnext line"
            XCTAssertEqual(input.maskLine(prefix: "JSON: "), output)
        }
    }

    func test_examplesDataDir() throws {
        XCTAssertEqual(examplesDirectory()?.basename(), "examples")
        XCTAssert((examplesDirectory()!/"array.yml").exists)
    }

}
