defmodule Love.Component do
  @moduledoc """
  🔥 Rekindle your love for components.
  """

  alias Love.Component.Internal

  ##################################################
  # __using__/1
  ##################################################

  defmacro __using__(_opts) do
    Module.put_attribute(__CALLER__.module, :__reactive_fields__, %{})
    Module.put_attribute(__CALLER__.module, :__prop_fields__, %{})
    Module.put_attribute(__CALLER__.module, :__state_fields__, %{})
    Module.put_attribute(__CALLER__.module, :__computed_fields__, %{})
    Module.put_attribute(__CALLER__.module, :__field_defaults__, %{})

    quote do
      @on_definition Love.Component
      @before_compile Love.Component

      import Love.Component

      def mount(socket) do
        {:ok, Love.Component.Internal.init(socket, __MODULE__)}
      end

      def update(new_assigns, socket) do
        {:ok, Love.Component.Internal.update_props_and_reactive(socket, new_assigns)}
      end

      defoverridable mount: 1, update: 2
    end
  end

  ##################################################
  # __on_definition__/6
  ##################################################

  # Capture the @react function attribute into a module attribute
  def __on_definition__(env, :def, name, _args, _guards, _body) do
    validate_not_defined!(env.module, :react, name)

    if react_attr = Module.get_attribute(env.module, :react) do
      update_attribute(env.module, :__reactive_fields__, fn map ->
        Map.put(map, name, react_meta(react_attr))
      end)
    end

    reset_function_attributes(env.module)
  end

  # Wipe out function attributes that are hanging around
  def __on_definition__(env, _kind, _name, _args, _guards, _body) do
    reset_function_attributes(env.module)
  end

  # Returns a map of metadata for a @react field
  defp react_meta(react_attr) do
    %{
      react_to: List.flatten([Keyword.get(react_attr, :to, [])])
    }
  end

  # Resets all function attributes that we care about, at the end of any __on_definition__
  defp reset_function_attributes(module) do
    Module.delete_attribute(module, :react)
  end

  ##################################################
  # __before_compile__/1
  ##################################################

  defmacro __before_compile__(env) do
    # Evaluate quoted opts and turn them into more useful structures
    eval_metas(env, :prop, :__prop_fields__)
    eval_metas(env, :state, :__state_fields__)
    eval_metas(env, :computed, :__computed_fields__)

    # Add the :triggers fields, so we know what to reevaluate when a field changes
    put_meta_triggers(env.module, :__prop_fields__)
    put_meta_triggers(env.module, :__state_fields__)

    # TODO: Check for cycles in reactive values

    meta_fn = Internal.meta_fn_name()

    meta_fns =
      quote do
        # Delay these definitions until as late as possible, so we can ensure the attributes
        # are fully set up (i.e. wait for __on_definition__/6 to evaluate first!)
        def unquote(meta_fn)(:reactive), do: @__reactive_fields__
        def unquote(meta_fn)(:prop), do: @__prop_fields__
        def unquote(meta_fn)(:state), do: @__state_fields__
        def unquote(meta_fn)(:computed), do: @__computed_fields__
      end

    [meta_fns, def_defaults(env.module)]
  end

  # Assigns :triggers to state and prop field metadata
  defp put_meta_triggers(module, attribute) do
    update_attribute(module, attribute, fn map ->
      Map.new(map, fn {source_key, source_meta} ->
        source_meta =
          Map.put(
            source_meta,
            :triggers,
            reactive_triggers_depending_on(module, source_key)
          )

        {source_key, source_meta}
      end)
    end)
  end

  # Returns a list of all reactive fields that must be reevaluated as a reuslt of this
  # source field (:prop or :state) changing
  defp reactive_triggers_depending_on(module, source_key) do
    module
    |> Module.get_attribute(:__reactive_fields__)
    |> Enum.filter(fn {_reactive_key, reactive_meta} ->
      source_key in reactive_meta.react_to
    end)
    |> Enum.map(fn {reactive_key, _reactive_meta} -> reactive_key end)
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
    validate_not_defined!(__CALLER__.module, :prop, key)

    update_attribute(__CALLER__.module, :__prop_fields__, fn props ->
      Map.put(props, key, quoted_opts)
    end)

    put_quoted_default(__CALLER__.module, key, quoted_opts[:default])

    nil
  end

  @doc """
  Defines a state field.

  The second arg is the initial value for this state field (defaults to `nil` if omitted).
  """
  defmacro state(key, quoted_opts \\ []) when is_atom(key) do
    validate_not_defined!(__CALLER__.module, :state, key)

    update_attribute(__CALLER__.module, :__state_fields__, fn state ->
      Map.put(state, key, quoted_opts)
    end)

    put_quoted_default(__CALLER__.module, key, quoted_opts[:default])

    nil
  end

  @doc """
  Defines a state field.

  The second arg is the initial value for this state field (defaults to `nil` if omitted).
  """
  defmacro computed(key, quoted_opts \\ []) when is_atom(key) do
    validate_not_defined!(__CALLER__.module, :computed, key)

    update_attribute(__CALLER__.module, :__computed_fields__, fn state ->
      Map.put(state, key, quoted_opts)
    end)

    nil
  end

  @doc """
  Defines an event prop.

  Events are always optional. The default implementation is an anonymous function with
  the specified arity that returns `:ok`.
  """
  defmacro event(quoted_defn) do
    # The strategy here is to just parse the quoted function head and then define
    # a plain old optional prop with a no-op default.
    {key, _, args} = quoted_defn
    validate_not_defined!(__CALLER__.module, :event, key)
    args = for {_arg, x, y} <- args, do: {:_, x, y}

    quote do
      prop unquote(key), default: fn unquote_splicing(args) -> :ok end
    end
  end

  defp put_quoted_default(module, key, quoted) do
    update_attribute(module, :__field_defaults__, fn defaults ->
      Map.put(defaults, key, quoted)
    end)
  end

  defp def_defaults(module) do
    for {key, quoted} <- Module.get_attribute(module, :__field_defaults__) do
      quote do
        def __default__(unquote(key)) do
          unquote(quoted)
        end
      end
    end
  end

  @doc """
  Puts many state changes into the component.

  This will also immediately reevaluate any necessary reactive fields, so
  call this as infrequently as possible (i.e. state changes should be batched).
  """
  def put_state(socket, changes) do
    Internal.put_state!(socket, changes)
  end

  @doc """
  Puts many computed values.
  """
  def put_computed(socket, changes) do
    Enum.reduce(changes, socket, fn {key, value}, socket_acc ->
      Internal.put_computed!(socket_acc, key, value)
    end)
  end

  @doc """
  Puts a computed value into the component.
  """
  def put_computed(socket, key, value) do
    Internal.put_computed!(socket, key, value)
  end

  # Little helper to update module attributes
  defp update_attribute(module, key, default \\ nil, updater) do
    new_value = updater.(Module.get_attribute(module, key, default))
    Module.put_attribute(module, key, new_value)
  end

  defp validate_not_defined!(module, type, key) do
    [
      computed: :__computed_fields__,
      prop: :__prop_fields__,
      react: :__reactive_fields__,
      state: :__state_fields__
    ]
    |> Enum.find(fn {_type, attr} ->
      key in (module |> Module.get_attribute(attr, []) |> Map.keys())
    end)
    |> case do
      {^type, _attr} ->
        raise CompileError, description: "#{type} #{inspect(key)} is already defined"

      {defined_type, _attr} ->
        raise CompileError,
          description:
            "#{inspect(key)} is already defined as #{friendly_name(defined_type)}, and can't be reused as #{friendly_name(type)}"

      nil ->
        nil
    end
  end

  defp friendly_name(:computed), do: "computed"
  defp friendly_name(:event), do: "event"
  defp friendly_name(:prop), do: "a prop"
  defp friendly_name(:react), do: "a reactive function"
  defp friendly_name(:state), do: "state"

  defp eval_metas(env, type, attr_name) do
    update_attribute(env.module, attr_name, fn attr ->
      Map.new(attr, fn {key, value} ->
        {key, eval_meta(value, type, env)}
      end)
    end)
  end

  # If this is a map, it's already been evaluated
  defp eval_meta(%{} = meta, _key, _env), do: meta

  # Returns metadata map for a prop field
  defp eval_meta(quoted_opts, :prop, env) do
    {opts, _} = Module.eval_quoted(env, quoted_opts)

    %{
      required?: not Keyword.has_key?(opts, :default)
    }
  end

  # Returns metadata map for a state field
  defp eval_meta(quoted_opts, :state, env) do
    {opts, _} = Module.eval_quoted(env, quoted_opts)

    %{
      initialize?: Keyword.has_key?(opts, :default)
    }
  end

  # Returns metadata map for a computed field
  defp eval_meta(_quoted_opts, :computed, _env) do
    %{}
  end
end
