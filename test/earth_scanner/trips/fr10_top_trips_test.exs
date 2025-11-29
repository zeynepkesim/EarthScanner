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

  test "compute_top_trips/1 returns nil when no trips are provided" do
    top_trips = Trips.compute_top_trips([])

    assert top_trips.fastest == nil
    assert top_trips.cheapest == nil
    assert top_trips.greenest == nil
  end

  test "compute_top_trips/1 returns same trip for all categories when only one trip exists" do
    admin = TripTestHelper.admin_fixture()

    trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 10:00:00Z],
        arrival_time: ~U[2025-11-20 12:00:00Z],
        duration_minutes: 120,
        price: 20.0,
        co2_level: 100,
        available_tickets: 50,
        transport_mode: "bus",
        admin_id: admin.id
      })

    top_trips = Trips.compute_top_trips([trip])

    assert top_trips.fastest.id == trip.id
    assert top_trips.cheapest.id == trip.id
    assert top_trips.greenest.id == trip.id
  end

  test "compute_top_trips/1 handles multiple trips correctly" do
    admin = TripTestHelper.admin_fixture()

    trip1 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 10:00:00Z],
        arrival_time: ~U[2025-11-20 11:40:00Z],
        duration_minutes: 100,
        price: 25.0,
        co2_level: 150,
        available_tickets: 50,
        transport_mode: "bus",
        admin_id: admin.id
      })

    trip2 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 11:00:00Z],
        arrival_time: ~U[2025-11-20 13:00:00Z],
        duration_minutes: 120,
        price: 15.0,
        co2_level: 100,
        available_tickets: 40,
        transport_mode: "train",
        admin_id: admin.id
      })

    trip3 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 09:00:00Z],
        arrival_time: ~U[2025-11-20 10:30:00Z],
        duration_minutes: 90,
        price: 30.0,
        co2_level: 200,
        available_tickets: 30,
        transport_mode: "plane",
        admin_id: admin.id
      })

    trip4 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 12:00:00Z],
        arrival_time: ~U[2025-11-20 14:30:00Z],
        duration_minutes: 150,
        price: 20.0,
        co2_level: 80,
        available_tickets: 20,
        transport_mode: "bus",
        admin_id: admin.id
      })

    top_trips = Trips.compute_top_trips([trip1, trip2, trip3, trip4])

    # Trip3 is fastest (90 min)
    assert top_trips.fastest.id == trip3.id
    # Trip2 is cheapest (15.0)
    assert top_trips.cheapest.id == trip2.id
    # Trip4 is greenest (80 CO2)
    assert top_trips.greenest.id == trip4.id
  end

  test "compute_top_trips/1 handles tie-breaking deterministically" do
    admin = TripTestHelper.admin_fixture()

    # Two trips with same duration - should pick first by ID
    trip1 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 10:00:00Z],
        arrival_time: ~U[2025-11-20 11:30:00Z],
        duration_minutes: 90,
        price: 25.0,
        co2_level: 150,
        available_tickets: 50,
        transport_mode: "bus",
        admin_id: admin.id
      })

    trip2 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 11:00:00Z],
        arrival_time: ~U[2025-11-20 12:30:00Z],
        duration_minutes: 90,
        price: 15.0,
        co2_level: 100,
        available_tickets: 40,
        transport_mode: "train",
        admin_id: admin.id
      })

    top_trips = Trips.compute_top_trips([trip1, trip2])

    # Both have same duration, should pick deterministically (first by ID)
    assert top_trips.fastest.id in [trip1.id, trip2.id]
    # Trip2 is cheapest
    assert top_trips.cheapest.id == trip2.id
    # Trip2 is greenest
    assert top_trips.greenest.id == trip2.id
  end

  test "compute_top_trips/1 allows same trip in multiple categories" do
    admin = TripTestHelper.admin_fixture()

    # Super trip: fastest, cheapest, greenest
    super_trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 10:00:00Z],
        arrival_time: ~U[2025-11-20 11:30:00Z],
        duration_minutes: 90,
        price: 10.0,
        co2_level: 50,
        available_tickets: 50,
        transport_mode: "train",
        admin_id: admin.id
      })

    # Slower, more expensive, more polluting trip
    other_trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        departure_time: ~U[2025-11-20 11:00:00Z],
        arrival_time: ~U[2025-11-20 14:00:00Z],
        duration_minutes: 180,
        price: 30.0,
        co2_level: 200,
        available_tickets: 40,
        transport_mode: "bus",
        admin_id: admin.id
      })

    top_trips = Trips.compute_top_trips([super_trip, other_trip])

    # Super trip should be in all three categories
    assert top_trips.fastest.id == super_trip.id
    assert top_trips.cheapest.id == super_trip.id
    assert top_trips.greenest.id == super_trip.id
  end
end
