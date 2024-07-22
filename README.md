# rescript-react-restate

This library is a fork and re-design of [rescript-react-update](https://github.com/bloodyowl/rescript-react-update).

Essentially what introduce is a fix on the effect cancellation mechanism. A fix in terms of following 
React's philosophy about how we should ensure effects cancellation before re-render.

As a consequence, of the fix, the library also introduce an elegant approach in the separation between pure state management and side effects. By introducing the concept of `deferred actions` and `schedulers`.

A `deferred action` is an `action` that is not immediately dispatched, but rather scheduled to be dispatched later.
In contrast with `reducers` (that given an action and the state, provides the new state), a `scheduler` is a function that given the current context and a deferred action, can execute (user defined) side effects, and return (or not) a cleanup/cancellation function associated with.

## Handling side effects (Asynchronous actions, logging, etc.)

`Restate` powers up reducers by allow them not just update state, but also defer an action to be dispatched later if is desired. This is useful when you want to handle side effects (like logging, network requests, etc.) after the state has been updated.

```reason

// Your state

type state = int

// Your actions (both immediate and deferred ones)

type action =
  | Increment
  | Decrement

type deferredAction =
  | LogIncrement
  | LogDecrement

// A Reducer now can update the state and schedule deferred actions (if they need to)
let reducer = (state, action) => 
 switch action {
   | Increment =>
     Restate.UpdateWithDeferred(
       state + 1,
       LogIncrement,
     )
   | Decrement =>
     Restate.UpdateWithDeferred(
       state - 1,
       LogDecrement,
     )
   }

// A Scheduler handle deferred actions by triggering side effects and returning a cleanup function (if necessary)
let scheduler: (Restate.self<state, action, deferredAction>, deferredAction) => option<unit=>unit> = 
  (self, deferredAction) =>
    switch deferredAction {
    | LogIncrement =>
      Js.log2("increment side effect: ", self.state)
      // Note: The state on the cleanup will the content of this scope, and
      //       not the previous one that exist at moment of running the function.
      Some(() => Js.log2("increment cleanup: ", self.state))
    | LogDecrement =>
      Js.log2("decrement side effect: ", self.state)
      Some(() => Js.log2("decrement cleanup: ", self.state))
    }

@react.component
let make = () => {
  let (state, send, _defer) = Restate.useReducer(reducer, scheduler, 0)
  <div>
    {state->React.int}
    <button onClick={_ => send(Decrement)}> {"-"->React.string} </button>
    <button onClick={_ => send(Increment)}> {"+"->React.string} </button>
  </div>
}
```

## Lazy initialisation

If you'd rather initialize state lazily (if there's some computation you don't want executed at every render for instance), use `useReducerWithMapState` where the first argument is a function taking `unit` and returning the initial state.

## Installation

```console
$ yarn add rescript-react-restate
```

or

```console
$ npm install --save rescript-react-restate
```

Then add `rescript-react-restate` to your `bsconfig.json` `bs-dependencies` field.

## Development

```console
nix develop

# Run examples server:
yarn dev

# Build and watch rescript:
yarn re:watch
```