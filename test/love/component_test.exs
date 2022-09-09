defmodule Love.ComponentTest do
  use ExUnit.Case

  @endpoint LoveTest.Endpoint

  import LiveIsolatedComponent
  import Love.TestModules
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  setup do
    start_supervised!(@endpoint)
    :ok
  end

  test "compiles" do
    defcomponent KitchenSink do
      prop :profile
      prop :avatar_visible?, default: false

      slot :inner_block
      slot :whatever, required?: false

      state :age
      state :details_expanded?, default: false

      def handle_click("toggle-details", _, socket) do
        {:noreply, put_state(socket, details_expanded?: not socket.assigns.details_expanded?)}
      end

      @react to: :profile
      defp put_age(socket) do
        age = trunc(Date.diff(Date.utc_today(), socket.assigns.profile.birthday) / 365)
        put_state(socket, age: age)
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

    test "pass values to assigns" do
      defcomponent PropToAssign do
        prop :foo

        def render(assigns), do: ~H"<div data-foo><%= @foo %></div>"
      end

      {:ok, view, _html} = live_isolated_component(PropToAssign, assigns: %{foo: "whoa"})

      assert has_element?(view, "[data-foo]", "whoa")
    end

    test "raise RuntimeError if required but not specified" do
      defcomponent RequiredProp do
        prop :foo
      end

      error =
        assert_raise(RuntimeError, fn ->
          live_isolated_component(RequiredProp, assigns: %{})
        end)

      assert error.message == "expected prop :foo to be assigned"
    end
  end

  describe "slots" do
    test "work" do
      defcomponent SlotProp do
        slot :inner_block
        slot :name

        def render(assigns) do
          ~H"""
          <div>
            <div id="inner_block"><%= render_slot @inner_block %></div>
            <div id="name"><%= render_slot @name %></div>
          </div>
          """
        end
      end

      defmodule SlotPropLive do
        use Phoenix.LiveView

        def render(assigns) do
          ~H"""
          <.live_component module={SlotProp} id="slot-prop">
            So long, and thanks for all the fish.
            <:name>Zaphod</:name>
          </.live_component>
          """
        end
      end

      {:ok, view, _html} = live_isolated(build_conn(), SlotPropLive)

      assert view |> has_element?("#inner_block", "So long, and thanks for all the fish.")
      assert view |> has_element?("#name", "Zaphod")
    end
  end

  describe "state" do
    test "can be defined with a default value" do
      defcomponent(DetaultStateTest) do
        state :the_answer, default: 42

        def render(assigns), do: ~H"<div data-value={@the_answer} />"
      end

      {:ok, view, _html} = live_isolated_component(DetaultStateTest, assigns: %{})

      assert view |> has_element?("[data-value=42]")
    end

    test "can be initialized during mount" do
      defcomponent StateMountTest do
        state :the_answer

        def mount(socket) do
          {:ok, put_state(socket, the_answer: 42)}
        end

        def render(assigns), do: ~H"<div data-value={@the_answer} />"
      end

      {:ok, view, _html} = live_isolated_component(StateMountTest, assigns: %{})

      assert view |> has_element?("[data-value=42]")
    end

    test "can't be set with an undefined key" do
      defcomponent StateKeyTest do
        state :the_answer, default: 42

        def mount(socket) do
          {:ok,
           put_state(socket, the_question: "How many angels can dance on the head of a pin?")}
        end
      end

      error =
        assert_raise(RuntimeError, fn ->
          live_isolated_component(StateKeyTest, assigns: %{})
        end)

      assert error.message ==
               "attempted to set state :the_question, but is not defined; expected one of: [:the_answer]"
    end

    test "works" do
      defcomponent StateTest do
        state :improbability
        state :the_answer, default: 42

        def mount(socket) do
          {:ok, put_state(socket, improbability: 9000)}
        end

        def handle_event("inc", _, socket) do
          {:noreply, put_state(socket, improbability: socket.assigns.improbability + 1)}
        end

        def render(assigns) do
          ~H"""
          <div>
            <div id="improbability" data-value={@improbability} />
            <div id="the_answer" data-value={@the_answer} />
            <button phx-click="inc" phx-target={@myself} />
          </div>
          """
        end
      end

      {:ok, view, _html} = live_isolated_component(StateTest, assigns: %{})

      assert view |> has_element?("#improbability[data-value=9000]")
      assert view |> has_element?("#the_answer[data-value=42]")

      view |> element("button") |> render_click()

      assert view |> has_element?("#improbability[data-value=9001]")
      assert view |> has_element?("#the_answer[data-value=42]")
    end
  end

  describe "reactive functions" do
    test "can chain state changes" do
      defcomponent ChainedStateTest do
        state :thing_a, default: :a
        state :thing_b
        state :thing_c

        def mount(socket) do
          {:ok, socket}
        end

        def handle_event("click", _, socket) do
          {:noreply, put_state(socket, thing_a: :a)}
        end

        @react to: :thing_a
        defp put_thing_b(socket) do
          put_state(socket, thing_b: :b)
        end

        @react to: :thing_b
        defp put_thing_c(socket) do
          put_state(socket, thing_c: :c)
        end

        def render(assigns) do
          ~H"""
          <div>
            <div data-thing-a={@thing_a} />
            <div data-thing-b={@thing_b} />
            <div data-thing-c={@thing_c} />
            <button phx-click="click" phx-target={@myself} />
          </div>
          """
        end
      end

      {:ok, view, _html} = live_isolated_component(ChainedStateTest, assigns: %{})

      assert view |> has_element?("[data-thing-a=a]")
      assert view |> has_element?("[data-thing-b=b]")
      assert view |> has_element?("[data-thing-c=c]")
    end

    test "detct an infinite update loop" do
      defcomponent InfiniteUpdateLoopTest do
        state :thing_a, default: :a
        state :thing_b

        def handle_event("click", _, socket) do
          {:noreply, put_state(socket, thing_a: :a)}
        end

        @react to: :thing_a
        defp put_thing_b(socket) do
          put_state(socket, thing_b: :b)
        end

        @react to: :thing_b
        defp put_thing_a(socket) do
          put_state(socket, thing_a: :a)
        end
      end

      error =
        assert_raise RuntimeError, fn ->
          live_isolated_component(InfiniteUpdateLoopTest, assigns: %{})
        end

      assert error.message ==
               "reactive function put_thing_a/1 was triggered multiple times within a single update cycle, indicating a possible infinite loop. Disable this protection with `@react to: [:thing_b], repeats?: true`"
    end

    test "can be triggered multiple times" do
      defcomponent ManyTriggersTest do
        state :counter, default: 0
        state :tens_counter

        def handle_event("click", _, socket) do
          {:noreply, put_state(socket, counter: socket.assigns.counter + 1)}
        end

        @react to: :counter
        defp put_tens_counter(socket) do
          put_state(socket, tens_counter: socket.assigns.counter * 10)
        end

        def render(assigns) do
          ~H"""
          <div>
            <div data-counter={@counter} />
            <div data-tens-counter={@tens_counter} />
            <button phx-click="click" phx-target={@myself} />
          </div>
          """
        end
      end

      {:ok, view, _html} = live_isolated_component(ManyTriggersTest, assigns: %{})

      assert view |> has_element?("[data-counter=0]")
      assert view |> has_element?("[data-tens-counter=0]")

      view |> element("button") |> render_click()

      assert view |> has_element?("[data-counter=1]")
      assert view |> has_element?("[data-tens-counter=10]")

      view |> element("button") |> render_click()

      assert view |> has_element?("[data-counter=2]")
      assert view |> has_element?("[data-tens-counter=20]")
    end

    test "can disable infinite update loop detection" do
      defcomponent DisableInfiniteLoopCheckTest do
        state :counter, default: 10

        @react to: :counter, repeats?: true
        defp decrement(socket) do
          if socket.assigns.counter > 0 do
            put_state(socket, counter: socket.assigns.counter - 1)
          else
            socket
          end
        end

        def render(assigns), do: ~H[<div data-counter={@counter} />]
      end

      {:ok, view, _html} = live_isolated_component(DisableInfiniteLoopCheckTest, assigns: %{})

      assert view |> has_element?("[data-counter=0]")
    end
  end
end
