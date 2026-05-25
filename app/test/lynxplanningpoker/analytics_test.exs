defmodule Lynxplanningpoker.AnalyticsTest do
  use Lynxplanningpoker.DataCase, async: true

  alias Lynxplanningpoker.Analytics

  @secret "test-secret"

  defp record(overrides \\ []) do
    [
      ip: "1.2.3.4",
      user_agent: "Mozilla",
      country: "BR",
      date: ~D[2026-05-22],
      secret: @secret
    ]
    |> Keyword.merge(overrides)
    |> Analytics.record_visit()
  end

  describe "record_visit/1" do
    test "counts the first visit of a (day, visitor) pair" do
      assert {:ok, _} = record()
      assert Analytics.visitors_by_day() == [{~D[2026-05-22], 1}]
    end

    test "is idempotent within the same day for the same visitor" do
      record()
      record()
      record()

      assert Analytics.visitors_by_day() == [{~D[2026-05-22], 1}]
      assert Analytics.total_visitors() == 1
    end

    test "counts the same visitor again on a new day" do
      record(date: ~D[2026-05-21])
      record(date: ~D[2026-05-22])

      assert Analytics.visitors_by_day() == [
               {~D[2026-05-22], 1},
               {~D[2026-05-21], 1}
             ]

      assert Analytics.total_visitors() == 2
    end

    test "different IPs on the same day count as separate visitors" do
      record(ip: "1.2.3.4")
      record(ip: "5.6.7.8")

      assert Analytics.visitors_by_day() == [{~D[2026-05-22], 2}]
    end

    test "different user-agents on the same day count as separate visitors" do
      record(user_agent: "Mozilla")
      record(user_agent: "Chrome")

      assert Analytics.visitors_by_day() == [{~D[2026-05-22], 2}]
    end
  end

  describe "visitors_by_country/0" do
    test "groups by country, most visited first" do
      record(ip: "1.2.3.4", country: "BR")
      record(ip: "5.6.7.8", country: "BR")
      record(ip: "9.10.11.12", country: "FR")

      assert Analytics.visitors_by_country() == [{"BR", 2}, {"FR", 1}]
    end
  end

  describe "total_visitors/0" do
    test "is zero when nothing has been recorded" do
      assert Analytics.total_visitors() == 0
    end
  end

  describe "record_room_created/2" do
    test "inserts a session row for the given room id" do
      room_id = Ecto.UUID.generate()
      now = ~U[2026-05-24 10:00:00Z]

      assert {:ok, _} = Analytics.record_room_created(room_id, now: now)
      assert Analytics.total_rooms() == 1
    end

    test "is idempotent for the same room id" do
      room_id = Ecto.UUID.generate()
      Analytics.record_room_created(room_id)
      Analytics.record_room_created(room_id)

      assert Analytics.total_rooms() == 1
    end
  end

  describe "record_room_ended/2" do
    test "fills in ended_at on a live session" do
      room_id = Ecto.UUID.generate()
      started = ~U[2026-05-24 10:00:00Z]
      ended = ~U[2026-05-24 10:30:00Z]

      Analytics.record_room_created(room_id, now: started)

      assert {:ok, 1} = Analytics.record_room_ended(room_id, now: ended)
      assert Analytics.average_room_duration_seconds() == 1800.0
    end

    test "is a no-op when the room was never created" do
      assert {:ok, 0} = Analytics.record_room_ended(Ecto.UUID.generate())
    end

    test "is a no-op when the session has already ended" do
      room_id = Ecto.UUID.generate()
      Analytics.record_room_created(room_id, now: ~U[2026-05-24 10:00:00Z])
      Analytics.record_room_ended(room_id, now: ~U[2026-05-24 10:30:00Z])

      assert {:ok, 0} = Analytics.record_room_ended(room_id, now: ~U[2026-05-24 11:00:00Z])
      assert Analytics.average_room_duration_seconds() == 1800.0
    end
  end

  describe "rooms_by_day/0" do
    test "groups by started_at date, most recent first" do
      Analytics.record_room_created(Ecto.UUID.generate(), now: ~U[2026-05-22 10:00:00Z])
      Analytics.record_room_created(Ecto.UUID.generate(), now: ~U[2026-05-22 11:00:00Z])
      Analytics.record_room_created(Ecto.UUID.generate(), now: ~U[2026-05-23 09:00:00Z])

      assert Analytics.rooms_by_day() == [
               {~D[2026-05-23], 1},
               {~D[2026-05-22], 2}
             ]
    end
  end

  describe "average_room_duration_seconds/0" do
    test "returns nil when no room has ended" do
      Analytics.record_room_created(Ecto.UUID.generate())
      assert Analytics.average_room_duration_seconds() == nil
    end

    test "averages only rooms with ended_at filled in" do
      r1 = Ecto.UUID.generate()
      r2 = Ecto.UUID.generate()
      r3 = Ecto.UUID.generate()

      Analytics.record_room_created(r1, now: ~U[2026-05-24 10:00:00Z])
      Analytics.record_room_ended(r1, now: ~U[2026-05-24 10:10:00Z])

      Analytics.record_room_created(r2, now: ~U[2026-05-24 10:00:00Z])
      Analytics.record_room_ended(r2, now: ~U[2026-05-24 10:30:00Z])

      Analytics.record_room_created(r3, now: ~U[2026-05-24 10:00:00Z])

      assert Analytics.average_room_duration_seconds() == 1200.0
    end
  end

  describe "total_rooms/0" do
    test "is zero when nothing has been recorded" do
      assert Analytics.total_rooms() == 0
    end
  end
end
