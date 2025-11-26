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

  @tag :fr11
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
        admin_id: admin.id
      })

    # Again, use the /2 version
    results = Trips.search_future_trips("Tartu", "Tallinn")

    # No trip whose departure_time equals our `now` helper should be returned
    refute Enum.any?(results, fn trip ->
             DateTime.compare(trip.departure_time, now) == :eq
           end)
  end
end
