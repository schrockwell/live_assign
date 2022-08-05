defmodule Love do
  @type destination :: pid | {module, String.t() | atom}

  @spec send_message(destination(), atom, any) :: :ok
  def send_message(destination, key, payload) do
    message = %Love.Message{key: key, payload: payload}

    case destination do
      pid when is_pid(pid) ->
        send(pid, message)

      {module, id} when is_atom(module) ->
        Phoenix.LiveView.send_update(module, id: id, __message__: message)
    end

    :ok
  end
end
