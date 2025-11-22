defmodule EarthScanner.Trips.Fr11ExcludePastTripsTest do
  use EarthScanner.DataCase, async: true

  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Repo
  alias TripTestHelper

  @tag :fr11
  test "search_future_trips/3 excludes trips with departure time in the past" do
    # Create a real admin so foreign key admin_id points to an existing record
    admin = TripTestHelper.admin_fixture()

    # Truncate to seconds because Trip uses :utc_datetime (no microseconds allowed)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    past = DateTime.add(now, -3600, :second)
    future = DateTime.add(now, 3600, :second)

    # Past trip
    past_trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: past,
        arrival_time: DateTime.add(past, 3600, :second),
        duration_minutes: 60,
        price: 10,
        co2_level: 100,
        available_tickets: 10,
        admin_id: admin.id
      })

    # Future trip
    future_trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: future,
        arrival_time: DateTime.add(future, 3600, :second),
        duration_minutes: 60,
        price: 15,
        co2_level: 120,
        available_tickets: 10,
        admin_id: admin.id
      })

    results =
      Trips.search_future_trips("Tartu", "Tallinn", %{})

    # The future trip created in this test must be in the results
    assert Enum.any?(results, &(&1.id == future_trip.id))

    # The past trip created in this test must NOT be in the results
    refute Enum.any?(results, &(&1.id == past_trip.id))
  end

  @tag :fr11
  test "trip with departure exactly equal to now is treated as past" do
    # Create a real admin so foreign key admin_id points to an existing record
    admin = TripTestHelper.admin_fixture()

    # Truncate to seconds so it can be stored in :utc_datetime
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # This trip departs exactly 'now'
    trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: now,
        arrival_time: DateTime.add(now, 3600, :second),
        duration_minutes: 60,
        price: 20,
        co2_level: 150,
        available_tickets: 10,
        admin_id: admin.id
      })

    results =
      Trips.search_future_trips("Tartu", "Tallinn", %{})

    # Because search_future_trips uses departure_time > now,
    # the trip departing exactly at 'now' must NOT appear in results.
    refute Enum.any?(results, &(&1.id == trip.id))
  end
end
