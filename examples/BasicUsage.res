

module ReactUpdate = {
  type action = Tick | Reset
  type state = {elapsed: int}

  @react.component
  let make = () => {
    let (state, send) = ReactUpdate.useReducerWithMapState(
      (state, action) =>
        switch action {
        | Tick =>
          UpdateWithSideEffects(
            {elapsed: state.elapsed + 1},
            ({send}) => {
              let timeoutId = Js.Global.setTimeout(() => send(Tick), 1_000)
              Some(() => {
                Js.Console.log2("cleanup: ", timeoutId)
                Js.Global.clearTimeout(timeoutId)
              })
            },
          )
        | Reset => Update({elapsed: 0})
        },
      () => {elapsed: 0},
    )
    React.useEffect0(() => {
      send(Tick)
      None
    })
    <div>
      {state.elapsed->Js.String.make->React.string}
      <button onClick={_ => send(Reset)}> {"Reset"->React.string} </button>
    </div>
  }
}

module ReactRestate = {
  type action = Tick | Reset
  type state = {elapsed: int}
  @react.component
  let make = () => {
    React.null
    // let (state, send) = Restate.useReducerWithMapState(
    //   (state, action) =>
    //     switch action {
    //     | Tick =>
    //       UpdateWithSideEffects(
    //         {elapsed: state.elapsed + 1},
    //         ({send}) => {
    //           let timeoutId = Js.Global.setTimeout(() => send(Tick), 1_000)
    //           Some(() => Js.Global.clearTimeout(timeoutId))
    //         },
    //       )
    //     | Reset => Update({elapsed: 0})
    //     },
    //   () => {elapsed: 0},
    // )
    // React.useEffect0(() => {
    //   send(Tick)
    //   None
    // })
    // <div>
    //   {state.elapsed->Js.String.make->React.string}
    //   <button onClick={_ => send(Reset)}> {"Reset"->React.string} </button>
    // </div>
  }
}
