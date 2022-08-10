defmodule Love.React do
  @moduledoc """
  Define reactive functions.

  TODO: Add docs for @react
  """
  alias Love.Internal

  defmacro __using__(_opts) do
    quote do
      @on_definition {Love.Internal, :on_definition}
      @before_compile Love.React
    end
  end

  defmacro __before_compile__(env) do
    # Delay these function definitions until as late as possible, so we can ensure the attributes
    # are fully set up (i.e. wait for __on_definition__/6 to evaluate first!)
    [
      Internal.before_compile_define_meta_fns(env, [:react]),
      Internal.before_compile_define_react_wrappers(env)
    ]
  end
end
