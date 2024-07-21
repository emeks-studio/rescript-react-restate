
module App = {
  @react.component
  let make = () => {
    let url = RescriptReactRouter.useUrl()
    switch url.path {
      | list{"react-update", "basic"} => <BasicUsage.ReactUpdate />
      | list{"react-update", "counter"} => <Counter.ReactUpdate />
      | list{"react-update", "counter-effects"} => <Counter_SideEffects.ReactUpdate />
      | list{"react-restate", "basic"} => <BasicUsage.ReactRestate />
      | list{"react-restate", "counter"} => <Counter.ReactRestate />
      | list{"react-restate", "counter-effects"} => <Counter_SideEffects.ReactRestate />
      | _ => 
        <div>
          <div> 
            <h3> {"Basic Usage"->React.string} </h3>
            <button onClick={_ => RescriptReactRouter.push("/react-update/basic")}>
              {"React Update"->React.string}
            </button>
            <button onClick={_ => RescriptReactRouter.push("/react-restate/basic")}>
              {"Restate"->React.string}
            </button>
          </div>
          <div>
            <h3> {"Counter"->React.string} </h3>
            <button onClick={_ => RescriptReactRouter.push("/react-update/counter")}>
              {"React Update"->React.string}
            </button>
            <button onClick={_ => RescriptReactRouter.push("/react-restate/counter")}>
              {"Restate"->React.string}
            </button>
          </div>
          <div>
            <h3> {"Counter with Side Effects"->React.string} </h3>
            <button onClick={_ => RescriptReactRouter.push("/react-update/counter-effects")}>
              {"React Update"->React.string}
            </button>
            <button onClick={_ => RescriptReactRouter.push("/react-restate/counter-effects")}>
              {"Restate"->React.string}
            </button>
          </div>
        </div>
    }
  }
}

switch ReactDOM.querySelector("#root") {
| Some(root) => ReactDOM.render(<App />, root)
| None => ()
}