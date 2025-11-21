defmodule FilterResultsTest do
  use EarthScanner.DataCase, async: true
  alias EarthScanner.Trips
  import TripTestHelper

  test "filter by price range" do
    create_future_trips_with_varying_prices()

    results =
      Trips.search(%{
        "source" => "Tartu",
        "destination" => "Tallinn",
        "min_price" => "10",
        "max_price" => "35"
      })

    assert Enum.all?(results, fn t -> t.price >= 10 and t.price <= 35 end)
  end

  test "filter by CO2" do
    create_future_trips_with_varying_co2()

    results =
      Trips.search(%{
        "source" => "Tartu",
        "destination" => "Tallinn",
        "max_co2" => "150"
      })

    assert Enum.all?(results, fn t -> t.co2_level <= 150 end)
  end

  test "combined filters" do
    create_future_trips_with_varying_prices()
    create_future_trips_with_varying_co2()

    results =
      Trips.search(%{
        "source" => "Tartu",
        "destination" => "Tallinn",
        "min_price" => "10",
        "max_co2" => "150"
      })

    assert Enum.all?(results, fn t ->
             t.price >= 10 and t.co2_level <= 150
           end)
  end
end
