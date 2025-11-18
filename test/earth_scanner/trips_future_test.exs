defmodule EarthScanner.TripsFutureTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Accounts
  alias EarthScanner.Repo

  # Fixture to create an admin user
  defp admin_fixture(attrs \\ %{}) do
    unique_email = "admin_#{System.unique_integer([:positive])}@example.com"
    unique_username = "admin_user_#{System.unique_integer([:positive])}"

    {:ok, admin} =
      Accounts.register_user(
        Map.merge(
          %{
            "username" => unique_username,
            "password" => "Password123!",
            "password_confirmation" => "Password123!",
            "name" => "Admin",
            "last_name" => "User",
            "email" => unique_email,
            "birthdate" => "1990-01-01",
            "nationality" => "TR",
            "residence_address" => "Admin Street",
            "phone_number" => "+905551111111"
          },
          attrs
        )
      )

    # Update role to "admin"
    admin = Ecto.Changeset.change(admin, role: "admin") |> Repo.update!()
    admin
  end

  # Base attributes for trips
  defp base_trip_attrs do
    %{
      "picture_url" => "https://example.com/pic.jpg",
      "transport_mode" => "plane",
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "50"
    }
  end

  test "list_future_trips_for_admin/1 returns only future trips for the admin and sorted asc by departure_time" do
    admin1 = admin_fixture(%{"username" => "admin1", "email" => "future_admin1@example.com"})
    admin2 = admin_fixture(%{"username" => "admin2", "email" => "future_admin2@example.com"})

    # Create future trips for admin1
    {:ok, trip1} =
      Trips.create_trip(
        admin1,
        Map.merge(base_trip_attrs(), %{
          "departure_time" => ~N[2030-01-01 10:00:00],
          "arrival_time" => ~N[2030-01-01 13:00:00],
          "source_city" => "FutureA",
          "destination_city" => "DestA",
          "dates" => "2030-01-01"
        })
      )

    {:ok, trip2} =
      Trips.create_trip(
        admin1,
        Map.merge(base_trip_attrs(), %{
          "departure_time" => ~N[2031-06-01 10:00:00],
          "arrival_time" => ~N[2031-06-01 13:00:00],
          "source_city" => "FutureB",
          "destination_city" => "DestB",
          "dates" => "2031-06-01"
        })
      )

    # Create a trip for another admin (should not appear)
    {:ok, _other} =
      Trips.create_trip(
        admin2,
        Map.merge(base_trip_attrs(), %{
          "departure_time" => ~N[2030-05-01 10:00:00],
          "arrival_time" => ~N[2030-05-01 13:00:00],
          "source_city" => "OtherFuture",
          "destination_city" => "DestOther",
          "dates" => "2030-05-01"
        })
      )

    # Create a past trip (should not appear)
    {:ok, past_trip} =
      Trips.create_trip(
        admin1,
        Map.merge(base_trip_attrs(), %{
          "departure_time" => ~N[2020-01-01 10:00:00],
          "arrival_time" => ~N[2020-01-01 13:00:00],
          "source_city" => "PastCity",
          "destination_city" => "PastDest",
          "dates" => "2020-01-01"
        })
      )

    # Get future trips for admin1
    result = Trips.list_future_trips_for_admin(admin1)

    # Assertions
    assert Enum.any?(result, &(&1.id == trip1.id))
    assert Enum.any?(result, &(&1.id == trip2.id))
    refute Enum.any?(result, &(&1.id == past_trip.id))
    refute Enum.any?(result, &(&1.admin_id != admin1.id))

    # Ensure trips are sorted by departure_time ascending
    departure_times = Enum.map(result, & &1.departure_time)
    assert departure_times == Enum.sort(departure_times)
  end

  test "returns empty list if admin has no future trips" do
    admin = admin_fixture()
    assert Trips.list_future_trips_for_admin(admin) == []
  end
end
