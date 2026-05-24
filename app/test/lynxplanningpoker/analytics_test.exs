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
end
