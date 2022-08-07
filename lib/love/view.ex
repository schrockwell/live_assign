defmodule Love.View do
  @moduledoc """
  🔥 Rekindle your love for LiveViews.
  """

  alias Love.Internal
  alias Phoenix.LiveView

  @callback handle_message(key :: atom, payload :: any, socket :: LiveView.Socket.t()) ::
              socket :: LiveView.Socket.t()

  @optional_callbacks handle_message: 3

  ##################################################
  # __using__/1
  ##################################################

  defmacro __using__(_opts) do
    Internal.init_module_attributes(__CALLER__, [:prop, :react, :state, :computed, :defaults])

    quote do
      @behaviour Love.View
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
  Defines a state field.

  The second arg is the initial value for this state field (defaults to `nil` if omitted).
  """
  defmacro state(key, quoted_opts \\ []) when is_atom(key) do
    Internal.define_state(__CALLER__, key, quoted_opts)
  end

  @doc """
  Defines a state field.

  The second arg is the initial value for this state field (defaults to `nil` if omitted).
  """
  defmacro computed(key, quoted_opts \\ []) when is_atom(key) do
    Internal.define_computed(__CALLER__, key, quoted_opts)
  end

  @doc """
  Puts many state changes into the component.

  This will also immediately reevaluate any necessary reactive fields, so
  call this as infrequently as possible (i.e. state changes should be batched).
  """
  def put_state(socket, changes) do
    Internal.put_state(socket, changes)
  end

  @doc """
  Puts many computed values.
  """
  def put_computed(socket, changes) do
    Enum.reduce(changes, socket, fn {key, value}, socket_acc ->
      Internal.put_computed(socket_acc, key, value)
    end)
  end

  @doc """
  Puts a computed value into the component.
  """
  def put_computed(socket, key, value) do
    Internal.put_computed(socket, key, value)
  end

  @doc """
  Emits a predefined message.
  """
  defdelegate emit(socket, key, payload), to: Internal

  @doc false
  def on_mount(module, _params, _session, socket) do
    socket =
      socket
      |> Internal.put_private(:module, module)
      |> Internal.put_private(:assigns_validated?, false)

    {:cont,
     socket
     |> LiveView.assign(Internal.initial_state(socket))
     |> LiveView.attach_hook(:love_component_info, :handle_info, &handle_info_hook/2)}

    # |> LiveView.attach_hook(:love_component_params, :handle_params, &handle_params_hook/3)
  end

  defp handle_info_hook(%Love.Message{} = message, socket) do
    {:halt,
     Internal.live_view_module(socket).handle_message(message.key, message.payload, socket)}
  end

  defp handle_info_hook(_message, socket), do: {:cont, socket}

  # defp handle_params_hook(_params, _uri, socket) do
  #   if Internal.get_private(socket, :assigns_validated?) do
  #     {:cont, socket}
  #   else
  #     {:cont,
  #      socket
  #      |> Internal.ensure_assigns_present!(:state)
  #      |> Internal.ensure_assigns_present!(:computed)
  #      |> Internal.put_private(:assigns_validated?, true)}
  #   end
  # end
end
