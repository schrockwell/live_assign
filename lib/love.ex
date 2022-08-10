defmodule Love do
  @moduledoc """

  Conventions for LiveView and LiveComponent.

  Here are the core concepts – many of which are shared across both LiveViews and LiveComponents.

  ## Props

  _Supported by `Love.Component`._

  Props are a one-way street: they are assigns that can only be passed _in_ to a component,
  and are not modified internally beyond that. Props can be required by the component,
  or made optional with a default value. Reactive functions can be triggered by prop changes.

  See `Love.Component.prop/2` for details.

  ## Slots

  _Supported by `Love.Component`._

  LiveComponent slots are represented as "slot props". They may be required or optional.

  See `Love.Component.slot/2` for details.

  ## State

  _Supported by `Love.View` and `Love.Component`._

  State is used to track internal LiveView and LiveComponent logic, and can be modified throughout
  their lifecycles. State can be initialized with default values. Reactive functions can be triggered
  by state changes.

  See `Love.Component.state/2` and `Love.View.state/2` for details.

  ## Reactive Functions

  _Supported by `Love.View` and `Love.Component`._

  Reactive functions are regular functions tagged with the `@react` attribute. They can be triggered
  by changes to props or state.

  Reactive functions are triggered immediately when new prop values are assigned to the component,
  or when `put_state/2` is called.

  See [the example below](#updating-state-via-reactive-functions) for usage.

  ## Event Messages

  _Supported by `Love.View` and `Love.Component`._

  Love unifies the sending and receiving of events between LiveView and LiveComponents with its
  `Love.Events` behaviour. Components can emit events to LiveViews or other LiveComponents using
  one standard callback in both module types: `c:Love.Events.handle_message/4`.

  When writing a component, you no longer have to decide _how_ its events are bubbled up
  to where they need to go. Just `Love.Component.emit/3` and go.

  Events can also be explicitly sent with `Love.Events.send_message/4`.

  See `Love.Component.event/1` and `Love.Events` for details.

  ## Configuration

  Love performs some validations at runtime to provide helpful error messages to developers. You may
  wish to disable these checks - for example, to improve performance in a production environment.
  That is possible with:

      config :love_ex, runtime_checks?: false

  ## Examples

  ### Updating state via reactive functions

      prop :first_name
      prop :last_name

      state :big_display_name
      state :display_name
      state :full_name?, default: false

      # Triggered when there are any changes to these props or state
      @react to: [:first_name, :last_name, :full_name?]
      def put_display_name(socket) do
        if socket.assigns.full_name? do
          put_state(socket, display_name: "\#{socket.assigns.first_name, socket.assigns.last_name}")
        else
          put_state(socket, display_name: socket.assigns.first_name)
        end
      end

      # Triggered after put_display_name/1 finishes
      @react to: :display_name
      def put_big_display_name(socket) do
        put_state(socket, big_display_name: String.upcase(socket.assigns.display_name))
      end
  """
end
