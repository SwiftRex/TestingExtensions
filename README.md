# TestingExtensions
Testing helpers and extensions for SwiftRex and Combine

## SwiftRex Functional Tests (Use Case)
```swift
let (dependencies, scheduler) = self.setup

assert(
    initialValue: AppState.initial,
    reducer: Reducer.myReducer.lift(action: \.actionReducerScope, state: \.stateReducerScope),
    middleware: MyHandler.middleware.inject(dependencies),
    steps: {
        Send(action: .certainAction(.verySpecific))

        SideEffectResult {
            scheduler.advance(by: .seconds(5))
        }

        Send(action: .anotherAction(.withSomeValues(list: [], date: dependencies.now())))

        // if you receive an action and don't add this block, the test will fail to remind you
        Receive { action -> Bool in
            // validates that the received action is what you would expect
            // if this function returns false, the test will fail to show you that you've got an unexpected action
            if case let .my(.expectedAction(list)) = action {
                return list.isEmpty
            } else {
                return false
            }
        }

        SideEffectResult {
            scheduler.advance(by: .seconds(5))
        }

        Send(action: .anotherAction(.stopSomething)).expectStateToHaveChanged { state in
            // if during Send or Receive action, your state is expected to mutate, you must indicate which change is expected to happen here:
            state.somePropertyShouldHaveChangedTo = true
            // any unexpected state mutation will fail the test, as well as any expected state mutation that doesn't occur, will also fail the test
        }

        SideEffectResult {
            scheduler.advance(by: .seconds(5))
        }

        // if you receive an action and don't add this block, the test will fail to remind you
        Receive { action -> Bool in
            // validates that the received action is what you would expect
            // if this function returns false, the test will fail to show you that you've got an unexpected action
            if case let .my(.expectedAction(list)) = action {
                return list.isEmpty
            } else {
                return false
            }
        }.expectStateToHaveChanged { state in
            // if during Send or Receive action, your state is expected to mutate, you must indicate which change is expected to happen here:
            state.somePropertyShouldHaveChangedTo = true
            // any unexpected state mutation will fail the test, as well as any expected state mutation that doesn't occur, will also fail the test
        }
    }
)
```

## Better diagnostics
Result Builders (https://developer.apple.com/videos/play/wwdc2021/10253/) are awesome, however the diagnostics in case of type mismatch or failure to
infer the type expression are misleading, incomplete or confusing. Although the Swift Core Team keeps improving the diagnostics every release, you may
eventually find yourself in a compiler error that is tricky to understand. In that case, you may want to use the old format, that use plain arrays.

```swift
// Instead of:
assert(
    // ...
    steps: {
        Send(action: .certainAction(.verySpecific))

        SideEffectResult {
            scheduler.advance(by: .seconds(5))
        }
    }
)

// You can use:
assert(
    // ...
    steps: [
        Send(action: .certainAction(.verySpecific))
            .asStep,
            
        SideEffectResult {
            scheduler.advance(by: .seconds(5))
        }.asStep
    ]
)
```

For that:
- replace `steps: { }` curly-brackets for square-brackets `steps: []`
- add `.asStep` after each step
- add comma (,) after each step, except the last

The syntax is not so elegant, but the diagnostics are better.

## Combine

Validate Output of Publishers
```swift
let operation = assert(
    publisher: myPublisher,
    eventuallyReceives: "🙉", "🙊", "🙈",
    andCompletes: false
)
somethingHappensAndPublisherReceives("🙉")
somethingHappensAndPublisherReceives("🙊")
somethingHappensAndPublisherReceives("🙈")

operation.wait(0.0001)
```

Validate Output and Successful Completion of Publishers
```swift
let operation = assert(
    publisher: myPublisher,
    eventuallyReceives: "🙉", "🙊", "🙈",
    andCompletesWith: .isSuccess
)
somethingHappensAndPublisherReceives("🙉")
somethingHappensAndPublisherReceives("🙊")
somethingHappensAndPublisherReceives("🙈")
somethingHappensAndPublisherCompletes()

operation.wait(0.0001)
```

Validate Output and some Failure of Publishers
```swift
let operation = assert(
    publisher: myPublisher,
    eventuallyReceives: "🙉", "🙊", "🙈",
    andCompletesWith: .isFailure
)
somethingHappensAndPublisherReceives("🙉")
somethingHappensAndPublisherReceives("🙊")
somethingHappensAndPublisherReceives("🙈")
somethingHappensAndPublisherFails(SomeError())

operation.wait(0.0001)
```

Validate Output and specific Failure of Publishers
```swift
let operation = assert(
    publisher: myPublisher,
    eventuallyReceives: "🙉", "🙊", "🙈",
    andCompletesWith: .failedWithError { error in error == SomeError("123") }
)
somethingHappensAndPublisherReceives("🙉")
somethingHappensAndPublisherReceives("🙊")
somethingHappensAndPublisherReceives("🙈")
somethingHappensAndPublisherFails(SomeError("123"))

operation.wait(0.0001)
```

Validate No Output but completion of Publishers
```swift
let operation = assert(
    publisher: myPublisher,
    completesWithoutValues: .isSuccess
)
somethingHappensAndPublisherCompletes()

operation.wait(0.0001)
```
