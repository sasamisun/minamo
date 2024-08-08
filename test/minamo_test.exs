defmodule MinamoTest do
  use ExUnit.Case
  doctest Minamo

  test "greets the world" do
    assert Minamo.hello() == :world
  end
end
