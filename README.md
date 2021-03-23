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
