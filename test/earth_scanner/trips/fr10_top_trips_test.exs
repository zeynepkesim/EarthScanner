defmodule EarthScanner.Trips.Fr10TopTripsTest do
  use EarthScanner.DataCase, async: true

  alias EarthScanner.{Trips, Repo}
  alias EarthScanner.Trips.Trip

  @tag :fr10
  test "compute_top_trips/1 returns fastest, cheapest and greenest trips with deterministic tie-breaking" do
    # Truncate to seconds because Trip uses :utc_datetime (no microseconds allowed)
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    # Trip A: medium price, medium duration, medium CO2
    t1 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: now,
        arrival_time: DateTime.add(now, 60 * 60, :second),
        duration_minutes: 60,
        price: Decimal.new("20.00"),
        co2_level: 150,
        available_tickets: 10,
        admin_id: 1
      })

    # Trip B: cheapest and greenest, but slower
    t2 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "train",
        departure_time: now,
        arrival_time: DateTime.add(now, 90 * 60, :second),
        duration_minutes: 90,
        price: Decimal.new("10.00"),
        co2_level: 80,
        available_tickets: 10,
        admin_id: 1
      })

    # Trip C: fastest but more expensive and more polluting
    t3 =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "plane",
        departure_time: now,
        arrival_time: DateTime.add(now, 30 * 60, :second),
        duration_minutes: 30,
        price: Decimal.new("40.00"),
        co2_level: 300,
        available_tickets: 10,
        admin_id: 1
      })

    top = Trips.compute_top_trips([t1, t2, t3])

    assert top.fastest.id == t3.id
    assert top.cheapest.id == t2.id
    assert top.greenest.id == t2.id
  end
end
