defmodule Lynxplanningpoker.NamesTest do
  use ExUnit.Case, async: true

  alias Lynxplanningpoker.Names

  describe "random_display_name/0" do
    test "returns a non-empty string" do
      name = Names.random_display_name()
      assert is_binary(name)
      assert String.trim(name) != ""
    end

    test "returns two Title-Case words (adjective + animal), never a human name" do
      for _ <- 1..200 do
        name = Names.random_display_name()
        assert name =~ ~r/^[A-Z][a-z]+ [A-Z][a-z]+$/

        [adjective, animal] = String.split(name, " ")
        assert adjective in Names.adjectives()
        assert animal in Names.animals()
      end
    end

    test "every possible adjective + animal pair fits within the 20-character limit" do
      for adjective <- Names.adjectives(), animal <- Names.animals() do
        assert String.length("#{adjective} #{animal}") <= 20
      end
    end
  end
end
