defmodule Love.Events do
  @moduledoc """
  Send and receive event messages between views and components.

  The `use Love.View` and `use Love.Component` macros automatically use this behaviour.
  """

  @doc """
  Handle an event message sent by `Love.Component.emit/3` or `send_message/4`.

  When sent from a component via `Love.Component.emit/3`, the `source` takes the form `{module, id}`.

  ## Example

      # Emitted from a component
      def handle_message(:on_selected, {MyComponent, _id}, %{profile_id: profile_id}, socket), do: ...

  """
  @callback handle_message(
              name :: atom,
              source :: any,
              payload :: any,
              socket :: LiveView.Socket.t()
            ) ::
              socket :: LiveView.Socket.t()

  @optional_callbacks handle_message: 4

  @type destination :: pid | {module, String.t() | atom}

  @doc """
  Sends an event message to a `Love.View` or a `Love.Component`.

  To send to a `Love.View` (or any other process), specify a `pid` (usually `self()`) as the `destination`.
  To send to a `Love.Component`, specify `{module, id}` as the `destination`.

  It can be handled by the `c:Love.Events.handle_message/4` callback.

  When sending to an arbitrary process, the message will be an `Love.Events.Message` struct.

  ## Options

  - `:source` - where the event originated from; defaults to `nil`

  ## Examples

      send_message(self(), :on_selected, %{profile_id: 123})
      # => def handle_message(:on_selected, _source, %{profile_id: id}, socket), do: ...

      send_message({MyComponent, "my-id"}, :on_selected, %{profile_id: 123})
      # => def handle_message(:on_selected, _source, %{profile_id: id}, socket), do: ...
  """
  @spec send_message(destination :: destination(), name :: atom, payload :: any, opts :: keyword) ::
          :ok
  def send_message(destination, name, payload, opts \\ []) do
    message = %Love.Events.Message{name: name, source: opts[:source], payload: payload}

    case destination do
      pid when is_pid(pid) ->
        send(pid, message)

      {module, id} when is_atom(module) ->
        Phoenix.LiveView.send_update(module, id: id, __message__: message)
    end

    :ok
  end
end
