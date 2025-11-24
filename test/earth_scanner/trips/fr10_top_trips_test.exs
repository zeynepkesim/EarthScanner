defmodule EarthScanner.Trips.Fr10TopTripsTest do
  use EarthScanner.DataCase, async: true

  alias EarthScanner.Repo
  alias EarthScanner.Trips
  alias EarthScanner.Trips.Trip
  alias TripTestHelper

  test "compute_top_trips/1 returns fastest, cheapest and greenest trips with deterministic tie-breaking" do
    admin = TripTestHelper.admin_fixture()

    # Trip A: medium price, medium duration, medium CO2
    trip1 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 10:00:00Z],
        arrival_time: ~U[2025-11-20 13:00:00Z],
        duration_minutes: 180,
        price: 50.0,
        co2_level: 150,
        available_tickets: 50,
        transport_mode: "plane",
        admin_id: admin.id
      })

    # Trip B: cheapest and greenest, but slower
    trip2 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 11:00:00Z],
        arrival_time: ~U[2025-11-20 12:30:00Z],
        duration_minutes: 90,
        price: 60.0,
        co2_level: 130,
        available_tickets: 40,
        transport_mode: "bus",
        admin_id: admin.id
      })

    # Trip C: fastest but more expensive and more polluting
    trip3 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 09:00:00Z],
        arrival_time: ~U[2025-11-20 11:30:00Z],
        duration_minutes: 150,
        price: 40.0,
        co2_level: 100,
        available_tickets: 30,
        transport_mode: "train",
        admin_id: admin.id
      })

    top_trips = Trips.compute_top_trips([trip1, trip2, trip3])

    assert top_trips.fastest.id == trip2.id
    assert top_trips.cheapest.id == trip3.id
    assert top_trips.greenest.id == trip3.id
  end
end
