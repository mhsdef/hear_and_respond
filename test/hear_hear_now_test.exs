defmodule HearHearNowTest do
  use ExUnit.Case
  doctest HearHearNow

  test "greets the world" do
    assert HearHearNow.hello() == :world
  end
end
