defmodule AppOmsTest do
  use ExUnit.Case
  doctest AppOms

  test "greets the world" do
    assert AppOms.hello() == :world
  end
end
