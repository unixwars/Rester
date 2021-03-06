//
//  GlobalTests.swift
//  ResterTests
//
//  Created by Sven A. Schmidt on 31/01/2019.
//

import XCTest

@testable import ResterCore


class SubstitutableTests: XCTestCase {

    func test_substitute() throws {
        let vars: [Key: Value] = ["API_URL": .string("https://foo.bar"), "foo": .int(5)]
        let sub = try substitute(string: "${API_URL}/baz/${foo}/${foo}", with: vars)
        XCTAssertEqual(sub, "https://foo.bar/baz/5/5")
    }

    func test_substitute_Body() throws {
        let vars: [Key: Value] = ["a": "1", "b": 2]
        let values: [Key: Value] = ["data": "values: ${a} ${b}"]

        XCTAssertEqual(try Body.json(values).substitute(variables: vars).json, ["data": "values: 1 2"])
        XCTAssertEqual(try Body.form(values).substitute(variables: vars).form, ["data": "values: 1 2"])
        XCTAssertEqual(try Body.multipart(values).substitute(variables: vars).multipart, ["data": "values: 1 2"])
        XCTAssertEqual(try Body.text("${a} ${b}").substitute(variables: vars).text, "1 2")
        XCTAssertEqual(try Body.file("${a} ${b}").substitute(variables: vars).file, "1 2")
    }
    
}
