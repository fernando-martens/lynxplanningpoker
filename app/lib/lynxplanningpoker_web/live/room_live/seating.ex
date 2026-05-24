defmodule LynxplanningpokerWeb.RoomLive.Seating do
  @moduledoc """
  Computes where each user sits around the campfire in `RoomLive.Show`.

  The ring opens up as more people join: tight when only a couple are
  present, full table when the room is crowded. Each returned tuple is
  `{user, x%, y%}` relative to the `.room-table` element.
  """

  @min_radius_x 28
  @max_radius_x 42
  @min_radius_y 32
  @max_radius_y 44
  @ramp_start 2
  @ramp_end 12

  def positions([]), do: []

  def positions(users) do
    total = length(users)
    t = ramp_t(total)
    rx = @min_radius_x + (@max_radius_x - @min_radius_x) * t
    ry = @min_radius_y + (@max_radius_y - @min_radius_y) * t

    users
    |> Enum.with_index()
    |> Enum.map(fn {user, i} ->
      angle = -:math.pi() / 2 + 2 * :math.pi() / total * i
      x = 50 + rx * :math.cos(angle)
      y = 50 + ry * :math.sin(angle)
      {user, Float.round(x, 2), Float.round(y, 2)}
    end)
  end

  defp ramp_t(total) do
    ((total - @ramp_start) / (@ramp_end - @ramp_start))
    |> max(0.0)
    |> min(1.0)
  end
end
