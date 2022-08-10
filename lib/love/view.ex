defmodule Love.View do
  @moduledoc """
  Extend LiveViews.

  Add `use Love.View` to a `Phoenix.LiveView`. This adds:

  - `@behaviour Love.Events` for the optional `c:Love.Events.handle_message/4` callback
  - `import Love.View` to make macros and functions locally available
  -  Hooks into `mount` and `handle_info`
  """

  alias Love.Internal
  alias Phoenix.LiveView

  ##################################################
  # __using__/1
  ##################################################

  defmacro __using__(_opts) do
    Internal.init_module_attributes(__CALLER__, [:prop, :react, :state, :defaults])

    quote do
      @behaviour Love.Events
      @before_compile Love.View

      use Love.React

      import Love.View

      on_mount({Love.View, __MODULE__})
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
  """
  @doc group: :fields
  @spec state(key :: atom, opts :: keyword) :: nil
  defmacro state(key, quoted_opts \\ []) when is_atom(key) do
    Internal.define_state(__CALLER__, key, quoted_opts)
  end

  @doc """
  Updates state assigns.

  When called outside of a reactive function, any reacgive functions that depend on the changed
  state will be immediately evaluated, so call this function as infrequently as possible. In
  other words, try to batch state changes and limit `put_state/2` calls to once per function.

  Within a reactive function, any state changes that might trigger another reactive function will
  be deferred until the current reactive function completely finishes executing.

  Returns the socket with the new state and after any reactive callbacks have run.
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

    {:cont,
     socket
     |> LiveView.assign(Internal.initial_state(socket))
     |> LiveView.attach_hook(:love_view_info, :handle_info, &handle_info_hook/2)}
  end

  defp handle_info_hook(%Love.Events.Message{} = message, socket) do
    {:halt,
     Internal.live_view_module(socket).handle_message(
       message.name,
       message.source,
       message.payload,
       socket
     )}
  end

  defp handle_info_hook(_message, socket), do: {:cont, socket}
end
