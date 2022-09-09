defmodule LiveAssign.View do
  @moduledoc """
  Extend LiveViews.

  Add `use LiveAssign.View` to a `Phoenix.LiveView`. This adds:

  - `import LiveAssign.View` to make macros and functions locally available
  -  Hooks into `mount` and `handle_info`
  """

  alias LiveAssign.Internal
  alias Phoenix.LiveView

  ##################################################
  # __using__/1
  ##################################################

  defmacro __using__(_opts) do
    Internal.init_module_attributes(__CALLER__, [:prop, :react, :state, :defaults])

    quote do
      @before_compile LiveAssign.View

      use LiveAssign.React

      import LiveAssign.View

      on_mount({LiveAssign.View, __MODULE__})
    end
  end

  ##################################################
  # __before_compile__/1
  ##################################################

  defmacro __before_compile__(env) do
    # Evaluate quoted opts and turn them into more useful structures
    Internal.before_compile_eval_metas(env, [:state])

    # Add the :triggers fields, so we know what to reevaluate when a field changes
    Internal.before_compile_put_meta_triggers(env.module, [:state])

    # Delay these function definitions until as late as possible, so we can ensure the attributes
    # are fully set up (i.e. wait for __on_definition__/6 to evaluate first!)
    [
      Internal.before_compile_define_meta_fns(env, [:prop, :state]),
      Internal.define_defaults(env.module)
    ]
  end

  ##################################################
  # PUBLIC API
  ##################################################

  @doc """
  Defines a state assign.

  State is internal to the view and is modified via `put_state/2`.

  ## Options

  - `:default` - optional; if specified, the state will be assigned the default value during mount.
    The expression for the default value is wrapped in a function and its evaluation is deferred until runtime
    at the moment the view is mounted. If not specified, you should `put_state/2` during view
    initialization to set an initial value.

  ## Example

      # State with no initial value
      state :changeset

      # State with an initial value, evaluated during mount
      state :now, default: DateTime.utc_now()
  """
  @doc group: :fields
  @spec state(key :: atom, opts :: keyword) :: nil
  defmacro state(key, opts \\ []) when is_atom(key) do
    Internal.define_state(__CALLER__, key, opts)
  end

  @doc """
  Updates state assigns.

  When called outside of a reactive function, any reactive functions that depend on the changed
  state will be immediately evaluated, so call this function as infrequently as possible. In
  other words, try to batch state changes and limit `put_state/2` calls to once per function.

  Within a reactive function, any additionally-triggered reactive functions will
  be deferred until after the current reactive function completely executes.

  Returns the socket with the new state and after any reactive callbacks have run.

  ## Example

      state :first_name

      put_state(socket, first_name: "Marvin")
  """
  @spec put_state(LiveView.Socket.t(), map | keyword) :: LiveView.Socket.t()
  def put_state(socket, changes) do
    Internal.put_state(socket, changes)
  end

  @doc false
  def on_mount(module, _params, _session, socket) do
    socket =
      socket
      |> Internal.put_private(:module, module)
      |> Internal.put_private(:assigns_validated?, false)

    {:cont, LiveView.assign(socket, Internal.initial_state(socket))}
  end
end
