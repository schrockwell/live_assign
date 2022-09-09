defmodule LiveAssign.ViewTest do
  use ExUnit.Case

  @endpoint LiveAssignTest.Endpoint

  import LiveAssign.TestModules
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  setup do
    start_supervised!(@endpoint)
    :ok
  end

  describe "LiveAssign.View" do
    test "works" do
      defview LiveAssignViewTest do
        state :name, default: "Rockwell"
        state :age
        state :double_age

        def mount(_, _, socket) do
          {:ok, put_state(socket, age: 34)}
        end

        def render(assigns) do
          ~H"""
          <div data-age={@age} data-name={@name} data-double-age={@double_age} />
          """
        end

        @react to: :age
        defp put_double_age(socket) do
          put_state(socket, double_age: socket.assigns.age * 2)
        end
      end

      {:ok, view, _html} = live_isolated(build_conn(), LiveAssignViewTest)

      assert view |> has_element?("[data-age=34]")
      assert view |> has_element?("[data-double-age=68]")
      assert view |> has_element?("[data-name=Rockwell]")
    end
  end
end
