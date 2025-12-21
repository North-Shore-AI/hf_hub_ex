defmodule HfHubTest do
  use ExUnit.Case
  doctest HfHub

  test "module exists" do
    assert Code.ensure_loaded?(HfHub)
  end
end
