defmodule Love.Config do
  defmacro runtime_checks? do
    quote do
      Application.compile_env(:love_ex, :runtime_checks?, true)
    end
  end
end
