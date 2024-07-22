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
              Js.Console.log2("schedule next tick: ", timeoutId)
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
  type deferredAction = ScheduleNextTick
  let reducer = (state, action) =>
    switch action {
    | Tick =>
      Restate.UpdateWithDeferred(
        {elapsed: state.elapsed + 1},
        ScheduleNextTick
      )
    | Reset => Restate.Update({elapsed: 0})
    }
  let scheduler: (Restate.self<state, action, 'deferredAction>, deferredAction) => option<unit=>unit> = 
    (self, action) =>
        switch action {
        | ScheduleNextTick =>
          let timeoutId = Js.Global.setTimeout(() => self.send(Tick), 1_000)
          Js.Console.log2("schedule next tick: ", timeoutId)
          Some(() => {
            Js.Console.log2("cleanup: ", timeoutId)
            Js.Global.clearTimeout(timeoutId)
          })
        }
  @react.component
  let make = () => {
    let (state, send, _defer) = Restate.useReducerWithMapState(reducer, scheduler, () => {elapsed: 0})
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

module ReactRaw = {
  @react.component
  let make = () => {
    let (elapsed, setElapsed) = React.useState(_ => 0)
    React.useEffect1(() => {
      let timeoutId = Js.Global.setTimeout(() => setElapsed(e => e + 1), 1_000)
      Js.Console.log2("schedule next tick: ", timeoutId)
      Some(() => {
        Js.Console.log2("cleanup: ", timeoutId)
        Js.Global.clearTimeout(timeoutId)
      })
    }, [elapsed])
    let reset = () => setElapsed(_ => 0)
    <div>
      {elapsed->Js.String.make->React.string}
      <button onClick={_ => reset()}> {"Reset"->React.string} </button>
    </div>
  }
}