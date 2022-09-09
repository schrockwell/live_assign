defmodule LiveAssign.React do
  @moduledoc """
  Define reactive functions.

  A reactive function is tagged with the `@react` attribute and has an arity of 1, accepting the
  `%LiveView.Socket{}` as its argument, and returning the modified socket.

      @react to: [:some_prop, :some_state]
      defp put_changes(socket) do
        # ...
      end

  Reactive functions can subscribe to changes in state assigns or, in Live Compoents, prop assigns.

  ## Options for `@react`

  - `:to` - required; an atom, or list of atoms, specifying the state and prop fields to subscribe to
  - `:repeats?` - optional, defaults to `false`; when `true`, disables infinite loop detection

  ## Infinite Loop Detection

  If a reactive function is executed multiple times during a single update cycle, this
  indicates a possible infinite loop of reactive callbacks, and a `RuntimeError` will be raised.
  This check can be bypassed with the `repeats?: true` option on the `@react` attribute.

  ## Example

      defmodule MyComponent do
        use Phoenix.LiveComponent
        use LiveAssign.LiveComponent

        prop :first_name
        prop :last_name

        state :big_display_name
        state :display_name
        state :full_name?, default: false

        # Triggered when there are any changes to these props or state
        @react to: [:first_name, :last_name, :full_name?]
        defp put_display_name(socket) do
          if socket.assigns.full_name? do
            put_state(socket, display_name: "\#{socket.assigns.first_name, socket.assigns.last_name}")
          else
            put_state(socket, display_name: socket.assigns.first_name)
          end
        end

        # Triggered after put_display_name/1 finishes
        @react to: :display_name
        defp put_big_display_name(socket) do
          put_state(socket, big_display_name: String.upcase(socket.assigns.display_name))
        end
      end
  """
  alias LiveAssign.Internal

  defmacro __using__(_opts) do
    quote do
      @on_definition {LiveAssign.Internal, :on_definition}
      @before_compile LiveAssign.React
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
