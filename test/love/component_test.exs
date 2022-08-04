defmodule Love.ComponentTest do
  use ExUnit.Case

  @endpoint LoveTest.Endpoint

  import LiveIsolatedComponent
  import Phoenix.LiveViewTest

  defmodule BaseComponent do
    defmacro __using__(_) do
      quote do
        use Phoenix.LiveComponent
        use Love.Component
        import Love.Component

        prop :id

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

  setup do
    start_supervised!(@endpoint)
    :ok
  end

  test "compiles" do
    defcomponent KitchenSink do
      prop :profile
      prop :avatar_visible?, default: false

      state :details_expanded?, default: false

      computed :age

      def handle_click("toggle-details", _, socket) do
        {:noreply, put_state(socket, details_expanded?: not socket.assigns.details_expanded?)}
      end

      @react to: :profile
      def compute_age(socket) do
        age = trunc(Date.diff(Date.utc_today(), socket.assigns.profile.birthday) / 365)
        put_computed(socket, age: age)
      end

      def render(assigns) do
        ~H"""
        <div id={@id}>
          <%= if @details_expanded? do %>
            <div id="details" />
          <% end %>
          <%= if @avatar_visible? do %>
            <div id="avatar" />
          <% end %>
          <div id="age"><%= @age %></div>
          <button phx-click="toggle-details" />
        </div>
        """
      end
    end
  end

  describe "props" do
    test "can't be defined with duplicate keys" do
      error =
        assert_raise(CompileError, fn ->
          defcomponent SamePropName do
            prop :foo
            prop :foo
          end
        end)

      assert error.description == "prop :foo is already defined"
    end

    test "can't be defined with the same name as another field" do
      error =
        assert_raise(CompileError, fn ->
          defcomponent SameFieldName do
            state :foo
            prop :foo
          end
        end)

      assert error.description ==
               ":foo is already defined as state, and can't be reused as a prop"
    end

    test "can define a default value" do
      defcomponent PropWithDefault do
        prop :foo, default: "bar"

        def render(assigns), do: ~H"<div data-foo><%= @foo %></div>"
      end

      {:ok, view, _html} = live_isolated_component(PropWithDefault, assigns: %{})

      assert has_element?(view, "[data-foo]", "bar")
    end

    test "passes prop values to assigns" do
      defcomponent PropToAssign do
        prop :foo

        def render(assigns), do: ~H"<div data-foo><%= @foo %></div>"
      end

      {:ok, view, _html} = live_isolated_component(PropToAssign, assigns: %{foo: "whoa"})

      assert has_element?(view, "[data-foo]", "whoa")
    end

    test "raises RuntimeError if a prop is required but not specified" do
      defcomponent RequiredProp do
        prop :foo
      end

      error =
        assert_raise(RuntimeError, fn ->
          live_isolated_component(RequiredProp, assigns: %{})
        end)

      assert error.message == "expected required prop :foo to be assigned"
    end
  end
end
