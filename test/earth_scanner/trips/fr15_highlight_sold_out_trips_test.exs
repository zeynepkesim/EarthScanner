# FR-15: Sold-Out Trips - Server-Side Validation Tests
defmodule EarthScanner.Trips.HighlightSoldOutTripsTest do
  use EarthScanner.DataCase, async: true

  alias EarthScanner.{Trips, Accounts, Repo}
  alias EarthScanner.Trips.{Trip, TripInstance}
  alias TripTestHelper

  @tag :fr15
  # FR-15: Negative scenario - sold-out purchase blocked
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

  @tag :fr15
  # FR-15: Positive scenario - purchase succeeds when tickets available
  test "purchase_trip_instance/2 succeeds when instance has available tickets" do
    {:ok, user} =
      Accounts.register_user(%{
        username: "fr15user2",
        name: "FR",
        last_name: "Fifteen2",
        email: "fr15_2@example.com",
        birthdate: ~D[1990-01-01],
        nationality: "EE",
        residence_address: "Some street 2",
        phone_number: "+372000001",
        password: "password123",
        password_confirmation: "password123"
      })

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future = DateTime.add(now, 86_400, :second)
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
        picture_url: "https://via.placeholder.com/150",
        admin_id: admin.id
      })

    # Create instance with available tickets
    instance =
      Repo.insert!(%TripInstance{
        trip_id: trip.id,
        date: Date.add(Date.utc_today(), 1),
        available_tickets: 5
      })

    assert {:ok, _purchase} = Trips.purchase_trip_instance(user, instance.id)
  end

  @tag :fr15
  # FR-15: Edge case - last ticket purchase succeeds, next fails
  test "last ticket can be purchased but subsequent attempt fails with :sold_out" do
    {:ok, user1} =
      Accounts.register_user(%{
        username: "fr15user3",
        name: "FR",
        last_name: "Fifteen3",
        email: "fr15_3@example.com",
        birthdate: ~D[1990-01-01],
        nationality: "EE",
        residence_address: "Some street 3",
        phone_number: "+372000002",
        password: "password123",
        password_confirmation: "password123"
      })

    {:ok, user2} =
      Accounts.register_user(%{
        username: "fr15user4",
        name: "FR",
        last_name: "Fifteen4",
        email: "fr15_4@example.com",
        birthdate: ~D[1990-01-01],
        nationality: "EE",
        residence_address: "Some street 4",
        phone_number: "+372000003",
        password: "password123",
        password_confirmation: "password123"
      })

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future = DateTime.add(now, 86_400, :second)
    admin = TripTestHelper.admin_fixture()

    trip =
      Repo.insert!(%Trip{
        source_city: "Tartu",
        destination_city: "Tallinn",
        transport_mode: "train",
        departure_time: future,
        arrival_time: DateTime.add(future, 3600, :second),
        duration_minutes: 60,
        price: 30,
        co2_level: 100,
        available_tickets: 10,
        picture_url: "https://via.placeholder.com/150",
        admin_id: admin.id
      })

    # Create instance with only 1 ticket
    instance =
      Repo.insert!(%TripInstance{
        trip_id: trip.id,
        date: Date.add(Date.utc_today(), 1),
        available_tickets: 1
      })

    # First purchase should succeed (last ticket)
    assert {:ok, _purchase1} = Trips.purchase_trip_instance(user1, instance.id)

    # Refresh instance to get updated available_tickets
    instance = Repo.get!(TripInstance, instance.id)
    assert instance.available_tickets == 0

    # Second purchase should fail (sold out)
    assert {:error, :sold_out} = Trips.purchase_trip_instance(user2, instance.id)
  end
end
