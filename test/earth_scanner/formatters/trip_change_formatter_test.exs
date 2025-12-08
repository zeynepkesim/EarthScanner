defmodule EarthScanner.Formatters.TripChangeFormatterTest do
  use EarthScanner.DataCase, async: true

  alias EarthScanner.Formatters.TripChangeFormatter

  test "format_compact and multiline include trip name and route and deltas" do
    data = %{
      "timestamp" => "2025-11-30T20:59:50Z",
      "trip_name" => "Coastal Sunrise",
      "from" => "San Francisco",
      "to" => "Los Angeles",
      "co2_old" => 10,
      "co2_new" => 15,
      "recommended_price_old" => "0.7000000000000001",
      "recommended_price_new" => "1.05"
    }

    compact = TripChangeFormatter.format_compact(data)
    assert String.contains?(compact, "Coastal Sunrise")
    assert String.contains?(compact, "San Francisco → Los Angeles")
    assert String.contains?(compact, "$0.70 → $1.05")

    multi = TripChangeFormatter.format_multiline(data)
    assert String.contains?(multi, "Trip updated — Coastal Sunrise")
    assert String.contains?(multi, "Route: San Francisco → Los Angeles")
    assert String.contains?(multi, "CO2 level: 10 → 15")
  end
end
