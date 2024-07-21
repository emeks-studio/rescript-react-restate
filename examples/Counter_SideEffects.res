module ReactUpdate = {
  module Counter = {
    type state = int
    type action =
      | Increment
      | Decrement
    let reducer = (state, action) => 
      switch action {
      | Increment => ReactUpdate.UpdateWithSideEffects(
        state + 1,
        self => {
          Js.log2("increment side effect: ", self.state)
          Some(() => Js.log2("increment cleanup: ", self.state))
        },
      )
      | Decrement => ReactUpdate.UpdateWithSideEffects(
        state - 1,
        self => {
          Js.log2("decrement side effect: ", self.state)
          Some(() => Js.log2("decrement cleanup: ", self.state))
        },
      )
    }
    @react.component
    let make = () => {
      let (state, send) = ReactUpdate.useReducer(reducer, 0)
      <div>
        {state->React.int}
        <button onClick={_ => send(Decrement)}> {"-"->React.string} </button>
        <button onClick={_ => send(Increment)}> {"+"->React.string} </button>
      </div>
    }
  }
  @react.component
  let make = () => {
    let (show, setShow) = React.useState(() => true)
    <>
      <button onClick={_ => setShow(v => !v)}> {React.string("Mount/unmount")} </button>
      {show ? <Counter /> : React.null}
    </>
  }
}

module ReactRestate = {
  module Counter = {
    type state = int
    type action =
      | Increment
      | Decrement
    type deferredAction =
      | LogIncrement
      | LogDecrement
    module DeferredAction: Restate.HasDeferredAction with type t = deferredAction = {
      type t = deferredAction
      let variantId = action =>
        switch action {
        | LogIncrement => "LogIncrement"
        | LogDecrement => "LogDecrement"
      }
    }
    module RestateReducer = Restate.MakeReducer(DeferredAction)
    let reducer = (state, action) => 
     switch action {
       | Increment =>
         RestateReducer.UpdateWithDeferred(
           state + 1,
           LogIncrement,
         )
       | Decrement =>
         RestateReducer.UpdateWithDeferred(
           state - 1,
           LogDecrement,
         )
       }
    let scheduler: (RestateReducer.self<state, action>, deferredAction) => option<unit=>unit> = 
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
      let (state, send, _defer) = RestateReducer.useReducer(reducer, scheduler, 0)
      <div>
        {state->React.int}
        <button onClick={_ => send(Decrement)}> {"-"->React.string} </button>
        <button onClick={_ => send(Increment)}> {"+"->React.string} </button>
      </div>
    }
  }
  @react.component
  let make = () => {
    let (show, setShow) = React.useState(() => true)
    <>
      <button onClick={_ => setShow(v => !v)}> {React.string("Mount/unmount")} </button>
      {show ? <Counter /> : React.null}
    </>
  }
}