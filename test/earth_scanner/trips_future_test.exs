defmodule EarthScanner.TripsFutureTest do
  use EarthScanner.DataCase

  alias EarthScanner.Trips
  alias EarthScanner.Accounts

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

    admin
  end

  defp base_trip_attrs do
    %{
      "picture_url" => "https://example.com/pic.jpg",
      "transport_mode" => "plane",
      "price" => "150.0",
      "co2_level" => "200",
      "available_tickets" => "50",
      "arrival_time" => "2025-11-20T13:00:00Z"
    }
  end

  test "list_future_trips_for_admin/1 returns only future trips for the admin and sorted asc by departure_time" do
    admin1 = admin_fixture(%{"username" => "admin1", "email" => "future_admin1@example.com"})
    admin2 = admin_fixture(%{"username" => "admin2", "email" => "future_admin2@example.com"})

    {:ok, trip1} =
      Trips.create_trip(admin1, Map.merge(base_trip_attrs(), %{"departure_time" => "2030-01-01T10:00:00Z", "source_city" => "FutureA", "destination_city" => "DestA", "dates" => "2030-01-01"}))

    {:ok, trip2} =
      Trips.create_trip(admin1, Map.merge(base_trip_attrs(), %{"departure_time" => "2031-06-01T10:00:00Z", "source_city" => "FutureB", "destination_city" => "DestB", "dates" => "2031-06-01"}))

    {:ok, _other} =
      Trips.create_trip(admin2, Map.merge(base_trip_attrs(), %{"departure_time" => "2030-05-01T10:00:00Z", "source_city" => "OtherFuture", "destination_city" => "DestOther", "dates" => "2030-05-01"}))

    result = Trips.list_future_trips_for_admin(admin1)

    assert Enum.any?(result, &(&1.id == trip1.id))
    assert Enum.any?(result, &(&1.id == trip2.id))
    refute Enum.any?(result, &(&1.admin_id != admin1.id))

    # Ensure order: ascending by departure_time (older first)
    departure_times = Enum.map(result, & &1.departure_time)
    assert departure_times == Enum.sort(departure_times)
  end
end
