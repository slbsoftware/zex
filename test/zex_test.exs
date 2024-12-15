defmodule ZexTest do
  use ExUnit.Case
  doctest Zex

  test "greets the world" do
    assert Zex.hello() == :world
  end
end
