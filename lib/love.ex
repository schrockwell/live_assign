defmodule LiveAssign do
  @moduledoc """

  Conventions for the development of LiveViews and LiveComponents.

  See the [README](README.md) for another overview and some examples.

  Here are the core concepts – many of which are shared across both LiveViews and LiveComponents.

  ## Props

  _Supported by `LiveAssign.Component`._

  Props are a one-way street: they are assigns that can only be passed _in_ to a component,
  and are not modified internally beyond that. Props can be required by the component,
  or made optional with a default value. Reactive functions can be triggered by prop changes.

  See `LiveAssign.Component.prop/2` for details.

  ## Slots

  _Supported by `LiveAssign.Component`._

  LiveComponent slots are represented as "slot props". They may be required or optional.

  See `LiveAssign.Component.slot/2` for details.

  ## State

  _Supported by `LiveAssign.View` and `LiveAssign.Component`._

  State is used to track internal LiveView and LiveComponent logic, and can be modified throughout
  their lifecycles. State can be initialized with default values. Reactive functions can be triggered
  by state changes.

  See `LiveAssign.Component.state/2` and `LiveAssign.View.state/2` for details.

  ## Reactive Functions

  _Supported by `LiveAssign.View` and `LiveAssign.Component`._

  Reactive functions are regular functions tagged with the `@react` attribute. They can be triggered
  by changes to props or state.

  See `LiveAssign.React` for details.

  ## Configuration

  LiveAssign performs some validations at runtime to provide helpful error messages to developers. You may
  wish to disable these checks - for example, to improve performance in a production environment.
  That is possible with:

      config :live_assign, runtime_checks?: false
  """
end
