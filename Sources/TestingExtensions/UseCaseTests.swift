//
//  UseCaseTests.swift
//  TestingExtensions
//
//  Created by Luiz Barbosa on 12.05.20.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

#if canImport(XCTest)
import Combine
import CombineRex
import Foundation
@testable import SwiftRex
import XCTest

#if swift(>=5.4)
@resultBuilder public struct StepBuilder<Action, State> {
    public static func buildBlock(_ steps: [Step<Action, State>]...) -> [Step<Action, State>] {
        steps.flatMap { $0 }
    }

    public static func buildEither(first component: [Step<Action, State>]) -> [Step<Action, State>] {
        component
    }

    public static func buildEither(second component: [Step<Action, State>]) -> [Step<Action, State>] {
        component
    }

    public static func buildLimitedAvailability(_ component: [Step<Action, State>]) -> [Step<Action, State>] {
        component
    }

    public static func buildOptional(_ component: [Step<Action, State>]?) -> [Step<Action, State>] {
        component ?? []
    }

    public static func buildArray(_ components: [[Step<Action, State>]]) -> [Step<Action, State>] {
        components.flatMap { $0 }
    }

    public static func buildExpression<S: StepProtocol>(_ expression: S) -> [Step<Action, State>] where S.ActionType == Action, S.StateType == State {
        [expression.asStep]
    }

    public static func buildExpression(_ expression: [Step<Action, State>]...) -> [Step<Action, State>] {
        expression.flatMap { $0 }
    }
}
#endif

public protocol StepProtocol {
    associatedtype ActionType
    associatedtype StateType

    var asStep: Step<ActionType, StateType> { get }
}

public struct Send<ActionType, StateType>: StepProtocol {
    public init(
        action: @autoclosure @escaping () -> ActionType,
        file: StaticString = #file,
        fileForStateMutation: StaticString = #file,
        line: UInt = #line,
        lineForStateMutation: UInt = #line,
        stateChange: @escaping (inout StateType) -> Void = { _ in }
    ) {
        self.action = action
        self.file = file
        self.fileForStateMutation = fileForStateMutation
        self.line = line
        self.lineForStateMutation = lineForStateMutation
        self.stateChange = stateChange
    }

    let action: () -> ActionType
    let file: StaticString
    let line: UInt
    let fileForStateMutation: StaticString
    let lineForStateMutation: UInt
    let stateChange: (inout StateType) -> Void

    public var asStep: Step<ActionType, StateType> {
        .send(
            action: action(),
            file: file,
            fileForStateMutation: fileForStateMutation,
            line: line,
            lineForStateMutation: lineForStateMutation,
            stateChange: stateChange
        )
    }

    public func expectStateToHaveChanged(
        fileForStateMutation: StaticString = #file,
        lineForStateMutation: UInt = #line,
        _ expectedMutation: @escaping (inout StateType) -> Void = { _ in }
    ) -> Send {
        Send(
            action: action(),
            file: file,
            fileForStateMutation: fileForStateMutation,
            line: line,
            lineForStateMutation: lineForStateMutation
        ) { state in
            self.stateChange(&state)
            expectedMutation(&state)
        }
    }
}

public struct Receive<ActionType, StateType>: StepProtocol {
    public init(
        isExpectedAction: @escaping (ActionType) -> Bool,
        file: StaticString = #file,
        fileForStateMutation: StaticString = #file,
        line: UInt = #line,
        lineForStateMutation: UInt = #line,
        stateChange: @escaping (inout StateType) -> Void = { _ in }
    ) {
        self.isExpectedAction = isExpectedAction
        self.file = file
        self.fileForStateMutation = fileForStateMutation
        self.line = line
        self.lineForStateMutation = lineForStateMutation
        self.stateChange = stateChange
    }

    public init(
        action: @autoclosure @escaping () -> ActionType,
        file: StaticString = #file,
        fileForStateMutation: StaticString = #file,
        line: UInt = #line,
        lineForStateMutation: UInt = #line,
        stateChange: @escaping (inout StateType) -> Void = { _ in }
    ) where ActionType: Equatable {
        self.init(
            isExpectedAction: { $0 == action() },
            file: file,
            fileForStateMutation: fileForStateMutation,
            line: line,
            lineForStateMutation: lineForStateMutation,
            stateChange: stateChange
        )
    }

    let file: StaticString
    let line: UInt
    let fileForStateMutation: StaticString
    let lineForStateMutation: UInt
    let stateChange: (inout StateType) -> Void
    let isExpectedAction: (ActionType) -> Bool

    public var asStep: Step<ActionType, StateType> {
        .receive(
            isExpectedAction: isExpectedAction,
            file: file,
            fileForStateMutation: fileForStateMutation,
            line: line,
            lineForStateMutation: lineForStateMutation,
            stateChange: stateChange
        )
    }

    public func expectStateToHaveChanged(
        fileForStateMutation: StaticString = #file,
        lineForStateMutation: UInt = #line,
        _ expectedMutation: @escaping (inout StateType) -> Void = { _ in }
    ) -> Receive {
        Receive(
            isExpectedAction: isExpectedAction,
            file: file,
            fileForStateMutation: fileForStateMutation,
            line: line,
            lineForStateMutation: lineForStateMutation
        ) { state in
            self.stateChange(&state)
            expectedMutation(&state)
        }
    }
}

public struct SideEffectResult<ActionType, StateType>: StepProtocol {
    public init(do perform: @escaping () -> Void) {
        self.perform = perform
    }
    let perform: () -> Void

    public var asStep: Step<ActionType, StateType> {
        .sideEffectResult(do: perform)
    }
}

public enum Step<ActionType, StateType>: StepProtocol {
    case send(
            action: @autoclosure () -> ActionType,
            file: StaticString = #file,
            fileForStateMutation: StaticString = #file,
            line: UInt = #line,
            lineForStateMutation: UInt = #line,
            stateChange: (inout StateType) -> Void = { _ in }
         )
    case receive(
            isExpectedAction: (ActionType) -> Bool,
            file: StaticString = #file,
            fileForStateMutation: StaticString = #file,
            line: UInt = #line,
            lineForStateMutation: UInt = #line,
            stateChange: (inout StateType) -> Void = { _ in }
         )
    case sideEffectResult(
            do: () -> Void
         )

    public var asStep: Step<ActionType, StateType> {
        self
    }
}

extension XCTestCase {
    #if swift(>=5.4)
    public func assert<M: Middleware>(
        initialValue: M.StateType,
        reducer: Reducer<M.InputActionType, M.StateType>,
        middleware: M,
        @StepBuilder<M.InputActionType, M.StateType> steps: () -> [Step<M.InputActionType, M.StateType>],
        file: StaticString = #file,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType, M.StateType: Equatable {
        assert(
            initialValue: initialValue,
            reducer: reducer,
            middleware: middleware,
            stepsArray: steps(),
            stateEquating: ==,
            file: file,
            line: line
        )
    }

    public func assert<M: Middleware>(
        initialValue: M.StateType,
        reducer: Reducer<M.InputActionType, M.StateType>,
        middleware: M,
        @StepBuilder<M.InputActionType, M.StateType> steps: () -> [Step<M.InputActionType, M.StateType>],
        stateEquating: (M.StateType, M.StateType) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType {
        assert(
            initialValue: initialValue,
            reducer: reducer,
            middleware: middleware,
            stepsArray: steps(),
            stateEquating: stateEquating,
            file: file,
            line: line
        )
    }
    #endif

    public func assert<M: Middleware>(
        initialValue: M.StateType,
        reducer: Reducer<M.InputActionType, M.StateType>,
        middleware: M,
        steps: Step<M.InputActionType, M.StateType>...,
        file: StaticString = #file,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType, M.StateType: Equatable {
        assert(
            initialValue: initialValue,
            reducer: reducer,
            middleware: middleware,
            stepsArray: steps,
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
        stateEquating: (M.StateType, M.StateType) -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) where M.InputActionType == M.OutputActionType {
        assert(
            initialValue: initialValue,
            reducer: reducer,
            middleware: middleware,
            stepsArray: steps,
            stateEquating: stateEquating,
            file: file,
            line: line
        )
    }

    private func assert<M: Middleware>(
        initialValue: M.StateType,
        reducer: Reducer<M.InputActionType, M.StateType>,
        middleware: M,
        stepsArray: [Step<M.InputActionType, M.StateType>],
        stateEquating: (M.StateType, M.StateType) -> Bool,
        file: StaticString,
        line: UInt
    ) where M.InputActionType == M.OutputActionType {
        var state = initialValue
        var middlewareResponses: [M.OutputActionType] = []
        let gotAction = XCTestExpectation(description: "got action")
        gotAction.assertForOverFulfill = false
        let anyActionHandler = AnyActionHandler<M.OutputActionType>.init { dispatchedAction in
            middlewareResponses.append(dispatchedAction.action)
            gotAction.fulfill()
        }
        middleware.receiveContext(getState: { state }, output: anyActionHandler)

        stepsArray.forEach { outerStep in
            var expected = state

            switch outerStep {
            case let .send(action, file, fileForStateMutation, line, lineForStateMutation, stateChange):
                if !middlewareResponses.isEmpty {
                    XCTFail("""
                            Action sent before handling \(middlewareResponses.count) pending effect(s):
                            \(middlewareResponses.map { "\($0)" }.joined(separator: "\n"))
                            """, file: file, line: line)
                }

                var afterReducer: AfterReducer = .doNothing()
                let action = action()
                middleware.handle(
                    action: action,
                    from: .init(file: "\(file)", function: "", line: line, info: nil),
                    afterReducer: &afterReducer
                )
                reducer.reduce(action, &state)
                afterReducer.reducerIsDone()

                stateChange(&expected)
                ensureStateMutation(
                    equating: stateEquating,
                    statusQuo: state,
                    expected: expected,
                    step: outerStep,
                    file: fileForStateMutation,
                    line: lineForStateMutation
                )
            case let .receive(action, file, fileForStateMutation, line, lineForStateMutation, stateChange)://action, file, line, stateChange):
                if middlewareResponses.isEmpty {
                    _ = XCTWaiter.wait(for: [gotAction], timeout: 0.2)
                }
                guard !middlewareResponses.isEmpty else {
                    XCTFail("No pending effects to receive from", file: file, line: line)
                    break
                }
                let first = middlewareResponses.removeFirst()
                XCTAssertTrue(action(first), file: file, line: line)

                var afterReducer: AfterReducer = .doNothing()
                middleware.handle(
                    action: first,
                    from: .init(file: "\(file)", function: "", line: line, info: nil),
                    afterReducer: &afterReducer
                )
                reducer.reduce(first, &state)
                afterReducer.reducerIsDone()

                stateChange(&expected)
                ensureStateMutation(
                    equating: stateEquating,
                    statusQuo: state,
                    expected: expected,
                    step: outerStep,
                    file: fileForStateMutation,
                    line: lineForStateMutation
                )
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

    private func ensureStateMutation<ActionType, StateType>(
        equating: (StateType, StateType) -> Bool,
        statusQuo: StateType,
        expected: StateType,
        step: Step<ActionType, StateType>,
        file: StaticString,
        line: UInt
    ) {
        XCTAssertTrue(
            equating(statusQuo, expected),
            {
                var stateString: String = "", expectedString: String = ""

                dump(statusQuo, to: &stateString, name: nil, indent: 2)
                dump(expected, to: &expectedString, name: nil, indent: 2)

                let difference = diff(old: expectedString, new: stateString) ?? ""
                return "Expected state after step \(step) different from current state\n\(difference)"
            }(),
            file: file,
            line: line
        )
    }
}
#endif
