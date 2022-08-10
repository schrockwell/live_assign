# Love.View and Love.Component

![Test Status](https://github.com/schrockwell/love_ex/actions/workflows/elixir.yml/badge.svg)
[![Module Version](https://img.shields.io/hexpm/v/love_ex.svg)](https://hex.pm/packages/love_ex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-purple.svg)](https://hexdocs.pm/love_ex/)
[![License](https://img.shields.io/hexpm/l/love_ex.svg)](https://github.com/schrockwell/love_ex/blob/master/LICENSE)

Love provides a sprinkle of functionality on top of Phoenix LiveView to improve developer ergonomics.

It doesn't _replace_ the LiveView way of doing things, but instead _augments_ it with conventions. Love can be added to any view or component without affecting existing functionality, and features can be opted-in as they are needed.

LiveViews and LiveComponents both gain:

- **State** assigns which are defined in the module
- **Reactive functions** that are automatically invoked upon state changes
- **Universal event handling** via the `handle_message/4` callback on a LiveView or LiveComponent
- **Runtime checks** with developer-friendly error messages

LiveComponents also gain additional functionality:

- **Props** which are assigns that are strictly passed in to the component
- **Slot** props to represent component slots
- **Event** props to represent events that can be raised by the component and universally handled via `handle_message/4`

Here are a couple examples showing off these features. For complete details, please reference [the docs](https://hexdocs.pm/love_ex/).

## Love.View Example

```elixir
defmodule MyAppWeb.ProfileIndexLive do
  use Phoenix.LiveView
  use Love.View

  state :profiles, default: load_profiles()
  state :profile_count
  state :selected_profile_id, default: nil

  def handle_message(:on_selected, {MyAppWeb.UserProfileComponent, _id}, profile_id, socket) do
    put_state(socket, selected_profile_id: profile_id)
  end

  @react to: :profiles
  defp put_profile_count(socket) do
    put_state(socket, profile_count: length(socket.assigns.profiles))
  end

  defp load_profiles, do: # ...

  # ...
end
```

The `:profiles`, `:profile_count`, and `selected_profile_id` assigns are **state**. They can be modified throughout the LiveView lifecycle, and reactive functions can respond to their changes.

The `handle_message/4` callback is part of the `Love.View` behaviour. It's handling the event emitted by `UserProfileComponent`, which is wired up via its `:on_selected` event prop (see below).

The `put_profile_count/1` callback is a **reactive function** that is automatically invoked as soon as any changes occur to the `:profiles` state.

## Love.Component Example

```elixir
defmodule MyAppWeb.UserProfileComponent do
  use Phoenix.LiveComponent
  use Love.Component

  prop :profile
  prop :show_avatar?, default: false

  state :age
  state :expand_details?, default: false

  slot :inner_block

  event :on_selected

  def handle_event("toggle-details", _, socket) do
    {:noreply, put_state(socket, socket, expand_details?: not socket.assigns.expand_details?)}
  end

  def handle_event("select", %{"profile_id" => profile_id}}, socket) do
    {:noreply, emit(socket, :on_selected, profile_id)}
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

The `:id` assign is also a required prop, but it is implicitly defined by `use Love.Component`, because every LiveComponent requires an `:id`.

The `:show_avatar?` assign is an **optional prop** that defaults to `false` when unspecified.

The `:expand_details?` and `:age` assigns are **state**. They can be modified via `put_state/2`.

The `:inner_block` assign is a **slot prop**. It is required but can be made optional with the `required?: false` option.

The `:on_expanded` assign is a **event prop**. Events raised via `emit/3` can be handled by any Love.View _or_ Love.Component that implements the universal `handle_message/4` callback. Pass in a pid to send a message to a Love.View, or `{module, id}` to send a message to a Love.Component.

The `put_age/1` function is a **reactive callback**. It is automatically evaluated whenever the value of the `:profiles` state changes. The function can react to prop changes and state changes.

## Installation

The package can be installed by adding `love_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:love_ex, "~> 0.2.0"}
  ]
end
```
