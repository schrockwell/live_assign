defmodule Love.ViewTest do
  use ExUnit.Case

  @endpoint LoveTest.Endpoint

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  defmodule BaseView do
    defmacro __using__(_) do
      quote do
        use Phoenix.LiveView
        use Love.View

        def render(var!(assigns)), do: ~H""

        defoverridable render: 1
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

  setup do
    start_supervised!(@endpoint)
    :ok
  end

  describe "Love.Component" do
    test "works" do
      defview LoveViewTest do
        state :name, default: "Rockwell"
        state :age

        computed :double_age

        def mount(_, _, socket) do
          {:ok, put_state(socket, age: 34)}
        end

        def render(assigns) do
          ~H"""
          <div data-age={@age} data-name={@name} data-double-age={@double_age} />
          """
        end

        @react to: :age
        def compute_double_age(socket) do
          put_computed(socket, double_age: socket.assigns.age * 2)
        end
      end

      {:ok, view, _html} = live_isolated(build_conn(), LoveViewTest)

      assert view |> has_element?("[data-age=34]")
      assert view |> has_element?("[data-double-age=68]")
      assert view |> has_element?("[data-name=Rockwell]")
    end
  end
end
