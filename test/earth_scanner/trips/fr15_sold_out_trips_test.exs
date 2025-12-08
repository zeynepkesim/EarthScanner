defmodule EarthScanner.Trips.Fr15SoldOutTripsTest do
  use EarthScanner.DataCase, async: true

  alias EarthScanner.{Trips, Accounts, Repo}
  alias EarthScanner.Trips.{Trip, TripInstance}
  alias TripTestHelper

  @tag :fr15
  test "purchase_trip_instance/2 returns :sold_out when instance has no available tickets" do
    {:ok, user} =
      Accounts.register_user(%{
        username: "fr15user",
        name: "FR",
        last_name: "Fifteen",
        email: "fr15@example.com",
        birthdate: ~D[1990-01-01],
        nationality: "EE",
        residence_address: "Some street 1",
        phone_number: "+372000000",
        password: "password123",
        password_confirmation: "password123"
      })

    # Truncate to seconds because Trip uses :utc_datetime (no microseconds allowed)
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    future = DateTime.add(now, 86_400, :second)

    # Create a real admin so foreign key admin_id points to an existing record
    admin = TripTestHelper.admin_fixture()

    trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "bus",
        departure_time: future,
        arrival_time: DateTime.add(future, 3600, :second),
        duration_minutes: 60,
        price: 25,
        co2_level: 150,
        available_tickets: 10,
        admin_id: admin.id
      })

    # Insert a sold-out instance directly (bypassing changeset validation)
    instance =
      Repo.insert!(%TripInstance{
        trip_id: trip.id,
        date: Date.add(Date.utc_today(), 1),
        available_tickets: 0
      })

    assert {:error, :sold_out} = Trips.purchase_trip_instance(user, instance.id)
  end
end
