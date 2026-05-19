defmodule LynxplanningpokerWeb.RoomLive.Dev do
  @moduledoc """
  Development-only helpers for `LynxplanningpokerWeb.RoomLive.Show`.

  Every function in this module is a **no-op by default**. To activate a
  particular dev affordance, uncomment the single marked line at the top
  of the relevant function body. Production code paths always invoke
  these functions, so they cost nothing until you opt in here.
  """

  alias Lynxplanningpoker.Decks

  @doc """
  Either returns the real user list (default) or swaps it for a maxed-out
  fake roster used to preview the stats modal with the worst case — 15
  users covering all 12 deck cards plus one abstention.
  """
  def stats_users(real_users) do
    # Uncomment to enable the stats-modal preview:
    # fake_full_users()
    real_users
  end

  @doc """
  Schedules the periodic fake-users tick that cycles 1→15 users every
  second to preview the seating layout. Pair with `tick_fake_users/1`
  which is called from `handle_info(:tick_fake_users, _)` in
  `RoomLive.Show`.
  """
  def maybe_schedule_seating_tick(pid) do
    _ = pid
    # Uncomment to start cycling 1→15 fake users every second:
    # Process.send_after(pid, :tick_fake_users, 0)
    :ok
  end

  @doc """
  Optional artificial delay used to make the campfire loading spinner
  visible during reveal.
  """
  def maybe_slow_down_reveal do
    # Uncomment to sleep before reveal so the spinner is visible:
    # Process.sleep(4000)
    :ok
  end

  @doc """
  Advances the seating-preview tick: returns `{users_for_this_tick,
  next_count}`. Called from `handle_info(:tick_fake_users, _)`.
  """
  def tick_fake_users(count) do
    next_count = if count >= 15, do: 1, else: count + 1

    users =
      for i <- 1..count do
        %{
          id: "fake-#{i}",
          name: "User #{i}",
          vote: nil,
          vote_value: nil,
          has_voted: false,
          vote_changed_after_reveal: false,
          is_host: false
        }
      end

    {users, next_count}
  end

  defp fake_full_users do
    votes = [
      "0",
      "1",
      "2",
      "3",
      "5",
      "5",
      "8",
      "8",
      "13",
      "21",
      "34",
      "55",
      "89",
      "?",
      nil
    ]

    for {vote, i} <- Enum.with_index(votes) do
      %{
        id: "fake-#{i}",
        name: "User #{i + 1}",
        vote: vote,
        vote_value: Decks.numeric_value(vote),
        has_voted: not is_nil(vote),
        vote_changed_after_reveal: false,
        is_host: false
      }
    end
  end
end
