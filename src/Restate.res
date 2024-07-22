// PoC for Restate library: Let's make useReducer great again!
// Redux like architecture with modern React effects approach.

/** API Types **/
type dispatch<'action> = 'action => unit // Reducer Trigger Function
type schedule<'deferredAction> = 'deferredAction => unit // Scheduler Trigger Function
// Magic Types based on ReactUpdate library
type update<'state, 'deferredAction> =
  | NoUpdate // no update
  | Update('state) // update only
  | UpdateWithDeferred('state, 'deferredAction) // update and defer a deferred action
  | Deferred('deferredAction) // no update, but defer a deferred action
// Shape of Restate Reducer
type self<'state, 'action, 'deferredAction> = {
  send: dispatch<'action>,
  defer: schedule<'deferredAction>,
  state: 'state,
}
// React Reducers looks like this:
// type reducer<'state, 'action> = ('state, 'action) => 'state
// vs Restate Reducer "reduce" function:
type reducer<'state, 'action, 'deferredAction> = ('state, 'action) => update<'state, 'deferredAction>
// ^ Main difference is that our reduce function is wrapped in an custom "update" type.
type scheduler<'state, 'action, 'deferredAction> = (self<'state, 'action, 'deferredAction>, 'deferredAction) => option<unit => unit>
// ^ Scheduler is like an impure reducer that group the async/side effects actions related code.
//   But instead of dispatch actions inmmediatly, in their case, we differ them into a queue.

// This our the library internal actions we can dispatch.
// As you can see in the implementation, they act as a proxy to the user actions.
/** Internal Types ***/
type proxy<'action, 'deferredAction> =
  | WiredAction('action)
  | PushDeferred('deferredAction)
  | PopDeferred(Belt.List.t<'deferredAction>)
type internalState<'action, 'state, 'deferredAction> = {
  userState: 'state,
  // TODO: Ideally we should use a Queue data type. If not, maybe use Array instead.
  deferredActionsQueue: Belt.List.t<'deferredAction>,
}

// /** Usage: **/
// 1. Init module;
// module RestateReducer = Restate.MakeReducer(DeferredActions)
// 2. Use the Hook;
// RestateReduser.useReducer(reducer, scheduler, initialState)
let useReducer = (
  reducer: reducer<'state, 'action, 'deferredAction>, // The reducer provided by the user
  scheduler: scheduler<'state, 'action, 'deferredAction>, // The scheduler provided by the user
  initialState: 'state,
) => {
  // NOTE: We must follow the rules of React about effects cleanup!
  // After every re-render with changed dependencies,
  // React will first run the cleanup function (if you provided it) with the old values,
  // and then run your setup function with the new values
  // type effect<'action> = ('action => option<unit => unit>) => unit
  // Ref. https://react.dev/reference/react/useEffect#parameters
  let cleanupFnsRef: React.ref<
    Internal_Map.t<'deferredAction, option<unit => unit>>,
  > = React.useRef(Internal_Map.make())
  let ({userState, deferredActionsQueue}, internalDispatch) = React.useReducer(
    ({userState, deferredActionsQueue} as internalState, internalAction) =>
      switch internalAction {
      | WiredAction(action) =>
        switch reducer(userState, action) {
        | NoUpdate => internalState
        | Update(state) => {...internalState, userState: state}
        | UpdateWithDeferred(state, deferredAction) => {
            userState: state,
            deferredActionsQueue: Belt.List.concat(deferredActionsQueue, list{deferredAction}),
          }
        | Deferred(deferredAction) => {
            ...internalState,
            deferredActionsQueue: Belt.List.concat(deferredActionsQueue, list{deferredAction}),
          }
        }
      | PushDeferred(deferredAction) => {
          ...internalState,
          deferredActionsQueue: Belt.List.concat(deferredActionsQueue, list{deferredAction}),
        }
      | PopDeferred(tailDeferredActions) => {
          ...internalState,
          deferredActionsQueue: tailDeferredActions,
        }
      },
    {userState: initialState, deferredActionsQueue: list{}},
  )
  let defer: schedule<'deferredAction> = deferredAction => internalDispatch(PushDeferred(deferredAction))
  let send: dispatch<'action> = action => internalDispatch(WiredAction(action))
  // Obs: Actually this useEffect and the other one compose the "scheduler"
  React.useEffect1(() => {
    // CAUTION: Maybe we should run all of them in a single effect (?)
    // What happens if there are 2 consecutives of the same type?
    switch deferredActionsQueue {
    | list{deferredAction, ...queueTail} =>
      // 1. If there is a previous cleanup function, run it
      cleanupFnsRef.current
      ->Internal_Map.get(deferredAction)
      ->Belt.Option.map(mPrevCleanupFn =>
        mPrevCleanupFn->Belt.Option.map(prevCleanupFn => prevCleanupFn())
      )
      ->ignore
      // 2. Run the deferred action
      let mNewCleanupFn = scheduler({state: userState, send, defer}, deferredAction) // CAUTION: Is reducerState the latest state?
      // 3. Update the cleanup function
      cleanupFnsRef.current->Internal_Map.set(deferredAction, mNewCleanupFn)
      // 4. Pop the action from the queue
      internalDispatch(PopDeferred(queueTail))
    | list{} => () // Stop condition!
    }
    None
  }, [deferredActionsQueue])
  // In case of unmount, we must run all cleanup functions and empty their tracking map
  React.useEffect0(() => {
    Some(
      () => {
        cleanupFnsRef.current
        ->Internal_Map.values
        ->Internal_Iterator.toArray
        ->Belt.Array.forEach(mCleanupFn =>
          mCleanupFn->Belt.Option.forEach(cleanupFn => cleanupFn())
        )
        // Not needed, given after unmount the ref is destroyed by React
        // cleanupFnsRef.current = Belt.Map.String.empty
      },
    )
  })
  // Notice that this is the API the user will receive.
  // This way, we hide implementation (unsafe) tricks.
  (userState, send, defer)
}

let useReducerWithMapState = (
  reducer: reducer<'state, 'action, 'deferredAction>, // The reducer provided by the user
  scheduler: scheduler<'state, 'action, 'deferredAction>, // The scheduler provided by the user
  createInitialState: unit => 'state,
) => {
  // A function to map the initial state

  let cleanupFnsRef: React.ref<
    Internal_Map.t<'deferredAction, option<unit => unit>>,
  > = React.useRef(Internal_Map.make())
  let ({userState, deferredActionsQueue}, internalDispatch) = React.useReducerWithMapState(
    ({userState, deferredActionsQueue} as internalState, internalAction) =>
      switch internalAction {
      | WiredAction(action) =>
        switch reducer(userState, action) {
        | NoUpdate => internalState
        | Update(state) => {...internalState, userState: state}
        | UpdateWithDeferred(state, deferredAction) => {
            userState: state,
            deferredActionsQueue: Belt.List.concat(deferredActionsQueue, list{deferredAction}),
          }
        | Deferred(deferredAction) => {
            ...internalState,
            deferredActionsQueue: Belt.List.concat(deferredActionsQueue, list{deferredAction}),
          }
        }
      | PushDeferred(deferredAction) => {
          ...internalState,
          deferredActionsQueue: Belt.List.concat(deferredActionsQueue, list{deferredAction}),
        }
      | PopDeferred(tailDeferredActions) => {
          ...internalState,
          deferredActionsQueue: tailDeferredActions,
        }
      },
    (),
    initialState => {userState: createInitialState(initialState), deferredActionsQueue: list{}},
  )
  let defer: schedule<'deferredAction> = deferredAction => internalDispatch(PushDeferred(deferredAction))
  let send: dispatch<'action> = action => internalDispatch(WiredAction(action))
  React.useEffect1(() => {
    switch deferredActionsQueue {
    | list{deferredAction, ...queueTail} =>
      cleanupFnsRef.current
      ->Internal_Map.get(deferredAction)
      ->Belt.Option.map(mPrevCleanupFn =>
        mPrevCleanupFn->Belt.Option.map(prevCleanupFn => prevCleanupFn())
      )
      ->ignore
      let mNewCleanupFn = scheduler({state: userState, send, defer}, deferredAction)
      cleanupFnsRef.current->Internal_Map.set(deferredAction, mNewCleanupFn)
      internalDispatch(PopDeferred(queueTail))
    | list{} => ()
    }
    None
  }, [deferredActionsQueue])
  React.useEffect0(() => {
    Some(
      () => {
        cleanupFnsRef.current
        ->Internal_Map.values
        ->Internal_Iterator.toArray
        ->Belt.Array.forEach(mCleanupFn =>
          mCleanupFn->Belt.Option.forEach(cleanupFn => cleanupFn())
        )
      },
    )
  })
  (userState, send, defer)
}
