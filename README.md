# 💕 Love.Component 💕

Fall in love with LiveComponents all over again.

Love.Component provides functionality on top of Phoenix.LiveComponent to improve developer ergonomics through a few simple conventions.

- Explicit assign **definitions** in three different buckets:
  - **Props** are passed in to the component and are never updated internally
  - **State** is managed entirely by the component
  - **Computed** values are derived entirely from other values
- Simple **reactivity** so that computed values and other side-effects are automatically invoked when component state changes
- **Runtime checks** to ensure that everything you define has been assigned, and nothing you haven't defined isn't

## Example

```elixir
defmodule MyAppWeb.UserProfileComponent
  use Phoenix.LiveComponent
  use Love.Component
  import Love.Component

  prop :id
  prop :profile
  prop :show_avatar?, default: false

  state :expand_details?, initial: false

  computed :age

  event on_share(profile, social)

  def handle_click("toggle-details", _, socket) do
    {:noreply, put_state(socket, expand_details?: not socket.assigns.expand_details?)}
  end

  def handle_click("share-profile", %{"social" => social}, socket) do
    socket.assigns.on_share.(socket.assigns.profile, social)
    {:noreply, socket}
  end

  @react to: :profile
  def compute_age(socket) do
    age = trunc(Date.diff(Date.utc_today(), socket.assigns.profile.birthday) / 365)
    put_computed(socket, age: age)
  end
end
```

The `:id` and `:profile` assigns are **required props**. If they are not passed in, a helpful runtime error will occur.

The `:show_avatar?` assign is an **optional prop**.

The `:expand_details?` assign is **state** and has an initial value. It can be modified via `put_state/2`.

The `:age` assign is **computed** and is set by `put_computed/2`. If we forget to set it, a helpful runtime error will occur.

The `compute_age/1` function is a **reactive callback**. It is automatically evaluated whenever any of the assigns listed in the `@react to: ...` attribute have changed. The function can react to prop changes, state changes, and even _other_ reactive callbacks.

The `:on_share_profile` assign is an **event prop** that can accept a callback function to be invoked when the component does something of interest. Event props are always optional, with default no-op implementations.

## Gotchas

### Call `super` when overriding `mount/1` and `update/2`

Love.Component implements the LiveComponent `mount/1` and `update/2` callbacks. If your component needs to override either of these functions, `super/{1,2}` _must_ be invoked so that Live.Component can continue to work its magic.

## Installation

The package can be installed by adding `love_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:love_ex, "~> 0.1.0"}
  ]
end
```
