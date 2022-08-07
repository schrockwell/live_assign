# 💕 Love.View and Love.Component 💕

## Fall in love all over again.

Love provides functionality on top of Phoenix LiveView to improve developer ergonomics through a few simple conventions.

LiveView and LiveComponent _both_ gain:

- **State** assigns which can trigger reactive functions
- **Reactive functions** that are automatically invoked upon state changes
- **Computed** assigns which are purely derived from other state
- **Universal event handling** via the `handle_message/4` callback
- **Runtime checks** with developer-friendly error messages

LiveComponents also gain additional functionality:

- **Prop** assigns which are strictly passed in to the component and never modified internally
- **Slot** props
- **Event** props to represent events that can be raised by the component and universally handled by either a LiveComponent OR LiveView via `handle_message/4`

## Love.View Exmaple

```elixir
defmodule MyAppWeb.ProfileIndexLive do
  use Phoenix.LiveView
  use Love.View

  state :profiles
  state :detailed_profile_id, default: nil

  computed :profile_count

  def mount(_, _, socket) do
    {:ok, put_state(socket, profiles: load_profiles())}
  end

  @impl Love.View
  def handle_message(:on_show_details, {MyAppWeb.UserProfileComponent, _id}, profile_id, socket) do
    put_state(socket, detailed_profile_id: profile_id)
  end

  @react to: :profiles
  def compute_profile_count(socket) do
    put_computed(socket, profile_count: length(socket.assigns.profiles))
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= for profile <- @profiles do %>
        <.live_component
          module={MyAppWeb.UserProfileComponent}
          id={"profile-#{profile.id}"}
          profile={profile}
          on_show_details={self()} />
      <% end %>
    </div>
    """
  end
end
```

The `:profiles` and `detailed_profile_id` assigns are **state**. They can be modified throughout the LiveView lifecycle, and reactive functions can respond to their changes.

The `:profile_count` is a **computed** assign because it is derived purely from other state.

The `handle_message/4` callback is part of the `Love.View` behaviour. It's handling the event emitted by `UserProfileComponent`, which is wired up via its `:on_show_details` event prop (see below).

The `compute_profile_count/1` callback is a **reactive function** that is automatically invoked as soon as any changes occur to the `:profiles` state.

## Love.Component Example

```elixir
defmodule MyAppWeb.UserProfileComponent do
  use Phoenix.LiveComponent
  use Love.Component

  prop :profile
  prop :show_avatar?, default: false

  state :expand_details?, default: false

  computed :age

  slot :inner_block, required?: false

  event :on_show_details

  def handle_event("toggle-details", _, socket) do
    {:noreply, put_state(socket, socket, expand_details?: not socket.assigns.expand_details?)}
  end

  def handle_event("show-details", %{"profile_id" => profile_id}}, socket) do
    {:noreply, emit(socket, :on_show_details, profile_id)}
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

The `:age` assign is **computed** and is set by `put_computed/2`.

The `:inner_block` assign is a **required slot prop**. It can be made optional with the `required?: false` option.

The `:on_expanded` assign is a **event prop**. Events raised via `emit/3` can be handled by any Love.View (coming soon) _or_ Love.Component that implements the universal `handle_message/4` callback. Pass in a pid to send a message to a Love.View, or `{module, id}` to send a message to a Love.Component.

The `compute_age/1` function is a **reactive callback**. It is automatically evaluated whenever any of the assigns listed in the `@react to: ...` attribute have changed. The function can react to prop changes, state changes, and even _other_ reactive callbacks.

## Gotchas

### When overriding `mount/1` and `update/2`

`Love.Component` implements the `LiveComponent.mount/1` and `update/2` callbacks. If your component needs to override either of these functions, you _must_ invoke `Love.Component.on_mount/1` and `on_update/2`, respectively, so that `Love.Component` can continue to hook into the component lifecycle to do its magic.

`Love.View` does not have this same concern, because extends the LiveView via the built-in hook mechanism.

## Installation

The package can be installed by adding `love_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:love_ex, "~> 0.1.0"}
  ]
end
```
