defmodule Love.Component do
  @moduledoc """
  Extend LiveComponents.

  ## Usage

  Add `use Love.Component` to a `Phoenix.LiveComponent`. This adds:

  - `import Love.Component` to make macros and functions locally available
  - `prop :id` to define the required `:id` prop assign
  - `mount/1` and `update/2` default implementations (can safely overriden)

  ## Love.Component Example

      defmodule MyAppWeb.UserProfileComponent do
        use Phoenix.LiveComponent
        use Love.Component

        prop :profile
        prop :show_avatar?, default: false

        state :age
        state :expand_details?, default: false

        slot :inner_block

        event :on_selected

        def handle_event("toggle-details", _, socket) do
          {:noreply, put_state(socket, socket, expand_details?: not socket.assigns.expand_details?)}
        end

        def handle_event("select", %{"profile_id" => profile_id}}, socket) do
          {:noreply, emit(socket, :on_selected, profile_id)}
        end

        @react to: :profile
        defp put_age(socket) do
          age = trunc(Date.diff(Date.utc_today(), socket.assigns.profile.birthday) / 365)
          put_state(socket, age: age)
        end
      end
  """

  alias Love.Internal
  alias Phoenix.LiveView

  ##################################################
  # __using__/1
  ##################################################

  defmacro __using__(_opts) do
    Internal.init_module_attributes(__CALLER__, [:react, :prop, :state, :defaults])

    quote do
      @on_definition {Love.Internal, :on_definition}
      @before_compile Love.Component

      import Love.Component

      prop :id
    end
  end

  ##################################################
  # __before_compile__/1
  ##################################################

  defmacro __before_compile__(env) do
    # Evaluate quoted opts and turn them into more useful structures
    Internal.before_compile_eval_metas(env, [:prop, :state])

    # Add the :triggers fields, so we know what to reevaluate when a field changes
    Internal.before_compile_put_meta_triggers(env.module, [:prop, :state])

    # Delay these function definitions until as late as possible, so we can ensure the attributes
    # are fully set up (i.e. wait for __on_definition__/6 to evaluate first!)
    [
      Internal.before_compile_define_meta_fns(env, [:prop, :state, :react]),
      Internal.define_defaults(env.module),
      Internal.before_compile_define_react_wrappers(env),
      wrap_mount(env),
      wrap_update(env)
    ]
  end

  # Learned this technique here:
  # https://github.com/surface-ui/surface/blob/a93cfa753cb5bb7155981f4328bb64d01fa5e579/lib/surface/live_view.ex#L77-L104
  defp wrap_mount(env) do
    if Module.defines?(env.module, {:mount, 1}) do
      quote do
        defoverridable mount: 1

        def mount(socket) do
          socket = Internal.component_mount_hook(socket, __MODULE__)
          super(socket)
        end
      end
    else
      quote do
        def mount(socket) do
          {:ok, Internal.component_mount_hook(socket, __MODULE__)}
        end
      end
    end
  end

  defp wrap_update(env) do
    if Module.defines?(env.module, {:update, 2}) do
      quote do
        defoverridable update: 2

        def update(assigns, socket) do
          socket = Internal.component_update_hook(socket, assigns)
          super(assigns, socket)
        end
      end
    else
      quote do
        def update(assigns, socket) do
          {:ok, Internal.component_update_hook(socket, assigns)}
        end
      end
    end
  end

  ##################################################
  # PUBLIC API
  ##################################################

  @doc """
  Defines a prop.

  `prop :id` is automatically defined as a required prop for all components that `use Love.Component`,
  because every stateful `LiveComponent` requires an `:id`.

  ## Options

  - `:default` - optional; if specified, this prop is considered optional, and will be assigned the default
    value during mount. If not specified, the prop is considered required. `nil` is a valid default value. The
    expression for the default value is wrapped in a function and its evaluation is deferred until runtime
    at the moment the component is mounted.

  ## Example

      # A required prop
      prop :visible?

      # An optional prop
      prop :thumbnail_url, default: nil
  """
  @doc group: :fields
  @spec prop(key :: atom, opts :: keyword) :: nil
  defmacro prop(key, opts \\ []) when is_atom(key) do
    Internal.define_prop(__CALLER__, key, opts)
  end

  @doc """
  Defines a slot prop.

  ## Options

  - `:required?` - defaults to `true`. When `false`, the prop given the empty slot value of `[]`

  ## Example

      # Default slot name
      slot :inner_block

      # Optional slot
      slot :navbar, required?: false
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
  Defines an event prop.

  Event props are always optional, and default to `nil`.

  The value of this prop must be a destination to receive the event, either a PID or `{module, id}`.
  See `emit/3` for details on raising events.

  The emitted event name defaults to the name of the event prop. The event name can be overridden
  by the parent specifying `{pid, :my_custom_event_name}` or `{module, id, :my_custom_event_name}`.

  ## Example

      event :on_selected

      # To raise it:
      emit(socket, :on_selected, "some payload")

      # To handle it:
      handle_event(:on_selected, {module, id}, "some payload", socket)
  """
  @doc group: :fields
  @spec event(name :: atom) :: nil
  defmacro event(name) when is_atom(name) do
    Internal.define_prop(__CALLER__, name, default: nil)
  end

  @doc """
  Defines a state assign.

  State is internal to the component and is modified via `put_state/2`.

  ## Options

  - `:default` - optional; if specified, the state will be assigned the default value during mount.
    The expression for the default value is wrapped in a function and its evaluation is deferred until runtime
    at the moment the component is mounted. If not specified, you should `put_state/2` during component
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
  other words, try to batch state changes and limit `put_state/2` calls to once per lifecycle event.

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
end
