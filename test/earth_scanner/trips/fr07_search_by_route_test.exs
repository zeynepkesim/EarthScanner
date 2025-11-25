defmodule SearchByRouteTest do
  use EarthScanner.DataCase, async: true
  alias EarthScanner.Trips
  import TripTestHelper

  test "successful search with valid source & destination" do
    uniq = System.unique_integer([:positive]) |> Integer.to_string()

    unique_destination = "Parnu-" <> uniq

    create_trip(%{source_city: "Tartu", destination_city: unique_destination})
    create_trip(%{source_city: "Tallinn", destination_city: "Riga"})

    results = Trips.search(%{"source" => "Tartu", "destination" => unique_destination})

    assert Enum.any?(results, fn r -> r.destination_city == unique_destination end)
  end

  test "missing source → validation returns empty list or error" do
    create_trip()

    results = Trips.search(%{"source" => "", "destination" => "Tallinn"})
    assert results == []
  end

  test "only future trips are shown" do
    create_past_and_future_trips()

    results = Trips.search(%{"source" => "Tartu", "destination" => "Tallinn"})

    assert Enum.all?(results, fn trip ->
             DateTime.compare(trip.departure_time, DateTime.utc_now()) == :gt
           end)
  end
end
