defmodule Love.TestModules do
  defmodule BaseLoveComponent do
    defmacro __using__(_) do
      quote do
        use Phoenix.LiveComponent
        use Love.Component

        def render(var!(assigns)), do: ~H"<div />"

        defoverridable render: 1
      end
    end
  end

  defmodule BaseLoveView do
    defmacro __using__(_) do
      quote do
        use Phoenix.LiveView
        use Love.View

        def render(var!(assigns)), do: ~H""

        defoverridable render: 1
      end
    end
  end

  defmacro defcomponent(name, do: quoted) do
    quote do
      defmodule unquote(name) do
        use BaseLoveComponent

        unquote(quoted)
      end
    end
  end

  defmacro defview(name, do: quoted) do
    quote do
      defmodule unquote(name) do
        use BaseLoveView

        unquote(quoted)
      end
    end
  end
end
