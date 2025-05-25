defmodule PipecoreTest do
  use ExUnit.Case
  doctest Pipecore

  test "greets the world" do
    assert Pipecore.hello() == :world
  end
end
