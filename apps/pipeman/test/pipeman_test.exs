defmodule PipemanTest do
  use ExUnit.Case
  doctest Pipeman

  test "greets the world" do
    assert Pipeman.hello() == :world
  end
end
