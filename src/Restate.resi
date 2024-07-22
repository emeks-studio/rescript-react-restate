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

let useReducer: (
  reducer<'state, 'action, 'deferredAction>, // The reducer provided by the user
  scheduler<'state, 'action, 'deferredAction>, // The scheduler provided by the user
  'state,
) => ('state, dispatch<'action>, schedule<'deferredAction>)

let useReducerWithMapState: (
  reducer<'state, 'action, 'deferredAction>, // The reducer provided by the user
  scheduler<'state, 'action, 'deferredAction>, // The scheduler provided by the user
  unit => 'state, 
) => ('state, dispatch<'action>, schedule<'deferredAction>)