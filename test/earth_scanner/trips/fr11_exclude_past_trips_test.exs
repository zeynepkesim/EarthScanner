# FR-11: Exclude Past Trips - TDD Tests
# Tests for ensuring past trips are excluded from search results
defmodule EarthScanner.Trips.Fr11ExcludePastTripsTest do
  use EarthScanner.DataCase, async: false

  alias EarthScanner.{Trips, Repo}
  alias EarthScanner.Trips.Trip
  alias EarthScanner.Accounts

  # Simple admin fixture so trips can reference a valid admin_id
  defp admin_fixture do
    {:ok, admin} =
      Accounts.register_user(%{
        username: "fr11admin_#{System.unique_integer()}",
        name: "FR11",
        last_name: "Admin",
        email: "fr11admin_#{System.unique_integer()}@example.com",
        birthdate: ~D[1990-01-01],
        nationality: "EE",
        residence_address: "Admin street 1",
        phone_number: "+37200000001",
        password: "password123",
        password_confirmation: "password123",
        role: "admin"
      })

    admin
  end

  # FR-11: Clean database before each test
  setup do
    Repo.delete_all(Trip)
    :ok
  end

  @tag :fr11
  # FR-11: Positive scenario - mix of past and future trips
  test "search_future_trips/2 excludes trips with departure time in the past" do
    admin = admin_fixture()

    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    past_departure = DateTime.add(now, -3600, :second)
    future_departure = DateTime.add(now, 3600, :second)

    past_trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: past_departure,
        arrival_time: DateTime.add(past_departure, 3600, :second),
        duration_minutes: 60,
        price: 10,
        co2_level: 100,
        available_tickets: 10,
        picture_url: "https://via.placeholder.com/150",
        admin_id: admin.id
      })

    _future_trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: future_departure,
        arrival_time: DateTime.add(future_departure, 3600, :second),
        duration_minutes: 60,
        price: 20,
        co2_level: 150,
        available_tickets: 10,
        picture_url: "https://via.placeholder.com/150",
        admin_id: admin.id
      })

    # NOTE: Here we call the public API that actually exists: /2
    results = Trips.search_future_trips("Tartu", "Tallinn")

    # All returned trips must start strictly after now (no past trips)
    assert Enum.all?(results, fn trip ->
             DateTime.compare(trip.departure_time, now) == :gt
           end)

    # The explicitly past trip must not appear in the results
    refute Enum.any?(results, fn trip -> trip.id == past_trip.id end)
  end

  @tag :fr11
  # FR-11: Edge case - trip departing exactly now
  test "trip with departure exactly equal to now is treated as past" do
    admin = admin_fixture()

    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    _trip_at_now =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: now,
        arrival_time: DateTime.add(now, 3600, :second),
        duration_minutes: 60,
        price: 15,
        co2_level: 120,
        available_tickets: 10,
        picture_url: "https://via.placeholder.com/150",
        admin_id: admin.id
      })

    # Again, use the /2 version
    results = Trips.search_future_trips("Tartu", "Tallinn")

    # No trip whose departure_time equals our `now` helper should be returned
    refute Enum.any?(results, fn trip ->
             DateTime.compare(trip.departure_time, now) == :eq
           end)
  end

  @tag :fr11
  # FR-11: Negative scenario - only past trips exist
  test "returns empty list when only past trips exist" do
    admin = admin_fixture()

    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    # Create only past trips (2 hours ago)
    _past_trip1 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: DateTime.add(now, -7200, :second),
        arrival_time: DateTime.add(now, -3600, :second),
        duration_minutes: 60,
        price: 10,
        co2_level: 100,
        available_tickets: 10,
        picture_url: "https://via.placeholder.com/150",
        admin_id: admin.id
      })

    # Create another past trip (1 hour ago)
    _past_trip2 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "train",
        departure_time: DateTime.add(now, -3600, :second),
        arrival_time: DateTime.add(now, -1800, :second),
        duration_minutes: 30,
        price: 15,
        co2_level: 80,
        available_tickets: 5,
        picture_url: "https://via.placeholder.com/150",
        admin_id: admin.id
      })

    # Search should return empty list (no future trips)
    results = Trips.search_future_trips("Tartu", "Tallinn")
    assert results == []
  end
end
