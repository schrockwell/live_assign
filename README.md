# LiveAssign

![Test Status](https://github.com/schrockwell/live_assign/actions/workflows/elixir.yml/badge.svg)
[![Module Version](https://img.shields.io/hexpm/v/live_assign.svg)](https://hex.pm/packages/live_assign)
[![Hex Docs](https://img.shields.io/badge/hex-docs-purple.svg)](https://hexdocs.pm/live_assign/)
[![License](https://img.shields.io/hexpm/l/live_assign.svg)](https://github.com/schrockwell/live_assign/blob/master/LICENSE)

LiveAssign improves state management by sprinkling functionality on top of Phoenix LiveView.

It doesn't _replace_ the LiveView way of doing things, but instead _augments_ it with conventions. LiveAssign can be added to any view or component without affecting existing functionality, and its features can be opted-in as they are needed.

Combine it with [LiveEvent](https://hexdocs.pm/live_event/) for an altogether improved component-building experience.

LiveViews and LiveComponents both gain:

- **State** assigns which are defined in the module
- **Reactive functions** that are automatically invoked upon state changes
- **Runtime checks** with developer-friendly error messages

LiveComponents also gain additional functionality:

- **Props** which are assigns that are strictly passed in to the component
- **Slot** props to represent component slots
- **Event** props that integrate with [LiveEvent](https://hexdocs.pm/live_event/)

Here are a couple examples showing off these features. For complete details, please reference [the docs](https://hexdocs.pm/live_assign/).

## LiveComponent Example

```elixir
defmodule MyAppWeb.UserProfileComponent do
  use Phoenix.LiveComponent
  use LiveAssign.LiveComponent

  prop :profile
  prop :show_avatar?, default: false

  state :age
  state :expand_details?, default: false

  slot :inner_block

  def handle_event("toggle-details", _, socket) do
    {:noreply, put_state(socket, expand_details?: not socket.assigns.expand_details?)}
  end

  @react to: :profile
  defp put_age(socket) do
    age = trunc(Date.diff(Date.utc_today(), socket.assigns.profile.birthday) / 365)
    put_state(socket, age: age)
  end

  # ...
end
```

The `:profile` assign is a **required prop**. If it is not passed in, a helpful runtime error will occur.

The `:id` assign is also a required prop, but it is implicitly defined by `use LiveAssign.LiveComponent`, because every LiveComponent requires an `:id`.

The `:show_avatar?` assign is an **optional prop** that defaults to `false` when unspecified.

The `:expand_details?` and `:age` assigns are **state**. They can be modified via `put_state/2`.

The `:inner_block` assign is a **slot prop**. It is required but can be made optional with the `required?: false` option.

The `put_age/1` function is a **reactive callback**. It is automatically evaluated whenever the value of the `:profiles` state changes. The function can react to prop changes and state changes.

## LiveView Example

```elixir
defmodule MyAppWeb.ProfileIndexLive do
  use Phoenix.LiveView
  use LiveAssign.LiveView

  state :profiles, default: load_profiles()
  state :profile_count

  @react to: :profiles
  defp put_profile_count(socket) do
    put_state(socket, profile_count: length(socket.assigns.profiles))
  end

  defp load_profiles, do: # ...

  # ...
end
```

The `:profiles` and `:profile_count` assigns are **state**. They can be modified throughout the LiveView lifecycle, and reactive functions can respond to their changes.

The `put_profile_count/1` callback is a **reactive function** that is automatically invoked as soon as any changes occur to the `:profiles` state.

## Installation

The package can be installed by adding `live_assign` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:live_assign, "~> 0.3.0"}
  ]
end
```
