//
//  Request.swift
//  ResterCore
//
//  Created by Sven A. Schmidt on 19/01/2019.
//

import Foundation
import PromiseKit
import PMKFoundation
import AnyCodable


public struct Request: Codable {
    public let url: String
    public let method: Method
    public let validation: Validation
}


public struct Response {
    let data: Data
    let response: HTTPURLResponse

    var status: Int {
        return response.statusCode
    }
}


public enum ValidationResult: Equatable {
    case valid
    case invalid(String)
}


extension Request {
    public func substitute(variables: Variables) throws -> Request {
        let _url = try _substitute(string: url, with: variables)
        return Request(url: _url, method: method, validation: validation)
    }

    public func execute() throws -> Promise<Response> {
        guard let url = URL(string: url) else { throw ResterError.invalidURL(self.url) }

        return URLSession.shared.dataTask(.promise, with: url)
            .map { Response(data: $0.data, response: $0.response as! HTTPURLResponse) }
    }

    public func test() throws -> Promise<ValidationResult> {
        guard let url = URL(string: url) else { throw ResterError.invalidURL(self.url) }

        return URLSession.shared.dataTask(.promise, with: url)
            .map { Response(data: $0.data, response: $0.response as! HTTPURLResponse) }
            .map {
                self.validate($0)
        }
    }

    public func validate(_ response: Response) -> ValidationResult {
        if
            let status = validation.status,
            response.status != status {
            return .invalid("status invalid, expected '\(status)' was '\(response.response.statusCode)'")
        }

        if let json = validation.json {
            // assume Dictionary response
            // TODO: handle Array response
            guard let data = try? JSONDecoder().decode([String: AnyCodable].self, from: response.data)
                else {
                    return .invalid("failed to decode JSON object from response")
            }

            for (key, matcher) in json {
                guard let value = data[key] else { return .invalid("key '\(key)' not found in JSON response") }

                switch matcher {
                case .int(let expected):
                    let res = _validate(key: key, expected: expected, found: value)
                    if res != .valid {
                        return res
                    }
                case .string(let expected):
                    let res = _validate(key: key, expected: expected, found: value)
                    if res != .valid {
                        return res
                    }
                case .regex(let regex):
                    break
                }
            }
        }
        return .valid
    }
}


func _validate<T: Equatable>(key: Key, expected: T, found: AnyCodable) -> ValidationResult {
    guard let value = try? found.assertValue(T.self) else {
        return .invalid("json.\(key) expected to be of type \(T.self), was '\(found)'")
    }
    if value != expected {
        return .invalid("json.\(key) invalid, expected '\(expected)' was '\(value)'")
    }
    return .valid
}
