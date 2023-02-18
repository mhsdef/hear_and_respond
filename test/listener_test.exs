defmodule HearHearTest do
  use ExUnit.Case
  doctest HearHear

  test "greets the world" do
    assert HearHear.hello() == :world
  end
end
