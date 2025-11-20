defmodule SortResultsTest do
  use EarthScanner.DataCase, async: true
  alias EarthScanner.Trips
  import TripTestHelper

  test "sort by price ascending" do
    create_future_trips_with_varying_prices()

    results =
      Trips.search(%{
        "source" => "Tartu",
        "destination" => "Tallinn",
        "sort" => "price_asc"
      })

    assert Enum.sort_by(results, & &1.price) == results
  end

  test "sort by CO2 descending" do
    create_future_trips_with_varying_co2()

    results =
      Trips.search(%{
        "source" => "Tartu",
        "destination" => "Tallinn",
        "sort" => "co2_desc"
      })

    assert Enum.sort_by(results, & &1.co2_level, :desc) == results
  end

  test "sort by duration ascending" do
    create_future_trips_with_varying_durations()

    results =
      Trips.search(%{
        "source" => "Tartu",
        "destination" => "Tallinn",
        "sort" => "duration_asc"
      })

    assert Enum.sort_by(results, & &1.duration_minutes) == results
  end
end
