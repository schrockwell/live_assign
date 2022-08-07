# 💕 Love.Component 💕

Fall in love with LiveComponents all over again.

Love.Component provides functionality on top of Phoenix.LiveComponent to improve developer ergonomics through a few simple conventions.

- Explicit assign **definitions** in three different buckets:
  - **Props** are passed in to the component and are never updated internally
  - **State** is managed entirely by the component
  - **Computed** values are derived entirely from other values
- Universal **events** that can handled by LiveViews and LiveComponents using the exact same `handle_message/3` callback
- Simple **reactivity** so that computed values and other side-effects are automatically invoked when component state changes
- **Runtime checks** to ensure that everything you define has been assigned, and nothing you haven't defined isn't

## Example

```elixir
defmodule MyAppWeb.UserProfileComponent
  use Phoenix.LiveComponent
  use Love.Component
  import Love.Component

  prop :profile
  prop :show_avatar?, default: false

  state :expand_details?, default: false

  computed :age

  slot :inner_block

  event :on_expanded

  def handle_click("toggle-details", _, socket) do
    expanded? = not socket.assigns.expand_details?

    {:noreply,
     socket
     |> emit(:on_expanded, expanded?)
     |> put_state(expand_details?: expanded?)}
  end

  @react to: :profile
  def compute_age(socket) do
    age = trunc(Date.diff(Date.utc_today(), socket.assigns.profile.birthday) / 365)
    put_computed(socket, age: age)
  end
end
```

The `:profile` assign is a **required prop**. If it is not passed in, a helpful runtime error will occur.

The `:id` assign is also a required prop, but it is implicitly defined by `use Love.Component`, because every LiveComponent requires an `:id`.

The `:show_avatar?` assign is an **optional prop** that defaults to `false` when unspecified.

The `:expand_details?` assign is **state** and has an initial value. It can be modified via `put_state/2`.

The `:age` assign is **computed** and is set by `put_computed/2`. If we forget to set it, a helpful runtime error will occur.

The `:inner_block` assign is a **required slot prop**. It can be made optional with the `required?: false` option.

The `:on_expanded` assign is a **event prop**. Events raised via `emit/3` can be handled by any Love.View (coming soon) _or_ Love.Component that implements the universal `handle_message/4` callback. Pass in a pid to send a message to a Love.View, or `{module, id}` to send a message to a Love.Component.

The `compute_age/1` function is a **reactive callback**. It is automatically evaluated whenever any of the assigns listed in the `@react to: ...` attribute have changed. The function can react to prop changes, state changes, and even _other_ reactive callbacks.

## Gotchas

### Call `super` when overriding `mount/1` and `update/2`

Love.Component implements the LiveComponent `mount/1` and `update/2` callbacks. If your component needs to override either of these functions, `super/{1,2}` _must_ be invoked so that Love.Component can continue to work its magic.

## Installation

The package can be installed by adding `love_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:love_ex, "~> 0.1.0"}
  ]
end
```
