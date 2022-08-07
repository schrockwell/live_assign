defmodule Love.Internal do
  @moduledoc false

  import Love.Config

  @meta_fn_name :__love_component_meta__
  @socket_private_key :love_component
  @attrs %{
    react: :__reactive_fields__,
    prop: :__prop_fields__,
    state: :__state_fields__,
    computed: :__computed_fields__,
    defaults: :__field_defaults__
  }

  ##################################################
  # COMPILE TIME - MODULE ATTRIBUTES
  ##################################################

  def init_module_attributes(env, types) do
    for type <- types do
      Module.put_attribute(env.module, @attrs[type], %{})
    end
  end

  # Little helper to update module attributes
  defp update_attribute(module, key, default \\ nil, updater) do
    new_value = updater.(Module.get_attribute(module, key, default))
    Module.put_attribute(module, key, new_value)
  end

  ##################################################
  # COMPILE TIME - __on_definition__/6
  ##################################################

  # Capture the @react function attribute into a module attribute
  def on_definition(env, :def, name, _args, _guards, _body) do
    ensure_not_already_defined!(env.module, :react, name)

    if react_attr = Module.get_attribute(env.module, :react) do
      update_attribute(env.module, @attrs.react, fn map ->
        Map.put(map, name, react_meta(react_attr))
      end)
    end

    reset_function_attributes(env.module)
  end

  # Wipe out function attributes that are hanging around
  def on_definition(env, _kind, _name, _args, _guards, _body) do
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
  # COMPILE-TIME - PUBLIC API
  ##################################################

  def define_prop(env, key, quoted_opts) when is_atom(key) do
    ensure_not_already_defined!(env.module, :prop, key)

    update_attribute(env.module, @attrs.prop, fn props ->
      Map.put(props, key, quoted_opts)
    end)

    put_quoted_default(env.module, key, quoted_opts[:default])

    nil
  end

  def define_state(env, key, quoted_opts) when is_atom(key) do
    ensure_not_already_defined!(env.module, :state, key)

    update_attribute(env.module, @attrs.state, fn state ->
      Map.put(state, key, quoted_opts)
    end)

    put_quoted_default(env.module, key, quoted_opts[:default])

    nil
  end

  def define_computed(env, key, quoted_opts) when is_atom(key) do
    ensure_not_already_defined!(env.module, :computed, key)

    update_attribute(env.module, @attrs.computed, fn state ->
      Map.put(state, key, quoted_opts)
    end)

    nil
  end

  defp put_quoted_default(module, key, quoted) do
    update_attribute(module, @attrs.defaults, fn defaults ->
      Map.put(defaults, key, quoted)
    end)
  end

  def define_defaults(module) do
    for {key, quoted} <- Module.get_attribute(module, @attrs.defaults) do
      quote do
        def __default__(unquote(key)) do
          unquote(quoted)
        end
      end
    end
  end

  defp ensure_not_already_defined!(module, type, key) do
    [:computed, :prop, :react, :state]
    |> Enum.find(fn type ->
      key in (module |> Module.get_attribute(@attrs[type], %{}) |> Map.keys())
    end)
    |> case do
      nil ->
        nil

      ^type ->
        raise CompileError, description: "#{type} #{inspect(key)} is already defined"

      defined_type ->
        raise CompileError,
          description:
            "#{inspect(key)} is already defined as #{friendly_name(defined_type)}, and can't be reused as #{friendly_name(type)}"
    end
  end

  defp friendly_name(:computed), do: "computed"
  defp friendly_name(:prop), do: "a prop"
  defp friendly_name(:react), do: "a reactive function"
  defp friendly_name(:state), do: "state"

  ##################################################
  # COMPILE-TIME - __before_compile__/1
  ##################################################

  # Assigns :triggers to state and prop field metadata
  def before_compile_put_meta_triggers(module, types) when is_list(types) do
    for type <- types, do: before_compile_put_meta_triggers(module, type)
  end

  def before_compile_put_meta_triggers(module, type) do
    update_attribute(module, @attrs[type], fn map ->
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
    |> Module.get_attribute(@attrs.react)
    |> Enum.filter(fn {_reactive_key, reactive_meta} ->
      source_key in reactive_meta.react_to
    end)
    |> Enum.map(fn {reactive_key, _reactive_meta} -> reactive_key end)
  end

  def before_compile_eval_metas(env, types) when is_list(types) do
    for type <- types, do: before_compile_eval_metas(env, type)
  end

  def before_compile_eval_metas(env, type) do
    update_attribute(env.module, @attrs[type], fn attr ->
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

  def before_compile_define_meta_fns(env, keys) do
    meta_fn = @meta_fn_name

    for key <- keys do
      attr_value = Module.get_attribute(env.module, @attrs[key])

      quote do
        def unquote(meta_fn)(unquote(key)), do: unquote(Macro.escape(attr_value))
      end
    end
  end

  ##################################################
  # RUNTIME - GET METADATA
  ##################################################

  ### Fetching module metadata

  # Returns metadata compiled into the socket module.
  defp get_meta(module_or_socket, key) when is_atom(module_or_socket) do
    apply(module_or_socket, @meta_fn_name, [key])
  end

  defp get_meta(module_or_socket, key) do
    module_or_socket |> live_view_module() |> get_meta(key)
  end

  ##################################################
  # RUNTIME - PRIVATE SOCKET VALUES
  ##################################################

  ### Manipulation of :private field in LiveView.Socket

  # Stores a library-specific private value on the LiveView.Socket.
  def put_private(socket, key, value) do
    new_lib_private =
      socket.private
      |> Map.get(@socket_private_key, %{})
      |> Map.put(key, value)

    new_private = Map.put(socket.private, @socket_private_key, new_lib_private)

    Map.put(socket, :private, new_private)
  end

  # Retrieves a library-specific private value from the LiveView.Socket.
  def get_private(socket, key, default \\ nil) do
    socket.private
    |> Map.get(@socket_private_key, %{})
    |> Map.get(key, default)
  end

  # Convenience function
  def update_private(socket, key, default \\ nil, fun) do
    put_private(socket, key, fun.(get_private(socket, key, default)))
  end

  # Returns the LiveView module name
  def live_view_module(socket) do
    get_private(socket, :module)
  end

  ##################################################
  # RUNTIME - UPDATING ASSIGNS
  ##################################################

  def put_state(socket, changes) do
    changes
    |> Enum.reduce(socket, fn {key, value}, socket_acc ->
      socket_acc
      |> ensure_can_put_state!()
      |> validate_assign_key!(:state, key)
      |> Phoenix.LiveView.assign(key, value)
    end)
    |> update_reactive()
  end

  def put_computed(socket, key, value) do
    socket
    |> validate_assign_key!(:computed, key)
    |> Phoenix.LiveView.assign(key, value)
  end

  ##################################################
  # RUNTIME - COMPONENT EVENTS
  ##################################################

  @doc """
  Emit a message.
  """
  def emit(socket, key, payload) do
    source = {live_view_module(socket), socket.assigns.id}

    case socket.assigns[key] do
      nil ->
        nil

      {pid, custom_key} when is_pid(pid) ->
        Love.send_message(pid, custom_key, payload, source: source)

      {module, id, custom_key} ->
        Love.send_message({module, id}, custom_key, payload, source: source)

      destination ->
        Love.send_message(destination, key, payload, source: source)
    end

    socket
  end

  ##################################################
  # RUNTIME - ASSIGN INITIALIZATION
  ##################################################

  # Returns a map of initial state fields based on their default values, to be
  # called during mount/1.
  def initial_state(socket) do
    socket
    |> get_meta(:state)
    |> Enum.filter(fn {_, meta} -> meta.initialize? end)
    |> Map.new(fn {key, _meta} ->
      {key, live_view_module(socket).__default__(key)}
    end)
  end

  # Returns a map of initial prop fields based on their default values, to be
  # called during mount/1.
  def initial_props(socket) do
    socket
    |> get_meta(:prop)
    |> Enum.reject(fn {_, meta} -> meta.required? end)
    |> Map.new(fn {key, _meta} ->
      {key, live_view_module(socket).__default__(key)}
    end)
  end

  if runtime_checks?() do
    defp ensure_assigns_present!(socket, type) do
      # Only run checks on initial update/2
      unless get_private(socket, :assigns_validated?) do
        socket
        |> get_meta(type)
        |> Enum.each(fn {key, _meta} ->
          if Map.has_key?(socket.assigns, key) do
            socket
          else
            raise "expected #{type} #{inspect(key)} to be assigned"
          end
        end)
      end

      socket
    end

    defp ensure_can_put_state!(socket) do
      unless get_private(socket, :in_transaction?, false) do
        socket
      else
        raise "put_state/2 is only permitted outside of @react functions"
      end
    end

    defp validate_assign_key!(socket, type, key) do
      if Map.has_key?(get_meta(socket, type), key) do
        socket
      else
        raise "attempted to set #{type} #{inspect(key)}, but is not defined; expected one of: #{inspect(Map.keys(get_meta(socket, type)))}"
      end
    end
  else
    defp ensure_can_put_state!(socket), do: socket
    defp validate_assign_key!(socket, _type, _key), do: socket
  end

  ##################################################
  # RUNTIME - REACTIVITIY
  ##################################################

  # Recomputes only the necessary fields, based on pending prop and state changes.
  defp update_reactive(socket) do
    triggers = list_all_triggers(socket)

    socket
    |> start_reactive_transaction()
    |> ensure_all_triggered(triggers)
    |> commit_reactive_transaction()
  end

  # Returns a flat list of all reactive functions that need to be reevaluated at this current
  # update cycle. This is based purely on which data sources (props and state) have changed
  defp list_all_triggers(socket) do
    for type <- [:prop, :state],
        {key, meta} <- get_meta(socket, type),
        true == Phoenix.LiveView.changed?(socket, key),
        reduce: MapSet.new() do
      acc -> MapSet.union(acc, MapSet.new(meta.triggers))
    end
    |> MapSet.to_list()
  end

  defp start_reactive_transaction(socket) do
    socket
    |> put_private(:in_transaction?, true)
    |> put_private(:triggered, %{})
  end

  defp commit_reactive_transaction(socket) do
    socket
    |> put_private(:in_transaction?, false)
    |> put_private(:triggered, %{})
  end

  ### Calling reactive triggers

  # Nothing to do if we don't depend on any other reactive functions. Returns the socket
  defp ensure_all_triggered(socket, [] = _reactive_keys), do: socket

  # Recursive function that is both the _entry point_ for kicking off reactivity, as well
  # as the _recursive_ solution for reactive functions that depend on each other.
  # Returns the socket
  defp ensure_all_triggered(socket, keys) do
    Enum.reduce(keys, socket, fn key, socket_acc ->
      ensure_triggered(socket_acc, key)
    end)
  end

  # Ensures that a single reactive function has been reevaluated, returning the socket
  defp ensure_triggered(socket, key) do
    if was_triggered?(socket, key) do
      # If we're done, we're done
      socket
    else
      module = live_view_module(socket)

      # Recursion alert! Ensure that all the reactive functions that we care about
      # are fully reevaluated before trying to evaluate this field
      reactive_meta = get_meta(module, :react)[key]

      new_socket =
        ensure_all_triggered(socket, filter_reactive_names(socket, reactive_meta.react_to))

      # Finally, we can actually evaluate the function and flag it as triggered
      module
      |> apply(key, [new_socket])
      |> flag_as_triggered(key)
    end
  end

  defp filter_reactive_names(socket, react_to) do
    reactive_meta = get_meta(socket, :react)

    Enum.filter(react_to, fn rt ->
      Map.has_key?(reactive_meta, rt)
    end)
  end

  defp was_triggered?(socket, key) do
    socket
    |> get_private(:triggered)
    |> Map.has_key?(key)
  end

  defp flag_as_triggered(socket, key) do
    update_private(socket, :triggered, fn triggered ->
      Map.put(triggered, key, true)
    end)
  end

  ##################################################
  # RUNTIME - LiveComponent.update/2
  ##################################################

  if runtime_checks?() do
    def on_component_update(socket, new_assigns) do
      socket
      |> merge_props(new_assigns)
      |> ensure_assigns_present!(:prop)
      |> update_reactive()
      |> put_private(:assigns_validated?, true)
    end
  else
    def on_component_update(socket, new_assigns) do
      socket
      |> merge_props(new_assigns)
      |> update_reactive()
    end
  end

  # Assigns props from update/2
  defp merge_props(socket, new_assigns) do
    Enum.reduce(new_assigns, socket, fn {key, value}, socket_acc ->
      socket_acc
      |> validate_assign_key!(:prop, key)
      |> Phoenix.LiveView.assign(key, value)
    end)
  end
end
