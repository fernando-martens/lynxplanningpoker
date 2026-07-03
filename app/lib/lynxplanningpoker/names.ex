defmodule Lynxplanningpoker.Names do
  @moduledoc "Random whimsical display-name generation for un-onboarded users."

  # Curated so every "<adjective> <animal>" pair stays within the 20-char user
  # name limit (longest adjective + space + longest animal <= 20). Deliberately
  # non-human — an adjective + woodland animal, matching the app's forest/
  # campfire theme, so a temporary name never looks like a real person.
  @adjectives ~w(Sleepy Brave Curious Misty Amber Bold Cozy Wild Quiet Pale
                 Swift Merry Fuzzy Sly Jolly Nimble Rusty Snug Dusky Mossy
                 Frosty Cedar Autumn Golden Shady Woolly Plucky Spry Drowsy
                 Perky Wily Gentle Feisty Cheery Whimsical)

  @animals ~w(Lynx Fox Owl Deer Badger Otter Marten Hare Stoat Weasel Vole
              Wren Robin Finch Newt Toad Moth Beetle Hedgehog Squirrel Raccoon
              Chipmunk Beaver Bobcat Ermine Sparrow Falcon Heron Boar Elk Mole Bat)

  @doc "Returns a fresh random whimsical name, e.g. \"Sleepy Lynx\"."
  def random_display_name do
    "#{Enum.random(@adjectives)} #{Enum.random(@animals)}"
  end

  @doc false
  # Exposed for tests to exhaustively verify the length invariant.
  def adjectives, do: @adjectives

  @doc false
  def animals, do: @animals
end
