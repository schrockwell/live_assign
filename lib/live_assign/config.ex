defmodule LiveAssign.Config do
  @moduledoc false

  defmacro runtime_checks? do
    quote do
      Application.compile_env(:live_assign, :runtime_checks?, true)
    end
  end
end
