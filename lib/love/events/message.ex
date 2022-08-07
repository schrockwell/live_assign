defmodule Love.Events.Message do
  @moduledoc """
  Represents an event message.

  This is documented in the unlikely chance that the destination process or component needs to directly handle it.

  This struct should not be constructed directly by the developer - use `Love.Events.send_message/4`
  and `Love.Component.emit/3` instead.
  """

  @type t :: %__MODULE__{
          name: atom,
          payload: any,
          source: any
        }

  defstruct [:name, :payload, :source]
end
