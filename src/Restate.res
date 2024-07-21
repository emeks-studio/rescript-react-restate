// PoC for Restate library: Let's make useReducer great again! 
// Redux like architecture with modern React effects approach.

// TODO: Look for a better name
// HasDeferredAction "type class" should provide a way of identify for each deferred action. 
// By uniquely identify their variant constructor.
module type HasDeferredAction = {
  type t
  let variantId: t => string
}

module MakeReducer = (DeferredAction: HasDeferredAction) => {  
  /** API Types **/
  type dispatch<'action> = 'action => unit // Reducer Trigger Function
  type schedule = DeferredAction.t => unit // Scheduler Trigger Function
  // Magic Types based on ReactUpdate library
  type update<'state> =
    | NoUpdate // no update
    | Update('state) // update only
    | UpdateWithDeferred('state, DeferredAction.t) // update and defer a deferred action
    | Deferred(DeferredAction.t) // no update, but defer a deferred action 
  // Shape of Restate Reducer
  type self<'state, 'action> = {
    send: dispatch<'action>,
    defer: schedule,
    state: 'state,
  }
  // React Reducers looks like this:
  // type reducer<'state, 'action> = ('state, 'action) => 'state
  // vs Restate Reducer "reduce" function:
  type reducer<'state, 'action> = ('state, 'action) => update<'state>
  // ^ Main difference is that our reduce function is wrapped in an custom "update" type.
  type scheduler<'state, 'action> = (self<'state, 'action>, DeferredAction.t) => option<unit => unit>
  // ^ Scheduler is like an impure reducer that group the async/side effects actions related code.
  //   But instead of dispatch actions inmmediatly, in their case, we differ them into a queue.

  /** Internal Types ***/
  // This our the library internal actions we can dispatch.
  // As you can see in the implementation, they act as a proxy to the user actions.
  type proxy<'action> =
    | WiredAction('action)
    | PushDeferred(DeferredAction.t)
    | PopDeferred(Belt.List.t<DeferredAction.t>)
  type internalState<'action, 'state> = {
    userState: 'state,
    // TODO: Ideally we should use a Queue data type. If not, maybe use Array instead.
    deferredActionsQueue: Belt.List.t<DeferredAction.t>
  }

  // /** Usage: **/
  // 1. Init module;
  // module RestateReducer = Restate.MakeReducer(DeferredActions)
  // 2. Use the Hook;
  // RestateReduser.useReducer(reducer, scheduler, initialState)
  let useReducer = (
    reducer: reducer<'state, 'action>, // The reducer provided by the user
    scheduler: scheduler<'state, 'action>, // The scheduler provided by the user
    initialState: 'state
  ) => {
    // NOTE: We must follow the rules of React about effects cleanup!
    // After every re-render with changed dependencies, 
    // React will first run the cleanup function (if you provided it) with the old values,
    // and then run your setup function with the new values
    // type effect<'action> = ('action => option<unit => unit>) => unit
    // Ref. https://react.dev/reference/react/useEffect#parameters
    let cleanupFnsRef: React.ref<Belt.Map.String.t<option<unit => unit>>> = React.useRef(Belt.Map.String.empty)  
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
        }
      , {userState: initialState, deferredActionsQueue: list{}}
    )
    let defer: schedule = deferredAction => internalDispatch(PushDeferred(deferredAction))
    let send: dispatch<'action> = action => internalDispatch(WiredAction(action)) 
    // Obs: Actually this useEffect and the other one compose the "scheduler"
    React.useEffect1(() => {
      // CAUTION: Maybe we should run all of them in a single effect (?)
      // What happens if there are 2 consecutives of the same type?
      switch (deferredActionsQueue) {
      | list{deferredAction, ...queueTail} => 
        // 1. If there is a previous cleanup function, run it
        cleanupFnsRef.current
          ->Belt.Map.String.get(DeferredAction.variantId(deferredAction))
          ->Belt.Option.map(mPrevCleanupFn => mPrevCleanupFn->Belt.Option.map(prevCleanupFn => prevCleanupFn()))
          ->ignore
        // 2. Run the deferred action  
        let mNewCleanupFn = scheduler({state: userState, send, defer}, deferredAction) // CAUTION: Is reducerState the latest state?
        // 3. Update the cleanup function
        cleanupFnsRef.current = cleanupFnsRef.current->Belt.Map.String.set(DeferredAction.variantId(deferredAction), mNewCleanupFn)
        // 4. Pop the action from the queue
        internalDispatch(PopDeferred(queueTail)) 
      | list{} => () // Stop condition!
      }
      None
    }, [deferredActionsQueue])
    // In case of unmount, we must run all cleanup functions and empty their tracking map
    React.useEffect0(() => {
      Some(() => {
        cleanupFnsRef.current
        ->Belt.Map.String.valuesToArray
        ->Belt.Array.forEach(
          mCleanupFn => mCleanupFn->Belt.Option.forEach(cleanupFn => cleanupFn())
        )
        // Not needed, given after unmount the ref is destroyed by React
        // cleanupFnsRef.current = Belt.Map.String.empty
        }
      )
      }
    )
    // Notice that this is the API the user will receive.
    // This way, we hide implementation (unsafe) tricks.
    (userState, send, defer)
  }

  let useReducerWithMapState = (
    reducer: reducer<'state, 'action>, // The reducer provided by the user
    scheduler: scheduler<'state, 'action>, // The scheduler provided by the user
    createInitialState: () => 'state, // A function to map the initial state
  ) => {
    let cleanupFnsRef: React.ref<Belt.Map.String.t<option<unit => unit>>> = React.useRef(Belt.Map.String.empty)  
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
        }
      , (), initialState =>  {userState: createInitialState(initialState), deferredActionsQueue: list{}}
    )
    let defer: schedule = deferredAction => internalDispatch(PushDeferred(deferredAction))
    let send: dispatch<'action> = action => internalDispatch(WiredAction(action)) 
    React.useEffect1(() => {
      switch (deferredActionsQueue) {
      | list{deferredAction, ...queueTail} => 
        cleanupFnsRef.current
          ->Belt.Map.String.get(DeferredAction.variantId(deferredAction))
          ->Belt.Option.map(mPrevCleanupFn => mPrevCleanupFn->Belt.Option.map(prevCleanupFn => prevCleanupFn()))
          ->ignore
        let mNewCleanupFn = scheduler({state: userState, send, defer}, deferredAction)
        cleanupFnsRef.current = cleanupFnsRef.current->Belt.Map.String.set(DeferredAction.variantId(deferredAction), mNewCleanupFn)
        internalDispatch(PopDeferred(queueTail)) 
      | list{} => ()
      }
      None
    }, [deferredActionsQueue])
    React.useEffect0(() => {
      Some(() => {
        cleanupFnsRef.current
        ->Belt.Map.String.valuesToArray
        ->Belt.Array.forEach(
          mCleanupFn => mCleanupFn->Belt.Option.forEach(cleanupFn => cleanupFn())
        )
        }
      )
      }
    )
    (userState, send, defer)
  }
}
