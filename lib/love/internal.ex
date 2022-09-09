defmodule Love.Internal do
  @moduledoc false

  import Love.Config

  alias Phoenix.LiveView

  @meta_fn_name :__love_component_meta__
  @react_fn_name :__love_component_react__
  @socket_private_key :love_component
  @attrs %{
    react: :__reactive_fields__,
    prop: :__prop_fields__,
    state: :__state_fields__,
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
  def on_definition(env, type, name, _args, _guards, _body) when type in [:def, :defp] do
    if react_attr = Module.get_attribute(env.module, :react) do
      ensure_not_already_defined!(env.module, :react, name)

      react_meta = %{
        react_to: List.flatten([Keyword.get(react_attr, :to, [])]),
        repeats?: Keyword.get(react_attr, :repeats?, false)
      }

      update_attribute(env.module, @attrs.react, fn map ->
        Map.put(map, name, react_meta)
      end)
    end

    reset_function_attributes(env.module)
  end

  # Wipe out function attributes that are hanging around
  def on_definition(env, _kind, _name, _args, _guards, _body) do
    reset_function_attributes(env.module)
  end

  # Expose @react functions as `__react__(key, socket)` so that they
  # are public to us, even if they are defined as private
  def before_compile_define_react_wrappers(env) do
    react_fn = @react_fn_name

    for {key, _} <- Module.get_attribute(env.module, @attrs.react) do
      quote do
        def unquote(react_fn)(unquote(key), var!(socket)) do
          unquote(key)(var!(socket))
        end
      end
    end
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

  defp put_quoted_default(module, key, quoted_default) do
    update_attribute(module, @attrs.defaults, fn defaults ->
      Map.put(defaults, key, quoted_default)
    end)
  end

  def define_defaults(module) do
    for {key, quoted_default} <- Module.get_attribute(module, @attrs.defaults) do
      quote do
        def __default__(unquote(key)) do
          unquote(quoted_default)
        end
      end
    end
  end

  defp ensure_not_already_defined!(module, type, key) do
    [:prop, :react, :state]
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
  defp eval_meta(quoted_opts, :prop, _env) do
    %{
      required?: not Keyword.has_key?(quoted_opts, :default)
    }
  end

  # Returns metadata map for a state field
  defp eval_meta(quoted_opts, :state, _env) do
    %{
      initialize?: Keyword.has_key?(quoted_opts, :default)
    }
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
    changes = Enum.into(changes, %{})

    if get_private(socket, :inner_transaction?, false) do
      socket
      |> assign_state(changes)
      |> update_private(:pending_state_changes, &Map.merge(&1, changes))
    else
      assign_state_and_react(socket, changes)
    end
  end

  defp assign_state(socket, assigns) do
    Enum.reduce(assigns, socket, fn {key, value}, socket_acc ->
      socket_acc
      |> validate_assign_key!(:state, key)
      |> LiveView.assign(key, value)
    end)
  end

  defp assign_state_and_react(socket, changes, opts \\ [])

  defp assign_state_and_react(socket, changes, _opts) when changes == %{}, do: socket

  defp assign_state_and_react(socket, changes, opts) do
    socket
    |> assign_state(changes)
    |> update_reactive(Map.keys(changes), opts)
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

    defp validate_assign_key!(socket, type, key) do
      if Map.has_key?(get_meta(socket, type), key) do
        socket
      else
        raise "attempted to set #{type} #{inspect(key)}, but is not defined; expected one of: #{inspect(Map.keys(get_meta(socket, type)))}"
      end
    end
  else
    defp validate_assign_key!(socket, _type, _key), do: socket
  end

  ##################################################
  # RUNTIME - REACTIVITIY
  ##################################################

  # Recomputes only the necessary fields, based on pending prop and state changes.
  defp update_reactive(socket, keys_changed, opts \\ []) do
    reacts = list_all_reacts_triggered_by(socket, keys_changed)
    check_for_loops? = Keyword.get(opts, :check_for_loops?, false)

    socket
    |> check_for_loops!(check_for_loops?, reacts)
    |> start_reactive_transaction()
    |> ensure_all_triggered(reacts)
    |> commit_reactive_transaction()
  end

  # Returns a flat list of all reactive functions that need to be reevaluated at this current
  # update cycle. This is based purely on which data sources (props and state) have changed
  defp list_all_reacts_triggered_by(socket, keys) do
    for type <- [:prop, :state],
        {key, meta} <- get_meta(socket, type),
        key in keys,
        reduce: MapSet.new() do
      acc -> MapSet.union(acc, MapSet.new(meta.triggers))
    end
  end

  if runtime_checks?() do
    defp check_for_loops!(socket, true, reacts) do
      reacts_triggered = get_private(socket, :reacts_triggered)

      for react <- reacts do
        meta = get_meta(socket, :react)[react]

        if not meta.repeats? and MapSet.member?(reacts_triggered, react) do
          raise """
          reactive function #{react}/1 was triggered multiple times within a single update cycle, \
          indicating a possible infinite loop. Disable this protection with \
          `@react to: #{inspect(meta.react_to)}, repeats?: true`\
          """
        end
      end

      put_private(socket, :reacts_triggered, MapSet.union(reacts_triggered, MapSet.new(reacts)))
    end

    # Reset back to zero on intiial put_state/2
    defp check_for_loops!(socket, false, _reacts) do
      put_private(socket, :reacts_triggered, MapSet.new())
    end
  else
    defp check_for_loops!(socket, _enable, _reacts), do: socket
  end

  defp start_reactive_transaction(socket) do
    socket
    |> put_private(:inner_transaction?, true)
    |> put_private(:inner_triggered, %{})
    |> put_private(:pending_state_changes, %{})
  end

  defp commit_reactive_transaction(socket) do
    socket
    |> put_private(:inner_transaction?, false)
    |> put_private(:inner_triggered, %{})
    |> assign_state_and_react(get_private(socket, :pending_state_changes), check_for_loops?: true)
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

      # Now we can actually evaluate the function and flag it as triggered
      module
      |> apply(@react_fn_name, [key, socket])
      |> flag_as_triggered(key)
    end
  end

  defp was_triggered?(socket, key) do
    socket
    |> get_private(:inner_triggered)
    |> Map.has_key?(key)
  end

  defp flag_as_triggered(socket, key) do
    update_private(socket, :inner_triggered, fn triggered ->
      Map.put(triggered, key, true)
    end)
  end

  ##################################################
  # RUNTIME - LiveComponent.mount/1
  ##################################################

  def component_mount_hook(socket, module) do
    socket =
      socket
      |> put_private(:module, module)
      |> put_private(:assigns_validated?, false)

    initial_assigns = Map.merge(initial_props(socket), initial_state(socket))

    socket
    |> LiveView.assign(initial_assigns)
    |> update_reactive(Map.keys(initial_assigns))
  end

  ##################################################
  # RUNTIME - LiveComponent.update/2
  ##################################################

  if runtime_checks?() do
    def component_update_hook(socket, new_assigns) do
      socket
      |> merge_props(new_assigns)
      |> ensure_assigns_present!(:prop)
      |> update_reactive(Map.keys(new_assigns))
      |> put_private(:assigns_validated?, true)
    end
  else
    def component_update_hook(socket, new_assigns) do
      socket
      |> merge_props(new_assigns)
      |> update_reactive(Map.keys(new_assigns))
    end
  end

  # Assigns props from update/2
  defp merge_props(socket, new_assigns) do
    Enum.reduce(new_assigns, socket, fn {key, value}, socket_acc ->
      socket_acc
      |> validate_assign_key!(:prop, key)
      |> LiveView.assign(key, value)
    end)
  end
end
