defmodule PocCoreTest do
  use ExUnit.Case
  doctest PocCore

  test "greets the world" do
    assert PocCore.hello() == :world
  end
end
