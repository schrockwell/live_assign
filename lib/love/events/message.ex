defmodule Love.Events.Message do
  @moduledoc """
  TODO
  """

  @type t :: %__MODULE__{
          name: atom,
          payload: any,
          source: any
        }

  @doc "TODO?"
  defstruct [:name, :payload, :source]
end
