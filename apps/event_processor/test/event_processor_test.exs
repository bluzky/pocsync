defmodule EventProcessorTest do
  use ExUnit.Case
  doctest EventProcessor

  test "greets the world" do
    assert EventProcessor.hello() == :world
  end
end
