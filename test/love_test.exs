defmodule LoveTest do
  use ExUnit.Case
  doctest Love

  test "greets the world" do
    assert Love.hello() == :world
  end
end
