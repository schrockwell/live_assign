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
    Internal.init_module_attributes(__CALLER__, [:prop, :react, :state, :computed, :defaults])

    quote do
      @behaviour Love.Events
      @on_definition {Love.Internal, :on_definition}
      @before_compile Love.View

      import Love.View

      on_mount({Love.View, __MODULE__})
    end
  end

  ##################################################
  # __before_compile__/1
  ##################################################

  defmacro __before_compile__(env) do
    # Evaluate quoted opts and turn them into more useful structures
    Internal.before_compile_eval_metas(env, [:state, :computed])

    # Add the :triggers fields, so we know what to reevaluate when a field changes
    Internal.before_compile_put_meta_triggers(env.module, [:state])

    # TODO: Check for cycles in reactive values

    # Delay these function definitions until as late as possible, so we can ensure the attributes
    # are fully set up (i.e. wait for __on_definition__/6 to evaluate first!)
    [
      Internal.before_compile_define_meta_fns(__CALLER__, [:prop, :state, :computed, :react]),
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
  Defines a computed assign.

  Computed assigns are set via `put_computed/2` or `put_computed/3`. They are internal to the
  view and are typically set inside reactive callbacks, although they can be updated at any
  time in the view lifecycle. Computed assigns cannot trigger reactive callbacks.
  """
  @doc group: :fields
  @spec computed(key :: atom) :: nil
  defmacro computed(key) when is_atom(key) do
    Internal.define_computed(__CALLER__, key, [])
  end

  @doc """
  Updates state assigns.

  This will immediately reevaluate reactive fields that depend on the changed state, so
  call this function as infrequently as possible. In other words, try to batch state changes
  and limit `put_state/2` calls to once per function.

  This function cannot be called within a reactive callback. Doing so will raise a `RuntimeError`.
  If you need to update an assign within a reactive callback, you must use a computed assign.

  Returns the socket with the new state and after any reactive callbacks have run.
  """
  @spec put_state(LiveView.Socket.t(), map | keyword) :: LiveView.Socket.t()
  def put_state(socket, changes) do
    Internal.put_state(socket, changes)
  end

  @doc """
  Updates computed assigns.

  This can be called at any point in the view lifecycle.
  """
  @spec put_computed(socket :: LiveView.Socket.t(), changes :: map | keyword) ::
          LiveView.Socket.t()
  def put_computed(socket, changes) do
    Enum.reduce(changes, socket, fn {key, value}, socket_acc ->
      Internal.put_computed(socket_acc, key, value)
    end)
  end

  @doc """
  Updates a computed assign.

  This can be called at any point in the view lifecycle.
  """
  @spec put_computed(socket :: LiveView.Socket.t(), key :: atom, value :: any) ::
          LiveView.Socket.t()
  def put_computed(socket, key, value) do
    Internal.put_computed(socket, key, value)
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
