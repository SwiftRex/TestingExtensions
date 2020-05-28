//
//  UseCaseTests.swift
//  TestingExtensions
//
//  Created by Luiz Barbosa on 12.05.20.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

import Combine
import CombineRex
import Foundation
@testable import SwiftRex
import XCTest

public enum Step<ActionType, StateType> {
    case send(
        ActionType,
        file: StaticString = #file,
        line: UInt = #line,
        stateChange: (inout StateType) -> Void = { _ in }
    )
    case receive(
        ActionType,
        file: StaticString = #file,
        line: UInt = #line,
        stateChange: (inout StateType) -> Void = { _ in }
    )
    case sideEffectResult(
        do: () -> Void
    )
}

extension XCTestCase {
    public func assert<M: Middleware>(
        initialValue: M.StateType,
        reducer: Reducer<M.InputActionType, M.StateType>,
        middleware: M,
        steps: Step<M.InputActionType, M.StateType>...,
        otherSteps: [Step<M.InputActionType, M.StateType>] = [],
        file: StaticString = #file,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType, M.InputActionType: Equatable, M.StateType: Equatable {
        assert(
            initialValue: initialValue,
            reducer: reducer,
            middleware: middleware,
            steps: steps + otherSteps,
            stateEquating: ==,
            file: file,
            line: line
        )
    }

    public func assert<M: Middleware>(
        initialValue: M.StateType,
        reducer: Reducer<M.InputActionType, M.StateType>,
        middleware: M,
        steps: Step<M.InputActionType, M.StateType>...,
        otherSteps: [Step<M.InputActionType, M.StateType>] = [],
        stateEquating: (M.StateType, M.StateType) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType, M.InputActionType: Equatable {
        assert(
            initialValue: initialValue,
            reducer: reducer,
            middleware: middleware,
            steps: steps + otherSteps,
            stateEquating: stateEquating,
            file: file,
            line: line
        )
    }

    public func assert<M: Middleware>(
        initialValue: M.StateType,
        reducer: Reducer<M.InputActionType, M.StateType>,
        middleware: M,
        steps: [Step<M.InputActionType, M.StateType>],
        stateEquating: (M.StateType, M.StateType) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType, M.InputActionType: Equatable {
        var state = initialValue
        var middlewareResponses: [M.OutputActionType] = []
        let gotAction = XCTestExpectation(description: "got action")
        gotAction.assertForOverFulfill = false
        let anyActionHandler = AnyActionHandler<M.OutputActionType>.init { (action, _) in
            middlewareResponses.append(action)
            gotAction.fulfill()
        }
        middleware.receiveContext(getState: { state }, output: anyActionHandler)

        steps.forEach { step in
            var expected = state

            switch step {
            case let .send(action, file, line, stateChange):
                if !middlewareResponses.isEmpty {
                    XCTFail("Action sent before handling \(middlewareResponses.count) pending effect(s)", file: file, line: line)
                }

                handle(action: action, state: &state, middleware: middleware, reducer: reducer)
                stateChange(&expected)
                ensureStateMutation(equating: stateEquating, statusQuo: state, expected: expected)
            case let .receive(action, file, line, stateChange):
                if middlewareResponses.isEmpty {
                    _ = XCTWaiter.wait(for: [gotAction], timeout: 0.2)
                }
                guard !middlewareResponses.isEmpty else {
                    XCTFail("No pending effects to receive from", file: file, line: line)
                    break
                }
                let first = middlewareResponses.removeFirst()
                XCTAssertEqual(first, action, file: file, line: line)

                handle(action: action, state: &state, middleware: middleware, reducer: reducer)
                stateChange(&expected)
                ensureStateMutation(equating: stateEquating, statusQuo: state, expected: expected)
            case let .sideEffectResult(execute):
                execute()
            }
        }
        if !middlewareResponses.isEmpty {
            let pendingActions = middlewareResponses.map { "\($0)" }.joined(separator: "\n")
            let msg = "Assertion failed to handle \(middlewareResponses.count) pending effect(s)\n\(pendingActions)"
            XCTFail(msg, file: file, line: line)
        }
    }

    fileprivate func handle<M: Middleware>(
        action: M.InputActionType,
        state: inout M.StateType,
        middleware: M,
        reducer: Reducer<M.InputActionType, M.StateType>,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        var afterReducer: AfterReducer = .doNothing()
        middleware.handle(
            action: action,
            from: .init(file: "\(file)", function: "", line: line, info: nil),
            afterReducer: &afterReducer
        )
        state = reducer.reduce(action, state)
        afterReducer.reducerIsDone()
    }

    private func ensureStateMutation<StateType>(
        equating: (StateType, StateType) -> Bool,
        statusQuo: StateType,
        expected: StateType,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            equating(statusQuo, expected),
            {
                var stateString: String = "", expectedString: String = ""
                dump(statusQuo, to: &stateString, name: nil, indent: 2)
                dump(expected, to: &expectedString, name: nil, indent: 2)
                let difference = diff(old: expectedString, new: stateString) ?? ""

                return "Expected state different from current state\n\(difference)"
            }(),
            file: file,
            line: line
        )
    }
}
