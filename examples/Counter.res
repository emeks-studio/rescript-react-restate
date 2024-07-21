
module ReactUpdate = {
  type state = int
  type action = Increment | Decrement
  let reducer = (state, action) => {
    switch action {
    | Increment => ReactUpdate.Update(state + 1)
    | Decrement => Update(state - 1)
    }
  }

  @react.component
  let make = () => {
    let (state, dispatch) = ReactUpdate.useReducer(reducer, 0)
    <div>
      {React.int(state)}
      <div>
        <button onClick={_ => dispatch(Increment)}> {React.string("+")} </button>
        <button onClick={_ => dispatch(Decrement)}> {React.string("-")} </button>
      </div>
    </div>
  }
}

// (!) If you don't need to trigger deferred actions, you should use React.useReducer
module ReactRestate = {
  type state = int
  type action = Increment | Decrement

  let reducer = (state, action) => {
    switch action {
    | Increment => state + 1
    | Decrement => state - 1
    }
  }

  @react.component
  let make = () => {
    let (state, dispatch) = React.useReducer(reducer, 0)
    <div>
      {React.int(state)}
      <div>
        <button onClick={_ => dispatch(Increment)}> {React.string("+")} </button>
        <button onClick={_ => dispatch(Decrement)}> {React.string("-")} </button>
      </div>
    </div>
  }
}
