defmodule Love.Component.Internal do
  @moduledoc false

  @socket_private_key :love_component
  @meta_fn_name :__love_component_meta__

  import Phoenix.LiveView

  ##################################################
  # PUBLIC (INTERNALLY TO THE LIBRARY)
  ##################################################

  @doc """
  Called from the LiveComponent.mount/1 callback.
  """
  def init(socket, module) do
    socket =
      socket
      |> put_private(:module, module)
      |> put_private(:assigns_validated?, false)

    socket
    |> assign(initial_props(socket))
    |> assign(initial_state(socket))
  end

  @doc """
  Called from the LiveComponent.update/2 callback.
  """
  def update_props_and_reactive(socket, %{__message__: %Love.Message{} = message}) do
    case live_view_module(socket).handle_message(message.key, message.payload, socket) do
      {:ok, socket} ->
        socket

      _else ->
        raise "expected handle_message/3 callback to return {:ok, socket}"
    end
  end

  def update_props_and_reactive(socket, new_assigns) do
    socket
    |> merge_props(new_assigns)
    |> ensure_assigns_present!(:prop)
    |> update_reactive()
    |> ensure_assigns_present!(:state)
    |> ensure_assigns_present!(:computed)
    |> put_private(:assigns_validated?, true)
  end

  @doc """
  Returns the name of the injected function for reading library metadata.
  """
  def meta_fn_name, do: @meta_fn_name

  @doc """
  Assigns props from update/2
  """
  def merge_props(socket, new_assigns) do
    Enum.reduce(new_assigns, socket, fn {key, value}, socket_acc ->
      put_prop!(socket_acc, key, value)
    end)
  end

  @doc """
  Recomputes only the necessary fields, based on pending prop and state changes.
  """
  def update_reactive(socket) do
    triggers = list_all_triggers(socket)

    socket
    |> start_reactive_transaction()
    |> ensure_all_triggered(triggers)
    |> commit_reactive_transaction()
  end

  def ensure_can_put_computed!(socket) do
    if can_put_computed?(socket) do
      socket
    else
      raise "put_computed/3 is only permitted in reactive functions"
    end
  end

  def ensure_can_put_state!(socket) do
    if can_put_state?(socket) do
      socket
    else
      raise "put_state/2 is only permitted outside of reactive functions"
    end
  end

  def put_state!(socket, changes) do
    changes
    |> Enum.reduce(socket, fn {key, value}, socket_acc ->
      put_state!(socket_acc, key, value)
    end)
    |> update_reactive()
  end

  def put_state!(socket, key, value) do
    socket
    |> ensure_can_put_state!()
    |> validate_assign_key!(:state, key)
    |> assign(key, value)
  end

  def put_computed!(socket, key, value) do
    socket
    |> ensure_can_put_computed!()
    |> validate_assign_key!(:computed, key)
    |> assign(key, value)
  end

  defp put_prop!(socket, key, value) do
    socket
    |> validate_assign_key!(:prop, key)
    |> assign(key, value)
  end

  @doc """
  Emit a message.
  """
  def emit(socket, key, payload) do
    case socket.assigns[key] do
      nil ->
        nil

      {pid, custom_key} when is_pid(pid) ->
        Love.send_message(pid, custom_key, payload)

      {module, id, custom_key} ->
        Love.send_message({module, id}, custom_key, payload)

      destination ->
        Love.send_message(destination, key, payload)
    end

    socket
  end

  ##################################################
  # PRIVATE
  ##################################################

  ### Manipulation of :private field in LiveView.Socket

  # Stores a library-specific private value on the LiveView.Socket.
  defp put_private(socket, key, value) do
    new_lib_private =
      socket.private
      |> Map.get(@socket_private_key, %{})
      |> Map.put(key, value)

    new_private = Map.put(socket.private, @socket_private_key, new_lib_private)

    Map.put(socket, :private, new_private)
  end

  # Retrieves a library-specific private value from the LiveView.Socket.
  defp get_private(socket, key, default \\ nil) do
    socket.private
    |> Map.get(@socket_private_key, %{})
    |> Map.get(key, default)
  end

  # Convenience function
  defp update_private(socket, key, default \\ nil, fun) do
    put_private(socket, key, fun.(get_private(socket, key, default)))
  end

  # Returns the LiveView module name
  defp live_view_module(socket) do
    get_private(socket, :module)
  end

  ### Initialization of assigns

  # Returns a map of initial state fields based on their default values, to be
  # called during mount/1.
  defp initial_state(socket) do
    socket
    |> get_meta(:state)
    |> Enum.filter(fn {_, meta} -> meta.initialize? end)
    |> Map.new(fn {key, _meta} ->
      {key, live_view_module(socket).__default__(key)}
    end)
  end

  # Returns a map of initial prop fields based on their default values, to be
  # called during mount/1.
  defp initial_props(socket) do
    socket
    |> get_meta(:prop)
    |> Enum.reject(fn {_, meta} -> meta.required? end)
    |> Map.new(fn {key, _meta} ->
      {key, live_view_module(socket).__default__(key)}
    end)
  end

  ### Runtime checks on prop, state, and computed fields

  defp ensure_assigns_present!(socket, type) do
    # Only run checks on initial update/2
    unless get_private(socket, :assigns_validated?) do
      socket
      |> get_meta(type)
      |> Enum.each(fn {key, _meta} ->
        ensure_assign_present!(socket, type, key)
      end)
    end

    socket
  end

  # Ensures that a required prop has been assigned.
  defp ensure_assign_present!(socket, :prop, key) do
    if Map.has_key?(socket.assigns, key) do
      socket
    else
      raise "expected required prop #{inspect(key)} to be assigned"
    end
  end

  defp ensure_assign_present!(socket, :state, key) do
    if Map.has_key?(socket.assigns, key) do
      socket
    else
      raise "expected state #{inspect(key)} to be assigned"
    end

    socket
  end

  defp ensure_assign_present!(socket, :computed, key) do
    if Map.has_key?(socket.assigns, key) do
      socket
    else
      raise "expected computed key #{inspect(key)} to be assigned"
    end
  end

  defp validate_assign_key!(socket, type, key) do
    if Map.has_key?(get_meta(socket, type), key) do
      socket
    else
      raise "attempted to set #{type} #{inspect(key)}, but is not defined; expected one of: #{inspect(Map.keys(get_meta(socket, type)))}"
    end
  end

  ### Fetching module metadata

  # Returns metadata compiled into the socket module.
  defp get_meta(module_or_socket, key) when is_atom(module_or_socket) do
    apply(module_or_socket, @meta_fn_name, [key])
  end

  defp get_meta(module_or_socket, key) do
    module_or_socket |> live_view_module() |> get_meta(key)
  end

  ### Enumerating reactive functions to trigger

  # Returns a flat list of all reactive functions that need to be reevaluated at this current
  # update cycle. This is based purely on which data sources (props and state) have changed
  defp list_all_triggers(socket) do
    for type <- [:prop, :state],
        {key, meta} <- get_meta(socket, type),
        true == changed?(socket, key),
        reduce: MapSet.new() do
      acc -> MapSet.union(acc, MapSet.new(meta.triggers))
    end
    |> MapSet.to_list()
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
      reactive_meta = get_meta(module, :reactive)[key]

      new_socket =
        ensure_all_triggered(socket, filter_reactive_names(socket, reactive_meta.react_to))

      # Finally, we can actually evaluate the function and flag it as triggered
      module
      |> apply(key, [new_socket])
      |> flag_triggered(key)
    end
  end

  defp filter_reactive_names(socket, react_to) do
    reactive_meta = get_meta(socket, :reactive)

    Enum.filter(react_to, fn rt ->
      Map.has_key?(reactive_meta, rt)
    end)
  end

  defp was_triggered?(socket, key) do
    socket
    |> get_private(:triggered)
    |> Map.has_key?(key)
  end

  defp flag_triggered(socket, key) do
    update_private(socket, :triggered, fn triggered ->
      Map.put(triggered, key, true)
    end)
  end

  ### Reactive lifecycle

  defp can_put_computed?(_socket) do
    # Disabling this check for now... I think it is okay if we allow put_computed anywhere,
    # since nothing reacts to computed changes
    # get_private(socket, :in_transaction?, false)
    true
  end

  defp can_put_state?(socket) do
    not get_private(socket, :in_transaction?, false)
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
end
