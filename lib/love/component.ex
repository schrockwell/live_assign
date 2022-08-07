defmodule Love.Component do
  @moduledoc """
  🔥 Rekindle your love for components.
  """

  alias Love.Internal
  alias Phoenix.LiveView

  ##################################################
  # __using__/1
  ##################################################

  defmacro __using__(_opts) do
    Internal.init_module_attributes(__CALLER__, [:react, :prop, :state, :computed, :defaults])

    quote do
      @behaviour Love.Events
      @on_definition {Love.Internal, :on_definition}
      @before_compile Love.Component

      import Love.Component

      prop :id

      def mount(socket) do
        {:ok, Love.Component.on_mount(socket, __MODULE__)}
      end

      def update(new_assigns, socket) do
        {:ok, Love.Component.on_update(socket, new_assigns)}
      end

      defoverridable mount: 1, update: 2
    end
  end

  ##################################################
  # __before_compile__/1
  ##################################################

  defmacro __before_compile__(env) do
    # Evaluate quoted opts and turn them into more useful structures
    Internal.before_compile_eval_metas(env, [:prop, :state, :computed])

    # Add the :triggers fields, so we know what to reevaluate when a field changes
    Internal.before_compile_put_meta_triggers(env.module, [:prop, :state])

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
  Defines a component prop field.

  > #### Note {: .info}
  >
  > `prop :id` is automatically defined as a required prop for all components that `use Love.Component`,
  > because every stateful `LiveComponent` requires an `:id`.

  ## Options

  - `:default` - optional; if specified, this prop is considered optional, and will be assigned the default
    value during mount. If not specified, the prop is considered required. `nil` is a valid default value. The
    expression for the default value is wrapped in a function and its evaluation is deferred until runtime
    at the moment the component is mounted.
  """
  @doc group: :fields
  @spec prop(key :: atom, opts :: keyword) :: nil
  defmacro prop(key, opts \\ []) when is_atom(key) do
    Internal.define_prop(__CALLER__, key, opts)
  end

  @doc """
  Defines a slot prop.

  ## Options

  - `:required?` - defaults to `true`; if not required, the slot has a default value of `[]`
  """
  @doc group: :fields
  @spec slot(key :: atom, opts :: keyword) :: nil
  defmacro slot(key, opts \\ []) when is_atom(key) do
    prop_opts =
      if opts[:required?] == false do
        [default: []]
      else
        []
      end

    Internal.define_prop(__CALLER__, key, prop_opts)
  end

  @doc """
  Defines a event prop.

  Event props are optional and default to `nil`.

  The value of this prop must be a destination to receive the event, either a pid or `{module, id}`.
  See `emit/3` for details on how to raise this event.

  ## Example

      event :on_selected

      # => to raise it: emit(socket, :on_selected, "some payload")
      # => to handle it: handle_event(:on_selected, {module, id}, "some payload", socket)
  """
  @doc group: :fields
  @spec event(key :: atom) :: nil
  defmacro event(key) when is_atom(key) do
    Internal.define_prop(__CALLER__, key, default: nil)
  end

  @doc """
  Defines a state assign.

  State is internal to the component and is modified via `put_state/2`.

  ## Options

  - `:default` - optional; if specified, the state will be assigned the default value during mount.
    The expression for the default value is wrapped in a function and its evaluation is deferred until runtime
    at the moment the component is mounted. If not specified, you should `put_state/2` during component
    initialization to set an initial value.
  """
  @doc group: :fields
  @spec state(key :: atom, opts :: keyword) :: nil
  defmacro state(key, opts \\ []) when is_atom(key) do
    Internal.define_state(__CALLER__, key, opts)
  end

  @doc """
  Defines a computed assign.

  Computed assigns are set via `put_computed/2` or `put_computed/3`. They are internal to the
  component and are typically set inside reactive callbacks, although they can be updated at any
  time in the component lifecycle. Computed assigns cannot trigger reactive callbacks.

  ## Example

      prop :profile
      state :profile_params, default: %{}
      computed :changeset

      def handle_event("validate", %{"profile" => profile_params}, socket) do
        {:noreply, put_state(socket, profile_params: profile_params)}
      end

      @react to: [:profile, :profile_params]
      def compute_changeset(socket) do
        put_computed(socket,
          changeset: MySchema.changeset(socket.assigns.profile, socket.assigns.profile_params)
        )
      end
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

  This can be called at any point in the component lifecycle.
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

  This can be called at any point in the component lifecycle.
  """
  @spec put_computed(socket :: LiveView.Socket.t(), key :: atom, value :: any) ::
          LiveView.Socket.t()
  def put_computed(socket, key, value) do
    Internal.put_computed(socket, key, value)
  end

  @doc """
  Sends an event message.

  The event `name` is an event prop defined by `event/1`. The destination for the event is determined
  by the value of the event prop. See `Love.Events.send_message/4` for details on valid destinations.
  """
  @spec emit(LiveView.Socket.t(), name :: atom, payload :: any) :: LiveView.Socket.t()
  defdelegate emit(socket, name, payload \\ nil), to: Internal

  @doc """
  Hooks into the `LiveComponent` mount.

  This is not normally called directly, because it is automatically called via a default implementation
  of `mount/1` defined by `use Love.Component`.

  If the component overrides the default implementation of `mount/1`, then `on_mount/2` must be invoked manually.

  ## Example

      def mount(socket) do
        {:ok,
         socket
         |> Love.Component.on_mount(__MODULE__)
         |> do_other_stuff()}
      end
  """
  @spec on_mount(socket :: LiveView.Socket.t(), module :: module) :: LiveView.Socket.t()
  def on_mount(socket, module) do
    socket =
      socket
      |> Internal.put_private(:module, module)
      |> Internal.put_private(:assigns_validated?, false)

    socket
    |> LiveView.assign(Internal.initial_props(socket))
    |> LiveView.assign(Internal.initial_state(socket))
  end

  @doc """
  Hooks into the `LiveComponent` update.

  This is not normally called directly, because it is automatically called via a default implementation
  of `update/2` defined by `use Love.Component`.

  If the component overrides the default implementation of `update/2`, then `on_update/2` must be invoked manually.
  The `is_message?/1` guard can be used to detect if `assigns` contains an event message that should be handled
  separately.

  ## Example

      def update(assigns, socket) when is_message?(assigns) do
        {:ok, Love.Component.on_update(socket, assigns)}
      end

      def update(assigns, socket) do
        {:ok,
         socket
         |> Love.Component.on_update(assigns)
         |> do_other_stuff()}
      end
  """
  @spec on_update(socket :: LiveView.Socket.t(), assigns :: map) :: LiveView.Socket.t()
  def on_update(socket, %{__message__: %Love.Events.Message{} = message}) do
    case Internal.live_view_module(socket).handle_message(
           message.name,
           message.source,
           message.payload,
           socket
         ) do
      %LiveView.Socket{} = socket ->
        socket

      _else ->
        raise "expected handle_message/3 callback to return a %Phoenix.LiveView.Socket{}"
    end
  end

  def on_update(socket, new_assigns) do
    Internal.on_component_update(socket, new_assigns)
  end

  @doc """
  Checks if an `assigns` argument passed to `update/2` contains an event message.
  """
  @doc group: :guards
  @spec is_message?(assigns :: map) :: boolean
  defguard is_message?(assigns) when assigns.__message__.__struct__ == Love.Events.Message
end
