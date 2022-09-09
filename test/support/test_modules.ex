defmodule LiveAssign.TestModules do
  defmodule BaseComponent do
    defmacro __using__(_) do
      quote do
        use Phoenix.LiveComponent
        use LiveAssign.LiveComponent

        def render(var!(assigns)), do: ~H"<div />"

        defoverridable render: 1
      end
    end
  end

  defmodule BaseView do
    defmacro __using__(_) do
      quote do
        use Phoenix.LiveView
        use LiveAssign.LiveView

        def render(var!(assigns)), do: ~H""

        defoverridable render: 1
      end
    end
  end

  defmacro defcomponent(name, do: quoted) do
    quote do
      defmodule unquote(name) do
        use BaseComponent

        unquote(quoted)
      end
    end
  end

  defmacro defview(name, do: quoted) do
    quote do
      defmodule unquote(name) do
        use BaseView

        unquote(quoted)
      end
    end
  end
end
