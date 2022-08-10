# Love.View and Love.Component

Love provides functionality on top of Phoenix LiveView to improve developer ergonomics through a conventions.

LiveView and LiveComponent _both_ gain:

- **State** assigns which can trigger reactive functions
- **Reactive functions** that are automatically invoked upon state changes
- **Universal event handling** via the `handle_message/4` callback on a LiveView or LiveComponent
- **Runtime checks** with developer-friendly error messages

LiveComponents also gain additional functionality:

- **Prop** assigns which are strictly passed in to the component and never modified internally
- **Slot** props
- **Event** props to represent events that can be raised by the component and universally handled by either a LiveComponent or LiveView via `handle_message/4`

## Love.View Example

```elixir
defmodule MyAppWeb.ProfileIndexLive do
  use Phoenix.LiveView
  use Love.View

  state :profiles, default: []
  state :profile_count, default: 0
  state :detailed_profile_id, default: nil

  def mount(_, _, socket) do
    {:ok, put_state(socket, profiles: load_profiles())}
  end

  def handle_message(:on_show_details, {MyAppWeb.UserProfileComponent, _id}, profile_id, socket) do
    put_state(socket, detailed_profile_id: profile_id)
  end

  @react to: :profiles
  defp put_profile_count(socket) do
    put_state(socket, profile_count: length(socket.assigns.profiles))
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= for profile <- @profiles do %>
        <.live_component
          module={MyAppWeb.UserProfileComponent}
          id={"profile-#{profile.id}"}
          profile={profile}
          on_show_details={self()}>

          some content
        </.live_component>
      <% end %>
    </div>
    """
  end
end
```

The `:profiles`, `:profile_count`, and `detailed_profile_id` assigns are **state**. They can be modified throughout the LiveView lifecycle, and reactive functions can respond to their changes.

The `handle_message/4` callback is part of the `Love.View` behaviour. It's handling the event emitted by `UserProfileComponent`, which is wired up via its `:on_show_details` event prop (see below).

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

  event :on_show_details

  def handle_event("toggle-details", _, socket) do
    {:noreply, put_state(socket, socket, expand_details?: not socket.assigns.expand_details?)}
  end

  def handle_event("show-details", %{"profile_id" => profile_id}}, socket) do
    {:noreply, emit(socket, :on_show_details, profile_id)}
  end

  @react to: :profile
  defp put_age(socket) do
    age = trunc(Date.diff(Date.utc_today(), socket.assigns.profile.birthday) / 365)
    put_state(socket, age: age)
  end
end
```

The `:profile` assign is a **required prop**. If it is not passed in, a helpful runtime error will occur.

The `:id` assign is also a required prop, but it is implicitly defined by `use Love.Component`, because every LiveComponent requires an `:id`.

The `:show_avatar?` assign is an **optional prop** that defaults to `false` when unspecified.

The `:expand_details?` and `:age` assigns are **state**. They can be modified via `put_state/2`.

The `:inner_block` assign is a **slot prop**. It is optional but can be made required with the `required?: true` option.

The `:on_expanded` assign is a **event prop**. Events raised via `emit/3` can be handled by any Love.View (coming soon) _or_ Love.Component that implements the universal `handle_message/4` callback. Pass in a pid to send a message to a Love.View, or `{module, id}` to send a message to a Love.Component.

The `put_age/1` function is a **reactive callback**. It is automatically evaluated whenever the value of the `:profiles` state changes. The function can react to prop changes and state changes.

## Installation

The package can be installed by adding `love_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:love_ex, "~> 0.1.0"}
  ]
end
```
