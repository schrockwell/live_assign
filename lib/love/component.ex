defmodule Love.Component do
  @moduledoc """
  🔥 Rekindle your love for components.
  """

  alias Love.Common
  alias Phoenix.LiveView

  @callback handle_message(key :: atom, payload :: any, socket :: LiveView.Socket.t()) ::
              {:ok, socket :: LiveView.Socket.t()}

  @optional_callbacks handle_message: 3

  ##################################################
  # __using__/1
  ##################################################

  defmacro __using__(_opts) do
    Common.init_attrs(__CALLER__, [:react, :prop, :state, :computed, :defaults])

    quote do
      @behaviour Love.Component
      @on_definition {Love.Common, :on_definition}
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
    Common.before_compile_eval_metas(env, [:prop, :state, :computed])

    # Add the :triggers fields, so we know what to reevaluate when a field changes
    Common.before_compile_put_meta_triggers(env.module, [:prop, :state])

    # TODO: Check for cycles in reactive values

    # Delay these function definitions until as late as possible, so we can ensure the attributes
    # are fully set up (i.e. wait for __on_definition__/6 to evaluate first!)
    [
      Common.before_compile_define_meta_fns(__CALLER__, [:prop, :state, :computed, :react]),
      Common.define_defaults(env.module)
    ]
  end

  ##################################################
  # PUBLIC API
  ##################################################

  @doc """
  Defines a component prop field.

  ## Options

  - `:default` - optional; if specified, this prop is considered optional, and will be assigned the default
    value during mount. If nothing is passed, this prop is required. `nil` is a valid default value (i.e. it
    will be optional)
  """
  defmacro prop(key, quoted_opts \\ []) when is_atom(key) do
    Common.define_prop(__CALLER__, key, quoted_opts)
  end

  @doc """
  Defines a slot prop.

  Takes the same arguments as `prop/2`.
  """
  defmacro slot(key, quoted_opts \\ []) when is_atom(key) do
    Common.define_prop(__CALLER__, key, quoted_opts)
  end

  @doc """
  Defines a message prop.
  """
  defmacro message(key) when is_atom(key) do
    Common.define_prop(__CALLER__, key, [])
  end

  @doc """
  Defines a state field.

  The second arg is the initial value for this state field (defaults to `nil` if omitted).
  """
  defmacro state(key, quoted_opts \\ []) when is_atom(key) do
    Common.define_state(__CALLER__, key, quoted_opts)
  end

  @doc """
  Defines a state field.

  The second arg is the initial value for this state field (defaults to `nil` if omitted).
  """
  defmacro computed(key, quoted_opts \\ []) when is_atom(key) do
    Common.define_computed(__CALLER__, key, quoted_opts)
  end

  @doc """
  Puts many state changes into the component.

  This will also immediately reevaluate any necessary reactive fields, so
  call this as infrequently as possible (i.e. state changes should be batched).
  """
  def put_state(socket, changes) do
    Common.put_state!(socket, changes)
  end

  @doc """
  Puts many computed values.
  """
  def put_computed(socket, changes) do
    Enum.reduce(changes, socket, fn {key, value}, socket_acc ->
      Common.put_computed!(socket_acc, key, value)
    end)
  end

  @doc """
  Puts a computed value into the component.
  """
  def put_computed(socket, key, value) do
    Common.put_computed!(socket, key, value)
  end

  @doc """
  Emits a predefined message.
  """
  defdelegate emit(socket, key, payload), to: Common

  @doc false
  def on_mount(socket, module) do
    socket =
      socket
      |> Common.put_private(:module, module)
      |> Common.put_private(:assigns_validated?, false)

    socket
    |> LiveView.assign(Common.initial_props(socket))
    |> LiveView.assign(Common.initial_state(socket))
  end

  @doc false
  def on_update(socket, %{__message__: %Love.Message{} = message}) do
    case Common.live_view_module(socket).handle_message(message.key, message.payload, socket) do
      {:ok, socket} ->
        socket

      _else ->
        raise "expected handle_message/3 callback to return {:ok, socket}"
    end
  end

  def on_update(socket, new_assigns) do
    socket
    |> Common.merge_props(new_assigns)
    |> Common.ensure_assigns_present!(:prop)
    |> Common.update_reactive()
    |> Common.ensure_assigns_present!(:state)
    |> Common.ensure_assigns_present!(:computed)
    |> Common.put_private(:assigns_validated?, true)
  end
end
