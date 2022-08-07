defmodule Love do
  @type destination :: pid | {module, String.t() | atom}

  @spec send_message(destination :: destination(), key :: atom, payload :: any, opts :: keyword) ::
          :ok
  def send_message(destination, key, payload, opts \\ []) do
    message = %Love.Message{key: key, source: opts[:source], payload: payload}

    case destination do
      pid when is_pid(pid) ->
        send(pid, message)

      {module, id} when is_atom(module) ->
        Phoenix.LiveView.send_update(module, id: id, __message__: message)
    end

    :ok
  end
end
