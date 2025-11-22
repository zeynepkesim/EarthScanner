defmodule EarthScanner.Trips.Fr11ExcludePastTripsTest do
  # To avoid DB pool issues on CI, set async: false if needed
  use EarthScanner.DataCase, async: false

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

    result_ids = Enum.map(results, & &1.id)

    # The future_trip created in this test must be present in result_ids
    assert future_trip.id in result_ids

    # No results should be in the past or have departure_time exactly equal to now
    refute Enum.any?(results, fn trip ->
      DateTime.compare(trip.departure_time, now) in [:lt, :eq]
    end)
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

    # the trip departing exactly at 'now' must NOT appear in results.
    refute Enum.any?(results, fn trip ->
      DateTime.compare(trip.departure_time, now) == :eq
    end)
  end
end
