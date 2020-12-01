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

public struct SendStep<ActionType, StateType> {
    public init(
        action: @autoclosure @escaping () -> ActionType,
        file: StaticString = #file,
        line: UInt = #line,
        stateChange: @escaping (inout StateType) -> Void = { _ in }
    ) {
        self.action = action
        self.file = file
        self.line = line
        self.stateChange = stateChange
    }

    let action: () -> ActionType
    let file: StaticString
    let line: UInt
    let stateChange: (inout StateType) -> Void
}

public struct ReceiveStep<ActionType, StateType> {
    public init(isExpectedAction: @escaping (ActionType) -> Bool,
                file: StaticString = #file,
                line: UInt = #line,
                stateChange: @escaping (inout StateType) -> Void = { _ in }) {
        self.isExpectedAction = isExpectedAction
        self.file = file
        self.line = line
        self.stateChange = stateChange
    }

    public init(action: @autoclosure @escaping () -> ActionType,
                file: StaticString = #file,
                line: UInt = #line,
                stateChange: @escaping (inout StateType) -> Void = { _ in }
    ) where ActionType: Equatable {
        self.init(
            isExpectedAction: { $0 == action() },
            file: file,
            line: line,
            stateChange: stateChange
        )
    }

    let file: StaticString
    let line: UInt
    let stateChange: (inout StateType) -> Void

    let isExpectedAction: (ActionType) -> Bool
}

public enum Step<ActionType, StateType> {
    case send(SendStep<ActionType, StateType>)
    case receive(ReceiveStep<ActionType, StateType>)
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
        file: StaticString = #filePath,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType, M.StateType: Equatable {
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
        file: StaticString = #filePath,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType {
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
        file: StaticString = #filePath,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType {
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
            case let .send(step)://action, file, line, stateChange):
                let file = step.file
                let line = step.line
                let stateChange = step.stateChange

                if !middlewareResponses.isEmpty {
                    XCTFail("Action sent before handling \(middlewareResponses.count) pending effect(s)", file: file, line: line)
                }

                var afterReducer: AfterReducer = .doNothing()
                let action = step.action()
                middleware.handle(
                    action: action,
                    from: .init(file: "\(file)", function: "", line: line, info: nil),
                    afterReducer: &afterReducer
                )
                reducer.reduce(action, &state)
                afterReducer.reducerIsDone()

                stateChange(&expected)
                ensureStateMutation(equating: stateEquating, statusQuo: state, expected: expected)
            case let .receive(step)://action, file, line, stateChange):
                let file = step.file
                let line = step.line
                let stateChange = step.stateChange

                if middlewareResponses.isEmpty {
                    _ = XCTWaiter.wait(for: [gotAction], timeout: 0.2)
                }
                guard !middlewareResponses.isEmpty else {
                    XCTFail("No pending effects to receive from", file: file, line: line)
                    break
                }
                let first = middlewareResponses.removeFirst()
                XCTAssertTrue(step.isExpectedAction(first), file: file, line: line)

                var afterReducer: AfterReducer = .doNothing()
                middleware.handle(
                    action: first,
                    from: .init(file: "\(file)", function: "", line: line, info: nil),
                    afterReducer: &afterReducer
                )
                reducer.reduce(first, &state)
                afterReducer.reducerIsDone()

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

    private func ensureStateMutation<StateType>(
        equating: (StateType, StateType) -> Bool,
        statusQuo: StateType,
        expected: StateType,
        file: StaticString = #filePath,
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
