defmodule LynxplanningpokerWeb.RoomLive.Forest do
  @moduledoc """
  Static layout for the decorative tree scenery that surrounds the campfire
  in `RoomLive.Show`. Each entry is `{x%, y%, scale}` relative to the
  `.room-scene` viewport — positions cluster along the edges so the central
  table (campfire + users) is never covered.
  """

  @trees [
    # Top strip
    {3, 4, 0.7},
    {8, 10, 0.6},
    {19, 12, 0.75},
    {37, 5, 0.7},
    {43, 11, 0.65},
    {50, 3, 0.9},
    {57, 9, 0.7},
    {63, 4, 0.85},
    {69, 11, 0.6},
    {75, 5, 0.75},
    {81, 10, 0.9},
    {86, 4, 0.65},
    {96, 5, 0.7},
    # Left side
    {2, 18, 0.75},
    {7, 28, 0.6},
    {2, 38, 0.9},
    {9, 48, 0.7},
    {3, 58, 0.85},
    {8, 68, 0.65},
    {2, 78, 0.95},
    {11, 86, 0.7},
    {6, 92, 0.8},
    {15, 94, 0.6},
    # Right side
    {93, 28, 0.85},
    {98, 38, 0.6},
    {91, 48, 0.95},
    {97, 58, 0.75},
    {92, 68, 0.65},
    {98, 78, 0.85},
    {89, 86, 0.7},
    {95, 92, 0.9},
    {84, 94, 0.65}
  ]

  def trees, do: @trees
end
