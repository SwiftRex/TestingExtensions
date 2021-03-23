//
//  CombineTesting.swift
//  TestingExtensions
//
//  Created by Luiz Rodrigo Martins Barbosa on 23.03.21.
//  Copyright © 2021 Lautsprecher Teufel GmbH. All rights reserved.
//

import Combine
import XCTest

extension XCTestCase {
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func assert<P: Publisher>(
        publisher: P,
        eventuallyReceives values: P.Output...,
        andCompletes: Bool = false,
        timeout: TimeInterval
    ) -> () -> Void where P.Output: Equatable {
        var collectedValues: [P.Output] = []
        let valuesExpectation = expectation(description: "Expected values")
        let completionExpectation = expectation(description: "Expected completion")
        valuesExpectation.expectedFulfillmentCount = values.count
        if !andCompletes { completionExpectation.fulfill() }
        let cancellable = publisher.sink(
            receiveCompletion: { result in
                switch result {
                case .finished:
                    if andCompletes { completionExpectation.fulfill() }
                case let .failure(error):
                    XCTFail("Received failure: \(error)")
                }
            },
            receiveValue: { value in
                collectedValues.append(value)
                valuesExpectation.fulfill()
            }
        )

        return { [weak self] in
            guard let self = self else {
                XCTFail("Test ended before waiting for expectations")
                return
            }
            self.wait(for: [valuesExpectation, completionExpectation], timeout: timeout)
            XCTAssertEqual(collectedValues, values, "Values don't match:\nreceived:\n\(collectedValues)\n\nexpected:\n\(values)")
            _ = cancellable
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func assert<P: Publisher>(
        publisher: P,
        eventuallyReceives values: P.Output...,
        andCompletesWith: ValidateCompletion<P.Failure>,
        timeout: TimeInterval
    ) -> () -> Void where P.Output: Equatable {
        var collectedValues: [P.Output] = []
        let valuesExpectation = expectation(description: "Expected values")
        let completionExpectation = expectation(description: "Expected completion")
        valuesExpectation.expectedFulfillmentCount = values.count
        let cancellable = publisher.sink(
            receiveCompletion: { result in
                XCTAssertTrue(andCompletesWith.isExpected(result), "Unexpected completion: \(result)")
                completionExpectation.fulfill()
            },
            receiveValue: { value in
                collectedValues.append(value)
                valuesExpectation.fulfill()
            }
        )

        return { [weak self] in
            guard let self = self else {
                XCTFail("Test ended before waiting for expectations")
                return
            }
            self.wait(for: [valuesExpectation, completionExpectation], timeout: timeout)
            XCTAssertEqual(collectedValues, values, "Values don't match:\nreceived:\n\(collectedValues)\n\nexpected:\n\(values)")
            _ = cancellable
        }
    }

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func assert<P: Publisher>(
        publisher: P,
        completesWithoutValues: ValidateCompletion<P.Failure>,
        timeout: TimeInterval
    ) -> () -> Void {
        let completionExpectation = expectation(description: "Expected completion")
        let cancellable = publisher.sink(
            receiveCompletion: { result in
                XCTAssertTrue(completesWithoutValues.isExpected(result), "Unexpected completion: \(result)")
                completionExpectation.fulfill()
            },
            receiveValue: { value in
                XCTFail("Unexpected value received: \(value)")
            }
        )

        return { [weak self] in
            guard let self = self else {
                XCTFail("Test ended before waiting for expectations")
                return
            }
            self.wait(for: [completionExpectation], timeout: timeout)
            _ = cancellable
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct ValidateCompletion<Failure: Error> {
    let isExpected: (Subscribers.Completion<Failure>) -> Bool
    public init(validate: @escaping (Subscribers.Completion<Failure>) -> Bool) {
        self.isExpected = validate
    }

    public static var isSuccess: ValidateCompletion {
        ValidateCompletion { result in
            guard case .finished = result else { return false }
            return true
        }
    }

    public static var isFailure: ValidateCompletion {
        ValidateCompletion { result in
            guard case .failure = result else { return false }
            return true
        }
    }

    public static func failedWithError(_ errorPredicate: @escaping (Failure) -> Bool) -> ValidateCompletion {
        ValidateCompletion { result in
            guard case let .failure(error) = result else { return false }
            return errorPredicate(error)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ValidateCompletion where Failure: Equatable {
    public static func failedWithError(_ expectedError: Failure) -> ValidateCompletion {
        ValidateCompletion { result in
            guard case let .failure(error) = result else { return false }
            return error == expectedError
        }
    }
}
